<script lang="ts">
	import { onDestroy } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { ChevronLeft, MessageCircle, WifiOff, RefreshCw, X, Home } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import { sfx } from '#lib/sfx.ts';
	import { playerAvatar, playerName } from '#lib/types.ts';
	import { Game, type GamePhase } from '#lib/game/game.svelte.ts';
	import Lobby from '#lib/game/Lobby.svelte';
	import LetterDraw from '#lib/game/LetterDraw.svelte';
	import Answering from '#lib/game/Answering.svelte';
	import Validating from '#lib/game/Validating.svelte';
	import Results from '#lib/game/Results.svelte';
	import Final from '#lib/game/Final.svelte';
	import Chat from '#lib/game/Chat.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Dialog from '#lib/components/Dialog.svelte';
	import Avatar from '#lib/components/Avatar.svelte';

	const id = page.params.id!;
	const game = new Game(id);
	app.activeRoom = id;
	game.start();
	onDestroy(() => { void game.stop(); app.activeRoom = null; });

	let showChat = $state(false), confirmLeave = $state(false);
	let wide = $state(false);
	$effect(() => { const mq = matchMedia('(min-width: 1024px)'); wide = mq.matches; const f = () => (wide = mq.matches); mq.addEventListener('change', f); return () => mq.removeEventListener('change', f); });

	// Sonidos por fase (igual que iOS)
	let lastPhase: GamePhase = 'loading';
	$effect(() => {
		const p = game.phase;
		if (p === 'answering' && lastPhase === 'letterDraw') sfx('go');
		if (p === 'validating' && lastPhase !== 'validating') sfx('tap');
		lastPhase = p;
	});
	let lastStop: string | null = null;
	$effect(() => { const s = game.currentRound?.stop_by ?? null; if (s && s !== lastStop) sfx('stop'); lastStop = s; });
	let lastHurry = -1;
	$effect(() => { const s = game.secondsLeft; if (game.phase === 'answering' && s > 0 && s <= 10 && s !== lastHurry) { lastHurry = s; sfx('hurry', s <= 5 ? .9 : .5); } });
	let lastCount = 0;
	$effect(() => { const n = game.activePlayers.length; if (n > lastCount && lastCount > 0 && game.phase === 'lobby') sfx('join'); lastCount = n; });
	let lastUnread = 0;
	$effect(() => { const n = game.unreadChat; if (n > lastUnread) sfx('message', .6); lastUnread = n; });
	$effect(() => { if (game.incomingMessage) { const t = setTimeout(() => (game.incomingMessage = null), 3500); return () => clearTimeout(t); } });

	const title = $derived.by(() => {
		const r = game.currentRound, total = game.room?.rounds_total ?? 1;
		switch (game.phase) {
			case 'lobby': return game.room?.name ?? 'Sala';
			case 'results': return `Ronda ${r?.number ?? 1}`;
			case 'finished': return 'Fin de la partida';
			default: return r ? `Ronda ${r.number} de ${total}` : 'Sala';
		}
	});

	async function leave() {
		if (game.phase !== 'finished') await game.leave();
		await game.stop();
		goto('/jugar');
		void app.refreshProfile();
	}
	function back() {
		if (['lobby', 'cancelled', 'loading', 'finished'].includes(game.phase)) leave(); else confirmLeave = true;
	}
</script>

<div class="shell" class:wide>
	<main class="main">
		<header class="bar">
			<button class="iconbtn" onclick={back} aria-label="Salir"><ChevronLeft /></button>
			<OutlinedTitle text={title} size={20} />
			{#if !wide}
				<button class="iconbtn" onclick={() => (showChat = true)} aria-label="Chat de la sala">
					<MessageCircle />{#if game.unreadChat > 0}<span class="badge">{game.unreadChat > 9 ? '9+' : game.unreadChat}</span>{/if}
				</button>
			{:else}<span></span>{/if}
		</header>

		{#if game.reconnecting && !game.isOffline}<div class="pill" transition:fly={{ y: -20 }}><RefreshCw size={14} /> Reconectando…</div>{/if}
		{#if game.notice && !game.reconnecting}<div class="pill" transition:fly={{ y: -20 }}><WifiOff size={14} /> {game.notice}</div>{/if}
		{#if game.incomingMessage && !showChat && !wide}
			{@const m = game.incomingMessage}
			<button class="banner" transition:fly={{ y: -40 }} onclick={() => { game.incomingMessage = null; showChat = true; }}>
				<Avatar avatar={playerAvatar(game.player(m.user_id)!)} size={34} /><span class="grow"><b>{playerName(game.player(m.user_id))}</b><br />{m.body}</span>
			</button>
		{/if}

		{#key game.phase}
			<div class="phase" in:fade={{ duration: 250 }}>
				{#if game.phase === 'loading'}
					<div class="center"><Mascot pose="hello" size={170} /><OutlinedTitle text="Conectando" size={26} /></div>
				{:else if game.phase === 'lobby' || game.phase === 'matchmaking'}<Lobby {game} />
				{:else if game.phase === 'letterDraw'}<LetterDraw {game} />
				{:else if game.phase === 'answering'}<Answering {game} />
				{:else if game.phase === 'validating'}<Validating {game} />
				{:else if game.phase === 'results'}<Results {game} />
				{:else if game.phase === 'finished'}<Final {game} />
				{:else}
					<div class="center"><Mascot pose="sad" size={170} /><OutlinedTitle text="La sala se cerró" size={28} />
						<div style="width: min(100%, 360px)"><CandyButton color="var(--tangerine)" icon={Home} ink onclick={() => goto('/jugar')}>Ir al inicio</CandyButton></div></div>
				{/if}
			</div>
		{/key}
	</main>

	{#if wide}
		<aside class="side">
			<h3 class="section-title">Jugadores</h3>
			<div class="plist">
				{#each game.activePlayers as p (p.user_id)}
					<div class="row"><Avatar avatar={playerAvatar(p)} name={playerName(p)} size={30} /><span class="grow">{playerName(p)}{p.user_id === game.me ? ' (tú)' : ''}</span><b class="sc">{p.score}</b></div>
				{/each}
			</div>
			<h3 class="section-title">Chat</h3>
			<div class="chatbox"><Chat {game} /></div>
		</aside>
	{/if}
</div>

{#if showChat && !wide}
	<div class="scrim" role="presentation" onclick={() => (showChat = false)} transition:fade={{ duration: 150 }}></div>
	<div class="sheet" transition:fly={{ y: 500, duration: 320 }}>
		<div class="row sheethead"><b class="grow">Chat de la sala</b><button class="iconbtn" aria-label="Cerrar" onclick={() => (showChat = false)}><X size={18} /></button></div>
		<Chat {game} />
	</div>
{/if}

{#if confirmLeave}
	<Dialog title="Salir" pose="bye" message={game.room?.is_public ? '¿Seguro que quieres abandonar? En salas públicas cuenta como derrota.' : '¿Seguro que quieres abandonar la partida?'}
		onconfirm={() => { confirmLeave = false; leave(); }} oncancel={() => (confirmLeave = false)} />
{/if}

{#if game.errorMessage}
	<Dialog title="Ups" pose="sad" message={game.errorMessage} confirm="OK" cancel="Cerrar" destructive={false}
		onconfirm={() => (game.errorMessage = null)} oncancel={() => (game.errorMessage = null)} />
{/if}

<style>
	.shell { width: 100%; max-width: 560px; margin: 0 auto; min-height: 100dvh; }
	.shell.wide { max-width: 1180px; display: grid; grid-template-columns: minmax(0, 1fr) 360px; gap: 24px; padding: 0 24px; }
	.main { padding: max(10px, env(safe-area-inset-top)) 16px 0; min-width: 0; }
	.wide .main { padding: 16px 0 0; }
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; margin-bottom: 10px; }
	.iconbtn { position: relative; display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon);
		border: 1.5px solid var(--panel-stroke); cursor: pointer; }
	.badge { position: absolute; top: -2px; right: -2px; min-width: 18px; height: 18px; padding: 0 4px; border-radius: 99px; background: var(--cherry); color: #fff; font-size: 11px; font-weight: 900; display: grid; place-items: center; }
	.pill { position: fixed; top: max(10px, env(safe-area-inset-top)); left: 50%; translate: -50% 0; z-index: 30; display: flex; gap: 6px; align-items: center;
		padding: 6px 12px; border-radius: 99px; background: rgba(20,30,50,.9); font-weight: 800; font-size: 13px; }
	.banner { position: fixed; top: 64px; left: 50%; translate: -50% 0; width: min(92vw, 520px); z-index: 30; display: flex; gap: 10px; align-items: center; text-align: left;
		padding: 10px 14px; border-radius: 20px; border: 0; background: rgba(20,30,50,.95); color: #fff; font-size: 14px; cursor: pointer; box-shadow: 0 8px 24px rgba(0,0,0,.3); }
	.center { min-height: 70dvh; display: grid; place-content: center; justify-items: center; gap: 16px; }
	.side { position: sticky; top: 0; height: 100dvh; padding: 16px 0; display: flex; flex-direction: column; gap: 10px; }
	.plist { display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: var(--radius); background: var(--panel); border: 1.5px solid var(--panel-stroke); }
	.sc { color: var(--lemon); }
	.chatbox { flex: 1; min-height: 0; padding: 12px; border-radius: var(--radius); background: var(--panel); border: 1.5px solid var(--panel-stroke); }
	.scrim { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 40; }
	.sheet { position: fixed; z-index: 41; left: 0; right: 0; bottom: 0; height: 72dvh; padding: 14px 14px calc(14px + env(safe-area-inset-bottom));
		background: var(--deep); border-radius: 26px 26px 0 0; border: 1.5px solid var(--panel-stroke); display: flex; flex-direction: column; gap: 8px; }
	.sheethead { font-size: 18px; }
</style>
