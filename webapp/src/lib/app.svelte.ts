import { supabase } from './supabase';
import * as API from './api';
import { syncClock } from './clock';
import { sfx } from './sfx';
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { AppNotification, Profile } from './types';

type Phase = 'loading' | 'signedOut' | 'needsProfile' | 'ready';

/** Sesión, perfil y avisos globales (equivalente a AppState.swift). */
class AppState {
	phase = $state<Phase>('loading');
	profile = $state<Profile | null>(null);
	isGuest = $state(false);
	toast = $state<string | null>(null);
	/** Enlace abierto antes de iniciar sesión (sala o amistad). */
	pendingJoinCode = $state<string | null>(null);
	pendingFriendToken = $state<string | null>(null);
	private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
	private toastTimer: ReturnType<typeof setTimeout> | null = null;
	activeRoom = $state<string | null>(null);
	/** Notificaciones in-app (tabla notifications + realtime), igual que iOS. */
	notifications = $state<AppNotification[]>([]);
	unread = $derived(this.notifications.filter((n) => !n.read).length);
	muted = $state<Set<string>>(new Set());
	/** El usuario llegó desde el enlace de "recuperar contraseña". */
	recovering = $state(false);
	email = $state<string | null>(null);
	private notifChannel: RealtimeChannel | null = null;
	private started = false;

	start() {
		if (this.started) return;
		this.started = true;
		supabase.auth.onAuthStateChange((event, session) => {
			this.isGuest = session?.user.is_anonymous ?? false;
			this.email = session?.user.email ?? null;
			if (event === 'PASSWORD_RECOVERY') this.recovering = true;
			if (event === 'INITIAL_SESSION') {
				if (!session) this.phase = 'signedOut';
				else void this.loadProfile();
			} else if (event === 'SIGNED_IN' || event === 'USER_UPDATED') {
				if (this.phase !== 'ready') void this.loadProfile();
			} else if (event === 'SIGNED_OUT') {
				this.stopHeartbeat();
				this.stopNotifications();
				this.profile = null;
				this.notifications = [];
				this.phase = 'signedOut';
			}
		});
		document.addEventListener('visibilitychange', () => {
			if (document.visibilityState === 'visible' && this.phase === 'ready') {
				void syncClock();
				void API.heartbeat(this.activeRoom);
				void this.refreshProfile();
			}
		});
	}

	async loadProfile() {
		try {
			const p = await API.myProfile();
			if (p) {
				this.profile = p;
				if (this.phase !== 'ready') {
					this.phase = 'ready';
					this.startHeartbeat();
					void this.startNotifications(p.id);
					await syncClock();
				}
			} else {
				this.phase = 'needsProfile';
			}
		} catch {
			if (this.phase === 'loading') this.phase = 'signedOut';
		}
	}

	async refreshProfile() {
		try { const p = await API.myProfile(); if (p) this.profile = p; } catch { /* reintenta luego */ }
	}

	private startHeartbeat() {
		this.stopHeartbeat();
		void API.heartbeat(this.activeRoom);
		this.heartbeatTimer = setInterval(() => void API.heartbeat(this.activeRoom), 20_000);
	}
	private stopHeartbeat() {
		if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
		this.heartbeatTimer = null;
	}

	private async startNotifications(userId: string) {
		this.stopNotifications();
		try { this.notifications = await API.notifications(); } catch { /* luego */ }
		API.mutedIds().then((m) => (this.muted = m)).catch(() => {});
		this.notifChannel = supabase.channel(`notif-${userId}`)
			.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` }, (msg) => {
				const n = msg.new as AppNotification;
				this.notifications = [n, ...this.notifications.filter((x) => x.id !== n.id)];
				// Dentro de una partida no interrumpe con avisos de resultados (ya se ven en pantalla).
				if (!(this.activeRoom && n.kind === 'results')) this.showToast(n.title);
				if (n.kind === 'achievement' || n.kind === 'level_up') void this.refreshProfile();
			})
			.subscribe();
	}
	private stopNotifications() {
		if (this.notifChannel) { void supabase.removeChannel(this.notifChannel); this.notifChannel = null; }
	}
	async refreshNotifications() {
		try { this.notifications = await API.notifications(); } catch { /* sin conexión */ }
	}
	async markAllRead() {
		this.notifications = this.notifications.map((n) => ({ ...n, read: true }));
		await API.markAllRead().catch(() => {});
	}
	async deleteNotification(id: number) {
		this.notifications = this.notifications.filter((n) => n.id !== id);
		await API.deleteNotification(id);
	}

	showToast(text: string, sound = true) {
		this.toast = text;
		if (sound) sfx('notify', 0.6);
		if (this.toastTimer) clearTimeout(this.toastTimer);
		this.toastTimer = setTimeout(() => (this.toast = null), 3200);
	}

	async signInGuest() {
		const { error } = await supabase.auth.signInAnonymously();
		if (error) throw error;
	}
	async signIn(email: string, password: string) {
		const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
		if (error) throw error;
	}
	async signUp(email: string, password: string): Promise<boolean> {
		const { data, error } = await supabase.auth.signUp({ email: email.trim(), password, options: { emailRedirectTo: `${location.origin}/jugar` } });
		if (error) throw error;
		return data.session != null;
	}
	async signOut() { await supabase.auth.signOut(); }
	async resetPassword(email: string) {
		const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${location.origin}/restablecer` });
		if (error) throw error;
	}
	async updatePassword(password: string) {
		const { error } = await supabase.auth.updateUser({ password });
		if (error) throw error;
		this.recovering = false;
	}
	/**
	 * Invitado → cuenta con correo, conservando nivel y progreso (se vincula a la misma cuenta).
	 * Paso 1: Supabase envía un correo de confirmación. Paso 2: al volver con la cuenta confirmada
	 * se pide crear la contraseña (Supabase no permite contraseña en anónimos sin correo verificado).
	 */
	async saveGuestWithEmail(email: string) {
		const { error } = await supabase.auth.updateUser({ email: email.trim() }, { emailRedirectTo: `${location.origin}/jugar` });
		if (error) throw error;
		try { localStorage.setItem('needsPassword', '1'); } catch { /* privado */ }
	}
	get needsPassword() {
		try { return !this.isGuest && !!this.email && localStorage.getItem('needsPassword') === '1'; } catch { return false; }
	}
	async createPassword(password: string) {
		await this.updatePassword(password);
		try { localStorage.removeItem('needsPassword'); } catch { /* privado */ }
	}
	/** Sale del modo invitado borrando la cuenta temporal (igual que iOS). */
	async leaveGuestMode() {
		if (this.isGuest) { try { await API.deleteAccount(); } catch { /* ya no existe */ } }
		await this.signOut();
	}
	/** Borra la cuenta (y todo su progreso) y cierra sesión. */
	async deleteAccount() {
		await API.deleteAccount();
		await this.signOut();
	}
}

export const app = new AppState();
