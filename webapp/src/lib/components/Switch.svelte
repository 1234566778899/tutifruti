<script lang="ts">
	import type { Snippet } from 'svelte';
	import { sfx } from '#lib/sfx.ts';
	/** Interruptor con toda la fila tocable (como GameToggleLabel de iOS). */
	let { checked = $bindable(false), onchange, children }: { checked?: boolean; onchange?: (v: boolean) => void; children: Snippet } = $props();
	function toggle() { checked = !checked; sfx('tap', .5); onchange?.(checked); }
</script>

<button class="sw" role="switch" aria-checked={checked} onclick={toggle}>
	<span class="lab">{@render children()}</span>
	<span class="track" class:on={checked}><span class="knob"></span></span>
</button>

<style>
	.sw { display: flex; align-items: center; gap: 12px; width: 100%; padding: 10px 0; background: none; border: 0; color: #fff; font: inherit; font-weight: 800; text-align: left; cursor: pointer; }
	.lab { flex: 1; display: flex; align-items: center; gap: 10px; }
	.track { position: relative; width: 52px; height: 32px; border-radius: 99px; background: rgba(255,255,255,.18); transition: background .2s; flex: none; }
	.track.on { background: var(--lime); }
	.knob { position: absolute; top: 3px; left: 3px; width: 26px; height: 26px; border-radius: 50%; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,.3);
		transition: transform .25s cubic-bezier(.3,1.5,.5,1); }
	.on .knob { transform: translateX(20px); }
	.sw:focus-visible .track { outline: 3px solid var(--lemon); outline-offset: 2px; }
</style>
