<script lang="ts">
	import { goto } from '$app/navigation';
	import { ChevronLeft, CheckCheck, Trash2, DoorOpen, UserPlus, Trophy, Award, ChartBar, Bell, Wifi } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import type { AppNotification } from '#lib/types.ts';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import Mascot from '#lib/components/Mascot.svelte';

	/** Avisos in-app (mismo origen que iOS: tabla notifications). */
	let joining = $state<number | null>(null);
	const ICONS: Record<string, [any, string]> = {
		room_invite: [DoorOpen, 'var(--sky)'], friend_request: [UserPlus, 'var(--lime)'], achievement: [Award, 'var(--lemon)'],
		level_up: [Trophy, 'var(--tangerine)'], results: [ChartBar, 'var(--grape)'], friend_online: [Wifi, 'var(--lime)']
	};
	$effect(() => {
		void app.refreshNotifications();
		// Al salir de la pantalla se marcan como leídas.
		return () => void app.markAllRead();
	});
	function ago(iso: string) {
		const m = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
		if (m < 1) return 'ahora';
		if (m < 60) return `hace ${m} min`;
		const h = Math.round(m / 60); if (h < 24) return `hace ${h} h`;
		const d = Math.round(h / 24); return d === 1 ? 'ayer' : `hace ${d} días`;
	}
	async function openN(n: AppNotification) {
		if (n.kind === 'room_invite' && n.payload?.code) {
			joining = n.id;
			try { const id = await API.joinByCode(n.payload.code); sfx('join'); goto(`/sala/${id}`); }
			catch (e) { app.showToast(friendlyError(e)); } finally { joining = null; }
		} else if (n.kind === 'friend_request' || n.kind === 'friend_online') goto('/amigos');
		else if (n.kind === 'achievement' || n.kind === 'level_up') goto('/perfil');
	}
</script>

<main class="page stack">
	<header class="bar">
		<a class="iconbtn" href="/jugar" aria-label="Volver"><ChevronLeft /></a>
		<OutlinedTitle text="Avisos" size={22} />
		<button class="iconbtn" aria-label="Marcar todo como leído" disabled={app.unread === 0} onclick={() => app.markAllRead()}><CheckCheck size={19} /></button>
	</header>

	{#if app.notifications.length === 0}
		<div class="empty stack"><Mascot pose="sleep" size={150} /><OutlinedTitle text="Todo tranquilo" size={22} /><p class="muted">Aquí verás invitaciones a salas, solicitudes de amistad y logros.</p></div>
	{:else}
		<section class="list">
			{#each app.notifications as n (n.id)}
				{@const [Icon, c] = ICONS[n.kind] ?? [Bell, 'var(--lemon)']}
				<div class="panel n" class:unread={!n.read}>
					<button class="main" onclick={() => openN(n)} disabled={joining === n.id}>
						<span class="ic" style:background={c}><Icon size={20} strokeWidth={2.6} /></span>
						<span class="grow txt"><b>{n.title}</b>{#if n.body}<span class="muted small">{n.body}</span>{/if}
							<span class="tiny muted">{ago(n.created_at)}{n.kind === 'room_invite' && n.payload?.code ? ` · ${joining === n.id ? 'Entrando…' : 'Toca para unirte'}` : ''}</span></span>
					</button>
					<button class="del" aria-label="Borrar aviso" onclick={() => app.deleteNotification(n.id)}><Trash2 size={16} /></button>
				</div>
			{/each}
		</section>
	{/if}
</main>

<style>
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); cursor: pointer; }
	.iconbtn:disabled { opacity: .4; cursor: default; }
	.empty { align-items: center; text-align: center; padding-top: 30px; }
	.list { display: grid; gap: 10px; }
	.n { display: flex; align-items: center; gap: 4px; padding: 6px 6px 6px 12px; }
	.n.unread { border-color: rgba(255,210,63,.55); background: rgba(255,210,63,.08); }
	.main { flex: 1; display: flex; align-items: center; gap: 12px; padding: 6px 0; background: none; border: 0; color: #fff; font: inherit; text-align: left; cursor: pointer; min-width: 0; }
	.ic { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 50%; color: var(--ink); flex: none; }
	.txt { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
	.del { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 50%; border: 0; background: none; color: rgba(255,255,255,.4); cursor: pointer; flex: none; }
	.del:hover { color: #ff8aa0; }
</style>
