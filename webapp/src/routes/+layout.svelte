<script lang="ts">
	import '../app.css';
	import GameBackground from '#lib/components/GameBackground.svelte';
	let { children } = $props();
</script>

<GameBackground />
{@render children()}
