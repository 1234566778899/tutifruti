<script lang="ts">
	import { goto } from '$app/navigation';
	import { Play, Plus, Hash, Users, CloudUpload, ChevronRight, Bell, KeyRound } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import * as API from '#lib/api.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import { xpForNext } from '#lib/types.ts';
	import Logo from '#lib/components/Logo.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';

	let openRooms = $state(0);
	let showJoin = $state(false), code = $state(''), joining = $state(false), joinError = $state<string | null>(null);
	const p = $derived(app.profile!);
	const progress = $derived(Math.min(1, p.xp / xpForNext(p.level)));

	$effect(() => {
		let alive = true;
		const load = async () => { try { const r = await API.publicRooms(); if (alive) openRooms = r.length; } catch { /* luego */ } };
		load(); const t = setInterval(load, 10_000);
		return () => { alive = false; clearInterval(t); };
	});

	const normalized = $derived.by(() => {
		const raw = code.toUpperCase().replace(/[^A-Z0-9]/g, '');
		return 'TUTI-' + (raw.startsWith('TUTI') ? raw.slice(4) : raw).slice(0, 4);
	});
	async function join() {
		joining = true; joinError = null;
		try { const id = await API.joinByCode(normalized); sfx('join'); goto(`/sala/${id}`); }
		catch (e) { joinError = friendlyError(e); } finally { joining = false; }
	}
</script>

<main class="page stack home">
	<header class="top">
		{#if app.isGuest}<span class="guest">Invitado</span>{/if}
		<span class="grow"></span>
		<a class="iconbtn" href="/avisos" aria-label={app.unread ? `Avisos, ${app.unread} sin leer` : 'Avisos'}><Bell size={20} />{#if app.unread}<span class="badge">{app.unread > 9 ? '9+' : app.unread}</span>{/if}</a>
		{#if !app.isGuest}<a class="iconbtn" href="/amigos" aria-label="Amigos"><Users size={20} /></a>{/if}
	</header>

	<div class="logo"><Logo height={78} /></div>

	<a class="panel me" href="/perfil" aria-label="Ver perfil">
		<Avatar avatar={p.avatar} name={p.username} size={62} />
		<div class="grow">
			<div class="row"><b class="grow name">¡Hola, {p.username}!</b><b class="lv">Nv {p.level}</b></div>
			<div class="xp"><span style:width="{Math.max(4, progress * 100)}%"></span></div>
			<span class="muted tiny">{p.xp} / {xpForNext(p.level)} XP</span>
		</div>
		<ChevronRight size={20} color="rgba(255,255,255,.5)" />
	</a>

	<div class="play">
		<div class="tuti"><Mascot pose="hello" size={104} /></div>
		<CandyButton color="var(--tangerine)" icon={Play} height={70} ink href="/salas">
			Jugar {#if openRooms > 0}<span class="count">{openRooms} {openRooms === 1 ? 'sala' : 'salas'}</span>{/if}
		</CandyButton>
	</div>

	<div class="tiles">
		<a class="tile" href="/crear" onpointerdown={() => sfx('tap', 0.6)}><span class="dot" style:background="var(--lime)"><Plus size={22} strokeWidth={3.5} /></span>Crear sala</a>
		<button class="tile" onclick={() => { showJoin = true; sfx('tap', 0.6); }}><span class="dot" style:background="var(--lemon)"><Hash size={22} strokeWidth={3.5} /></span>Con código</button>
	</div>

	{#if app.isGuest}
		<a class="panel banner" href="/perfil">
			<CloudUpload size={26} color="var(--lemon)" />
			<span class="grow"><b>Estás jugando como invitado</b><br /><span class="muted">Guarda tu progreso con un correo para no perder tu nivel.</span></span>
			<ChevronRight size={18} />
		</a>
	{:else if app.needsPassword}
		<a class="panel banner" href="/perfil">
			<KeyRound size={26} color="var(--lemon)" />
			<span class="grow"><b>Crea tu contraseña</b><br /><span class="muted">Tu correo está confirmado: crea una contraseña para entrar desde otros dispositivos.</span></span>
			<ChevronRight size={18} />
		</a>
	{/if}
</main>

{#if showJoin}
	<div class="scrim" role="presentation" onclick={() => (showJoin = false)}></div>
	<form class="sheet stack" onsubmit={(e) => { e.preventDefault(); join(); }}>
		<h3 class="section-title">Unirse con código</h3>
		<input class="field code" placeholder="TUTI-4F7K" bind:value={code} autocapitalize="characters" autocomplete="off" />
		<CandyButton type="submit" color="var(--sky)" icon={Hash} ink disabled={normalized.length !== 9 || joining}>{joining ? 'Entrando…' : 'Entrar a la sala'}</CandyButton>
		{#if joinError}<p class="err">{joinError}</p>{/if}
	</form>
{/if}


<style>
	.home { min-height: 100dvh; justify-content: center; }
	.top { display: flex; align-items: center; gap: 10px; }
	.iconbtn { position: relative; }
	.badge { position: absolute; top: -4px; right: -4px; min-width: 20px; height: 20px; padding: 0 5px; border-radius: 99px; background: var(--cherry); color: #fff;
		font-size: 11px; font-weight: 900; display: grid; place-items: center; box-shadow: 0 0 0 2px var(--deep); animation: pop .4s cubic-bezier(.3,1.7,.5,1); }
	@keyframes pop { from { transform: scale(0); } }
	a.me { color: #fff; text-decoration: none; }
	.guest { padding: 6px 12px; border-radius: 999px; background: var(--panel); font-weight: 900; font-size: 13px; }
	.iconbtn { display: grid; place-items: center; width: 42px; height: 42px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.logo { display: flex; justify-content: center; }
	.me { display: flex; align-items: center; gap: 14px; padding: 12px; }
	.name { font-size: 17px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.lv { color: var(--lemon); }
	.xp { height: 10px; border-radius: 99px; background: rgba(255,255,255,.12); overflow: hidden; margin: 7px 0 4px; }
	.xp span { display: block; height: 100%; border-radius: 99px; background: linear-gradient(90deg, var(--lemon), var(--lime)); animation: grow 1s cubic-bezier(.3,1.3,.5,1) both .2s; }
	@keyframes grow { from { width: 4% !important; } }
	.play { position: relative; padding-top: 54px; }
	.tuti { position: absolute; right: 6px; top: -24px; pointer-events: none; }
	.count { margin-left: 8px; padding: 3px 8px; border-radius: 99px; background: var(--lemon); color: var(--ink); font-size: 13px; text-transform: none; vertical-align: 3px; }
	.tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
	.tile { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 16px; border-radius: var(--radius); background: var(--panel);
		border: 1.5px solid var(--panel-stroke); color: #fff; font-weight: 900; font-size: 15px; text-decoration: none; cursor: pointer;
		transition: transform .2s cubic-bezier(.3,1.6,.5,1); }
	.tile:active { transform: scale(.95); }
	.dot { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; color: var(--ink); }
	.banner { text-decoration: none; display: flex; align-items: center; gap: 12px; text-align: left; color: #fff; cursor: pointer; font-size: 14px; }
	.scrim { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 40; }
	.sheet { position: fixed; z-index: 41; left: 50%; bottom: 0; translate: -50% 0; width: min(100%, 560px); padding: 20px 16px calc(20px + env(safe-area-inset-bottom));
		background: var(--deep); border-radius: 26px 26px 0 0; border: 1.5px solid var(--panel-stroke); animation: up .35s cubic-bezier(.3,1.3,.5,1); }
	@keyframes up { from { transform: translateY(100%); } }
	.code { text-align: center; font-size: 28px; letter-spacing: 2px; height: 64px; text-transform: uppercase; }
	.err { color: #ff8aa0; font-weight: 800; text-align: center; margin: 0; }
	@media (min-width: 900px) { .home { justify-content: flex-start; padding-top: 6vh; } }
</style>
