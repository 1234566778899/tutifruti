<script lang="ts">
	import { Send, Check } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import type { FriendRow } from '#lib/types.ts';
	import Sheet from '#lib/components/Sheet.svelte';
	import Avatar from '#lib/components/Avatar.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Mascot from '#lib/components/Mascot.svelte';

	/** Invita amigos a la sala (notificación room_invite, igual que iOS). */
	let { roomId, inRoom, onclose }: { roomId: string; inRoom: Set<string>; onclose: () => void } = $props();
	let friends = $state<FriendRow[]>([]), loaded = $state(false), picked = $state<Set<string>>(new Set()), sending = $state(false), error = $state<string | null>(null);
	const online = (f: FriendRow) => new Date(f.last_seen).getTime() > Date.now() - 90_000;
	const list = $derived(friends.filter((f) => f.status === 'accepted' && !inRoom.has(f.user_id))
		.sort((a, b) => Number(online(b)) - Number(online(a)) || a.username.localeCompare(b.username)));
	$effect(() => { API.friends().then((f) => (friends = f)).catch(() => {}).finally(() => (loaded = true)); });
	function toggle(id: string) { const s = new Set(picked); s.has(id) ? s.delete(id) : s.add(id); picked = s; sfx('tap', .5); }
	async function send() {
		sending = true; error = null;
		try {
			const n = await API.inviteToRoom(roomId, [...picked]);
			sfx('notify', .6);
			app.showToast(n === 1 ? 'Invitación enviada' : `${n} invitaciones enviadas`, false);
			onclose();
		} catch (e) { error = friendlyError(e); } finally { sending = false; }
	}
</script>

<Sheet title="Invitar amigos" {onclose}>
	{#if loaded && list.length === 0}
		<div class="empty"><Mascot pose="think" size={110} /><p class="muted">No tienes amigos para invitar. Comparte el enlace de la sala o tu enlace de amistad desde Amigos.</p></div>
	{:else}
		<div class="list">
			{#each list as f (f.user_id)}
				<button class="row f" class:on={picked.has(f.user_id)} onclick={() => toggle(f.user_id)}>
					<span class="av"><Avatar avatar={f.avatar} name={f.username} size={40} />{#if online(f)}<span class="dot"></span>{/if}</span>
					<span class="grow"><b>{f.username}</b><span class="muted small block">{f.playing ? 'Jugando una partida' : online(f) ? 'En línea' : `Nivel ${f.level}`}</span></span>
					<span class="chk">{#if picked.has(f.user_id)}<Check size={16} strokeWidth={4} />{/if}</span>
				</button>
			{/each}
		</div>
		{#if error}<p class="err">{error}</p>{/if}
		<CandyButton color="var(--lime)" icon={Send} ink height={52} disabled={picked.size === 0 || sending} onclick={send}>
			{sending ? 'Enviando…' : picked.size ? `Invitar (${picked.size})` : 'Elige a quién invitar'}
		</CandyButton>
	{/if}
</Sheet>

<style>
	.list { display: grid; gap: 8px; }
	.f { width: 100%; padding: 10px 12px; border-radius: 18px; border: 1.5px solid var(--panel-stroke); background: var(--panel); color: #fff; font: inherit; text-align: left; cursor: pointer; }
	.f.on { border-color: var(--lime); background: rgba(140,217,51,.12); }
	.av { position: relative; } .dot { position: absolute; right: 0; bottom: 0; width: 11px; height: 11px; border-radius: 50%; background: var(--lime); box-shadow: 0 0 0 2px var(--deep); }
	.block { display: block; }
	.chk { display: grid; place-items: center; width: 26px; height: 26px; border-radius: 50%; border: 2px solid rgba(255,255,255,.3); color: var(--ink); }
	.f.on .chk { background: var(--lime); border-color: var(--lime); }
	.empty { text-align: center; display: flex; flex-direction: column; align-items: center; }
	.err { color: #ff8aa0; font-weight: 800; text-align: center; margin: 0; }
</style>
