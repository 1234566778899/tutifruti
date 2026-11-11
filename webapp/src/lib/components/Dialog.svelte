<script lang="ts">
	import { fade, scale } from 'svelte/transition';
	import { backOut } from 'svelte/easing';
	import { X, Check } from '@lucide/svelte';
	import CandyButton from './CandyButton.svelte';
	import Mascot from './Mascot.svelte';
	import OutlinedTitle from './OutlinedTitle.svelte';
	/** Diálogo ilustrado con Tuti (como GameDialog de iOS). */
	let { title, message, pose = 'bye', confirm = 'Sí', cancel = 'No', destructive = true, onconfirm, oncancel }:
		{ title: string; message: string; pose?: any; confirm?: string; cancel?: string; destructive?: boolean; onconfirm: () => void; oncancel: () => void } = $props();
</script>
<div class="scrim" transition:fade={{ duration: 180 }} onclick={oncancel} role="presentation"></div>
<div class="dlg" role="dialog" aria-modal="true" aria-label={title} transition:scale={{ start: 0.7, duration: 320, easing: backOut }}>
	<OutlinedTitle text={title} size={28} fill="#fff" />
	<Mascot {pose} size={150} />
	<p>{message}</p>
	<div class="btns">
		<CandyButton color="var(--sky)" icon={X} height={50} ink onclick={oncancel}>{cancel}</CandyButton>
		<CandyButton color={destructive ? 'var(--cherry)' : 'var(--lime)'} icon={Check} height={50} ink={!destructive} onclick={onconfirm}>{confirm}</CandyButton>
	</div>
</div>
<style>
	.scrim { position: fixed; inset: 0; background: rgba(0,0,0,.55); z-index: 60; }
	.dlg { position: fixed; z-index: 61; left: 50%; top: 50%; translate: -50% -50%; width: min(92vw, 420px); background: var(--cream); color: var(--ink);
		border-radius: 26px; box-shadow: inset 0 0 0 2.5px rgba(46,28,20,.85), 0 5px 0 #eed2a3; padding: 22px; display: flex; flex-direction: column; align-items: center; gap: 12px; }
	p { margin: 0; text-align: center; font-size: 19px; font-weight: 800; }
	.btns { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; width: 100%; }
</style>
