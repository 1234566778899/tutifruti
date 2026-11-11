<script lang="ts">
	import { app } from '#lib/app.svelte.ts';
	import { tick } from 'svelte';
	import { Send } from '@lucide/svelte';
	import { playerAvatar, playerName } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Avatar from '#lib/components/Avatar.svelte';

	let { game }: { game: Game } = $props();
	let text = $state(''), list: HTMLDivElement;
	const quick = ['¡Suerte!', 'GG', '¡Qué rápido!', '¡Bien jugado!'];
	$effect(() => { game.chat.length; tick().then(() => list?.scrollTo({ top: list.scrollHeight, behavior: 'smooth' })); });
	$effect(() => { game.chatOpen = true; game.unreadChat = 0; return () => (game.chatOpen = false); });
	async function send(t = text) { if (!t.trim()) return; text = ''; await game.sendChat(t); }
</script>

<div class="chat">
	<div class="list" bind:this={list}>
		{#each game.chat.filter((m) => !m.user_id || !app.muted.has(m.user_id)) as m (m.id)}
			{#if m.kind !== 'msg'}
				<p class="sys">{m.body}</p>
			{:else}
				{@const mine = m.user_id === game.me}
				{@const a = game.player(m.user_id)}
				<div class="msg" class:mine>
					{#if !mine}<Avatar avatar={playerAvatar(a!)} name={playerName(a)} size={26} />{/if}
					<div>{#if !mine}<span class="who">{playerName(a)}</span>{/if}<span class="bubble">{m.body}</span></div>
				</div>
			{/if}
		{/each}
	</div>
	<div class="quick">{#each quick as q}<button onclick={() => send(q)}>{q}</button>{/each}</div>
	<form class="row" onsubmit={(e) => { e.preventDefault(); send(); }}>
		<input class="field grow" placeholder="Escribe un mensaje…" bind:value={text} maxlength="300" />
		<button class="sendbtn" aria-label="Enviar" disabled={!text.trim()}><Send size={18} /></button>
	</form>
</div>

<style>
	.chat { display: flex; flex-direction: column; gap: 8px; height: 100%; min-height: 0; }
	.list { flex: 1; overflow: auto; display: flex; flex-direction: column; gap: 8px; padding: 4px; }
	.sys { text-align: center; font-size: 12px; color: rgba(255,255,255,.55); margin: 2px 0; font-weight: 700; }
	.msg { display: flex; gap: 6px; align-items: flex-end; } .msg.mine { justify-content: flex-end; }
	.who { display: block; font-size: 11px; color: rgba(255,255,255,.5); font-weight: 800; margin: 0 0 2px 4px; }
	.bubble { display: inline-block; padding: 8px 12px; border-radius: 16px; background: var(--panel); font-weight: 700; max-width: 260px; word-wrap: break-word; }
	.mine .bubble { background: var(--lemon); color: var(--ink); }
	.quick { display: flex; gap: 6px; overflow-x: auto; }
	.quick button { flex: none; padding: 6px 12px; border-radius: 99px; border: 0; background: rgba(255,210,63,.15); color: var(--lemon); font-weight: 900; cursor: pointer; }
	.sendbtn { width: 50px; height: 50px; border-radius: 50%; border: 0; background: var(--lemon); color: var(--ink); display: grid; place-items: center; cursor: pointer; }
	.sendbtn:disabled { opacity: .4; }
</style>
