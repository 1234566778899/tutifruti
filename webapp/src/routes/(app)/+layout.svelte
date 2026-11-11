<script lang="ts">
	import { onMount } from 'svelte';
	import { fly } from 'svelte/transition';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { app } from '#lib/app.svelte.ts';
	import * as API from '#lib/api.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import { applyTheme, usableTheme } from '#lib/themes.ts';
	import Mascot from '#lib/components/Mascot.svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Welcome from '#lib/screens/Welcome.svelte';
	import ProfileSetup from '#lib/screens/ProfileSetup.svelte';

	let { children } = $props();

	onMount(() => app.start());

	// Tema visual equipado (Pizarra / Neón) en todas las pantallas del juego.
	$effect(() => applyTheme(usableTheme(app.profile)));

	// Enlaces /j/CODIGO (sala) y /a/TOKEN (amistad): se guardan hasta tener sesión.
	$effect(() => {
		const path = page.url.pathname;
		const j = path.match(/^\/j\/(TUTI-[A-Z0-9]{4,6})$/i);
		const a = path.match(/^\/a\/([A-Za-z0-9]{8,32})$/);
		if (j) app.pendingJoinCode = j[1].toUpperCase();
		if (a) app.pendingFriendToken = a[1];
	});

	// Con sesión lista, procesa los enlaces pendientes.
	$effect(() => {
		if (app.phase !== 'ready') return;
		const code = app.pendingJoinCode, token = app.pendingFriendToken;
		if (code) {
			app.pendingJoinCode = null;
			API.joinByCode(code).then((id) => { sfx('join'); goto(`/sala/${id}`, { replaceState: true }); })
				.catch((e) => { app.showToast(friendlyError(e)); goto('/jugar', { replaceState: true }); });
		}
		if (token) {
			app.pendingFriendToken = null;
			if (app.isGuest) { app.showToast('Crea una cuenta para agregar amigos.'); goto('/jugar', { replaceState: true }); return; }
			API.acceptFriendInvite(token).then((r) => {
				sfx('levelup');
				app.showToast(r.status === 'already' ? `Ya eras amigo de ${r.username}` : `¡Ahora eres amigo de ${r.username}!`, false);
				goto('/amigos', { replaceState: true });
			}).catch((e) => { app.showToast(friendlyError(e)); goto('/jugar', { replaceState: true }); });
		}
	});
</script>

<svelte:head>
	<title>Jugar · Tutifruti AI</title>
	<meta name="robots" content="noindex" />
</svelte:head>

{#if app.phase === 'loading'}
	<div class="center"><Logo height={80} /><Mascot pose="hello" size={150} /></div>
{:else if app.phase === 'signedOut'}
	<Welcome />
{:else if app.phase === 'needsProfile'}
	<ProfileSetup />
{:else}
	{@render children()}
{/if}

{#if app.toast}
	<div class="toast" transition:fly={{ y: -40, duration: 300 }} role="status">{app.toast}</div>
{/if}

<style>
	.center { min-height: 100dvh; display: grid; place-content: center; justify-items: center; gap: 18px; }
	.toast { position: fixed; top: max(12px, env(safe-area-inset-top)); left: 50%; translate: -50% 0; z-index: 80; padding: 10px 16px;
		border-radius: 999px; background: rgba(20, 30, 50, .92); backdrop-filter: blur(12px); font-weight: 800; font-size: 15px;
		box-shadow: 0 6px 20px rgba(0,0,0,.3); max-width: 92vw; text-align: center; }
</style>
