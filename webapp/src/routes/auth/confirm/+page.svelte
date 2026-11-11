<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { supabase } from '#lib/supabase.ts';
	import { friendlyError } from '#lib/errors.ts';
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';

	/**
	 * Enlaces de los correos de Supabase (plantillas con token_hash): confirmar cuenta, recuperar contraseña
	 * y cambio de correo. Funciona aunque el correo se pidiera desde el iPhone (no depende de PKCE).
	 */
	type OtpType = 'signup' | 'email' | 'recovery' | 'email_change' | 'invite' | 'magiclink';
	let error = $state<string | null>(null);
	const type = (page.url.searchParams.get('type') ?? 'email') as OtpType;
	const title = type === 'recovery' ? 'Recuperando tu cuenta…' : type === 'email_change' ? 'Confirmando tu correo…' : 'Confirmando tu cuenta…';

	onMount(async () => {
		const token_hash = page.url.searchParams.get('token_hash');
		if (!token_hash) { error = 'El enlace no es válido.'; return; }
		// Correo pedido desde la app de iPhone (redirect_to = tutifruti://…) y abierto en un iPhone: lo completa la app.
		// Si la app no se abre (otro dispositivo o sin la app), se confirma aquí en la web.
		const redirect = page.url.searchParams.get('redirect_to') ?? '';
		const ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
		if (redirect.startsWith('tutifruti://') && ios) {
			location.href = `tutifruti://auth/callback?token_hash=${encodeURIComponent(token_hash)}&type=${type}`;
			await new Promise((r) => setTimeout(r, 2500));
			if (document.hidden) return;  // se abrió la app
		}
		const { error: e } = await supabase.auth.verifyOtp({ token_hash, type });
		if (e) { error = /expired|invalid/i.test(e.message) ? 'El enlace venció o ya se usó. Pide uno nuevo.' : friendlyError(e); return; }
		location.replace(type === 'recovery' ? '/restablecer' : '/jugar');
	});
</script>

<svelte:head><title>Tutifruti AI</title><meta name="robots" content="noindex" /></svelte:head>
<main class="page stack c">
	<Mascot pose={error ? 'sad' : 'judge'} size={150} />
	<OutlinedTitle text={error ? 'Ups' : title} size={24} />
	{#if error}
		<p class="muted">{error}</p>
		<CandyButton color="var(--tangerine)" ink height={54} href="/jugar">Ir a Tutifruti</CandyButton>
	{/if}
</main>

<style>.c { min-height: 100dvh; justify-content: center; align-items: center; text-align: center; }</style>
