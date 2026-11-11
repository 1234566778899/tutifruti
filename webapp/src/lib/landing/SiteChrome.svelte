<script lang="ts">
	import type { Snippet } from 'svelte';
	import { onMount } from 'svelte';
	import { Play } from '@lucide/svelte';
	/** Barra superior y pie de las páginas públicas. */
	let { children }: { children: Snippet } = $props();
	let hasSession = $state(false), scrolled = $state(false);
	onMount(() => {
		// Enlaces de correo de Supabase (confirmación / recuperación) que caen en el Site URL: se pasan a la app web.
		const h = location.hash;
		if (/access_token=|error_description=/.test(h)) { location.replace((/type=recovery/.test(h) ? '/restablecer' : '/jugar') + h); return; }
		if (new URLSearchParams(location.search).has('code')) { location.replace('/jugar' + location.search); return; }
		try { hasSession = Object.keys(localStorage).some((k) => k.startsWith('sb-') && k.endsWith('-auth-token')); } catch { /* privado */ }
		const on = () => (scrolled = window.scrollY > 12);
		on(); window.addEventListener('scroll', on, { passive: true });
		return () => window.removeEventListener('scroll', on);
	});
</script>

<header class="nav" class:scrolled>
	<div class="inner">
		<a class="brand" href="/" aria-label="Tutifruti AI, inicio"><img src="/img/ui/logo_wordmark.png" alt="Tutifruti AI" height="40" width="139" /></a>
		<nav aria-label="Secciones">
			<a href="/#como-se-juega">Cómo se juega</a>
			<a href="/#arbitro">Árbitro IA</a>
			<a href="/#preguntas">Preguntas</a>
		</nav>
		<a class="cta" href="/jugar"><Play size={16} strokeWidth={3} />{hasSession ? 'Seguir jugando' : 'Jugar'}</a>
	</div>
</header>

{@render children()}

<footer class="foot">
	<div class="inner">
		<img src="/img/mascot/tuti_bye.png" alt="" width="72" height="72" loading="lazy" />
		<div class="grow">
			<b>Tutifruti AI</b>
			<p>El Stop, Basta o Tutifruti de siempre, con un árbitro de inteligencia artificial. Hecho con cariño en Latinoamérica.</p>
		</div>
		<nav aria-label="Legal">
			<a href="/como-jugar">Reglas</a>
			<a href="/terminos">Términos</a>
			<a href="/privacidad">Privacidad</a>
		</nav>
	</div>
	<p class="copy">© 2026 Tutifruti AI</p>
</footer>

<style>
	.nav { position: sticky; top: 0; z-index: 30; transition: background .25s, box-shadow .25s; }
	.nav.scrolled { background: rgba(10, 23, 51, .82); backdrop-filter: blur(14px); box-shadow: 0 1px 0 rgba(255,255,255,.08); }
	.inner { max-width: 1120px; margin: 0 auto; padding: 12px 20px; display: flex; align-items: center; gap: 18px; }
	.brand img { display: block; height: 40px; width: auto; }
	nav { display: flex; gap: 22px; margin-left: auto; }
	nav a { color: rgba(255,255,255,.8); text-decoration: none; font-weight: 800; font-size: 15px; }
	nav a:hover { color: var(--lemon); }
	.cta { display: inline-flex; align-items: center; gap: 6px; padding: 10px 18px; border-radius: 999px; background: var(--lemon); color: var(--ink);
		font-weight: 900; text-decoration: none; box-shadow: inset 0 0 0 1.5px rgba(46,28,20,.5); white-space: nowrap; }
	.cta:active { transform: scale(.96); }
	@media (max-width: 760px) { header nav { display: none; } .cta { margin-left: auto; } }
	.foot { margin-top: 40px; border-top: 1px solid rgba(255,255,255,.08); background: rgba(5, 12, 28, .5); }
	.foot .inner { align-items: flex-start; padding: 28px 20px 10px; flex-wrap: wrap; }
	.foot p { margin: 4px 0 0; color: rgba(255,255,255,.65); font-size: 14px; max-width: 460px; }
	.foot nav { flex-direction: column; gap: 8px; }
	.copy { text-align: center; color: rgba(255,255,255,.4); font-size: 13px; padding: 0 0 24px; margin: 0; }
</style>
