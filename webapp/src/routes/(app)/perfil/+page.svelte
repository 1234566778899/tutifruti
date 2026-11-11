<script lang="ts">
	import { goto } from '$app/navigation';
	import { ChevronLeft, Pencil, Volume2, Vibrate, Bell, Mail, KeyRound, LogOut, Trash2, CloudUpload, BookOpen, Shield, FileText, Trophy, Lock, Check, Globe, Palette, Gavel } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx, soundEnabled, setSoundEnabled, hapticsEnabled, setHapticsEnabled } from '#lib/sfx.ts';
	import { FREE_AVATARS, AVATAR_NAMES } from '#lib/avatars.ts';
	import { ACHIEVEMENT_ICONS, ACHIEVEMENT_COLORS } from '#lib/achievements.ts';
	import { THEMES, THEME_LEVEL, themeUnlocked, usableTheme, type ThemeKey } from '#lib/themes.ts';
	import { xpForNext, LANGUAGES, type Achievement, type HistoryRow, type UserAchievement } from '#lib/types.ts';
	import Avatar from '#lib/components/Avatar.svelte';
	import OutlinedTitle from '#lib/components/OutlinedTitle.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Dialog from '#lib/components/Dialog.svelte';
	import Sheet from '#lib/components/Sheet.svelte';
	import Switch from '#lib/components/Switch.svelte';
	import Segmented from '#lib/components/Segmented.svelte';

	const p = $derived(app.profile!);
	const progress = $derived(Math.min(1, p.xp / xpForNext(p.level)));
	let achievements = $state<Achievement[]>([]), unlocked = $state<UserAchievement[]>([]), history = $state<HistoryRow[]>([]);
	let filter = $state<'all' | 'public' | 'private'>('all');
	let sound = $state(soundEnabled()), haptics = $state(hapticsEnabled());
	let sheet = $state<null | 'avatar' | 'username' | 'password' | 'save'>(null);
	let confirm = $state<null | 'signout' | 'delete' | 'leave'>(null);
	let busy = $state(false), error = $state<string | null>(null), info = $state<string | null>(null);
	let newName = $state(''), pass1 = $state(''), pass2 = $state(''), saveEmail = $state('');

	const prefs = $derived({ invites: true, friend_requests: true, friends_online: true, results: true, achievements: true, ...(p.notif_prefs ?? {}) });
	const theme = $derived(usableTheme(p));
	const themeKeys = Object.keys(THEMES) as ThemeKey[];
	const unlockedIds = $derived(new Set(unlocked.map((u) => u.achievement_id)));
	const winRate = $derived(p.games_played ? Math.round((p.games_won / p.games_played) * 100) : 0);

	$effect(() => {
		API.achievements().then((a) => (achievements = a.filter((x) => x.id !== 'season_top100'))).catch(() => {});
		API.userAchievements(p.id).then((u) => (unlocked = u)).catch(() => {});
		void app.refreshProfile();
	});
	$effect(() => { if (!app.isGuest) API.history(filter).then((h) => (history = h)).catch(() => {}); });

	function open(s: typeof sheet) { sheet = s; error = null; info = null; busy = false; newName = p.username; pass1 = ''; pass2 = ''; }
	async function run(fn: () => Promise<void>) {
		busy = true; error = null;
		try { await fn(); } catch (e) { error = friendlyError(e); } finally { busy = false; }
	}
	const pickAvatar = (a: string) => run(async () => { await API.updateAvatar(a); app.profile = { ...p, avatar: a }; sfx('coin', .5); sheet = null; });
	const saveName = () => run(async () => { app.profile = await API.changeUsername(newName.trim().toLowerCase()); sfx('valid', .6); sheet = null; });
	const savePassword = () => run(async () => {
		if (pass1 !== pass2) throw new Error('Las contraseñas no coinciden');
		if (app.needsPassword) await app.createPassword(pass1); else await app.updatePassword(pass1);
		app.showToast('Contraseña guardada', false); sheet = null;
	});
	const saveGuest = () => run(async () => { await app.saveGuestWithEmail(saveEmail); info = `Te enviamos un enlace a ${saveEmail.trim()}. Ábrelo para confirmar tu cuenta; luego crearás tu contraseña.`; });
	async function setPref(key: string, on: boolean) {
		const next = { ...prefs, [key]: on };
		app.profile = { ...p, notif_prefs: next };
		try { await API.updateProfile({ notif_prefs: next }); } catch (e) { app.showToast(friendlyError(e)); }
	}
	async function setTheme(key: ThemeKey) {
		if (!themeUnlocked(key, p) || key === theme) return;
		app.profile = { ...p, theme: key }; sfx('tap', .5);
		try { await API.updateProfile({ theme: key }); } catch (e) { app.showToast(friendlyError(e)); }
	}
	async function setLanguage(language: string) {
		app.profile = { ...p, language };
		try { await API.updateProfile({ language }); app.showToast('Idioma de juego guardado', false); } catch (e) { app.showToast(friendlyError(e)); }
	}
	function date(iso: string | null) { return iso ? new Date(iso).toLocaleDateString('es', { day: 'numeric', month: 'short' }) : ''; }
</script>

<main class="page wide-ish stack">
	<header class="bar"><a class="iconbtn" href="/jugar" aria-label="Volver"><ChevronLeft /></a><OutlinedTitle text={app.isGuest ? 'Invitado' : 'Perfil'} size={22} /><span></span></header>

	<section class="panel hero">
		<button class="avbtn" onclick={() => open('avatar')} aria-label="Cambiar avatar"><Avatar avatar={p.avatar} name={p.username} size={86} /><span class="edit"><Pencil size={13} strokeWidth={3} /></span></button>
		<div class="grow">
			<div class="row"><b class="name">{p.username}</b>{#if !app.isGuest}<button class="mini" onclick={() => open('username')} aria-label="Cambiar nombre de usuario"><Pencil size={14} /></button>{/if}</div>
			<div class="row lvrow"><b class="lv">Nivel {p.level}</b><span class="muted small">{p.xp} / {xpForNext(p.level)} XP</span></div>
			<div class="xp"><span style:width="{Math.max(4, progress * 100)}%"></span></div>
		</div>
	</section>

	{#if app.isGuest}
		<section class="panel save">
			<CloudUpload size={30} color="var(--lemon)" />
			<div class="grow"><b>Guarda tu progreso</b><p class="muted small">Vincula un correo para conservar tu nivel, jugar en otros dispositivos y agregar amigos.</p></div>
			<CandyButton color="var(--lemon)" ink height={46} onclick={() => open('save')}>Guardar</CandyButton>
		</section>
	{:else if app.needsPassword}
		<section class="panel save">
			<KeyRound size={30} color="var(--lemon)" />
			<div class="grow"><b>Crea tu contraseña</b><p class="muted small">Tu correo está confirmado. Crea una contraseña para iniciar sesión en otros dispositivos.</p></div>
			<CandyButton color="var(--lemon)" ink height={46} onclick={() => open('password')}>Crear</CandyButton>
		</section>
	{/if}

	<div class="cols">
		<div class="stack">
			<h3 class="section-title">Estadísticas</h3>
			<section class="stats">
				<div class="panel st"><b>{p.games_played}</b><span>Partidas</span></div>
				<div class="panel st"><b>{p.games_won}</b><span>Victorias</span></div>
				<div class="panel st"><b>{winRate}%</b><span>Ganadas</span></div>
				<div class="panel st"><b>{p.best_score}</b><span>Mejor puntaje</span></div>
				<div class="panel st"><b>{p.total_points}</b><span>Puntos totales</span></div>
				<div class="panel st"><b>{p.win_streak}</b><span>Racha</span></div>
			</section>

			<h3 class="section-title">Logros · {unlockedIds.size}/{achievements.length}</h3>
			<section class="achs">
				{#each achievements as a, i (a.id)}
					{@const Icon = ACHIEVEMENT_ICONS[a.icon] ?? Trophy}
					{@const on = unlockedIds.has(a.id)}
					<div class="panel ach" class:on title={a.description} style:--c={ACHIEVEMENT_COLORS[i % ACHIEVEMENT_COLORS.length]}>
						<span class="aic">{#if on}<Icon size={22} strokeWidth={2.6} />{:else}<Lock size={18} />{/if}</span>
						<b>{a.title}</b><span class="desc">{a.description}</span>
					</div>
				{/each}
			</section>
		</div>

		<div class="stack">
			{#if !app.isGuest}
				<h3 class="section-title">Historial</h3>
				<Segmented bind:value={filter} options={[['all', 'Todas'], ['public', 'Públicas'], ['private', 'Privadas']]} />
				<section class="panel stack hist">
					{#if history.length === 0}<p class="muted small">Aún no hay partidas terminadas.</p>{/if}
					{#each history.slice(0, 30) as h (h.room_id)}
						<div class="row">
							<span class="rank" class:first={h.final_rank === 1}>{h.final_rank ? `${h.final_rank}º` : '—'}</span>
							<div class="grow"><b>{h.name}</b><div class="muted small">{date(h.finished_at)} · {h.players} jugadores · {h.rounds} rondas</div></div>
							<div class="right"><b class="pts">{h.score} pts</b>{#if h.xp_gained}<div class="muted tiny">+{h.xp_gained} XP</div>{/if}</div>
						</div>
					{/each}
				</section>
			{/if}

			<h3 class="section-title">Ajustes</h3>
			<section class="panel">
				<Switch bind:checked={sound} onchange={(v) => setSoundEnabled(v)}><Volume2 size={18} color="var(--lemon)" /> Sonidos</Switch>
				<Switch bind:checked={haptics} onchange={(v) => setHapticsEnabled(v)}><Vibrate size={18} color="var(--lemon)" /> Vibración</Switch>
			</section>
			<section class="panel">
				<span class="tiny muted">Avisos dentro del juego</span>
				<Switch checked={prefs.invites} onchange={(v) => setPref('invites', v)}><Bell size={18} color="var(--lemon)" /> Invitaciones a salas</Switch>
				{#if !app.isGuest}<Switch checked={prefs.friend_requests} onchange={(v) => setPref('friend_requests', v)}><Bell size={18} color="var(--lemon)" /> Solicitudes de amistad</Switch>
				<Switch checked={prefs.friends_online} onchange={(v) => setPref('friends_online', v)}><Bell size={18} color="var(--lemon)" /> Amigos que se conectan</Switch>{/if}
				<Switch checked={prefs.results} onchange={(v) => setPref('results', v)}><Bell size={18} color="var(--lemon)" /> Resultados de partidas</Switch>
				<Switch checked={prefs.achievements} onchange={(v) => setPref('achievements', v)}><Bell size={18} color="var(--lemon)" /> Logros</Switch>
			</section>

			{#if !app.isGuest}
				<section class="panel stack prefs">
					<label class="langrow"><Globe size={18} color="var(--lemon)" /><span class="grow">Idioma de juego</span>
						<select value={p.language ?? 'es'} onchange={(e) => setLanguage(e.currentTarget.value)}>
							{#each LANGUAGES as [k, name]}<option value={k}>{name}</option>{/each}
						</select>
					</label>
					<p class="tiny muted">Las salas que crees se juegan en este idioma: la IA valida las respuestas en él.</p>
					<span class="langrow"><Palette size={18} color="var(--lemon)" /><span class="grow">Tema</span></span>
					<div class="themes">
						{#each themeKeys as k}
							{@const ok = themeUnlocked(k, p)}
							<button class="theme" class:on={k === theme} disabled={!ok} onclick={() => setTheme(k)}
								style:--a={THEMES[k].header} style:--b={THEMES[k].night} style:--g="rgb({THEMES[k].glow})">
								<span class="sw"></span><b>{THEMES[k].name}</b>
								<small>{k === theme ? 'En uso' : ok ? 'Usar' : `Nivel ${THEME_LEVEL[k]}`}</small>
							</button>
						{/each}
					</div>
				</section>
			{/if}

			<h3 class="section-title">Cuenta</h3>
			<section class="panel menu">
				{#if app.email}<div class="item static"><Mail size={18} /><span class="grow">{app.email}</span></div>{/if}
				{#if app.email && !app.needsPassword}<button class="item" onclick={() => open('password')}><KeyRound size={18} /><span class="grow">Cambiar contraseña</span></button>{/if}
				{#if p.is_admin}<a class="item" href="/moderacion"><Gavel size={18} /><span class="grow">Moderación</span></a>{/if}
				<a class="item" href="/como-jugar"><BookOpen size={18} /><span class="grow">Reglas del juego</span></a>
				<a class="item" href="/terminos"><FileText size={18} /><span class="grow">Términos de uso</span></a>
				<a class="item" href="/privacidad"><Shield size={18} /><span class="grow">Privacidad</span></a>
				{#if app.isGuest}
					<button class="item danger" onclick={() => (confirm = 'leave')}><LogOut size={18} /><span class="grow">Salir del modo invitado</span></button>
				{:else}
					<button class="item" onclick={() => (confirm = 'signout')}><LogOut size={18} /><span class="grow">Cerrar sesión</span></button>
					<button class="item danger" onclick={() => (confirm = 'delete')}><Trash2 size={18} /><span class="grow">Eliminar cuenta</span></button>
				{/if}
			</section>
		</div>
	</div>
</main>

{#if sheet === 'avatar'}
	<Sheet title="Elige tu avatar" onclose={() => (sheet = null)}>
		<div class="avs">
			{#each FREE_AVATARS as a}
				<button class="av" class:on={a === p.avatar} disabled={busy} onclick={() => pickAvatar(a)} aria-label={AVATAR_NAMES[a]}>
					<Avatar avatar={a} name={a} size={58} />{#if a === p.avatar}<span class="tick"><Check size={12} strokeWidth={4} /></span>{/if}
				</button>
			{/each}
		</div>
		{#if error}<p class="err">{error}</p>{/if}
	</Sheet>
{:else if sheet === 'username'}
	<Sheet title="Nombre de usuario" onclose={() => (sheet = null)}>
		<form class="stack" onsubmit={(e) => { e.preventDefault(); saveName(); }}>
			<input class="field" bind:value={newName} maxlength="20" autocapitalize="none" autocomplete="username" spellcheck="false" />
			<p class="muted small">3 a 20 caracteres: letras, números y guion bajo. Solo puedes cambiarlo una vez cada 30 días.</p>
			{#if error}<p class="err">{error}</p>{/if}
			<CandyButton type="submit" color="var(--lemon)" ink height={52} disabled={busy || newName.trim().length < 3 || newName.trim().toLowerCase() === p.username}>{busy ? 'Guardando…' : 'Guardar'}</CandyButton>
		</form>
	</Sheet>
{:else if sheet === 'password'}
	<Sheet title={app.needsPassword ? 'Crea tu contraseña' : 'Cambiar contraseña'} onclose={() => (sheet = null)}>
		<form class="stack" onsubmit={(e) => { e.preventDefault(); savePassword(); }}>
			<input class="field" type="password" placeholder="Nueva contraseña (mínimo 8)" minlength="8" autocomplete="new-password" bind:value={pass1} required />
			<input class="field" type="password" placeholder="Repite la contraseña" minlength="8" autocomplete="new-password" bind:value={pass2} required />
			{#if error}<p class="err">{error}</p>{/if}
			<CandyButton type="submit" color="var(--lemon)" ink height={52} disabled={busy || pass1.length < 8}>{busy ? 'Guardando…' : 'Guardar contraseña'}</CandyButton>
		</form>
	</Sheet>
{:else if sheet === 'save'}
	<Sheet title="Guardar mi progreso" onclose={() => (sheet = null)}>
		{#if info}
			<p class="ok">{info}</p>
			<CandyButton color="var(--lemon)" ink height={50} onclick={() => (sheet = null)}>Entendido</CandyButton>
		{:else}
			<form class="stack" onsubmit={(e) => { e.preventDefault(); saveGuest(); }}>
				<p class="muted small">Conservarás tu apodo, nivel y logros. Te enviaremos un correo para confirmar.</p>
				<input class="field" type="email" placeholder="nombre@correo.com" autocomplete="email" bind:value={saveEmail} required />
				{#if error}<p class="err">{error}</p>{/if}
				<CandyButton type="submit" color="var(--lemon)" icon={Mail} ink height={52} disabled={busy || !saveEmail.includes('@')}>{busy ? 'Enviando…' : 'Enviar enlace'}</CandyButton>
			</form>
		{/if}
	</Sheet>
{/if}

{#if confirm === 'signout'}
	<Dialog title="Cerrar sesión" message="¿Quieres cerrar sesión en este navegador?" pose="bye" confirm="Salir" cancel="Cancelar"
		onconfirm={async () => { confirm = null; await app.signOut(); goto('/jugar'); }} oncancel={() => (confirm = null)} />
{:else if confirm === 'leave'}
	<Dialog title="Salir" message="Se borrará tu partida de invitado (nombre, nivel y logros). ¿Continuar?" pose="bye" confirm="Salir" cancel="Cancelar"
		onconfirm={async () => { confirm = null; await app.leaveGuestMode(); goto('/jugar'); }} oncancel={() => (confirm = null)} />
{:else if confirm === 'delete'}
	<Dialog title="Eliminar cuenta" message="Se borrarán para siempre tu perfil, nivel, logros, historial y amigos. No se puede deshacer." pose="sad" confirm="Eliminar" cancel="Cancelar"
		onconfirm={async () => { confirm = null; try { await app.deleteAccount(); goto('/'); } catch (e) { app.showToast(friendlyError(e)); } }} oncancel={() => (confirm = null)} />
{/if}

<style>
	.wide-ish { max-width: 980px; }
	.prefs { gap: 10px; }
	.langrow { display: flex; align-items: center; gap: 10px; font-weight: 800; }
	.langrow select { background: var(--panel); color: #fff; border: 1.5px solid var(--panel-stroke); border-radius: 12px; padding: 8px 10px; font: inherit; font-weight: 800; }
	.langrow select option { color: #000; }
	.themes { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
	.theme { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 10px 6px; border-radius: 16px; cursor: pointer;
		background: var(--panel); border: 2px solid var(--panel-stroke); color: #fff; font: inherit; }
	.theme.on { border-color: var(--lemon); }
	.theme:disabled { opacity: .5; cursor: not-allowed; }
	.theme .sw { width: 44px; height: 44px; border-radius: 50%; border: 2px solid rgba(255,255,255,.3);
		background: radial-gradient(circle at 50% 15%, var(--g) 0 12%, transparent 45%), linear-gradient(180deg, var(--a), var(--b)); }
	.theme small { font-size: 11px; font-weight: 800; opacity: .75; }
	.bar { display: grid; grid-template-columns: 44px 1fr 44px; align-items: center; }
	.iconbtn { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: var(--panel); color: var(--lemon); border: 1.5px solid var(--panel-stroke); }
	.hero { display: flex; align-items: center; gap: 16px; }
	.avbtn { position: relative; background: none; border: 0; padding: 0; cursor: pointer; }
	.edit { position: absolute; right: 0; bottom: 0; display: grid; place-items: center; width: 26px; height: 26px; border-radius: 50%; background: var(--lemon); color: var(--ink); box-shadow: 0 0 0 2px var(--deep); }
	.name { font-size: 22px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.mini { background: none; border: 0; color: var(--lemon); cursor: pointer; padding: 4px; display: grid; }
	.lvrow { justify-content: space-between; margin-top: 2px; }
	.lv { color: var(--lemon); }
	.xp { height: 10px; border-radius: 99px; background: rgba(255,255,255,.12); overflow: hidden; margin-top: 6px; }
	.xp span { display: block; height: 100%; border-radius: 99px; background: linear-gradient(90deg, var(--lemon), var(--lime)); }
	.save { display: flex; align-items: center; gap: 12px; }
	.save p { margin: 2px 0 0; }
	.save :global(.candy) { width: 120px; flex: none; }
	.cols { display: grid; gap: 14px; }
	@media (min-width: 900px) { .cols { grid-template-columns: 1fr 1fr; align-items: start; } }
	.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
	.st { display: flex; flex-direction: column; align-items: center; padding: 14px 6px; text-align: center; }
	.st b { font-size: 24px; color: var(--lemon); } .st span { font-size: 12px; font-weight: 800; color: rgba(255,255,255,.65); }
	.achs { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px; }
	.ach { display: flex; flex-direction: column; gap: 4px; padding: 12px; opacity: .55; }
	.ach.on { opacity: 1; border-color: color-mix(in srgb, var(--c) 55%, transparent); background: color-mix(in srgb, var(--c) 12%, transparent); }
	.aic { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 50%; background: rgba(255,255,255,.1); color: rgba(255,255,255,.6); }
	.on .aic { background: var(--c); color: var(--ink); }
	.ach b { font-size: 14px; }
	.desc { font-size: 12px; font-weight: 700; color: rgba(255,255,255,.6); line-height: 1.3; }
	.hist { gap: 12px; }
	.rank { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 50%; background: rgba(255,255,255,.1); font-weight: 900; flex: none; }
	.rank.first { background: var(--lemon); color: var(--ink); }
	.right { text-align: right; } .pts { color: var(--lemon); }
	.menu { padding: 6px 14px; }
	.item { display: flex; align-items: center; gap: 12px; width: 100%; padding: 12px 0; background: none; border: 0; border-bottom: 1px solid rgba(255,255,255,.07);
		color: #fff; font: inherit; font-weight: 800; text-decoration: none; cursor: pointer; text-align: left; }
	.item:last-child { border-bottom: 0; }
	.item :global(svg) { color: var(--lemon); flex: none; }
	.item.static { cursor: default; color: rgba(255,255,255,.7); }
	.item.danger, .item.danger :global(svg) { color: #ff8aa0; }
	.avs { display: grid; grid-template-columns: repeat(auto-fill, minmax(70px, 1fr)); gap: 10px; }
	.av { position: relative; display: grid; place-items: center; padding: 6px; border-radius: 20px; background: var(--panel); border: 2px solid transparent; cursor: pointer; }
	.av.on { border-color: var(--lemon); }
	.tick { position: absolute; right: 4px; top: 4px; display: grid; place-items: center; width: 20px; height: 20px; border-radius: 50%; background: var(--lemon); color: var(--ink); }
	.err { color: #ff8aa0; font-weight: 800; text-align: center; margin: 0; }
	.ok { color: var(--lime); font-weight: 800; text-align: center; margin: 0; }
</style>
