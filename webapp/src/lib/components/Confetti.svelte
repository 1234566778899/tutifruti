<script lang="ts">
	/** Lluvia de confeti en canvas. Cambia `trigger` para lanzar una ráfaga. */
	let { trigger = 0, count = 110 }: { trigger?: number; count?: number } = $props();
	let canvas: HTMLCanvasElement;
	const colors = ['#ff941f', '#fa4085', '#ffd23f', '#8cd933', '#40b8f2', '#9e61f2'];
	$effect(() => {
		if (!trigger || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
		const ctx = canvas.getContext('2d')!;
		const dpr = devicePixelRatio || 1;
		const resize = () => { canvas.width = innerWidth * dpr; canvas.height = innerHeight * dpr; };
		resize();
		const pieces = Array.from({ length: count }, () => ({
			x: Math.random() * innerWidth, vx: (Math.random() - 0.5) * 2.4, vy: 0.5 + Math.random() * 2.5,
			spin: 2 + Math.random() * 7, size: 7 + Math.random() * 6, color: colors[Math.floor(Math.random() * colors.length)],
			delay: Math.random() * 0.6, round: Math.random() < 0.33
		}));
		const start = performance.now();
		let raf = 0;
		const frame = (t: number) => {
			const s = (t - start) / 1000;
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
			ctx.clearRect(0, 0, innerWidth, innerHeight);
			for (const p of pieces) {
				const tt = s - p.delay; if (tt <= 0 || tt > 4) continue;
				const x = p.x + p.vx * tt * 60, y = -20 + p.vy * tt * 60 + 0.5 * 420 * tt * tt * 0.35;
				ctx.save(); ctx.translate(x, y); ctx.rotate(p.spin * tt); ctx.scale(Math.cos(tt * p.spin * 0.7), 1);
				ctx.globalAlpha = Math.max(0, Math.min(1, 4 - tt)); ctx.fillStyle = p.color;
				if (p.round) { ctx.beginPath(); ctx.arc(0, 0, p.size / 2, 0, 7); ctx.fill(); } else ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
				ctx.restore();
			}
			if (s < 4.8) raf = requestAnimationFrame(frame); else ctx.clearRect(0, 0, innerWidth, innerHeight);
		};
		raf = requestAnimationFrame(frame);
		return () => cancelAnimationFrame(raf);
	});
</script>
<canvas bind:this={canvas} aria-hidden="true"></canvas>
<style>canvas { position: fixed; inset: 0; width: 100vw; height: 100vh; pointer-events: none; z-index: 50; }</style>
