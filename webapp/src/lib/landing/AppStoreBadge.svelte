<script lang="ts" module>
	/** Ficha de la app en el App Store (ID de Apple 6833576367). */
	export const APP_STORE_URL = 'https://apps.apple.com/us/app/tutifruti-ai/id6833576367?l=es-MX';
</script>

<script lang="ts">
	/** Insignia "Descárgalo en el App Store" (negra, al estilo de la oficial de Apple). */
	let { size = 'md' }: { size?: 'sm' | 'md' } = $props();
</script>

<a class="badge {size}" href={APP_STORE_URL} target="_blank" rel="noopener" aria-label="Descargar Tutifruti AI en el App Store">
	<svg viewBox="0 0 384 512" aria-hidden="true"><path fill="currentColor" d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/></svg>
	<span class="txt"><small>Descárgalo en el</small><b>App Store</b></span>
</a>

<style>
	.badge { display: inline-flex; align-items: center; gap: 10px; height: 54px; padding: 0 20px 0 16px; border-radius: 14px; background: #000; color: #fff;
		text-decoration: none; border: 1.5px solid rgba(255,255,255,.55); transition: transform .15s, border-color .15s; }
	.badge:hover { transform: translateY(-2px); border-color: var(--lemon); }
	.badge:active { transform: translateY(1px); }
	svg { width: 24px; height: 28px; flex: none; }
	.txt { display: flex; flex-direction: column; line-height: 1.05; text-align: left; }
	small { font-size: 11px; font-weight: 700; letter-spacing: .01em; }
	b { font-size: 21px; font-weight: 800; letter-spacing: -.01em; }
	.sm { height: 44px; padding: 0 14px 0 12px; border-radius: 11px; gap: 8px; }
	.sm svg { width: 19px; height: 22px; }
	.sm small { font-size: 9px; } .sm b { font-size: 17px; }
</style>
