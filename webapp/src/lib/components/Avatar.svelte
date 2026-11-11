<script lang="ts">
	/** Avatar: ilustración por clave (fox, owl…), foto (URL) o inicial. Mismas claves que iOS. */
	const KEYS = ['fox','owl','panda','frog','octopus','lion','koala','tiger','monkey','penguin','unicorn','turtle','fire_fox','robot','llama','wise_owl','stop_cat','dragon'];
	let { avatar = '', name = '', size = 40 }: { avatar?: string; name?: string; size?: number } = $props();
	const isKey = $derived(KEYS.includes(avatar));
	const isUrl = $derived(avatar.startsWith('http'));
</script>
<span class="av" style:width="{size}px" style:height="{size}px" aria-hidden="true">
	{#if isKey}<img src="/img/avatars/{avatar}.png" alt="" />
	{:else if isUrl}<img class="photo" src={avatar} alt="" />
	{:else if avatar}<img src="/img/avatars/fox.png" alt="" />
	{:else}<span class="init" style:font-size="{size * 0.45}px">{name.slice(0, 1).toUpperCase()}</span>{/if}
</span>
<style>
	.av { display: inline-grid; place-items: center; border-radius: 50%; background: rgba(255,255,255,.12); flex: none; overflow: hidden; }
	img { width: 100%; height: 100%; object-fit: contain; }
	.photo { object-fit: cover; }
	.init { font-weight: 900; }
</style>
