<script lang="ts">
	/** Metadatos por página: título, descripción, canónica, Open Graph, Twitter y JSON-LD opcional. */
	let { title, description, path = '/', jsonld = [] as object[] }:
		{ title: string; description: string; path?: string; jsonld?: object[] } = $props();
	const SITE = 'https://tutifruti.site';
	const url = $derived(SITE + (path === '/' ? '/' : path));
	const ld = $derived(jsonld.map((j) => `<script type="application/ld+json">${JSON.stringify(j).replace(/</g, '\\u003c')}</` + 'script>'));
</script>

<svelte:head>
	<title>{title}</title>
	<meta name="description" content={description} />
	<link rel="canonical" href={url} />
	<meta name="robots" content="index, follow, max-image-preview:large" />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="Tutifruti AI" />
	<meta property="og:locale" content="es_LA" />
	<meta property="og:title" content={title} />
	<meta property="og:description" content={description} />
	<meta property="og:url" content={url} />
	<meta property="og:image" content="{SITE}/og.png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content="Tutifruti AI: el Stop de siempre con un árbitro de IA" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content={title} />
	<meta name="twitter:description" content={description} />
	<meta name="twitter:image" content="{SITE}/og.png" />
	{#each ld as tag}{@html tag}{/each}
</svelte:head>
