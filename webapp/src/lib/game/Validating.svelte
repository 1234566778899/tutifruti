<script lang="ts">
	import { fade } from 'svelte/transition';
	import { Lock, Search, Hourglass } from '@lucide/svelte';
	import { playerAvatar, playerName } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import LetterBadge from '#lib/components/LetterBadge.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import Avatar from '#lib/components/Avatar.svelte';

	let { game }: { game: Game } = $props();
	const letter = $derived(game.currentRound?.letter ?? '');
	const msgs = $derived([`Revisando que empiecen con la ${letter}…`, 'Consultando el diccionario…', '¿Pertenece a la categoría?…', 'Buscando respuestas repetidas…', 'Contando los puntos…']);
	let t = $state(0);
	$effect(() => { const s = performance.now(); const i = setInterval(() => (t = (performance.now() - s) / 1000), 100); return () => clearInterval(i); });
	const msg = $derived(msgs[Math.floor(t / 2.2) % msgs.length]);
	const progress = $derived(Math.min(0.95, 1 - Math.exp(-t / 6)));
	const scanning = $derived(Math.floor(t / 0.7) % Math.max(1, game.categories.length));
</script>

<div class="val stack">
	<div class="judge"><Mascot pose="judge" size={170} /><span class="lb"><LetterBadge {letter} size={52} /></span></div>
	<OutlinedTitle text="El árbitro está revisando" size={22} />
	{#key msg}<p class="msg" in:fade>{msg}</p>{/key}
	<div class="prog"><span style:width="{progress * 100}%"></span></div>
	<div class="avs">{#each game.activePlayers as p (p.user_id)}<Avatar avatar={playerAvatar(p)} name={playerName(p)} size={32} />{/each}</div>
	<p class="muted small center">{game.activePlayers.length * game.categories.length} respuestas de {game.activePlayers.length} jugadores</p>
	<h3 class="section-title">Tus respuestas <Lock size={14} /></h3>
	<div class="grid">
		{#each game.categories as cat, i (cat)}
			{@const on = i === scanning}
			{@const v = game.drafts[cat] ?? ''}
			<div class="card" class:on>
				<span class="tiny muted">{cat}</span>
				<b class:empty={!v}>{v || '—'}</b>
				<span class="st">{#if on}<Search size={12} /> Revisando…{:else}<Hourglass size={12} /> En espera{/if}</span>
			</div>
		{/each}
	</div>
	{#if game.aiFailed && game.aiAttempt < 3}<p class="muted small center">El árbitro tarda más de lo normal. Reintentando (intento {game.aiAttempt + 1} de 3)…</p>{/if}
</div>

<style>
	.val { align-items: center; padding-bottom: 30px; }
	.judge { position: relative; } .lb { position: absolute; right: -40px; top: 10px; rotate: 10deg; }
	.msg { margin: 0; color: var(--lemon); font-weight: 900; }
	.prog { width: min(100%, 320px); height: 10px; border-radius: 99px; background: rgba(255,255,255,.1); overflow: hidden; }
	.prog span { display: block; height: 100%; background: linear-gradient(90deg, var(--lemon), var(--tangerine)); transition: width .3s linear; }
	.avs { display: flex; } .avs :global(.av) { margin-left: -8px; box-shadow: 0 0 0 2px var(--deep); }
	.center { text-align: center; margin: 0; }
	.section-title { align-self: stretch; display: flex; gap: 6px; align-items: center; }
	.grid { align-self: stretch; display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 10px; }
	.card { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: 18px; background: var(--panel); border: 1.5px solid var(--panel-stroke);
		transition: transform .3s cubic-bezier(.3,1.6,.5,1), border-color .3s, background .3s; }
	.card.on { transform: scale(1.03); border-color: rgba(255,210,63,.7); background: rgba(255,210,63,.12); }
	.card b { font-size: 17px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; } .card b.empty { opacity: .4; }
	.st { display: inline-flex; align-items: center; gap: 4px; font-size: 12px; font-weight: 900; color: rgba(255,255,255,.45); }
	.card.on .st { color: var(--lemon); }
</style>
