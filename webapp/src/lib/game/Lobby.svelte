<script lang="ts">
	import { Copy, Check, Share2, Globe, Lock, Crown, UserPlus, Play, Hand, RotateCw, Timer, Users } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import InviteFriends from './InviteFriends.svelte';
	import { INVITE_HOST } from '#lib/supabase.ts';
	import { sfx } from '#lib/sfx.ts';
	import { isConnected, playerAvatar, playerName } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import Pill from '#lib/components/Pill.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';

	let { game }: { game: Game } = $props();
	let copied = $state(false), starting = $state(false), inviting = $state(false);
	const room = $derived(game.room!);
	const readyCount = $derived(game.activePlayers.filter((p) => p.ready).length);
	const free = $derived(Math.max(0, Math.min(2, room.max_players - game.activePlayers.length)));
	const link = $derived(`https://${INVITE_HOST}/j/${room.code}`);

	async function copy() {
		try { await navigator.clipboard.writeText(room.code); } catch { /* sin permiso */ }
		copied = true; sfx('coin', 0.5); setTimeout(() => (copied = false), 2000);
	}
	async function share() {
		const text = `¡Juega Tutifruti conmigo! Toca el enlace para entrar a la sala ${room.code}:`;
		if (navigator.share) { try { await navigator.share({ title: 'Tutifruti AI', text, url: link }); } catch { /* cancelado */ } }
		else { try { await navigator.clipboard.writeText(`${text} ${link}`); } catch { /* sin permiso */ } copied = true; setTimeout(() => (copied = false), 2000); }
	}
</script>

<div class="stack">
	<section class="panel code">
		<Pill text={room.is_public ? 'Sala pública' : 'Sala privada'} icon={room.is_public ? Globe : Lock} color={room.is_public ? 'var(--lime)' : 'var(--grape)'} ink={room.is_public} />
		<div class="big">{room.code}</div>
		<div class="acts">
			<button class="act" onclick={copy}><span class="dot" style:background={copied ? 'var(--lime)' : 'var(--lemon)'}>{#if copied}<Check size={15} strokeWidth={3} />{:else}<Copy size={15} strokeWidth={3} />{/if}</span>{copied ? '¡Copiado!' : 'Copiar'}</button>
			<button class="act" onclick={share}><span class="dot"><Share2 size={15} strokeWidth={3} /></span>Enlace</button>
			{#if !app.isGuest}<button class="act" onclick={() => (inviting = true)}><span class="dot" style:background="var(--sky)"><Users size={15} strokeWidth={3} /></span>Amigos</button>{/if}
		</div>
		{#if room.is_public}<p class="muted small">Visible en Salas públicas: cualquiera puede unirse hasta que inicies.</p>{/if}
	</section>

	<h3 class="section-title">Jugadores <span class="cnt">{game.activePlayers.length}/{room.max_players}</span></h3>
	<div class="players">
		{#each game.activePlayers as p, i (p.user_id)}
			{@const online = isConnected(p, game.now)}
			<div class="panel pl" style:animation-delay="{i * 60}ms">
				<span class="avw"><Avatar avatar={playerAvatar(p)} name={playerName(p)} size={46} />{#if room.host_id === p.user_id}<span class="crown"><Crown size={11} strokeWidth={3} /></span>{/if}</span>
				<div class="grow"><b>{playerName(p)}{p.user_id === game.me ? ' (tú)' : ''}</b><div class="muted small">Nivel {p.profile?.level ?? 1}{room.host_id === p.user_id ? ' · Anfitrión' : ''}</div></div>
				{#if !online}<Pill text="Sin conexión" color="var(--cherry)" ink={false} />
				{:else if p.ready}<Pill text="Listo" icon={Check} />
				{:else}<Pill text="Esperando" color="var(--tangerine)" />{/if}
			</div>
		{/each}
		{#each { length: free } as _}
			<div class="slot"><UserPlus size={20} /> Libre</div>
		{/each}
	</div>

	<h3 class="section-title">Reglas</h3>
	<section class="panel rules">
		<div><RotateCw size={18} color="var(--lemon)" /><b>{room.rounds_total}</b><small>rondas</small></div>
		<div><Timer size={18} color="var(--lemon)" /><b>{room.round_seconds}s</b><small>por ronda</small></div>
		<div><Hand size={18} color="var(--lemon)" /><b>{room.stop_seconds}s</b><small>tras STOP</small></div>
		<div class="catlist">{#each room.categories as c}<span>{c}</span>{/each}</div>
	</section>

	<div class="bottom">
		{#if game.isHost}
			<CandyButton color="var(--lime)" icon={Play} ink disabled={starting || readyCount < 2} onclick={async () => { starting = true; await game.startGame(); starting = false; }}>
				{starting ? 'Iniciando…' : 'Iniciar partida'}
			</CandyButton>
			<p class="muted small">{readyCount < 2 ? 'Necesitas al menos 2 jugadores listos' : '¡Todo listo para empezar!'}</p>
		{:else if game.myPlayer}
			<CandyButton color={game.myPlayer.ready ? 'var(--lime)' : 'var(--tangerine)'} icon={game.myPlayer.ready ? Check : Hand} ink onclick={() => game.setReady(!game.myPlayer!.ready)}>
				{game.myPlayer.ready ? '¡Estoy listo!' : 'Marcar como listo'}
			</CandyButton>
			<p class="muted small">Espera a que el anfitrión inicie la partida</p>
		{/if}
	</div>
</div>

{#if inviting}<InviteFriends roomId={game.roomId} inRoom={new Set(game.activePlayers.map((p) => p.user_id))} onclose={() => (inviting = false)} />{/if}

<style>
	.code { display: flex; flex-direction: column; align-items: center; gap: 12px; }
	.big { font-size: 40px; font-weight: 900; letter-spacing: 1px; font-family: ui-monospace, 'SF Mono', Menlo, monospace; }
	.acts { display: grid; grid-auto-flow: column; grid-auto-columns: 1fr; gap: 10px; width: 100%; }
	.act { display: flex; align-items: center; justify-content: center; gap: 8px; height: 48px; border-radius: 99px; border: 1.5px solid var(--panel-stroke);
		background: rgba(255,255,255,.08); color: #fff; font-weight: 900; font-size: 15px; cursor: pointer; transition: transform .15s; }
	.act:active { transform: scale(.95); }
	.dot { display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--lemon); color: var(--ink); }
	.code p { margin: 0; text-align: center; }
	.cnt { float: right; color: #fff; -webkit-text-stroke: 0; }
	.players { display: grid; gap: 10px; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); }
	.pl { display: flex; align-items: center; gap: 12px; padding: 10px; animation: pop .45s cubic-bezier(.3,1.6,.5,1) both; }
	@keyframes pop { from { opacity: 0; transform: scale(.85) translateY(10px); } }
	.avw { position: relative; }
	.crown { position: absolute; right: -4px; bottom: -4px; display: grid; place-items: center; width: 22px; height: 22px; border-radius: 50%; background: var(--lemon); color: var(--ink); }
	.slot { display: flex; align-items: center; gap: 10px; padding: 18px 14px; border-radius: 20px; border: 2px dashed rgba(255,255,255,.25); color: rgba(255,255,255,.6); font-weight: 900; }
	.rules { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; text-align: center; }
	.rules > div { display: flex; flex-direction: column; align-items: center; gap: 2px; }
	.rules b { font-size: 20px; } .rules small { font-weight: 800; opacity: .7; font-size: 11px; }
	.catlist { grid-column: 1 / -1; flex-direction: row !important; flex-wrap: wrap; justify-content: center; gap: 6px !important; margin-top: 6px; }
	.catlist span { padding: 6px 10px; border-radius: 99px; background: var(--header); border: 1.5px solid rgba(255,210,63,.5); font-weight: 800; font-size: 14px; }
	.bottom { position: sticky; bottom: 0; padding: 18px 0 calc(8px + env(safe-area-inset-bottom)); background: linear-gradient(transparent, var(--night) 30%);
		display: flex; flex-direction: column; align-items: center; gap: 6px; }
	.bottom p { margin: 0; }
</style>
