<script lang="ts">
	import type { Component } from 'svelte';
	let { text, color = 'var(--lime)', ink = true, icon }: { text: string; color?: string; ink?: boolean; icon?: Component<any> } = $props();
	const Icon = $derived(icon);
</script>
<span class="pill" style:background={color} class:ink>{#if Icon}<Icon size={12} strokeWidth={3.5} />{/if}{text}</span>
<style>
	.pill { display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 900;
		text-transform: uppercase; color: #fff; white-space: nowrap; }
	.pill.ink { color: var(--ink); }
</style>
