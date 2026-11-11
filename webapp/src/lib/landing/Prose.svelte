<script lang="ts">
	import type { Snippet } from 'svelte';
	import SiteChrome from './SiteChrome.svelte';
	/** Plantilla de páginas de texto (reglas y legales). */
	let { title, updated, children }: { title: string; updated?: string; children: Snippet } = $props();
</script>

<SiteChrome>
	<main class="prose">
		<h1>{title}</h1>
		{#if updated}<p class="upd">Última actualización: {updated}</p>{/if}
		{@render children()}
	</main>
</SiteChrome>

<style>
	.prose { max-width: 780px; margin: 0 auto; padding: 30px 20px 20px; line-height: 1.65; font-weight: 600; color: rgba(255,255,255,.86); }
	.prose :global(h1) { font-size: clamp(32px, 4.4vw, 46px); line-height: 1.1; color: #fff; margin: 10px 0 6px; font-weight: 900; }
	.prose :global(h2) { font-size: 24px; color: var(--lemon); margin: 34px 0 8px; font-weight: 900; }
	.prose :global(h3) { font-size: 19px; color: #fff; margin: 22px 0 6px; font-weight: 900; }
	.prose :global(a) { color: var(--lemon); }
	.prose :global(li) { margin: 4px 0; }
	.prose :global(b), .prose :global(strong) { color: #fff; }
	.prose :global(table) { width: 100%; border-collapse: collapse; margin: 10px 0; }
	.prose :global(td), .prose :global(th) { padding: 10px 12px; border-bottom: 1px solid rgba(255,255,255,.12); text-align: left; }
	.upd { color: rgba(255,255,255,.55); font-size: 14px; margin: 0 0 20px; }
</style>
