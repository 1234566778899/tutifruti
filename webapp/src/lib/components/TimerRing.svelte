<script lang="ts">
	let { seconds, total, size = 54 }: { seconds: number; total: number; size?: number } = $props();
	const r = $derived(size / 2 - 4);
	const c = $derived(2 * Math.PI * r);
	const urgent = $derived(seconds <= 10);
</script>
<span class="tr" class:urgent class:beat={urgent && seconds % 2 === 0} style:width="{size}px" style:height="{size}px" aria-label="{seconds} segundos">
	<svg width={size} height={size}>
		<circle cx={size / 2} cy={size / 2} {r} stroke="rgba(255,255,255,.12)" stroke-width="6" fill="none" />
		<circle cx={size / 2} cy={size / 2} {r} stroke={urgent ? 'var(--cherry)' : 'var(--lemon)'} stroke-width="6" fill="none" stroke-linecap="round"
			stroke-dasharray={c} stroke-dashoffset={c * (1 - Math.min(1, seconds / Math.max(1, total)))} transform="rotate(-90 {size / 2} {size / 2})" />
	</svg>
	<b>{seconds}</b>
</span>
<style>
	.tr { position: relative; display: inline-grid; place-items: center; flex: none; transition: transform .3s cubic-bezier(.3,1.6,.5,1); }
	.tr circle { transition: stroke-dashoffset 1s linear, stroke .3s; }
	.tr svg { position: absolute; inset: 0; }
	b { font-size: 17px; font-weight: 900; font-variant-numeric: tabular-nums; }
	.urgent b { color: var(--cherry); }
	.beat { transform: scale(1.08); }
</style>
