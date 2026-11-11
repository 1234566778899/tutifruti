<script lang="ts">
	import { goto } from '$app/navigation';
	import { KeyRound } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import Mascot from '#lib/components/Mascot.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';

	/** Llega desde el correo de "recuperar contraseña": Supabase ya abrió la sesión con el enlace. */
	let pass1 = $state(''), pass2 = $state(''), busy = $state(false), error = $state<string | null>(null), done = $state(false);
	async function save(e: SubmitEvent) {
		e.preventDefault();
		if (pass1 !== pass2) { error = 'Las contraseñas no coinciden'; return; }
		busy = true; error = null;
		try { await app.updatePassword(pass1); sfx('valid'); done = true; } catch (err) { error = friendlyError(err); } finally { busy = false; }
	}
</script>

<main class="page stack c">
	<Mascot pose={done ? 'party' : 'think'} size={150} />
	<OutlinedTitle text={done ? '¡Listo!' : 'Nueva contraseña'} size={26} />
	{#if done}
		<p class="muted">Tu contraseña se actualizó. Ya puedes usarla en la web y en el iPhone.</p>
		<CandyButton color="var(--tangerine)" ink height={56} onclick={() => goto('/jugar')}>Ir a jugar</CandyButton>
	{:else}
		<form class="panel stack" onsubmit={save}>
			<input class="field" type="password" placeholder="Nueva contraseña (mínimo 8)" minlength="8" autocomplete="new-password" bind:value={pass1} required />
			<input class="field" type="password" placeholder="Repite la contraseña" minlength="8" autocomplete="new-password" bind:value={pass2} required />
			{#if error}<p class="err">{error}</p>{/if}
			<CandyButton type="submit" color="var(--lemon)" icon={KeyRound} ink height={54} disabled={busy || pass1.length < 8}>{busy ? 'Guardando…' : 'Guardar contraseña'}</CandyButton>
		</form>
	{/if}
</main>

<style>
	.c { min-height: 100dvh; justify-content: center; align-items: center; text-align: center; }
	.c form { width: 100%; }
	.err { color: #ff8aa0; font-weight: 800; margin: 0; }
</style>
