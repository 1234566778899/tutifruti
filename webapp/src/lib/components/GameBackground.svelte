<!-- Fondo de juego: degradado verde azulado → azul noche, patrón de frutas/letras que se desliza y viñeta. -->
<div class="bg" aria-hidden="true">
	<div class="pattern"></div>
	<div class="glow"></div>
	<div class="vignette"></div>
</div>

<style>
	.bg { position: fixed; inset: 0; z-index: -1; background: linear-gradient(180deg, var(--header) 0%, var(--deep) 45%, var(--night) 100%); }
	.pattern { position: absolute; inset: -320px; background: url('/img/ui/game_pattern.png') repeat; background-size: 320px; opacity: 0.045;
		animation: drift 60s linear infinite; }
	.glow { position: absolute; inset: 0; background: radial-gradient(380px 300px at 50% 6%, rgba(255, 148, 31, 0.16), transparent 70%); }
	.vignette { position: absolute; inset: 0; background: radial-gradient(circle at center, transparent 45%, rgba(0, 0, 0, 0.35) 100%); }
	@keyframes drift { from { transform: translate(0, 0); } to { transform: translate(160px, 320px); } }
</style>
