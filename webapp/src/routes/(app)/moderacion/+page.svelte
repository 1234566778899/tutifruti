<script lang="ts">
	import { ChevronLeft, Ban, Check, RotateCcw, MessageSquare } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import type { AdminReport } from '#lib/types.ts';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import Segmented from '#lib/components/Segmented.svelte';
	import Mascot from '#lib/components/Mascot.svelte';

	/** Panel de moderación: reportes de jugadores (tabla reports). Solo para profiles.is_admin. */
	let filter = $state<'open' | 'all'>('open');
	let reports = $state<AdminReport[]>([]), loading = $state(true), busy = $state<string | null>(null);
	let days = $state<Record<string, string>>({});

	async function load() {
		loading = true;
		try { reports = await API.adminReports(filter); } catch (e) { app.showToast(friendlyError(e)); } finally { loading = false; }
	}
	$effect(() => { void filter; if (app.profile?.is_admin) void load(); });

	async function act(r: AdminReport, fn: () => Promise<void>, msg: string) {
		busy = r.id;
		try { await fn(); app.showToast(msg, false); await load(); } catch (e) { app.showToast(friendlyError(e)); } finally { busy = null; }
	}
	const ban = (r: AdminReport) => {
		const d = days[r.id] ?? '7';
		return act(r, () => API.adminResolveReport(r.id, 'ban', d === 'forever' ? null : Number(d)),
			`${r.reported_name} suspendido ${d === 'forever' ? 'para siempre' : `${d} días`}`);
	};
	const banned = (r: AdminReport) => !!r.reported_banned_until && new Date(r.reported_banned_until) > new Date();
	const fmt = (iso: string) => new Date(iso).toLocaleString('es', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
</script>

<svelte:head><title>Moderación · Tutifruti</title></svelte:head>

<main class="page stack wide">
	<header class="bar"><a class="iconbtn" href="/perfil" aria-label="Volver"><ChevronLeft /></a><OutlinedTitle text="Moderación" size={22} /><span></span></header>

	{#if !app.profile?.is_admin}
		<div class="empty stack"><Mascot pose="stop" size={140} /><p class="muted">Esta sección es solo para administradores.</p></div>
	{:else}
		<Segmented bind:value={filter} options={[['open', 'Pendientes'], ['all', 'Todos']]} />
		{#if loading && reports.length === 0}
			<p class="muted">Cargando…</p>
		{:else if reports.length === 0}
			<div class="empty stack"><Mascot pose="party" size={140} /><p class="muted">No hay reportes {filter === 'open' ? 'pendientes' : ''}.</p></div>
		{/if}
		{#each reports as r (r.id)}
			<article class="panel stack rep">
				<div class="row">
					<Avatar avatar={r.reported_avatar} name={r.reported_name} size={44} />
					<div class="grow">
						<b>{r.reported_name}</b>
						<div class="muted small">{r.reports_against} reporte{r.reports_against === 1 ? '' : 's'} en total{#if banned(r)} · <span class="bad">suspendido hasta {r.reported_banned_until?.startsWith('infinity') ? 'siempre' : fmt(r.reported_banned_until!)}</span>{/if}</div>
					</div>
					<span class="tag" class:open={r.status === 'open'}>{r.status === 'open' ? 'Pendiente' : r.resolution ?? r.status}</span>
				</div>
				<p class="reason"><b>{r.reason}</b>{#if r.details} · {r.details}{/if}</p>
				<p class="tiny muted">Reportado por {r.reporter_name ?? 'cuenta borrada'} · {fmt(r.created_at)}{#if r.room_code} · sala {r.room_code}{/if}</p>
				{#if r.recent_messages.length}
					<details>
						<summary><MessageSquare size={14} /> Mensajes recientes ({r.recent_messages.length})</summary>
						<ul class="msgs">{#each r.recent_messages as m}<li><span class="tiny muted">{fmt(m.at)}</span> {m.body}</li>{/each}</ul>
					</details>
				{/if}
				<div class="actions">
					{#if r.status === 'open'}
						<button class="btn" disabled={busy === r.id} onclick={() => act(r, () => API.adminResolveReport(r.id, 'dismiss'), 'Reporte descartado')}><Check size={16} /> Descartar</button>
						<select bind:value={days[r.id]} aria-label="Duración de la suspensión">
							<option value="1">1 día</option><option value="7" selected>7 días</option><option value="30">30 días</option><option value="forever">Para siempre</option>
						</select>
						<button class="btn danger" disabled={busy === r.id} onclick={() => ban(r)}><Ban size={16} /> Suspender</button>
					{/if}
					{#if banned(r)}
						<button class="btn" disabled={busy === r.id} onclick={() => act(r, () => API.adminUnban(r.reported), 'Suspensión levantada')}><RotateCcw size={16} /> Levantar suspensión</button>
					{/if}
				</div>
			</article>
		{/each}
	{/if}
</main>

<style>
	.wide { max-width: 820px; }
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.empty { align-items: center; text-align: center; padding: 30px 0; }
	.rep { gap: 8px; }
	.row { display: flex; align-items: center; gap: 12px; }
	.grow { flex: 1; min-width: 0; }
	.reason { margin: 0; }
	.bad { color: var(--cherry); font-weight: 800; }
	.tag { font-size: 12px; font-weight: 800; padding: 4px 10px; border-radius: 99px; background: var(--panel); white-space: nowrap; }
	.tag.open { background: var(--lemon); color: var(--ink); }
	summary { cursor: pointer; font-weight: 800; display: flex; align-items: center; gap: 6px; }
	.msgs { margin: 8px 0 0; padding-left: 18px; display: grid; gap: 4px; }
	.actions { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
	.btn { display: inline-flex; align-items: center; gap: 6px; padding: 9px 14px; border-radius: 14px; border: 1.5px solid var(--panel-stroke);
		background: var(--panel); color: #fff; font: inherit; font-weight: 800; cursor: pointer; }
	.btn.danger { background: var(--cherry); border-color: transparent; }
	.btn:disabled { opacity: .5; }
	select { background: var(--panel); color: #fff; border: 1.5px solid var(--panel-stroke); border-radius: 12px; padding: 8px 10px; font: inherit; font-weight: 800; }
	select option { color: #000; }
</style>
