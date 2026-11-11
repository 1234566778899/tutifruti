<script lang="ts">
	let { text, size = 28, fill = 'var(--lemon)' }: { text: string; size?: number; fill?: string } = $props();
</script>
<h2 class="ot" style:font-size="{size}px" style:color={fill} style:--sw="{Math.max(3, size * 0.16)}px">{text}</h2>
<style>
	.ot { margin: 0; font-weight: 900; text-transform: uppercase; letter-spacing: 0.01em; line-height: 1.05; text-align: center;
		-webkit-text-stroke: var(--sw) var(--ink); paint-order: stroke fill; text-shadow: 0 3px 0 var(--ink); }
</style>
