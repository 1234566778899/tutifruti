<script lang="ts">
	let { height = 80 }: { height?: number } = $props();
</script>
<div class="logo" style:height="{height}px" aria-label="Tutifruti AI">
	<img class="word" src="/img/ui/logo_wordmark.png" alt="" style:height="{height}px" />
	<img class="badge" src="/img/ui/logo_badge.png" alt="" style:height="{height * 0.36}px" />
</div>
<style>
	.logo { position: relative; display: inline-block; animation: pop .6s cubic-bezier(.3,1.6,.5,1) both; }
	.word { display: block; }
	.badge { position: absolute; right: -4%; bottom: -18%; rotate: -8deg; }
	@keyframes pop { from { transform: scale(.85) rotate(-4deg); } to { transform: none; } }
</style>
