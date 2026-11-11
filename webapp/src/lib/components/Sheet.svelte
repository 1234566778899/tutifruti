<script lang="ts">
	import type { Snippet } from 'svelte';
	import { X } from '@lucide/svelte';
	/** Hoja inferior (móvil) / diálogo centrado (escritorio), con cierre por fondo y Escape. */
	let { title, onclose, children, wide = false }: { title?: string; onclose: () => void; children: Snippet; wide?: boolean } = $props();
	function key(e: KeyboardEvent) { if (e.key === 'Escape') onclose(); }
</script>

<svelte:window onkeydown={key} />
<div class="scrim" role="presentation" onclick={onclose}></div>
<div class="sheet" class:wide role="dialog" aria-modal="true" aria-label={title}>
	<header>
		{#if title}<h3>{title}</h3>{/if}
		<button class="x" onclick={onclose} aria-label="Cerrar"><X size={18} strokeWidth={3} /></button>
	</header>
	<div class="body">{@render children()}</div>
</div>

<style>
	.scrim { position: fixed; inset: 0; background: rgba(0,0,0,.55); z-index: 60; animation: fade .2s; }
	.sheet { position: fixed; z-index: 61; left: 50%; bottom: 0; translate: -50% 0; width: min(100%, 560px); max-height: 88dvh; display: flex; flex-direction: column;
		background: var(--deep); border-radius: 26px 26px 0 0; border: 1.5px solid var(--panel-stroke); animation: up .35s cubic-bezier(.3,1.3,.5,1); }
	.sheet.wide { width: min(100%, 720px); }
	header { display: flex; align-items: center; gap: 10px; padding: 16px 16px 6px; }
	h3 { margin: 0; flex: 1; font-size: 19px; font-weight: 900; color: var(--lemon); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.x { margin-left: auto; display: grid; place-items: center; width: 36px; height: 36px; border-radius: 50%; border: 0; background: rgba(255,255,255,.1); color: #fff; cursor: pointer; }
	.body { overflow-y: auto; padding: 8px 16px calc(18px + env(safe-area-inset-bottom)); display: flex; flex-direction: column; gap: 12px; }
	@keyframes up { from { transform: translateY(100%); } }
	@keyframes fade { from { opacity: 0; } }
	@media (min-width: 900px) {
		.sheet { bottom: auto; top: 50%; translate: -50% -50%; border-radius: 26px; animation: zoom .3s cubic-bezier(.3,1.4,.5,1); }
		@keyframes zoom { from { transform: scale(.9); opacity: 0; } }
	}
</style>
