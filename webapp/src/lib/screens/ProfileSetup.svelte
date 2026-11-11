<script lang="ts">
	import { Play } from '@lucide/svelte';
	import { app } from '#lib/app.svelte.ts';
	import * as API from '#lib/api.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { FREE_AVATARS, AVATAR_NAMES } from '#lib/avatars.ts';
	import Avatar from '#lib/components/Avatar.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';

	/** Igual que iOS: el invitado solo pone un apodo (nombre único automático "apodo####"). */
	let avatar = $state('fox'), name = $state(''), available = $state<boolean | null>(null), loading = $state(false), error = $state<string | null>(null);
	const normalized = $derived(name.toLowerCase().trim());
	const formatOK = $derived(/^[a-z0-9._]{3,20}$/.test(normalized));
	const guestBase = $derived(name.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 14));
	let timer: ReturnType<typeof setTimeout>;
	$effect(() => {
		const n = normalized; available = null;
		if (app.isGuest || !/^[a-z0-9._]{3,20}$/.test(n)) return;
		clearTimeout(timer);
		timer = setTimeout(async () => (available = await API.usernameAvailable(n)), 400);
	});
	const canCreate = $derived(app.isGuest ? guestBase.length >= 2 : formatOK && available === true);

	async function create() {
		loading = true; error = null;
		try {
			if (app.isGuest) {
				let last: unknown = null;
				for (let i = 0; i < 5; i++) {
					try { await API.createProfile(guestBase + (10 + Math.floor(Math.random() * 9990)), avatar); last = null; break; } catch (e) { last = e; }
				}
				if (last) throw last;
			} else await API.createProfile(normalized, avatar);
			await app.loadProfile();
		} catch (e) { error = friendlyError(e); } finally { loading = false; }
	}
</script>

<main class="page stack">
	<OutlinedTitle text={app.isGuest ? '¿Cómo te llamas?' : 'Tu perfil'} size={28} />
	<div class="me"><Avatar {avatar} size={110} /></div>
	<div class="panel grid">
		{#each FREE_AVATARS as a, i}
			<button class="pick" class:on={a === avatar} style:animation-delay="{i * 40}ms" onclick={() => (avatar = a)} aria-label={AVATAR_NAMES[a]} aria-pressed={a === avatar}>
				<Avatar avatar={a} size={60} />
			</button>
		{/each}
	</div>
	<input class="field" placeholder={app.isGuest ? 'Tu apodo' : 'Nombre de usuario'} bind:value={name} autocapitalize="off" autocomplete="off" />
	<p class="muted small">
		{#if app.isGuest}{guestBase.length >= 2 ? `Te verán como ${guestBase} + un número.` : 'Escribe al menos 2 letras.'}
		{:else if name && !formatOK}3 a 20 caracteres: letras, números, punto o guion bajo.
		{:else if available === true}{normalized} está disponible{:else if available === false}{normalized} ya está en uso{/if}
	</p>
	<CandyButton color="var(--lime)" icon={Play} ink disabled={!canCreate || loading} onclick={create}>{loading ? 'Creando…' : 'Empezar a jugar'}</CandyButton>
	<button class="link" onclick={() => (app.isGuest ? app.leaveGuestMode() : app.signOut())}>{app.isGuest ? 'Cancelar' : 'Cerrar sesión'}</button>
	{#if error}<p class="err">{error}</p>{/if}
</main>

<style>
	.me { display: grid; place-items: center; }
	.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(68px, 1fr)); gap: 10px; justify-items: center; }
	.pick { border: 3px solid transparent; border-radius: 50%; padding: 2px; background: none; cursor: pointer; transition: transform .25s cubic-bezier(.3,1.6,.5,1);
		animation: pop .45s cubic-bezier(.3,1.6,.5,1) both; }
	.pick.on { border-color: var(--lemon); transform: scale(1.1); }
	@keyframes pop { from { opacity: 0; transform: scale(.7) translateY(12px); } }
	.link { background: none; border: 0; color: var(--cherry); font-weight: 900; cursor: pointer; }
	.err { color: #ff8aa0; font-weight: 800; text-align: center; }
	p.small { margin: -8px 4px 0; }
</style>
