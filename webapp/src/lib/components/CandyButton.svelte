<script lang="ts">
	import type { Snippet, Component } from 'svelte';
	import { sfx } from '#lib/sfx.ts';
	/** Botón "caramelo" (mismo estilo que CandyButtonStyle de iOS): un contorno continuo y relieve sutil. */
	let { color = 'var(--tangerine)', ink = false, icon, height = 58, disabled = false, onclick, children, type = 'button', href }:
		{ color?: string; ink?: boolean; icon?: Component<any>; height?: number; disabled?: boolean; onclick?: (e: MouseEvent) => void;
		  children: Snippet; type?: 'button' | 'submit'; href?: string } = $props();
	const Icon = $derived(icon);
</script>

{#snippet inner()}
	<span class="face" style:height="{height}px">
		{#if Icon}<span class="ico" style:width="{height * 0.62}px" style:height="{height * 0.62}px" style:color={color}><Icon size={height * 0.3} strokeWidth={3} /></span>{/if}
		<span class="label" style:font-size="{height * 0.3}px" class:ink>{@render children()}</span>
		{#if Icon}<span style:width="{height * 0.62}px"></span>{/if}
	</span>
{/snippet}

{#if href}
	<a class="candy" class:disabled {href} style:--c={color} style:height="{height + 3}px" onpointerdown={() => sfx('tap', 0.6)}>{@render inner()}</a>
{:else}
	<button class="candy" {type} {disabled} style:--c={color} style:height="{height + 3}px" onpointerdown={() => !disabled && sfx('tap', 0.6)} {onclick}>{@render inner()}</button>
{/if}

<style>
	.candy { position: relative; display: block; width: 100%; border: 0; padding: 0; background: color-mix(in srgb, var(--c) 78%, black);
		border-radius: 999px; box-shadow: inset 0 0 0 1.5px rgba(46, 28, 20, 0.5); cursor: pointer; text-decoration: none; }
	.face { position: absolute; left: 1.5px; right: 1.5px; top: 1.5px; display: flex; align-items: center; gap: 10px; padding: 0 8px;
		border-radius: 999px; background: linear-gradient(180deg, color-mix(in srgb, var(--c) 90%, white), var(--c));
		transition: transform .15s cubic-bezier(.3,1.6,.5,1); }
	.face::after { content: ''; position: absolute; left: 22px; right: 22px; top: 4px; height: 22%; border-radius: 999px; background: rgba(255, 255, 255, 0.14); }
	.candy:active:not(:disabled) .face { transform: translateY(2px); }
	.ico { display: grid; place-items: center; border-radius: 50%; background: #fff; flex: none; }
	.label { flex: 1; text-align: left; font-weight: 900; text-transform: uppercase; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.label.ink { color: var(--ink); }
	.candy:disabled, .candy.disabled { opacity: 0.5; filter: saturate(0.4); cursor: default; }
	.candy:focus-visible { outline: 3px solid var(--lemon); outline-offset: 3px; }
</style>
