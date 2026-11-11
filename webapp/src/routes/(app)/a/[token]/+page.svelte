<script lang="ts">
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	// El layout guarda el enlace y lo procesa cuando hay sesión (entra a la sala o crea la amistad).
</script>
<div class="c"><Mascot pose="hello" size={160} /><OutlinedTitle text="Un momento…" size={24} /></div>
<style>.c { min-height: 100dvh; display: grid; place-content: center; justify-items: center; gap: 14px; }</style>
