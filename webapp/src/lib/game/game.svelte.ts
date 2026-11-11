import type { RealtimeChannel } from '@supabase/supabase-js';
import { supabase } from '../supabase';
import { app } from '../app.svelte';
import * as API from '../api';
import { serverNow, syncClock } from '../clock';
import { friendlyError, isNetworkError } from '../errors';
import { isConnected, type Answer, type ChatMessage, type Dispute, type Reaction, type Room, type RoomPlayer, type Round } from '../types';

export type GamePhase = 'loading' | 'lobby' | 'matchmaking' | 'letterDraw' | 'answering' | 'validating' | 'results' | 'finished' | 'cancelled';

/**
 * Estado en vivo de una sala (port de GameStore.swift). El servidor es la autoridad:
 * aquí solo se refleja su estado y se disparan las mismas RPC idempotentes que en iOS.
 */
export class Game {
	readonly roomId: string;
	me: string | null = null;

	room = $state<Room | null>(null);
	players = $state<RoomPlayer[]>([]);
	rounds = $state<Round[]>([]);
	chat = $state<ChatMessage[]>([]);
	now = $state(serverNow());

	drafts = $state<Record<string, string>>({});
	saved = $state<Record<string, string>>({});
	roundAnswers = $state<Answer[]>([]);
	loadedResultsFor = $state<string | null>(null);
	reactions = $state<Reaction[]>([]);
	disputes = $state<Dispute[]>([]);

	aiFailed = $state(false);
	aiAttempt = $state(0);
	isOffline = $state(false);
	reconnecting = $state(false);
	errorMessage = $state<string | null>(null);
	notice = $state<string | null>(null);
	unreadChat = $state(0);
	chatOpen = $state(false);
	incomingMessage = $state<ChatMessage | null>(null);

	private channel: RealtimeChannel | null = null;
	private ticker: ReturnType<typeof setInterval> | null = null;
	private saveTimers: Record<string, ReturnType<typeof setTimeout>> = {};
	private throttles = new Map<string, number>();
	private lastRoundId: string | null = null;
	private validatingNow = false;
	private lastRefresh = 0;
	private refreshTimer: ReturnType<typeof setTimeout> | null = null;
	private resyncing = false;
	private noticeTimer: ReturnType<typeof setTimeout> | null = null;
	private onlineHandler = () => { this.isOffline = false; void this.resync(); };
	private offlineHandler = () => { this.isOffline = true; };
	private visibilityHandler = () => {
		if (document.visibilityState === 'visible') void this.resync();
		else { const r = this.currentRound; if (r?.status === 'playing') void this.flushAll(r.id); }
	};

	constructor(roomId: string) {
		this.roomId = roomId;
	}

	// Derivados
	get currentRound(): Round | undefined { return this.rounds[this.rounds.length - 1]; }
	get activePlayers() { return this.players.filter((p) => !p.left_at); }
	get myPlayer() { return this.players.find((p) => p.user_id === this.me); }
	get isHost() { return !!this.room?.host_id && this.room.host_id === this.me; }
	get categories() { return this.room?.categories ?? []; }
	player(id: string | null | undefined) { return this.players.find((p) => p.user_id === id); }

	get phase(): GamePhase {
		const room = this.room;
		if (!room) return 'loading';
		if (room.status === 'waiting') return room.host_id == null ? 'matchmaking' : 'lobby';
		if (room.status === 'finished') return 'finished';
		if (room.status === 'cancelled') return 'cancelled';
		const r = this.currentRound;
		if (!r) return 'loading';
		if (r.status === 'playing') return this.now < new Date(r.starts_at).getTime() ? 'letterDraw' : 'answering';
		if (r.status === 'validating') return 'validating';
		return 'results';
	}

	get secondsLeft() {
		const r = this.currentRound;
		return r ? Math.max(0, Math.ceil((new Date(r.close_at).getTime() - this.now) / 1000)) : 0;
	}
	get secondsToStart() {
		const r = this.currentRound;
		return r ? Math.max(0, Math.ceil((new Date(r.starts_at).getTime() - this.now) / 1000)) : 0;
	}
	get stopCaller() { return this.player(this.currentRound?.stop_by); }

	startsWithLetter(v: string) {
		const letter = this.currentRound?.letter ?? '';
		const t = v.trim();
		if (t.length < 2 || !letter) return false;
		const norm = t.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase();
		return norm.startsWith(letter === 'Ñ' ? 'N' : letter);
	}
	get filledCount() { return this.categories.filter((c) => this.startsWithLetter(this.drafts[c] ?? '')).length; }
	/** 75 % de las categorías, redondeado hacia arriba (igual que `stop_threshold` en el servidor). */
	get stopThreshold() { return Math.max(1, Math.ceil(this.categories.length * 0.75)); }
	get canStop() { return this.filledCount >= this.stopThreshold; }
	isSaved(c: string) { const d = (this.drafts[c] ?? '').trim(); return d !== '' && this.saved[c] === d; }

	// Listos
	get readyIds() { return new Set(this.currentRound?.ready_users ?? []); }
	get iAmReady() { return !!this.me && this.readyIds.has(this.me); }
	get playersToWait() { return this.activePlayers.filter((p) => isConnected(p, this.now) || this.readyIds.has(p.user_id)); }
	get everyoneReady() { const w = this.playersToWait; return w.length > 0 && w.every((p) => this.readyIds.has(p.user_id)); }

	// Resultados
	points(user: string | null) { return this.roundAnswers.filter((a) => a.user_id === user).reduce((s, a) => s + a.points, 0); }
	get roundRanking() {
		return this.activePlayers.map((p) => ({ player: p, points: this.points(p.user_id) })).sort((a, b) => b.points - a.points);
	}
	answersFor(cat: string) {
		return this.roundAnswers.filter((a) => a.category === cat)
			.sort((a, b) => (this.player(a.user_id)?.joined_at ?? '').localeCompare(this.player(b.user_id)?.joined_at ?? ''));
	}

	// Ciclo de vida
	async start() {
		this.me = await API.myId();
		await this.refresh();
		try { this.chat = await API.chat(this.roomId); } catch { /* reintenta en resync */ }
		this.subscribe();
		this.ticker = setInterval(() => {
			this.now = serverNow();
			void this.healthCheck();
			void this.drive();
		}, 250);
		window.addEventListener('online', this.onlineHandler);
		window.addEventListener('offline', this.offlineHandler);
		document.addEventListener('visibilitychange', this.visibilityHandler);
		this.isOffline = !navigator.onLine;
	}

	async stop() {
		if (this.ticker) clearInterval(this.ticker);
		Object.values(this.saveTimers).forEach(clearTimeout);
		window.removeEventListener('online', this.onlineHandler);
		window.removeEventListener('offline', this.offlineHandler);
		document.removeEventListener('visibilitychange', this.visibilityHandler);
		if (this.channel) await supabase.removeChannel(this.channel);
		this.channel = null;
	}

	private subscribe() {
		const ch = supabase.channel(`room-${this.roomId}-${Math.floor(Math.random() * 99999)}`);
		const refresh = () => this.scheduleRefresh();
		ch.on('postgres_changes', { event: '*', schema: 'public', table: 'rooms', filter: `id=eq.${this.roomId}` }, refresh)
			.on('postgres_changes', { event: '*', schema: 'public', table: 'room_players', filter: `room_id=eq.${this.roomId}` }, (p) => {
				// El latido de cada jugador (cada 20 s) solo cambia last_seen: se aplica en local sin recargar la sala.
				if (p.eventType === 'UPDATE' && this.applyHeartbeat(p.new as RoomPlayer)) return;
				refresh();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'rounds', filter: `room_id=eq.${this.roomId}` }, refresh)
			.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `room_id=eq.${this.roomId}` }, (p) => {
				const m = p.new as ChatMessage;
				if (!this.chat.some((x) => x.id === m.id)) this.chat = [...this.chat, m];
				if (!this.chatOpen && m.user_id !== this.me && m.kind === 'msg' && !(m.user_id && app.muted.has(m.user_id))) { this.unreadChat += 1; this.incomingMessage = m; }
			})
			// Filtrada por sala: sin filtro, Realtime comprueba el permiso de todos los conectados en cada cambio.
			.on('postgres_changes', { event: '*', schema: 'public', table: 'reactions', filter: `room_id=eq.${this.roomId}` }, (p) => {
				const rid = this.currentRound?.id;
				const row = (p.new ?? p.old) as Partial<Reaction>;
				if (rid && row.round_id === rid) API.reactions(rid).then((r) => (this.reactions = r)).catch(() => {});
			})
			.subscribe();
		this.channel = ch;
	}

	/** Si el cambio es solo el latido, actualiza last_seen y devuelve true (no hace falta recargar). */
	private applyHeartbeat(row: RoomPlayer): boolean {
		const i = this.players.findIndex((x) => x.user_id === row.user_id);
		if (i < 0) return false;
		const p = this.players[i];
		const same = p.ready === row.ready && p.score === row.score && p.disputes_left === row.disputes_left
			&& p.final_rank === row.final_rank && p.xp_gained === row.xp_gained
			&& (p.left_at ? new Date(p.left_at).getTime() : null) === (row.left_at ? new Date(row.left_at).getTime() : null);
		if (!same) return false;
		this.players[i] = { ...p, last_seen: row.last_seen };
		return true;
	}

	private scheduleRefresh() {
		if (this.refreshTimer) clearTimeout(this.refreshTimer);
		this.refreshTimer = setTimeout(() => void this.refresh(), 150);
	}

	async refresh() {
		try {
			const [room, players, rounds] = await Promise.all([API.room(this.roomId), API.players(this.roomId), API.rounds(this.roomId)]);
			this.room = room; this.players = players; this.rounds = rounds;
			this.lastRefresh = Date.now();
		} catch (e) {
			if (isNetworkError(e)) return;
			this.errorMessage = friendlyError(e);
			return;
		}
		const r = this.currentRound;
		if (r) {
			if (r.id !== this.lastRoundId) {
				this.lastRoundId = r.id;
				this.aiFailed = false; this.aiAttempt = 0;
				this.drafts = {}; this.saved = {};
				try {
					for (const a of await API.myAnswers(r.id)) { this.drafts[a.category] = a.value; this.saved[a.category] = a.value; }
				} catch { /* sin respuestas previas */ }
			}
			if (r.status === 'results') await this.loadResults(r.id, this.loadedResultsFor === r.id && this.roundAnswers.length === 0);
		}
	}

	async loadResults(roundId: string, force = false) {
		if (this.loadedResultsFor === roundId && !force) return;
		try {
			const [answers, reactions, disputes] = await Promise.all([
				API.answers(roundId), API.reactions(roundId).catch(() => [] as Reaction[]), API.disputes(roundId).catch(() => [] as Dispute[])
			]);
			this.roundAnswers = answers; this.reactions = reactions; this.disputes = disputes;
			this.loadedResultsFor = roundId;
		} catch (e) {
			if (!isNetworkError(e)) this.report(e);
		}
	}

	async resync() {
		if (this.resyncing) return;
		this.resyncing = true; this.reconnecting = true;
		try {
			await syncClock();
			await API.heartbeat(this.roomId);
			if (this.channel) await supabase.removeChannel(this.channel);
			this.channel = null;
			this.subscribe();
			await this.refresh();
			const r = this.currentRound;
			if (r?.status === 'results') await this.loadResults(r.id, true);
			if (r?.status === 'playing') await this.flushAll(r.id);
			try { this.chat = await API.chat(this.roomId); } catch { /* luego */ }
		} finally { this.resyncing = false; this.reconnecting = false; }
	}

	private async healthCheck() {
		if (this.isOffline || this.resyncing) return;
		if (Date.now() - this.lastRefresh > 10_000 && this.throttle('poll', 10_000)) await this.refresh();
	}

	private throttle(key: string, ms: number) {
		const last = this.throttles.get(key) ?? 0;
		if (Date.now() - last < ms) return false;
		this.throttles.set(key, Date.now());
		return true;
	}

	private get validatorId() {
		const active = this.activePlayers.filter((p) => isConnected(p, this.now));
		const host = this.room?.host_id;
		if (host && active.some((p) => p.user_id === host)) return host;
		return (active[0] ?? this.activePlayers[0])?.user_id;
	}

	/** Motor de transiciones (idéntico a iOS): cerrar ronda, validar con IA, avanzar cuando todos están listos. */
	private async drive() {
		if (this.isOffline || !this.room) return;
		const r = this.currentRound;
		switch (this.phase) {
			case 'answering':
				if (r && this.now >= new Date(r.close_at).getTime() && this.throttle(`close-${r.id}`, 2000)) {
					await this.flushAll(r.id);
					try { if ((await API.closeRound(r.id)) === 'validating') await this.refresh(); } catch { /* reintenta */ }
				}
				break;
			case 'validating': {
				if (!r) return;
				const started = r.validation_started_at ? new Date(r.validation_started_at).getTime() : this.now;
				if (this.validatorId === this.me && !this.validatingNow && this.throttle(`ai-${r.id}-${this.aiAttempt}`, 4000)) {
					await this.runAIValidation(r.id);
				} else if (this.now - started > 25_000 && this.throttle(`basic-${r.id}`, 5000)) {
					try { await API.validateBasic(r.id); } catch { /* otro jugador ya lo hizo */ }
					await this.refresh();
				}
				break;
			}
			case 'results':
				if (r && this.loadedResultsFor !== r.id && this.throttle(`res-${r.id}`, 2000)) await this.loadResults(r.id);
				if (r && this.everyoneReady && this.throttle(`adv-${r.id}`, 3000)) {
					try { await API.advance(this.roomId); } catch { /* reintenta */ }
					await this.refresh();
				}
				break;
		}
	}

	private async runAIValidation(roundId: string) {
		this.validatingNow = true;
		try {
			await API.validateWithAI(roundId);
			this.aiFailed = false;
		} catch {
			this.aiAttempt += 1; this.aiFailed = true;
			if (this.aiAttempt >= 3) { try { await API.validateBasic(roundId); } catch { /* ya validada */ } }
		} finally { this.validatingNow = false; }
		await this.refresh();
	}

	// Respuestas
	setDraft(cat: string, value: string) {
		this.drafts[cat] = value.slice(0, 40);
		clearTimeout(this.saveTimers[cat]);
		this.saveTimers[cat] = setTimeout(() => { const r = this.currentRound; if (r) void this.save(r.id, cat); }, 600);
	}
	private async save(roundId: string, cat: string) {
		const v = (this.drafts[cat] ?? '').trim();
		if (this.saved[cat] === v) return;
		try { await API.saveAnswer(roundId, cat, v); this.saved[cat] = v; }
		catch (e) { if (!this.isOffline && !isNetworkError(e)) this.errorMessage = friendlyError(e); }
	}
	async flushAll(roundId: string) { await Promise.all(this.categories.map((c) => this.save(roundId, c))); }

	// Acciones del jugador (con reintentos ante cortes de red)
	private async retrying<T>(op: () => Promise<T>): Promise<T> {
		for (let attempt = 1; ; attempt++) {
			try { return await op(); }
			catch (e) {
				if (!isNetworkError(e) || attempt >= 3) throw e;
				await new Promise((res) => setTimeout(res, 600 * attempt));
			}
		}
	}
	private report(e: unknown) {
		if (isNetworkError(e)) { this.showNotice('Sin conexión · reintentando…'); void this.resync(); return; }
		this.errorMessage = friendlyError(e);
	}
	showNotice(text: string) {
		this.notice = text;
		if (this.noticeTimer) clearTimeout(this.noticeTimer);
		this.noticeTimer = setTimeout(() => (this.notice = null), 3000);
	}

	async callStop() {
		const r = this.currentRound; if (!r) return;
		await this.flushAll(r.id);
		try { await this.retrying(() => API.callStop(r.id)); } catch (e) { this.report(e); }
		await this.refresh();
	}
	async setReady(ready: boolean) {
		try { await API.setReady(this.roomId, ready); } catch (e) { this.report(e); }
		await this.refresh();
	}
	async startGame() {
		try { await this.retrying(() => API.startGame(this.roomId)); } catch (e) { this.report(e); }
		await this.refresh();
	}
	async toggleReady() {
		const r = this.currentRound; if (!r || !this.me) return;
		const want = !this.iAmReady;
		const set = new Set(r.ready_users ?? []);
		if (want) set.add(this.me); else set.delete(this.me);
		r.ready_users = [...set];
		this.rounds = [...this.rounds];
		try { await this.retrying(() => API.setRoundReady(r.id, want)); } catch (e) { this.report(e); }
		await this.refresh();
	}
	async leave() { try { await API.leaveRoom(this.roomId); } catch { /* ya fuera */ } }
	disputeFor(a: Answer) {
		return this.disputes.find((d) => d.target_user === a.user_id && d.category === a.category);
	}
	async react(category: string, emoji: string) {
		const r = this.currentRound; if (!r || !this.me) return;
		const me = this.me;
		this.reactions = [...this.reactions.filter((x) => !(x.user_id === me && x.category === category)), { round_id: r.id, user_id: me, category, emoji }];
		try { await API.react(r.id, category, emoji); } catch (e) { this.report(e); }
	}
	/** Impugna una respuesta: la registra, la resuelve una segunda IA y recarga resultados. */
	async dispute(a: Answer, kind: string, justification: string): Promise<Dispute> {
		const id = await API.submitDispute(a.round_id, a.user_id, a.category, kind, justification.trim());
		const d = await API.resolveDispute(id);
		await this.refresh();
		await this.loadResults(a.round_id, true);
		return d;
	}

	async sendChat(text: string) {
		const t = text.trim(); if (!t) return;
		try { await this.retrying(() => API.sendChat(this.roomId, t.slice(0, 300))); } catch (e) { this.report(e); }
	}
}
