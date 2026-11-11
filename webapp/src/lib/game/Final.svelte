<script lang="ts">
	import { goto } from '$app/navigation';
	import { Crown, Home, RotateCw, Star } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import { playerAvatar, playerName } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Confetti from '#lib/components/Confetti.svelte';

	let { game }: { game: Game } = $props();
	let confetti = $state(0), loading = $state(false);
	const ranking = $derived([...game.players].sort((a, b) => (a.final_rank ?? 99) - (b.final_rank ?? 99) || b.score - a.score));
	const winners = $derived(ranking.filter((p) => p.final_rank === 1));
	const iWon = $derived(winners.some((p) => p.user_id === game.me));
	$effect(() => {
		const t = setTimeout(() => {
			if (iWon) { sfx('win'); confetti++; } else if ((game.myPlayer?.final_rank ?? 9) <= 3) sfx('win', .6); else sfx('lose');
			void app.refreshProfile();
		}, 300);
		return () => clearTimeout(t);
	});
	async function again() {
		loading = true;
		try { const r = await API.rematch(game.roomId); await game.stop(); goto(`/sala/${r.id}`, { replaceState: true }); }
		catch (e) { app.showToast(friendlyError(e)); } finally { loading = false; }
	}
	const w = $derived(winners[0]);
</script>

<Confetti trigger={confetti} count={140} />
<div class="fin stack">
	{#if w}
		<Mascot pose={iWon ? 'party' : 'hello'} size={130} />
		<div class="win"><Avatar avatar={playerAvatar(w)} name={playerName(w)} size={84} /><span class="crown"><Crown size={26} fill="var(--lemon)" color="var(--tangerine)" /></span></div>
		<h2 class="title">{winners.length > 1 ? (iWon ? '¡Empate!' : 'Empate') : iWon ? '¡Ganaste!' : `${playerName(w)} gana`}</h2>
		<p class="muted">{winners.length > 1 ? `${winners.map(playerName).join(' y ')} · ${w.score} pts` : `${w.score} pts · ${game.room?.rounds_total} rondas`}</p>
	{/if}
	<h3 class="section-title self">Clasificación</h3>
	<section class="panel list">
		{#each ranking as p (p.user_id)}
			<div class="row it"><b class="rk">{p.final_rank ?? '–'}</b><Avatar avatar={playerAvatar(p)} name={playerName(p)} size={32} />
				<span class="grow">{playerName(p)}{p.user_id === game.me ? ' (tú)' : ''}{#if p.left_at}<span class="muted small"> · abandonó</span>{/if}</span><b>{p.score} pts</b></div>
		{/each}
	</section>
	<section class="panel row xp"><Star size={20} color="var(--lemon)" fill="var(--lemon)" /><b>+{game.myPlayer?.xp_gained ?? 0} XP</b></section>
	<CandyButton color="var(--lemon)" icon={RotateCw} ink disabled={loading} onclick={again}>{loading ? 'Creando…' : 'Volver a jugar'}</CandyButton>
	<button class="link" onclick={async () => { await game.stop(); goto('/jugar'); }}><Home size={16} /> Ir al inicio</button>
</div>

<style>
	.fin { align-items: center; text-align: center; padding-bottom: 30px; }
	.win { position: relative; } .crown { position: absolute; top: -24px; left: 50%; translate: -50% 0; animation: bob 1s ease-in-out infinite alternate; }
	@keyframes bob { to { transform: translateY(-5px); } }
	.title { margin: 0; font-size: 40px; font-weight: 900; text-transform: uppercase; color: var(--lemon); -webkit-text-stroke: 6px var(--ink); paint-order: stroke fill; text-shadow: 0 3px 0 var(--ink); }
	.self { align-self: stretch; text-align: left; }
	.list { align-self: stretch; display: flex; flex-direction: column; gap: 8px; text-align: left; }
	.rk { width: 24px; text-align: center; }
	.xp { align-self: stretch; justify-content: center; }
	.link { display: inline-flex; gap: 6px; align-items: center; background: none; border: 0; color: var(--lemon); font-weight: 900; font-size: 16px; cursor: pointer; }
</style>
