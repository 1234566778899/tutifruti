<script lang="ts">
	import { goto } from '$app/navigation';
	import { ChevronLeft, Plus, Users, RotateCw, Timer, LayoutGrid } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { app } from '#lib/app.svelte.ts';
	import { sfx } from '#lib/sfx.ts';
	import type { PublicRoom } from '#lib/types.ts';
	import Avatar from '#lib/components/Avatar.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';

	let rooms = $state<PublicRoom[]>([]), loaded = $state(false), joining = $state<string | null>(null);
	$effect(() => {
		let alive = true;
		const load = async () => { try { const r = await API.publicRooms(); if (alive) rooms = r; } catch { /* reintenta */ } loaded = true; };
		load(); const t = setInterval(load, 5000);
		return () => { alive = false; clearInterval(t); };
	});
	async function join(r: PublicRoom) {
		joining = r.room_id;
		try { const id = r.is_member ? r.room_id : await API.joinPublicRoom(r.room_id); sfx('join'); goto(`/sala/${id}`); }
		catch (e) { app.showToast(friendlyError(e)); } finally { joining = null; }
	}
</script>

<main class="page stack">
	<header class="bar">
		<a class="iconbtn" href="/jugar" aria-label="Volver"><ChevronLeft /></a>
		<OutlinedTitle text="Salas públicas" size={22} />
		<a class="iconbtn" href="/crear?publica=1" aria-label="Crear sala pública"><Plus /></a>
	</header>

	{#if loaded && rooms.length === 0}
		<div class="empty stack">
			<Mascot pose="think" size={150} />
			<OutlinedTitle text="No hay salas abiertas" size={22} />
			<p class="muted">Crea una y aparecerá aquí para que otros jugadores se unan.</p>
			<CandyButton color="var(--lime)" icon={Plus} ink href="/crear?publica=1">Crear sala pública</CandyButton>
		</div>
	{:else}
		<h3 class="section-title">{rooms.length === 1 ? 'Sala abierta' : 'Salas abiertas'} · {rooms.length}</h3>
		<div class="list">
			{#each rooms as r, i (r.room_id)}
				{@const full = r.players >= r.max_players}
				<article class="panel room" style:animation-delay="{i * 50}ms">
					<Avatar avatar={r.host_avatar} name={r.host_name} size={50} />
					<div class="grow">
						<b class="nm">{r.name}</b>
						<div class="muted small">de {r.host_name} · Nivel {r.host_level}</div>
						<div class="meta">
							<span style:color={full ? 'var(--cherry)' : 'var(--lime)'}><Users size={12} /> {r.players}/{r.max_players}</span>
							<span><RotateCw size={12} /> {r.rounds_total}</span><span><Timer size={12} /> {r.round_seconds}s</span>
							<span><LayoutGrid size={12} /> {r.categories.length}</span>
						</div>
					</div>
					<button class="join" disabled={!!joining || (full && !r.is_member)} onclick={() => join(r)}>
						{joining === r.room_id ? '…' : r.is_member ? 'Volver' : full ? 'Llena' : 'Unirme'}
					</button>
				</article>
			{/each}
		</div>
		<p class="muted small">Puedes unirte hasta que el anfitrión inicie la partida. La lista se actualiza sola.</p>
	{/if}
</main>

<style>
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.empty { align-items: center; text-align: center; padding-top: 30px; }
	.list { display: grid; gap: 10px; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); }
	.room { display: flex; align-items: center; gap: 12px; animation: pop .45s cubic-bezier(.3,1.6,.5,1) both; }
	@keyframes pop { from { opacity: 0; transform: scale(.85) translateY(12px); } }
	.nm { display: block; font-size: 17px; }
	.meta { display: flex; gap: 10px; margin-top: 4px; font-size: 12px; font-weight: 900; color: rgba(255,255,255,.65); }
	.meta span { display: inline-flex; align-items: center; gap: 3px; }
	.join { height: 40px; padding: 0 16px; border: 0; border-radius: 99px; background: var(--tangerine); color: var(--ink); font-weight: 900; font-size: 15px; cursor: pointer;
		box-shadow: inset 0 -3px 0 rgba(0,0,0,.2); }
	.join:disabled { background: gray; cursor: default; }
	@media (min-width: 900px) { main { max-width: 900px; } }
</style>
