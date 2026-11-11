<script lang="ts">
	import { ChevronLeft, Share2, Copy, Check, Search, UserPlus, UserCheck, X, UserX, RefreshCw, Clock } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { INVITE_HOST } from '#lib/supabase.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import type { FriendRow, SearchUser } from '#lib/types.ts';
	import Avatar from '#lib/components/Avatar.svelte';
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Dialog from '#lib/components/Dialog.svelte';

	let friends = $state<FriendRow[]>([]), token = $state<string | null>(null), copied = $state(false), loaded = $state(false);
	let query = $state(''), results = $state<SearchUser[]>([]), searching = $state(false);
	let removing = $state<FriendRow | null>(null), renewing = $state(false), confirmRenew = $state(false);

	const accepted = $derived(friends.filter((f) => f.status === 'accepted').sort((a, b) => Number(online(b)) - Number(online(a)) || a.username.localeCompare(b.username)));
	const incoming = $derived(friends.filter((f) => f.status === 'pending' && f.incoming));
	const outgoing = $derived(friends.filter((f) => f.status === 'pending' && !f.incoming));
	const online = (f: FriendRow) => new Date(f.last_seen).getTime() > Date.now() - 90_000;
	const status = (f: FriendRow) => (f.playing ? 'Jugando una partida' : online(f) ? 'En línea' : `Visto ${ago(f.last_seen)}`);
	function ago(iso: string) {
		const m = Math.max(1, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
		if (m < 60) return `hace ${m} min`;
		const h = Math.round(m / 60); if (h < 24) return `hace ${h} h`;
		const d = Math.round(h / 24); return d === 1 ? 'ayer' : `hace ${d} días`;
	}

	async function load() { try { friends = await API.friends(); } catch { /* sin conexión */ } finally { loaded = true; } }
	$effect(() => {
		if (app.isGuest) { loaded = true; return; }
		load();
		API.myFriendInvite().then((t) => (token = t)).catch(() => {});
		const t = setInterval(load, 30_000);
		return () => clearInterval(t);
	});

	// Búsqueda con espera para no llamar en cada tecla.
	$effect(() => {
		const q = query.trim();
		if (q.length < 2) { results = []; return; }
		searching = true;
		const t = setTimeout(async () => {
			try { results = await API.searchUsers(q); } catch { results = []; } finally { searching = false; }
		}, 350);
		return () => clearTimeout(t);
	});

	async function act(fn: () => Promise<unknown>, sound: Parameters<typeof sfx>[0] = 'tap') {
		try { await fn(); sfx(sound, .6); await load(); if (query.trim().length >= 2) results = await API.searchUsers(query.trim()); }
		catch (e) { app.showToast(friendlyError(e)); }
	}

	const link = $derived(token ? `https://${INVITE_HOST}/a/${token}` : '');
	async function share() {
		const text = '¡Agrégame como amigo en Tutifruti AI! Toca el enlace:';
		if (typeof navigator.share === 'function') { try { await navigator.share({ title: 'Tutifruti AI', text, url: link }); } catch { /* cancelado */ } return; }
		try { await navigator.clipboard.writeText(`${text} ${link}`); copied = true; sfx('coin', .5); setTimeout(() => (copied = false), 2000); } catch { /* sin permiso */ }
	}
	async function renew() {
		confirmRenew = false; renewing = true;
		try { token = await API.myFriendInvite(true); app.showToast('Nuevo enlace creado. El anterior ya no funciona.', false); }
		catch (e) { app.showToast(friendlyError(e)); } finally { renewing = false; }
	}
</script>

<main class="page wide-ish stack">
	<header class="bar"><a class="iconbtn" href="/jugar" aria-label="Volver"><ChevronLeft /></a><OutlinedTitle text="Amigos" size={22} /><span></span></header>
	{#if app.isGuest}
		<div class="empty stack"><Mascot pose="think" size={140} /><OutlinedTitle text="Solo con cuenta" size={22} />
			<p class="muted">Los invitados no tienen amigos. Guarda tu progreso con un correo para agregar amigos.</p>
			<CandyButton color="var(--lemon)" ink height={50} href="/perfil">Guardar mi progreso</CandyButton></div>
	{:else}
		<div class="cols">
			<div class="stack">
				<section class="panel stack card">
					<div class="row"><img src="/img/icons/invite.png" alt="" width="44" height="44" /><div class="grow"><b>Tu enlace de amistad</b><div class="muted small">Quien lo abra quedará como tu amigo al instante.</div></div></div>
					<CandyButton color="var(--lime)" icon={copied ? Check : 'share' in navigator ? Share2 : Copy} ink height={50} disabled={!token} onclick={share}>{copied ? '¡Copiado!' : 'Compartir enlace'}</CandyButton>
					<button class="link" disabled={renewing} onclick={() => (confirmRenew = true)}><RefreshCw size={14} /> Generar un enlace nuevo</button>
				</section>

				<label class="search">
					<Search size={18} />
					<input placeholder="Buscar por nombre de usuario" bind:value={query} autocomplete="off" autocapitalize="none" spellcheck="false" />
					{#if query}<button class="clear" aria-label="Borrar búsqueda" onclick={() => (query = '')}><X size={16} /></button>{/if}
				</label>
				{#if query.trim().length >= 2}
					<section class="panel stack">
						{#if searching && results.length === 0}<p class="muted small">Buscando…</p>
						{:else if results.length === 0}<p class="muted small">No encontramos a nadie con “{query.trim()}”.</p>{/if}
						{#each results as u (u.user_id)}
							<div class="row"><Avatar avatar={u.avatar} name={u.username} size={40} />
								<div class="grow"><b>{u.username}</b><div class="muted small">Nivel {u.level}</div></div>
								{#if u.relation === 'friends'}<span class="tag ok"><UserCheck size={14} /> Amigos</span>
								{:else if u.relation === 'sent'}<span class="tag"><Clock size={14} /> Enviada</span>
								{:else if u.relation === 'received'}<button class="pill lime" onclick={() => act(() => API.respondFriendRequest(u.user_id, true), 'levelup')}>Aceptar</button>
								{:else}<button class="pill" onclick={() => act(() => API.sendFriendRequest(u.user_id), 'notify')}><UserPlus size={15} /> Agregar</button>{/if}
							</div>
						{/each}
					</section>
				{/if}

				{#if incoming.length}
					<h3 class="section-title">Solicitudes · {incoming.length}</h3>
					<section class="panel stack">
						{#each incoming as f (f.user_id)}
							<div class="row"><Avatar avatar={f.avatar} name={f.username} size={40} />
								<div class="grow"><b>{f.username}</b><div class="muted small">Quiere ser tu amigo</div></div>
								<button class="round lime" aria-label="Aceptar a {f.username}" onclick={() => act(() => API.respondFriendRequest(f.user_id, true), 'levelup')}><Check size={18} strokeWidth={3.5} /></button>
								<button class="round" aria-label="Rechazar a {f.username}" onclick={() => act(() => API.respondFriendRequest(f.user_id, false))}><X size={18} strokeWidth={3.5} /></button>
							</div>
						{/each}
					</section>
				{/if}
				{#if outgoing.length}
					<h3 class="section-title">Enviadas</h3>
					<section class="panel stack">
						{#each outgoing as f (f.user_id)}
							<div class="row"><Avatar avatar={f.avatar} name={f.username} size={36} /><div class="grow"><b>{f.username}</b><div class="muted small">Esperando respuesta</div></div>
								<button class="link small" onclick={() => act(() => API.removeFriend(f.user_id))}>Cancelar</button></div>
						{/each}
					</section>
				{/if}
			</div>

			<div class="stack">
				{#if loaded && accepted.length === 0}
					<div class="empty stack"><Mascot pose="hello" size={130} /><OutlinedTitle text="Aún no tienes amigos" size={20} /><p class="muted">Comparte tu enlace o búscalos por su nombre de usuario.</p></div>
				{:else if accepted.length}
					<h3 class="section-title">Tus amigos · {accepted.length}</h3>
					<section class="panel stack">
						{#each accepted as f (f.user_id)}
							<div class="row"><span class="av"><Avatar avatar={f.avatar} name={f.username} size={42} />{#if online(f)}<span class="on"></span>{/if}</span>
								<div class="grow"><b>{f.username}</b><div class="muted small">Nivel {f.level} · {status(f)}{f.games_together ? ` · ${f.games_together} ${f.games_together === 1 ? 'partida' : 'partidas'} juntos` : ''}</div></div>
								<button class="round ghost" aria-label="Eliminar a {f.username}" onclick={() => (removing = f)}><UserX size={17} /></button>
							</div>
						{/each}
					</section>
				{/if}
			</div>
		</div>
	{/if}
</main>

{#if removing}
	<Dialog title="Eliminar amigo" message="¿Quieres eliminar a {removing.username} de tus amigos?" pose="sad" confirm="Eliminar" cancel="Cancelar"
		onconfirm={() => { const f = removing!; removing = null; act(() => API.removeFriend(f.user_id)); }} oncancel={() => (removing = null)} />
{/if}
{#if confirmRenew}
	<Dialog title="Enlace nuevo" message="El enlace que ya compartiste dejará de funcionar. ¿Generar uno nuevo?" pose="think" confirm="Generar" cancel="Cancelar" destructive={false}
		onconfirm={renew} oncancel={() => (confirmRenew = false)} />
{/if}

<style>
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.empty { align-items: center; text-align: center; padding-top: 20px; }
	.av { position: relative; } .on { position: absolute; right: 0; bottom: 0; width: 12px; height: 12px; border-radius: 50%; background: var(--lime); box-shadow: 0 0 0 2px var(--deep); }
	.link { background: none; border: 0; color: var(--lemon); font-weight: 900; cursor: pointer; display: inline-flex; gap: 6px; align-items: center; justify-content: center; }
	.search { display: flex; align-items: center; gap: 10px; height: 52px; padding: 0 14px; border-radius: 999px; background: rgba(255,255,255,.08); border: 1.5px solid var(--panel-stroke); color: rgba(255,255,255,.6); }
	.search:focus-within { border-color: var(--lemon); }
	.search input { flex: 1; min-width: 0; background: none; border: 0; outline: 0; color: #fff; font: inherit; font-weight: 800; font-size: 16px; }
	.clear { background: none; border: 0; color: inherit; cursor: pointer; display: grid; }
	.tag { display: inline-flex; gap: 4px; align-items: center; font-weight: 900; font-size: 13px; color: rgba(255,255,255,.6); }
	.tag.ok { color: var(--lime); }
	.pill { display: inline-flex; gap: 5px; align-items: center; height: 36px; padding: 0 14px; border-radius: 99px; border: 0; background: var(--lemon); color: var(--ink); font-weight: 900; cursor: pointer; }
	.pill.lime, .round.lime { background: var(--lime); color: var(--ink); }
	.round { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 50%; border: 0; background: rgba(255,255,255,.12); color: #fff; cursor: pointer; flex: none; }
	.round.ghost { background: none; color: rgba(255,255,255,.45); }
	.round.ghost:hover { color: #ff8aa0; }
	.wide-ish { max-width: 980px; }
	.cols { display: grid; gap: 14px; }
	@media (min-width: 900px) { .cols { grid-template-columns: 1fr 1fr; align-items: start; } }
</style>
