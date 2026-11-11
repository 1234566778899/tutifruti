<script lang="ts">
	import { onMount } from 'svelte';
	/**
	 * Demo animada de una ronda para la landing: sale la letra, se escriben las respuestas
	 * y el árbitro IA las valida una por una. Se repite con otra letra.
	 */
	type Row = { cat: string; value: string; verdict: 'unique' | 'repeat' | 'invalid'; why: string };
	const DECKS: { letter: string; rows: Row[] }[] = [
		{ letter: 'M', rows: [
			{ cat: 'Nombre', value: 'Martina', verdict: 'unique', why: 'Nombre propio válido' },
			{ cat: 'País', value: 'México', verdict: 'repeat', why: 'Otro jugador también puso México' },
			{ cat: 'Animal', value: 'Mapache', verdict: 'unique', why: 'Mamífero, empieza con M' },
			{ cat: 'Fruta', value: 'Mesa', verdict: 'invalid', why: 'Una mesa no es una fruta' }
		] },
		{ letter: 'P', rows: [
			{ cat: 'Nombre', value: 'Pablo', verdict: 'repeat', why: 'Repetida con otro jugador' },
			{ cat: 'País', value: 'Perú', verdict: 'unique', why: 'País de Sudamérica' },
			{ cat: 'Animal', value: 'Pingüino', verdict: 'unique', why: 'Ave marina, empieza con P' },
			{ cat: 'Fruta', value: 'Papaya', verdict: 'unique', why: 'Fruta tropical' }
		] },
		{ letter: 'C', rows: [
			{ cat: 'Nombre', value: 'Camila', verdict: 'unique', why: 'Nombre propio válido' },
			{ cat: 'País', value: 'Colombia', verdict: 'unique', why: 'País de Sudamérica' },
			{ cat: 'Animal', value: 'Kanguro', verdict: 'invalid', why: 'Empieza con K, no con C' },
			{ cat: 'Fruta', value: 'Cereza', verdict: 'repeat', why: 'Repetida con otro jugador' }
		] }
	];
	const ALPHA = 'ABCDEFGHIJLMNOPRSTUV';

	let deck = $state(0);
	let shownLetter = $state('M');
	let spinning = $state(false);
	let typed = $state<string[]>(['Martina', 'México', 'Mapache', 'Mesa']);
	let judged = $state(4);
	let reduce = false;

	const cur = $derived(DECKS[deck]);
	const total = $derived(cur.rows.slice(0, judged).reduce((s, r) => s + pts(r.verdict), 0));
	function pts(v: Row['verdict']) { return v === 'unique' ? 10 : v === 'repeat' ? 5 : 0; }
	const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

	onMount(() => {
		reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
		if (reduce) return;
		let alive = true;
		(async () => {
			await wait(2500);
			while (alive) {
				deck = (deck + 1) % DECKS.length;
				judged = 0; typed = ['', '', '', ''];
				spinning = true;
				for (let i = 0; i < 14 && alive; i++) { shownLetter = ALPHA[Math.floor(Math.random() * ALPHA.length)]; await wait(55 + i * 6); }
				shownLetter = cur.letter; spinning = false;
				await wait(500);
				for (let r = 0; r < cur.rows.length && alive; r++) {
					const word = cur.rows[r].value;
					for (let c = 1; c <= word.length && alive; c++) { typed[r] = word.slice(0, c); await wait(70); }
					await wait(120);
				}
				await wait(500);
				for (let r = 0; r < cur.rows.length && alive; r++) { judged = r + 1; await wait(650); }
				await wait(2600);
			}
		})();
		return () => { alive = false; };
	});
</script>

<div class="demo" aria-label="Ejemplo de una ronda validada por la IA" role="img">
	<div class="top">
		<div class="letter" class:spinning>{shownLetter}</div>
		<div class="grow">
			<span class="kick">Ronda 2 de 5</span>
			<b>Letra {cur.letter}</b>
		</div>
		<div class="score"><span>{total}</span><small>pts</small></div>
	</div>
	<ul>
		{#each cur.rows as r, i (deck + '-' + i)}
			{@const done = judged > i}
			<li class:done class="v-{done ? r.verdict : 'none'}">
				<span class="cat">{r.cat}</span>
				<span class="val">{typed[i]}<i class="caret" class:hide={typed[i] === r.value}></i></span>
				{#if done}
					<span class="badge">{r.verdict === 'unique' ? '+10' : r.verdict === 'repeat' ? '+5' : '0'}</span>
					<span class="why">{r.why}</span>
				{/if}
			</li>
		{/each}
	</ul>
	<div class="judge">
		<img src="/img/mascot/tuti_judge.png" alt="" width="64" height="64" />
		<p>{judged < cur.rows.length ? 'Escribe rápido… el árbitro está mirando.' : 'Listo: cada respuesta tiene su explicación.'}</p>
	</div>
</div>

<style>
	.demo { position: relative; width: min(100%, 400px); padding: 18px; border-radius: 28px; background: rgba(255,255,255,.08);
		border: 1.5px solid rgba(255,255,255,.16); backdrop-filter: blur(10px); box-shadow: 0 30px 60px rgba(0,0,0,.35); rotate: 1.5deg; }
	.top { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
	.letter { display: grid; place-items: center; width: 62px; height: 62px; border-radius: 18px; font-size: 36px; font-weight: 900; color: var(--ink);
		background: linear-gradient(180deg, #ffe27a, var(--lemon)); box-shadow: inset 0 0 0 2px rgba(46,28,20,.55), 0 4px 0 #c99a12; }
	.letter.spinning { animation: jig .12s linear infinite alternate; }
	@keyframes jig { from { transform: translateY(-2px) rotate(-3deg); } to { transform: translateY(2px) rotate(3deg); } }
	.kick { display: block; font-size: 12px; font-weight: 800; color: rgba(255,255,255,.6); text-transform: uppercase; letter-spacing: .06em; }
	.top b { font-size: 20px; }
	.score { text-align: right; color: var(--lemon); font-weight: 900; }
	.score span { font-size: 32px; display: inline-block; min-width: 2ch; } .score small { margin-left: 3px; opacity: .8; }
	ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
	li { position: relative; display: grid; grid-template-columns: 74px 1fr auto; align-items: center; column-gap: 10px; padding: 10px 12px; border-radius: 16px;
		background: rgba(0,0,0,.18); border: 1.5px solid rgba(255,255,255,.08); transition: background .3s, border-color .3s; }
	.cat { font-size: 12px; font-weight: 900; color: rgba(255,255,255,.6); text-transform: uppercase; }
	.val { font-size: 18px; font-weight: 900; min-height: 24px; }
	.caret { display: inline-block; width: 2px; height: 18px; margin-left: 2px; vertical-align: -2px; background: var(--lemon); animation: blink 1s steps(1) infinite; }
	.caret.hide { display: none; }
	@keyframes blink { 50% { opacity: 0; } }
	.badge { padding: 3px 10px; border-radius: 99px; font-weight: 900; color: var(--ink); animation: pop .4s cubic-bezier(.3,1.7,.5,1) both; }
	.why { grid-column: 2 / 4; font-size: 12.5px; font-weight: 700; color: rgba(255,255,255,.7); animation: fade .4s ease both .1s; }
	@keyframes pop { from { transform: scale(.3); opacity: 0; } }
	@keyframes fade { from { opacity: 0; transform: translateY(-3px); } }
	.v-unique { background: rgba(140,217,51,.14); border-color: rgba(140,217,51,.55); } .v-unique .badge { background: var(--lime); }
	.v-repeat { background: rgba(64,184,242,.14); border-color: rgba(64,184,242,.55); } .v-repeat .badge { background: var(--sky); }
	.v-invalid { background: rgba(237,56,92,.14); border-color: rgba(237,56,92,.55); } .v-invalid .badge { background: var(--cherry); color: #fff; }
	.judge { display: flex; align-items: center; gap: 10px; margin-top: 12px; }
	.judge img { flex: none; }
	.judge p { margin: 0; padding: 10px 14px; border-radius: 16px 16px 16px 4px; background: var(--cream); color: var(--ink); font-weight: 800; font-size: 14px; }
	@media (prefers-reduced-motion: reduce) { .demo { rotate: 0deg; } .letter.spinning, .caret { animation: none; } }
</style>
