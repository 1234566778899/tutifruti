<script lang="ts">
	import { Play, Users, Globe, Lock, Sparkles, Flag, MessageCircle, Smartphone, Timer, Hand, BadgeCheck } from '@lucide/svelte';
	import Seo from '#lib/landing/Seo.svelte';
	import SiteChrome from '#lib/landing/SiteChrome.svelte';
	import RoundDemo from '#lib/landing/RoundDemo.svelte';
	import { reveal } from '#lib/landing/reveal.ts';
	import { FAQ } from '#lib/landing/faq.ts';
	import AppStoreBadge, { APP_STORE_URL } from '#lib/landing/AppStoreBadge.svelte';

	const title = 'Tutifruti AI · Juega Stop, Basta o Tutifruti online con árbitro de IA';
	const description = 'Juega gratis al Stop / Basta / Tutifruti online con tus amigos. Sale una letra, completa las categorías y un árbitro de inteligencia artificial valida cada respuesta. En el navegador y en iPhone.';
	const jsonld = [
		{
			'@context': 'https://schema.org', '@type': 'VideoGame', name: 'Tutifruti AI', alternateName: ['Stop', 'Basta', 'Tutifruti', 'Mercado'],
			url: 'https://tutifruti.site/', image: 'https://tutifruti.site/og.png', description, inLanguage: 'es',
			genre: ['Juego de palabras', 'Party game', 'Trivia'], playMode: ['MultiPlayer', 'CoOp'], numberOfPlayers: { '@type': 'QuantitativeValue', minValue: 2, maxValue: 12 },
			gamePlatform: ['Web', 'iOS'], applicationCategory: 'GameApplication', operatingSystem: 'Web, iOS',
			offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' }, sameAs: [APP_STORE_URL]
		},
		{ '@context': 'https://schema.org', '@type': 'WebSite', name: 'Tutifruti AI', url: 'https://tutifruti.site/', inLanguage: 'es' },
		{
			'@context': 'https://schema.org', '@type': 'FAQPage',
			mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } }))
		}
	];

	const steps = [
		{ icon: Users, color: 'var(--sky)', title: 'Arma la sala', text: 'Crea una sala privada y comparte el código, o entra a una pública.' },
		{ icon: Sparkles, color: 'var(--lemon)', title: 'Sale la letra', text: 'Una letra al azar para todos. Sin repetir en la partida.' },
		{ icon: Hand, color: 'var(--cherry)', title: 'Completa y di STOP', text: 'Al llenar el 75 % de las categorías puedes frenar a los demás.' },
		{ icon: BadgeCheck, color: 'var(--lime)', title: 'La IA decide', text: 'Valida cada respuesta, explica por qué y reparte los puntos.' }
	];
	const features = [
		{ icon: Sparkles, title: 'Árbitro de IA', text: 'Se acabaron las discusiones: cada veredicto viene con su explicación.' },
		{ icon: Flag, title: 'Impugnaciones', text: '¿No estás de acuerdo? Impugna y una segunda IA vuelve a revisar.' },
		{ icon: Lock, title: 'Salas privadas', text: 'Juega solo con tus amigos con un código TUTI o un enlace.' },
		{ icon: Globe, title: 'Salas públicas', text: '¿Sin amigos a mano? Entra a una sala abierta y juega al instante.' },
		{ icon: Smartphone, title: 'Web + iPhone', text: 'Los de la web y los de la app juegan juntos en la misma sala.' },
		{ icon: MessageCircle, title: 'Chat y reacciones', text: 'Celebra las respuestas buenas y ríete de las malas en vivo.' },
		{ icon: Timer, title: 'A tu ritmo', text: 'Elige rondas, tiempo, categorías y segundos tras el STOP.' },
		{ icon: Users, title: 'Hasta 12 jugadores', text: 'Perfecto para la familia, la oficina o la previa con amigos.' }
	];
	const cats = ['Nombre', 'País', 'Ciudad', 'Animal', 'Fruta', 'Color', 'Profesión', 'Marca', 'Comida', 'Deporte', 'Película', 'Cosa'];
</script>

<Seo {title} {description} path="/" {jsonld} />

<SiteChrome>
	<main>
		<section class="hero wrap">
			<div class="copy">
				<span class="eyebrow"><Sparkles size={14} strokeWidth={3} /> Multijugador · gratis · en español</span>
				<h1>El Stop de siempre, <span class="hl">con un árbitro de IA</span></h1>
				<p class="lead">Stop, Basta, Tutifruti o Mercado: como le digas. Sale una letra, todos completan las categorías y la inteligencia artificial valida cada respuesta. Sin trampas ni discusiones.</p>
				<div class="ctas">
					<a class="candy" href="/jugar"><span class="ic"><Play size={20} strokeWidth={3} /></span>Jugar ahora</a>
					<AppStoreBadge />
				</div>
				<p class="small">Juega en el navegador sin descargas ni registro, o descarga la app para iPhone.</p>
			</div>
			<div class="art">
				<img class="tuti" src="/img/mascot/tuti_hello.png" alt="Tuti, la mascota naranja de Tutifruti AI, saludando" width="190" height="190" fetchpriority="high" />
				<RoundDemo />
			</div>
		</section>

		<section class="marquee" aria-label="Algunas categorías">
			<div class="track">
				{#each [...cats, ...cats] as c, i}<span class:alt={i % 3 === 1}>{c}</span>{/each}
			</div>
		</section>

		<section id="como-se-juega" class="wrap block">
			<h2 use:reveal>Cómo se juega</h2>
			<p class="sub" use:reveal={60}>Cuatro pasos y ya estás gritando STOP.</p>
			<ol class="steps">
				{#each steps as s, i}
					{@const Icon = s.icon}
					<li use:reveal={i * 90}>
						<span class="num">{i + 1}</span>
						<span class="sic" style:background={s.color}><Icon size={26} strokeWidth={3} /></span>
						<h3>{s.title}</h3>
						<p>{s.text}</p>
					</li>
				{/each}
			</ol>
		</section>

		<section id="arbitro" class="wrap block split">
			<div use:reveal>
				<h2>Un árbitro que no se cansa (ni se deja convencer)</h2>
				<p>Cuando alguien dice STOP, la IA revisa todas las respuestas de la ronda en un par de segundos. Para cada una comprueba:</p>
				<ul class="checks">
					<li><BadgeCheck size={20} /> Que empiece con la letra de la ronda</li>
					<li><BadgeCheck size={20} /> Que pertenezca a la categoría</li>
					<li><BadgeCheck size={20} /> Que sea una palabra real en español</li>
					<li><BadgeCheck size={20} /> Que esté bien escrita</li>
				</ul>
				<p>Y si crees que se equivocó, tienes <b>2 impugnaciones por partida</b>: una segunda IA revisa tu argumento de forma independiente.</p>
			</div>
			<div class="points" use:reveal={120}>
				<div class="pt" style:--c="var(--lime)"><b>10</b><span>Respuesta única</span><small>Nadie más la puso</small></div>
				<div class="pt" style:--c="var(--sky)"><b>5</b><span>Repetida</span><small>Otro jugador coincidió</small></div>
				<div class="pt" style:--c="var(--cherry)"><b>0</b><span>Inválida o vacía</span><small>No cumple las reglas</small></div>
				<img src="/img/mascot/tuti_judge.png" alt="Tuti como árbitro" width="150" height="150" loading="lazy" />
			</div>
		</section>

		<section class="wrap block">
			<h2 use:reveal>Todo lo que necesitas para una buena partida</h2>
			<div class="feats">
				{#each features as f, i}
					{@const Icon = f.icon}
					<article use:reveal={(i % 4) * 70}>
						<span class="fic"><Icon size={22} strokeWidth={2.6} /></span>
						<h3>{f.title}</h3>
						<p>{f.text}</p>
					</article>
				{/each}
			</div>
		</section>

		<section id="preguntas" class="wrap block narrow">
			<h2 use:reveal>Preguntas frecuentes</h2>
			<div class="faq">
				{#each FAQ as [q, a], i}
					<details use:reveal={i * 40} open={i === 0}>
						<summary>{q}</summary>
						<p>{a}</p>
					</details>
				{/each}
			</div>
		</section>

		<section class="wrap final" use:reveal>
			<img src="/img/mascot/tuti_party.png" alt="" width="170" height="170" loading="lazy" />
			<h2>¿Listos? Sale la primera letra…</h2>
			<p>Invita a tus amigos por WhatsApp y empieza en menos de un minuto.</p>
			<a class="candy" href="/jugar"><span class="ic"><Play size={20} strokeWidth={3} /></span>Jugar gratis</a>
			<div class="also"><span>o en tu iPhone</span><AppStoreBadge /></div>
		</section>
	</main>
</SiteChrome>

<style>
	main { overflow-x: clip; }
	.wrap { max-width: 1120px; margin: 0 auto; padding: 0 20px; }
	.hero { display: grid; grid-template-columns: 1.05fr 1fr; gap: 40px; align-items: center; min-height: calc(100dvh - 70px); padding-top: 20px; padding-bottom: 40px; }
	.eyebrow { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 99px; background: rgba(255,210,63,.14);
		color: var(--lemon); font-weight: 900; font-size: 13px; border: 1px solid rgba(255,210,63,.35); }
	h1 { font-size: clamp(38px, 5.6vw, 66px); line-height: 1.02; margin: 16px 0 14px; font-weight: 900; letter-spacing: -.01em; }
	.hl { color: var(--lemon); }
	.lead { font-size: clamp(17px, 1.6vw, 20px); color: rgba(255,255,255,.82); font-weight: 700; line-height: 1.5; margin: 0 0 24px; max-width: 560px; }
	.ctas { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
	.candy { display: inline-flex; align-items: center; gap: 12px; height: 62px; padding: 0 28px 0 8px; border-radius: 999px; text-decoration: none;
		background: linear-gradient(180deg, #ffb04f, var(--tangerine)); color: var(--ink); font-weight: 900; font-size: 20px; text-transform: uppercase;
		box-shadow: inset 0 0 0 2px rgba(46,28,20,.5), 0 4px 0 #b9640d, 0 14px 30px rgba(255,148,31,.3); transition: transform .15s; }
	.candy:hover { transform: translateY(-2px); } .candy:active { transform: translateY(2px); }
	.candy .ic { display: grid; place-items: center; width: 46px; height: 46px; border-radius: 50%; background: #fff; color: var(--tangerine); }
	.small { color: rgba(255,255,255,.6); font-size: 14px; font-weight: 700; margin-top: 16px; }
	.art { position: relative; display: flex; justify-content: center; padding-top: 70px; }
	.tuti { position: absolute; top: -30px; right: max(0px, calc(50% - 250px)); z-index: 2; animation: sway 2.4s ease-in-out infinite alternate; transform-origin: 50% 100%; }
	@keyframes sway { from { transform: rotate(-4deg); } to { transform: rotate(4deg) translateY(-6px); } }

	.marquee { overflow: hidden; padding: 14px 0; background: rgba(255,255,255,.04); border-block: 1px solid rgba(255,255,255,.07); }
	.track { display: flex; gap: 12px; width: max-content; animation: slide 40s linear infinite; }
	.track span { padding: 8px 16px; border-radius: 99px; background: rgba(255,255,255,.08); font-weight: 900; white-space: nowrap; }
	.track span.alt { background: rgba(255,210,63,.16); color: var(--lemon); }
	@keyframes slide { to { transform: translateX(-50%); } }

	.block { padding-top: 90px; }
	h2 { font-size: clamp(28px, 3.6vw, 42px); line-height: 1.1; margin: 0 0 10px; font-weight: 900; }
	.sub { color: rgba(255,255,255,.7); font-weight: 700; margin: 0 0 28px; font-size: 18px; }
	.steps { list-style: none; padding: 0; margin: 0; display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
	.steps li { position: relative; padding: 22px 18px; border-radius: 24px; background: var(--panel); border: 1.5px solid var(--panel-stroke); }
	.num { position: absolute; top: 14px; right: 16px; font-size: 40px; font-weight: 900; color: rgba(255,255,255,.08); }
	.sic { display: grid; place-items: center; width: 54px; height: 54px; border-radius: 50%; color: var(--ink); box-shadow: inset 0 0 0 2px rgba(46,28,20,.45); }
	h3 { margin: 14px 0 6px; font-size: 19px; font-weight: 900; }
	.steps p, .feats p { margin: 0; color: rgba(255,255,255,.72); font-weight: 700; line-height: 1.45; font-size: 15px; }

	.split { display: grid; grid-template-columns: 1.1fr 1fr; gap: 40px; align-items: center; }
	.split p { color: rgba(255,255,255,.8); font-weight: 700; line-height: 1.55; font-size: 17px; }
	.checks { list-style: none; padding: 0; margin: 14px 0; display: grid; gap: 10px; }
	.checks li { display: flex; gap: 10px; align-items: center; font-weight: 800; font-size: 17px; }
	.checks :global(svg) { color: var(--lime); flex: none; }
	.points { position: relative; display: grid; gap: 12px; padding-right: 110px; }
	.points img { position: absolute; right: -10px; bottom: -20px; }
	.pt { display: grid; grid-template-columns: 70px 1fr; grid-template-rows: auto auto; column-gap: 14px; align-items: center; padding: 14px 18px; border-radius: 22px;
		background: color-mix(in srgb, var(--c) 14%, transparent); border: 1.5px solid color-mix(in srgb, var(--c) 55%, transparent); }
	.pt b { grid-row: span 2; font-size: 44px; font-weight: 900; color: var(--c); text-align: center; }
	.pt span { font-weight: 900; font-size: 18px; } .pt small { color: rgba(255,255,255,.65); font-weight: 700; }

	.feats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-top: 24px; }
	.feats article { padding: 20px; border-radius: 22px; background: var(--panel); border: 1.5px solid var(--panel-stroke); transition: transform .25s, border-color .25s; }
	.feats article:hover { transform: translateY(-4px); border-color: rgba(255,210,63,.5); }
	.fic { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 14px; background: rgba(255,210,63,.15); color: var(--lemon); }
	.feats h3 { font-size: 17px; }

	.narrow { max-width: 820px; }
	.faq { display: grid; gap: 10px; margin-top: 22px; }
	details { border-radius: 20px; background: var(--panel); border: 1.5px solid var(--panel-stroke); padding: 0 20px; }
	summary { cursor: pointer; list-style: none; padding: 18px 0; font-weight: 900; font-size: 17px; display: flex; justify-content: space-between; gap: 12px; }
	summary::-webkit-details-marker { display: none; }
	summary::after { content: '+'; color: var(--lemon); font-size: 24px; line-height: 1; transition: rotate .25s; }
	details[open] summary::after { rotate: 45deg; }
	details p { margin: 0 0 18px; color: rgba(255,255,255,.78); font-weight: 700; line-height: 1.55; }

	.final { text-align: center; padding-top: 100px; display: flex; flex-direction: column; align-items: center; gap: 6px; }
	.final p { color: rgba(255,255,255,.75); font-weight: 700; font-size: 18px; margin: 0 0 18px; }
	.also { display: flex; flex-direction: column; align-items: center; gap: 10px; margin-top: 18px; color: rgba(255,255,255,.6); font-weight: 800; font-size: 14px; }
	.final img { animation: hop .8s ease-in-out infinite alternate; }
	@keyframes hop { to { transform: translateY(-10px) scale(1.03); } }

	:global(.reveal) { opacity: 0; transform: translateY(24px); transition: opacity .6s ease, transform .6s cubic-bezier(.2,.9,.3,1.2); }
	:global(.reveal.shown) { opacity: 1; transform: none; }

	@media (max-width: 960px) {
		.hero, .split { grid-template-columns: 1fr; }
		.hero { min-height: 0; text-align: center; padding-top: 30px; }
		.lead { margin-inline: auto; } .ctas { justify-content: center; }
		.steps, .feats { grid-template-columns: repeat(2, 1fr); }
	}
	@media (max-width: 560px) {
		.steps, .feats { grid-template-columns: 1fr; }
		.points { padding-right: 0; } .points img { display: none; }
		.tuti { width: 140px; height: 140px; top: -10px; }
		.block { padding-top: 64px; }
	}
	@media (prefers-reduced-motion: reduce) { .track, .tuti, .final img { animation: none; } }
</style>
