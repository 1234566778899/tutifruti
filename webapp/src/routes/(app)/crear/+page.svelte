<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { slide } from 'svelte/transition';
	import { ChevronLeft, Lock, Globe, Dices, Zap, Star, Hourglass, Plus, X, ChevronDown, WandSparkles } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import type { Category } from '#lib/types.ts';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';

	let s = $state(API.defaultSettings());
	if (page.url.searchParams.get('publica')) { s.isPublic = true; s.name = 'Stop para todos'; }
	let loading = $state(false), error = $state<string | null>(null), more = $state(false), picking = $state(false);
	let all = $state<Category[]>([]);

	const presets = [
		{ id: 'Rápida', icon: Zap, rounds: 3, seconds: 60 },
		{ id: 'Clásica', icon: Star, rounds: 5, seconds: 90 },
		{ id: 'Larga', icon: Hourglass, rounds: 8, seconds: 120 }
	];
	const names = ['Viernes de Stop', 'Basta con amigos', 'La letra misteriosa', 'Tutifruti épico', 'Noche de Stop', 'Mente rápida', 'Duelo de palabras', 'Stop sin piedad', 'Los veloces', 'Club de la A a la Z'];
	const chips = (opts: number[], v: number) => [...new Set([...opts, v])].sort((a, b) => a - b);
	const fmtTime = (v: number) => (v % 60 === 0 ? `${v / 60} min` : `${v} s`);

	// Categorías generadas por IA a partir de un tema (Edge Function categories-ai, igual que iOS).
	let theme = $state(''), generating = $state(false), generated = $state<string[]>([]), genError = $state<string | null>(null);
	async function generate() {
		generating = true; genError = null;
		try { generated = (await API.generateCategories(theme.trim())).filter((c) => !all.some((x) => x.name === c)); sfx('reveal', .6); }
		catch (e) { genError = friendlyError(e); } finally { generating = false; }
	}
	async function openPicker() {
		picking = true;
		if (!all.length) { try { all = (await API.categories()).filter((c) => c.kind !== 'custom'); } catch { /* sin conexión */ } }
	}
	function toggleCat(n: string) {
		if (s.categories.includes(n)) { if (s.categories.length > 3) s.categories = s.categories.filter((c) => c !== n); }
		else if (s.categories.length < 12) s.categories = [...s.categories, n];
	}
	async function create() {
		loading = true; error = null;
		try { const room = await API.createRoom(s); sfx('join'); goto(`/sala/${room.id}`, { replaceState: true }); }
		catch (e) { error = friendlyError(e); } finally { loading = false; }
	}
</script>

<main class="page stack">
	<header class="bar">
		<a class="iconbtn" href="/jugar" aria-label="Volver"><ChevronLeft /></a>
		<OutlinedTitle text="Nueva sala" size={22} />
		<span></span>
	</header>

	<div class="types">
		<button class:on={!s.isPublic} onclick={() => (s.isPublic = false)}><Lock size={22} /><b>Privada</b><small>Con código</small></button>
		<button class:on={s.isPublic} onclick={() => (s.isPublic = true)}><Globe size={22} /><b>Pública</b><small>Abierta a todos</small></button>
	</div>
	<p class="muted small hint">{s.isPublic ? 'Aparece en Salas públicas: cualquiera puede unirse mientras esperas.' : 'Solo entran quienes tengan el código o tu invitación.'}</p>

	<div class="row">
		<input class="field grow" placeholder="Nombre de la sala" bind:value={s.name} maxlength="40" />
		<button class="dice" aria-label="Nombre al azar" onclick={() => { s.name = names.filter((n) => n !== s.name)[Math.floor(Math.random() * 9)]; sfx('tap'); }}><Dices size={22} /></button>
	</div>

	<h3 class="section-title">Estilo de partida</h3>
	<div class="presets">
		{#each presets as p}
			{@const on = s.rounds === p.rounds && s.roundSeconds === p.seconds}
			<button class:on onclick={() => { s.rounds = p.rounds; s.roundSeconds = p.seconds; sfx('tap', .5); }}>
				<p.icon size={20} strokeWidth={3} /><b>{p.id}</b><small>{p.rounds} · {p.seconds}s</small>
			</button>
		{/each}
	</div>
	<div class="panel stack values">
		{@render chipRow('Rondas', chips([3, 5, 8, 10], s.rounds), s.rounds, (v) => (s.rounds = v), (v) => String(v))}
		{@render chipRow('Tiempo por ronda', chips([60, 90, 120, 180], s.roundSeconds), s.roundSeconds, (v) => (s.roundSeconds = v), fmtTime)}
		{@render chipRow('Jugadores máximos', chips([4, 6, 8, 12], s.maxPlayers), s.maxPlayers, (v) => (s.maxPlayers = v), (v) => String(v))}
	</div>

	<h3 class="section-title">Categorías · {s.categories.length}</h3>
	<div class="panel stack">
		<div class="cats">
			{#each s.categories as c (c)}
				<span class="cat" transition:slide={{ axis: 'x', duration: 200 }}>{c}
					{#if s.categories.length > 3}<button aria-label="Quitar {c}" onclick={() => toggleCat(c)}><X size={14} strokeWidth={3} /></button>{/if}
				</span>
			{/each}
		</div>
		<button class="add" onclick={openPicker}><span class="dot"><Plus size={16} strokeWidth={3.5} /></span>Agregar o cambiar</button>
	</div>

	<div class="panel">
		<button class="more" onclick={() => (more = !more)}><b>Más opciones</b><span class:open={more}><ChevronDown size={18} color="var(--lemon)" /></span></button>
		{#if more}
			<div class="stack" transition:slide={{ duration: 220 }}>
				<label class="tg"><span><b>Sin letras difíciles</b><br /><small class="muted">K, Ñ, Q, W, X, Y, Z</small></span><input type="checkbox" bind:checked={s.excludeHard} /></label>
				{@render chipRow('Tiempo para cerrar tras STOP', chips([5, 10, 15, 20], s.stopSeconds), s.stopSeconds, (v) => (s.stopSeconds = v), (v) => `${v} s`)}
				<label class="tg"><span><b>Categorías personalizadas</b><br /><small class="muted">Permite categorías creadas por jugadores</small></span><input type="checkbox" bind:checked={s.allowCustom} /></label>
			</div>
		{/if}
	</div>

	<div class="footer">
		<p class="muted small">{s.rounds} rondas · {s.roundSeconds} s · {s.categories.length} categorías · hasta {s.maxPlayers}</p>
		<CandyButton color="var(--lime)" icon={Plus} ink disabled={loading || s.categories.length < 3 || !s.name.trim()} onclick={create}>{loading ? 'Creando…' : 'Crear sala'}</CandyButton>
		{#if error}<p class="err">{error}</p>{/if}
	</div>
</main>

{#snippet chipRow(title: string, options: number[], value: number, set: (v: number) => void, label: (v: number) => string, locked: number[] = [])}
	<div>
		<div class="tiny muted">{title}</div>
		<div class="chips">
			{#each options as v}
				<button class:on={v === value} disabled={locked.includes(v)} onclick={() => { set(v); sfx('tap', .5); }} title={locked.includes(v) ? 'No disponible' : undefined}>{label(v)}{#if locked.includes(v)}<Lock size={12} />{/if}</button>
			{/each}
		</div>
	</div>
{/snippet}

{#if picking}
	<div class="scrim" role="presentation" onclick={() => (picking = false)}></div>
	<div class="sheet stack">
		<h3 class="section-title">Elige categorías ({s.categories.length}/12)</h3>
		<form class="gen" onsubmit={(e) => { e.preventDefault(); if (theme.trim().length >= 3) generate(); }}>
			<WandSparkles size={18} color="var(--lemon)" />
			<input placeholder="Tema para la IA: cine, fútbol, comida…" bind:value={theme} maxlength="40" />
			<button class="genbtn" disabled={generating || theme.trim().length < 3}>{generating ? 'Creando…' : 'Generar'}</button>
		</form>
		{#if genError}<p class="err small">{genError}</p>{/if}
		{#if generated.length}
			<div class="cats pickgrid">
				{#each generated as n (n)}
					<button class="cat pickable ai" class:on={s.categories.includes(n)} onclick={() => toggleCat(n)}>{n}</button>
				{/each}
			</div>
		{/if}
		<div class="cats pickgrid">
			{#each all as c (c.id)}
				<button class="cat pickable" class:on={s.categories.includes(c.name)} onclick={() => toggleCat(c.name)}>{c.name}</button>
			{/each}
		</div>
		<CandyButton color="var(--lemon)" ink height={52} onclick={() => (picking = false)}>Listo</CandyButton>
	</div>
{/if}

<style>
	main { padding-bottom: 150px; }
	.gen { display: flex; align-items: center; gap: 8px; height: 50px; padding: 0 6px 0 14px; border-radius: 999px; background: rgba(255,255,255,.08); border: 1.5px solid var(--panel-stroke); }
	.gen:focus-within { border-color: var(--lemon); }
	.gen input { flex: 1; min-width: 0; background: none; border: 0; outline: 0; color: #fff; font: inherit; font-weight: 800; font-size: 15px; }
	.genbtn { height: 38px; padding: 0 14px; border-radius: 99px; border: 0; background: var(--lemon); color: var(--ink); font-weight: 900; cursor: pointer; }
	.genbtn:disabled { opacity: .5; cursor: default; }
	.cat.ai { border-style: dashed; }
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.types, .presets { display: grid; grid-template-columns: repeat(auto-fit, minmax(0, 1fr)); gap: 10px; }
	.types button, .presets button { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 14px 6px; border-radius: 18px; cursor: pointer;
		background: var(--panel); border: 1.5px solid var(--panel-stroke); color: #fff; transition: transform .2s cubic-bezier(.3,1.6,.5,1), background .2s; }
	.types button:active, .presets button:active { transform: scale(.95); }
	.types button.on, .presets button.on { background: var(--lemon); color: var(--ink); border-color: rgba(46,28,20,.5); }
	small { font-weight: 800; opacity: .75; font-size: 12px; }
	.hint { margin: -8px 4px 0; }
	.dice { width: 50px; height: 50px; border-radius: 50%; border: 0; background: var(--lemon); color: var(--ink); cursor: pointer; box-shadow: inset 0 -3px 0 rgba(0,0,0,.2); }
	.values { gap: 14px; }
	.chips { display: flex; gap: 8px; margin-top: 8px; }
	.chips button { flex: 1; height: 42px; border-radius: 99px; border: 1.5px solid var(--panel-stroke); background: rgba(255,255,255,.07); color: #fff;
		font-weight: 900; font-size: 16px; cursor: pointer; transition: background .2s, transform .15s; white-space: nowrap; }
	.chips button.on { background: var(--lemon); color: var(--ink); border-color: rgba(46,28,20,.4); }
	.chips button:disabled { opacity: .35; cursor: default; }
	.cats { display: flex; flex-wrap: wrap; gap: 8px; }
	.cat { display: inline-flex; align-items: center; gap: 4px; padding: 7px 12px; border-radius: 99px; background: var(--header); border: 1.5px solid rgba(255,210,63,.5);
		font-weight: 800; font-size: 15px; color: #fff; }
	.cat button { display: grid; place-items: center; border: 0; background: none; color: rgba(255,255,255,.6); cursor: pointer; padding: 0; }
	.add { display: flex; align-items: center; justify-content: center; gap: 8px; height: 48px; border-radius: 99px; border: 1.5px solid var(--panel-stroke);
		background: rgba(255,255,255,.08); color: #fff; font-weight: 900; font-size: 15px; cursor: pointer; }
	.dot { display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--lime); color: var(--ink); }
	.more { display: flex; width: 100%; justify-content: space-between; align-items: center; background: none; border: 0; color: #fff; font-size: 17px; cursor: pointer; padding: 0; }
	.more span { transition: transform .25s; } .more .open { transform: rotate(180deg); }
	.tg { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-top: 12px; }
	.tg input { width: 50px; height: 30px; accent-color: var(--lime); }
	.footer { position: fixed; left: 0; right: 0; bottom: 0; padding: 18px 16px calc(10px + env(safe-area-inset-bottom));
		background: linear-gradient(transparent, var(--night) 30%); display: flex; flex-direction: column; align-items: center; gap: 8px; z-index: 5; }
	.footer :global(.candy) { max-width: 528px; }
	.footer p { margin: 0; }
	.err { color: #ff8aa0; font-weight: 800; margin: 0; }
	.scrim { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 40; }
	.sheet { position: fixed; z-index: 41; left: 50%; bottom: 0; translate: -50% 0; width: min(100%, 640px); max-height: 80dvh; overflow: auto;
		padding: 20px 16px calc(20px + env(safe-area-inset-bottom)); background: var(--deep); border-radius: 26px 26px 0 0; border: 1.5px solid var(--panel-stroke); }
	.pickable { cursor: pointer; border-color: var(--panel-stroke); background: rgba(255,255,255,.06); }
	.pickable.on { background: var(--lemon); color: var(--ink); border-color: rgba(46,28,20,.4); }
</style>
