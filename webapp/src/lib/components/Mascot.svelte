<script lang="ts">
	/** Tuti con una animación sutil según la pose (mismo comportamiento que MascotView de iOS). */
	type Pose = 'hello' | 'judge' | 'party' | 'sad' | 'stop' | 'sleep' | 'bye' | 'think';
	let { pose = 'hello', size = 160 }: { pose?: Pose; size?: number } = $props();
</script>
<img class="m {pose}" src="/img/mascot/tuti_{pose}.png" alt="" width={size} height={size} draggable="false" />
<style>
	.m { display: block; object-fit: contain; transform-origin: 50% 100%; user-select: none; }
	.hello { animation: sway 2.2s ease-in-out infinite alternate; }
	.judge { animation: judge 2.2s ease-in-out infinite alternate; }
	.party { animation: hop .7s ease-in-out infinite alternate; }
	.stop { animation: shake .24s ease-in-out infinite alternate; }
	.sad { animation: wobble 2.4s ease-in-out infinite alternate; }
	.sleep { animation: breathe 3.6s ease-in-out infinite alternate; }
	.bye, .think { animation: sway 2.4s ease-in-out infinite alternate; }
	@keyframes sway { from { transform: rotate(-3deg) translateY(0); } to { transform: rotate(3deg) translateY(-4px); } }
	@keyframes judge { from { transform: rotate(4deg); } to { transform: rotate(-4deg) translateY(-4px); } }
	@keyframes hop { from { transform: scale(.97) translateY(0); } to { transform: scale(1.04) translateY(-8%); } }
	@keyframes shake { from { transform: rotate(-2.5deg); } to { transform: rotate(2.5deg); } }
	@keyframes wobble { from { transform: rotate(-1.5deg); } to { transform: rotate(1.5deg); } }
	@keyframes breathe { from { transform: scale(.98); } to { transform: scale(1.03); } }
</style>
