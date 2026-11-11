<script lang="ts">
	let { letter, size = 44 }: { letter: string; size?: number } = $props();
</script>
<span class="lb" style:width="{size}px" style:height="{size}px" style:font-size="{size * 0.55}px" style:border-radius="{size * 0.25}px" aria-label="Letra {letter}">{letter}</span>
<style>
	.lb { display: inline-grid; place-items: center; flex: none; color: #fff; font-weight: 900; background: linear-gradient(135deg, #ff8c1a, #fa4085);
		box-shadow: inset 0 0 0 3px rgba(255,255,255,.35), 0 6px 14px rgba(250,64,133,.35); text-shadow: 0 2px 2px rgba(0,0,0,.18); }
</style>
