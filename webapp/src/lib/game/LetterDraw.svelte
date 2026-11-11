<script lang="ts">
	import { scale } from 'svelte/transition';
	import { backOut } from 'svelte/easing';
	import { sfx, haptic } from '#lib/sfx.ts';
	import { playerAvatar, playerName } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import LetterBadge from '#lib/components/LetterBadge.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import Avatar from '#lib/components/Avatar.svelte';

	let { game }: { game: Game } = $props();
	const alphabet = 'ABCDEFGHIJLMNOPRSTUV'.split('');
	let spinning = $state('A');
	const remaining = $derived(game.secondsToStart);
	const revealed = $derived(remaining <= 3);

	// Tragamonedas: cambia de letra con tic hasta revelar.
	$effect(() => {
		if (revealed) return;
		const t = setInterval(() => { spinning = alphabet.filter((l) => l !== spinning)[Math.floor(Math.random() * 19)]; sfx('tick', 0.5); }, 90);
		return () => clearInterval(t);
	});
	$effect(() => { if (revealed) { sfx('reveal'); haptic(30); } });
	let lastCount = -1;
	$effect(() => { const r = remaining; if (revealed && r > 0 && r <= 3 && r !== lastCount) { lastCount = r; sfx('count'); } });
</script>

<div class="draw">
	<p class="muted small">Ronda {game.currentRound?.number ?? 1} de {game.room?.rounds_total ?? 1}</p>
	<div class="stage">
		{#if revealed}<div class="sun" in:scale={{ duration: 500 }}></div>{/if}
		<div class="badge" class:rev={revealed}>
			<LetterBadge letter={revealed ? (game.currentRound?.letter ?? '?') : spinning} size={180} />
		</div>
	</div>
	<OutlinedTitle text={revealed ? `¡La letra es ${game.currentRound?.letter}!` : 'Sorteando letra…'} size={30} fill={revealed ? 'var(--lemon)' : '#fff'} />
	{#if revealed}
		{#key remaining}<b class="num" in:scale={{ start: 1.6, duration: 350, easing: backOut }}>{remaining}</b>{/key}
	{/if}
	{#if (game.room?.used_letters.length ?? 0) > 1}
		<p class="muted small">Letras ya usadas: {game.room?.used_letters.slice(0, -1).join(', ')}</p>
	{/if}
	<div class="avs">{#each game.activePlayers as p (p.user_id)}<Avatar avatar={playerAvatar(p)} name={playerName(p)} size={40} />{/each}</div>
</div>

<style>
	.draw { min-height: 70dvh; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 18px; text-align: center; }
	.stage { position: relative; display: grid; place-items: center; width: 360px; height: 260px; max-width: 100%; }
	.sun { position: absolute; width: 360px; height: 360px; border-radius: 50%;
		background: repeating-conic-gradient(rgba(255,210,63,.45) 0 11.25deg, transparent 11.25deg 22.5deg);
		mask: radial-gradient(circle, #000 30%, transparent 70%); animation: spin 14s linear infinite; }
	@keyframes spin { to { rotate: 360deg; } }
	.badge { transform: scale(.9) rotate(-4deg); transition: transform .5s cubic-bezier(.3,1.7,.5,1); }
	.badge.rev { transform: scale(1.08); }
	.num { font-size: 54px; font-weight: 900; color: var(--lemon); }
	.avs { display: flex; } .avs :global(.av) { margin-left: -8px; box-shadow: 0 0 0 2px var(--deep); }
</style>
