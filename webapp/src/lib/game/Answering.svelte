<script lang="ts">
	import { tick } from 'svelte';
	import { fly } from 'svelte/transition';
	import { Check, AlertCircle, Hand } from '@lucide/svelte';
	import { sfx } from '#lib/sfx.ts';
	import type { Game } from './game.svelte';
	import LetterBadge from '#lib/components/LetterBadge.svelte';
	import TimerRing from '#lib/components/TimerRing.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import { playerName } from '#lib/types.ts';

	let { game }: { game: Game } = $props();
	let stopping = $state(false);
	let focused = $state<string | null>(null);
	const inputs: Record<string, HTMLInputElement> = {};
	const r = $derived(game.currentRound!);
	const letter = $derived(r?.letter ?? '');
	const stopped = $derived(!!r?.stop_by);

	const norm = (v: string) => v.trim().normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase();
	const target = $derived(letter === 'Ñ' ? 'N' : letter);
	const wrong = (v: string) => { const t = norm(v); return t.length > 0 && !t.startsWith(target); };

	$effect(() => { if (game.canStop && !stopped) sfx('reveal', 0.5); });
	// Primer campo vacío enfocado al empezar.
	$effect(() => { tick().then(() => { const first = game.categories.find((c) => !(game.drafts[c] ?? '')); if (first) inputs[first]?.focus(); }); });

	function next(cat: string) {
		const i = game.categories.indexOf(cat);
		const rest = game.categories.slice(i + 1);
		const n = rest.find((c) => !(game.drafts[c] ?? '')) ?? rest[0];
		if (n) inputs[n]?.focus(); else inputs[cat]?.blur();
	}
	async function stop() { stopping = true; await game.callStop(); stopping = false; }
</script>

<div class="ans">
	<div class="hud-wrap">
		{#if game.stopCaller}
			<div class="stopbar" transition:fly={{ y: -30 }}>
				<Mascot pose="stop" size={56} />
				<div class="grow"><b>{game.stopCaller.user_id === game.me ? '¡Dijiste STOP!' : `¡${playerName(game.stopCaller)} dijo STOP!`}</b><div class="small">Cierra tus respuestas</div></div>
				<b class="sec">{game.secondsLeft}</b>
			</div>
		{:else}
			<div class="panel hud">
				<LetterBadge {letter} size={50} />
				<div class="grow">
					<div class="row"><b>{game.filledCount}/{game.categories.length}</b>
						<span class="small" style:color={game.canStop ? 'var(--lime)' : 'rgba(255,255,255,.6)'}>{game.canStop ? '¡ya puedes decir STOP!' : `STOP con ${game.stopThreshold}`}</span></div>
					<div class="prog">
						<span class="fill" class:can={game.canStop} style:width="{(game.filledCount / Math.max(1, game.categories.length)) * 100}%"></span>
						<span class="mark" style:left="{(game.stopThreshold / Math.max(1, game.categories.length)) * 100}%"></span>
					</div>
				</div>
				<TimerRing seconds={game.secondsLeft} total={game.room?.round_seconds ?? 60} size={50} />
				{#if game.canStop && !stopped && focused}
					<!-- con el teclado abierto, el STOP queda arriba siempre visible -->
					<button class="mini" disabled={stopping} onclick={stop} in:fly={{ x: 20 }}><Hand size={14} strokeWidth={3} />STOP</button>
				{/if}
			</div>
		{/if}
	</div>

	<div class="fields">
		{#each game.categories as cat, i (cat)}
			{@const v = game.drafts[cat] ?? ''}
			{@const ok = game.startsWithLetter(v)}
			{@const bad = wrong(v)}
			<label class="f" class:focus={focused === cat} class:ok class:bad style:animation-delay="{i * 40}ms">
				<span class="tiny" class:hl={focused === cat}>{cat}</span>
				<div class="row">
					<input bind:this={inputs[cat]} value={v} placeholder="{letter}…" autocomplete="off" autocapitalize="words" spellcheck="false" enterkeyhint="next"
						oninput={(e) => game.setDraft(cat, e.currentTarget.value)} onfocus={() => (focused = cat)} onblur={() => focused === cat && (focused = null)}
						onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); next(cat); } }} />
					{#if ok}<span class="st okc"><Check size={14} strokeWidth={3.5} /></span>{:else if bad}<span class="st badc"><AlertCircle size={16} strokeWidth={3} /></span>{/if}
				</div>
				{#if bad}<span class="warn">Debe empezar con la {letter}</span>{/if}
			</label>
		{/each}
		<p class="muted small center">Se guarda solo. Puedes editar hasta que cierre la ronda.</p>
	</div>

	{#if game.canStop && !stopped && !focused}
		<div class="stopwrap" transition:fly={{ y: 80, duration: 350 }}>
			<CandyButton color="var(--cherry)" icon={Hand} height={58} disabled={stopping} onclick={stop}>¡STOP!</CandyButton>
		</div>
	{/if}
</div>

<style>
	.ans { padding-bottom: 10px; }
	.hud-wrap { position: sticky; top: 0; z-index: 4; padding: 4px 0 8px; }
	.hud { display: flex; align-items: center; gap: 12px; padding: 10px; background: var(--deep); }
	.prog { position: relative; height: 8px; border-radius: 99px; background: rgba(255,255,255,.1); margin-top: 6px; }
	.fill { position: absolute; inset: 0 auto 0 0; border-radius: 99px; background: var(--lemon); transition: width .4s cubic-bezier(.3,1.3,.5,1); min-width: 8px; }
	.fill.can { background: var(--lime); }
	.mark { position: absolute; top: -3px; width: 2px; height: 14px; background: rgba(255,255,255,.8); }
	.stopbar { display: flex; align-items: center; gap: 12px; padding: 12px; border-radius: 20px; background: var(--cherry); }
	.sec { font-size: 34px; font-variant-numeric: tabular-nums; }
	.fields { display: grid; gap: 10px; grid-template-columns: 1fr; }
	@media (min-width: 900px) { .fields { grid-template-columns: 1fr 1fr; } .fields p { grid-column: 1 / -1; } }
	.f { display: block; padding: 10px 14px; border-radius: 18px; background: var(--panel); border: 1.5px solid var(--panel-stroke); cursor: text;
		transition: border-color .2s, background .2s, transform .25s cubic-bezier(.3,1.6,.5,1); animation: pop .4s cubic-bezier(.3,1.6,.5,1) both; }
	@keyframes pop { from { opacity: 0; transform: translateY(10px) scale(.96); } }
	.f.ok { border-color: rgba(140,217,51,.6); }
	.f.bad { border-color: var(--cherry); }
	.f.focus { border-color: var(--lemon); border-width: 2.5px; background: rgba(255,255,255,.14); }
	.tiny.hl { color: var(--lemon); }
	input { flex: 1; min-width: 0; border: 0; outline: 0; background: transparent; color: #fff; font-size: 21px; font-weight: 800; padding: 2px 0; }
	input::placeholder { color: rgba(255,255,255,.3); }
	.st { display: grid; place-items: center; width: 26px; height: 26px; border-radius: 50%; flex: none; animation: pin .3s cubic-bezier(.3,1.8,.5,1); }
	@keyframes pin { from { transform: scale(0); } }
	.mini { display: inline-flex; align-items: center; gap: 4px; height: 36px; padding: 0 12px; border: 0; border-radius: 99px; background: var(--cherry);
		color: #fff; font-weight: 900; cursor: pointer; }
	.okc { background: var(--lime); color: var(--ink); } .badc { background: var(--cherry); color: #fff; }
	.warn { color: var(--cherry); font-weight: 900; font-size: 12px; }
	.center { text-align: center; }
	.stopwrap { position: sticky; bottom: 0; margin: 10px -16px 0; padding: 14px 16px calc(10px + env(safe-area-inset-bottom));
		background: linear-gradient(transparent, var(--night) 35%); z-index: 6; }
</style>
