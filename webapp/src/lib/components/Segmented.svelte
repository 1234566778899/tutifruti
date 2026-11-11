<script lang="ts" generics="T">
	import { sfx, haptic } from '#lib/sfx.ts';
	let { value = $bindable(), options }: { value: T; options: [T, string][] } = $props();
</script>
<div class="seg" role="tablist">
	{#each options as [v, label] (label)}
		<button role="tab" aria-selected={v === value} class:on={v === value}
			onclick={() => { if (v !== value) { value = v; sfx('tap', 0.5); haptic(); } }}>{label}</button>
	{/each}
</div>
<style>
	.seg { display: flex; gap: 4px; padding: 4px; border-radius: 999px; background: rgba(8, 44, 56, .7); border: 1.5px solid rgba(255,255,255,.18); }
	button { flex: 1; height: 40px; border: 0; border-radius: 999px; background: transparent; color: rgba(255,255,255,.75); font-weight: 900;
		font-size: 13px; text-transform: uppercase; cursor: pointer; transition: background .25s, color .25s, transform .15s; }
	button:active { transform: scale(.96); }
	button.on { background: var(--lemon); color: var(--ink); box-shadow: inset 0 0 0 1.5px rgba(46,28,20,.6); }
</style>
