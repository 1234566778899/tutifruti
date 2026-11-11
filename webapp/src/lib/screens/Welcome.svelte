<script lang="ts">
	import { Play, Mail, LogIn } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Mascot from '#lib/components/Mascot.svelte';

	let mode = $state<'start' | 'login' | 'register' | 'forgot'>('start');
	let email = $state(''), password = $state(''), loading = $state(false), error = $state<string | null>(null), info = $state<string | null>(null);

	async function guest() {
		loading = true; error = null;
		try { await app.signInGuest(); } catch (e) { error = friendlyError(e); } finally { loading = false; }
	}
	async function submit(e: SubmitEvent) {
		e.preventDefault(); loading = true; error = null; info = null;
		try {
			if (mode === 'forgot') { await app.resetPassword(email); info = `Si ${email.trim()} tiene cuenta, te llegará un enlace para crear una contraseña nueva.`; }
			else if (mode === 'login') await app.signIn(email, password);
			else if (!(await app.signUp(email, password))) info = `Te enviamos un enlace a ${email} para confirmar tu cuenta.`;
		} catch (err) { error = friendlyError(err); } finally { loading = false; }
	}
</script>

<main class="page stack welcome">
	<div class="hero">
		<Logo height={92} />
		<div class="tuti">
			{#each [['A', -125, -45, 0], ['S', 128, -40, .8], ['M', -138, 55, 1.6], ['P', 132, 62, 2.4], ['R', -95, -88, 3.2], ['T', 100, -86, 4]] as [l, x, y, d]}
				<span class="fl" style:--x="{x}px" style:--y="{y}px" style:animation-delay="{-d}s">{l}</span>
			{/each}
			<Mascot pose="hello" size={180} />
		</div>
		<p class="tag">El clásico Stop / Basta con un árbitro de IA que valida cada respuesta.</p>
	</div>

	{#if mode === 'start'}
		<CandyButton color="var(--tangerine)" icon={Play} height={66} ink disabled={loading} onclick={guest}>{loading ? 'Entrando…' : 'Jugar ahora'}</CandyButton>
		<p class="muted small center">o guarda tu progreso con una cuenta</p>
		<div class="two">
			<button class="secondary" onclick={() => (mode = 'login')}><span class="dot"><LogIn size={16} strokeWidth={3} /></span>Iniciar sesión</button>
			<button class="secondary" onclick={() => (mode = 'register')}><span class="dot"><Mail size={16} strokeWidth={3} /></span>Crear cuenta</button>
		</div>
	{:else}
		<form class="panel stack" onsubmit={submit}>
			<input class="field" type="email" placeholder="nombre@correo.com" autocomplete="email" bind:value={email} required />
			{#if mode !== 'forgot'}
				<input class="field" type="password" placeholder="Contraseña (mínimo 8)" autocomplete={mode === 'login' ? 'current-password' : 'new-password'} minlength="8" bind:value={password} required />
			{/if}
			<CandyButton type="submit" color="var(--lemon)" ink height={54} disabled={loading}>{mode === 'login' ? 'Iniciar sesión' : mode === 'forgot' ? 'Enviar enlace' : 'Crear cuenta'}</CandyButton>
			{#if mode === 'login'}<button type="button" class="link" onclick={() => { mode = 'forgot'; error = null; }}>¿Olvidaste tu contraseña?</button>{/if}
			<button type="button" class="link" onclick={() => { mode = 'start'; error = null; info = null; }}>Volver</button>
		</form>
	{/if}
	{#if error}<p class="err">{error}</p>{/if}
	{#if info}<p class="ok">{info}</p>{/if}
	<p class="muted legal">Al continuar aceptas los <a href="/terminos">Términos</a> y la <a href="/privacidad">Política de privacidad</a>. <a href="/">Conoce Tutifruti</a></p>
</main>

<style>
	.welcome { min-height: 100dvh; justify-content: center; }
	.hero { display: flex; flex-direction: column; align-items: center; gap: 8px; }
	.tuti { position: relative; display: grid; place-items: center; height: 220px; width: 100%; }
	.fl { position: absolute; left: 50%; top: 50%; width: 38px; height: 38px; margin: -19px 0 0 -19px; display: grid; place-items: center; border-radius: 10px;
		color: #fff; font-weight: 900; font-size: 21px; background: linear-gradient(135deg, #ff8c1a, #fa4085); opacity: .9;
		transform: translate(var(--x), var(--y)); animation: float 3s ease-in-out infinite alternate; }
	@keyframes float { from { transform: translate(var(--x), var(--y)) rotate(-12deg); } to { transform: translate(var(--x), calc(var(--y) - 10px)) rotate(12deg); } }
	.tag { text-align: center; font-weight: 800; color: rgba(255,255,255,.85); margin: 0 16px; }
	.center { text-align: center; margin: 0; }
	.two { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
	.secondary { display: flex; align-items: center; justify-content: center; gap: 8px; height: 50px; border-radius: 999px; border: 1.5px solid var(--panel-stroke);
		background: rgba(255,255,255,.08); color: #fff; font-weight: 900; font-size: 15px; cursor: pointer; }
	.dot { display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--lemon); color: var(--ink); }
	.link { background: none; border: 0; color: var(--lemon); font-weight: 900; cursor: pointer; }
	.err { color: #ff8aa0; font-weight: 800; text-align: center; margin: 0; }
	.ok { color: var(--lime); font-weight: 800; text-align: center; margin: 0; }
	.legal { font-size: 12px; text-align: center; margin: 0; }
	.legal a { color: var(--lemon); }
</style>
