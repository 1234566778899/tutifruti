<script lang="ts">
	import { Check, X, HelpCircle, Minus, Trophy, Play, Laugh, Flame, Zap, PartyPopper, CircleHelp, HeartCrack, Flag } from '@lucide/svelte';
	import { Tween } from 'svelte/motion';
	import { cubicOut } from 'svelte/easing';
	import { sfx } from '#lib/sfx.ts';
	import { playerAvatar, playerName, REACTIONS, type Answer } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import Segmented from '#lib/components/Segmented.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import AnswerSheet from './AnswerSheet.svelte';

	let { game }: { game: Game } = $props();
	let mode = $state<0 | 1>(0);
	let selected = $state<Answer | null>(null);
	const RX: Record<string, [any, string]> = { haha: [Laugh, '#ffd23f'], fire: [Flame, '#ff941f'], wow: [Zap, '#b07cff'], clap: [PartyPopper, '#ff6fa8'], hmm: [CircleHelp, '#40d8c8'], ouch: [HeartCrack, '#ed385c'] };
	const RX_NAME: Record<string, string> = { haha: 'risa', fire: 'fuego', wow: 'sorpresa', clap: 'aplauso', hmm: 'duda', ouch: 'auch' };
	function open(a: Answer) { selected = a; sfx('tap', 0.5); }
	const myPts = $derived(game.points(game.me));
	const ranking = $derived(game.roundRanking);
	const top = $derived(ranking[0]?.points ?? 0);
	const pos = $derived(1 + ranking.filter((e) => e.points > myPts).length);
	const tied = $derived(ranking.filter((e) => e.points === myPts).length > 1);
	const mine = $derived(game.roundAnswers.filter((a) => a.user_id === game.me).sort((a, b) => game.categories.indexOf(a.category) - game.categories.indexOf(b.category)));
	const pose = $derived(myPts === 0 ? 'sad' : myPts >= top ? 'party' : 'hello');
	const shown = new Tween(0, { duration: 900, easing: cubicOut });
	$effect(() => { shown.target = myPts; });

	// Sonido de cada respuesta mía y luego las monedas.
	let played: string | null = null;
	$effect(() => {
		const id = game.loadedResultsFor;
		if (!id || id === played) return;
		played = id;
		const list = [...mine];
		list.slice(0, 8).forEach((a, i) => setTimeout(() => sfx(a.status === 'valid' ? 'valid' : a.status === 'doubtful' ? 'doubtful' : 'invalid', 0.6), 450 + i * 170));
		if (myPts > 0) setTimeout(() => sfx('coin'), 450 + list.length * 170);
	});

	const color = (s: Answer['status']) => (s === 'valid' ? 'var(--lime)' : s === 'doubtful' ? 'var(--tangerine)' : s === 'invalid' ? 'var(--cherry)' : 'gray');
	const label = (a: Answer) => (a.status === 'valid' ? (a.points >= 10 ? 'Única' : 'Repetida') : a.status === 'doubtful' ? 'Dudosa' : a.status === 'invalid' ? 'Inválida' : 'Vacía');
	const pts = (a: Answer) => (a.status === 'doubtful' ? '—' : a.points > 0 ? `+${a.points}` : '0');
	const isLast = $derived((game.currentRound?.number ?? 0) >= (game.room?.rounds_total ?? 0));
	const waiting = $derived(game.playersToWait);
	const readyCount = $derived(waiting.filter((p) => game.readyIds.has(p.user_id)).length);
</script>

{#snippet icon(s: Answer['status'])}
	<span class="ic" style:background={color(s)}>{#if s === 'valid'}<Check size={12} strokeWidth={4} />{:else if s === 'invalid'}<X size={12} strokeWidth={4} />{:else if s === 'doubtful'}<HelpCircle size={12} strokeWidth={3} />{:else}<Minus size={12} strokeWidth={4} />{/if}</span>
{/snippet}

<div class="res stack">
	<section class="panel hero">
		<Mascot pose={pose as any} size={92} />
		<div>
			<span class="tiny muted">Esta ronda</span>
			<div class="big">+{Math.round(shown.current)}<small>pts</small></div>
			<span class="small muted">{pos}º{tied ? ' (empate)' : ''} de {ranking.length} · {mine.filter((a) => a.status === 'valid').length} válidas · {mine.filter((a) => a.points >= 10).length} únicas</span>
		</div>
	</section>

	<section class="panel rank">
		{#each ranking as e (e.player.user_id)}
			{@const place = 1 + ranking.filter((x) => x.points > e.points).length}
			<div class="rr" class:me={e.player.user_id === game.me}>
				<span class="pl" class:first={place === 1}>{place}</span>
				<Avatar avatar={playerAvatar(e.player)} name={playerName(e.player)} size={34} />
				<b class="grow nm">{playerName(e.player)}{e.player.user_id === game.me ? ' (tú)' : ''}</b>
				<b class="pts">+{e.points}</b><span class="muted small tot">{e.player.score}</span>
			</div>
		{/each}
	</section>

	<Segmented bind:value={mode} options={[[0, 'Mis respuestas'], [1, 'Todas']]} />

	{#if mode === 0}
		<div class="grid">
			{#each mine as a, i (a.category)}
				<button class="card" style:--c={color(a.status)} style:animation-delay="{i * 50}ms" onclick={() => open(a)}>
					<span class="tiny muted row">{a.category}{#if a.disputed}<Flag size={12} />{/if}</span>
					<b class="val">{a.value || '—'}</b>
					<div class="row">{@render icon(a.status)}<span class="lab">{label(a)}</span><b class="grow right" class:dim={a.points === 0}>{pts(a)}</b></div>
					{#if a.reason}<span class="why">{a.reason}</span>{/if}
				</button>
			{/each}
		</div>
	{:else}
		<div class="grid wide">
			{#each game.categories as cat (cat)}
				<section class="panel">
					<div class="tiny cat">{cat}</div>
					{#each game.answersFor(cat) as a (a.user_id)}
						{@const p = game.player(a.user_id)}
						<button class="row line" onclick={() => open(a)}>
							<Avatar avatar={playerAvatar(p!)} name={playerName(p)} size={28} />
							<div class="grow"><b class:dim={!a.value}>{a.value || '—'}</b><div class="muted tiny2">{playerName(p)}{a.user_id === game.me ? ' (tú)' : ''}</div></div>
							{@render icon(a.status)}<b class="pts" class:dim={a.points === 0}>{pts(a)}</b>
						</button>
					{/each}
					<div class="rx">
						{#each REACTIONS as k}
							{@const n = game.reactions.filter((r) => r.category === cat && r.emoji === k).length}
							{@const mine = game.reactions.some((r) => r.category === cat && r.emoji === k && r.user_id === game.me)}
							{@const [Icon, c] = RX[k]}
							<button class="rxb" class:mine style:--c={c} aria-label="Reaccionar con {RX_NAME[k]}" aria-pressed={mine} onclick={() => { sfx('tap', .5); game.react(cat, k); }}>
								<Icon size={17} strokeWidth={2.6} />{#if n}<span>{n}</span>{/if}
							</button>
						{/each}
					</div>
				</section>
			{/each}
		</div>
	{/if}
	<p class="muted small hint">Toca una respuesta para ver la explicación del árbitro o impugnarla.</p>
	{#if game.currentRound && !game.currentRound.validated_by_ai}<p class="muted small">Árbitro IA no disponible: se aplicó la validación básica (letra correcta).</p>{/if}

	<div class="readybar">
		<div class="row"><div class="avs">{#each waiting as p (p.user_id)}<span class:ok={game.readyIds.has(p.user_id)}><Avatar avatar={playerAvatar(p)} name={playerName(p)} size={30} /></span>{/each}</div>
			<b>{game.everyoneReady ? '¡Todos listos!' : `${readyCount} de ${waiting.length} listos`}</b></div>
		<CandyButton color={game.iAmReady ? 'var(--lime)' : 'var(--lemon)'} icon={game.iAmReady ? Check : isLast ? Trophy : Play} ink onclick={() => game.toggleReady()}>
			{game.iAmReady ? 'Listo · esperando a los demás' : isLast ? 'Listo para ver la clasificación' : 'Listo para la siguiente ronda'}
		</CandyButton>
	</div>
</div>

{#if selected}<AnswerSheet {game} answer={selected} onclose={() => (selected = null)} />{/if}

<style>
	button.card, button.line { font: inherit; color: inherit; text-align: left; cursor: pointer; width: 100%; }
	button.line { background: none; border: 0; border-radius: 10px; }
	button.line:hover { background: rgba(255,255,255,.05); }
	button.card:hover { filter: brightness(1.1); }
	.hint { text-align: center; margin: 0; }
	.rx { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 8px; padding-top: 8px; border-top: 1px solid rgba(255,255,255,.08); }
	.rxb { display: inline-flex; align-items: center; gap: 4px; height: 32px; padding: 0 10px; border-radius: 99px; border: 1.5px solid transparent;
		background: rgba(255,255,255,.06); color: rgba(255,255,255,.45); font-weight: 900; font-size: 13px; cursor: pointer; transition: transform .2s cubic-bezier(.3,1.7,.5,1); }
	.rxb:active { transform: scale(.85); }
	.rxb.mine { color: var(--c); border-color: color-mix(in srgb, var(--c) 60%, transparent); background: color-mix(in srgb, var(--c) 14%, transparent); }
	.res { padding-bottom: 10px; }
	.hero { display: flex; align-items: center; gap: 12px; }
	.big { font-size: 44px; font-weight: 900; color: var(--lemon); line-height: 1; } .big small { font-size: 16px; margin-left: 4px; opacity: .8; }
	.rank { display: flex; flex-direction: column; gap: 6px; padding: 10px; }
	.rr { display: flex; align-items: center; gap: 10px; padding: 6px 8px; border-radius: 14px; border: 1.5px solid transparent; }
	.rr.me { background: rgba(255,210,63,.12); border-color: rgba(255,210,63,.5); }
	.pl { display: grid; place-items: center; width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,.1); font-weight: 900; }
	.pl.first { background: var(--lemon); color: var(--ink); }
	.nm { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.pts { color: var(--lemon); font-variant-numeric: tabular-nums; } .pts.dim, .dim { color: rgba(255,255,255,.4); }
	.tot { min-width: 30px; text-align: right; }
	.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 10px; }
	.grid.wide { grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
	.card { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: 18px; background: color-mix(in srgb, var(--c) 14%, transparent);
		border: 1.5px solid color-mix(in srgb, var(--c) 55%, transparent); animation: pop .45s cubic-bezier(.3,1.6,.5,1) both; }
	@keyframes pop { from { opacity: 0; transform: scale(.85) translateY(10px); } }
	.val { font-size: 18px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.lab { color: var(--c); font-weight: 900; font-size: 13px; } .right { text-align: right; color: var(--lemon); }
	.why { font-size: 12px; color: rgba(255,255,255,.6); font-weight: 600; }
	.ic { display: grid; place-items: center; width: 20px; height: 20px; border-radius: 50%; color: var(--ink); flex: none; }
	.cat { color: var(--lemon); margin-bottom: 6px; }
	.line { padding: 4px 0; } .tiny2 { font-size: 11px; font-weight: 700; }
	.readybar { position: sticky; bottom: 0; margin: 0 -16px; padding: 22px 16px calc(10px + env(safe-area-inset-bottom));
		background: linear-gradient(transparent, var(--night) 22%); display: flex; flex-direction: column; gap: 10px; z-index: 6; }
	.avs { display: flex; } .avs span { margin-left: -8px; opacity: .45; transition: opacity .3s; } .avs span.ok { opacity: 1; }
</style>
