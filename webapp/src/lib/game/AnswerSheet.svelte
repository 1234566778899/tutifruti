<script lang="ts">
	import { Check, X, Minus, Flag, MessageSquareWarning, Info } from '@lucide/svelte';
	import * as API from '#lib/api.ts';
	import { app } from '#lib/app.svelte.ts';
	import { friendlyError } from '#lib/errors.ts';
	import { sfx } from '#lib/sfx.ts';
	import { playerName, type Answer, type Dispute } from '#lib/types.ts';
	import type { Game } from './game.svelte';
	import Sheet from '#lib/components/Sheet.svelte';
	import CandyButton from '#lib/components/CandyButton.svelte';
	import Mascot from '#lib/components/Mascot.svelte';

	/** Detalle de una respuesta: explicación del árbitro, impugnación y reporte (igual que AnswerDetailSheet de iOS). */
	let { game, answer, onclose }: { game: Game; answer: Answer; onclose: () => void } = $props();

	let mode = $state<'detail' | 'dispute' | 'report'>('detail');
	const current = $derived(game.roundAnswers.find((a) => a.user_id === answer.user_id && a.category === answer.category) ?? answer);
	const dispute = $derived(game.disputeFor(current));
	const isMine = $derived(current.user_id === game.me);
	const left = $derived(game.myPlayer?.disputes_left ?? 0);
	const letter = $derived(game.currentRound?.letter ?? '');
	const owner = $derived(playerName(game.player(current.user_id)));

	const statusText: Record<string, string> = { valid: 'Válida', invalid: 'Inválida', doubtful: 'Dudosa', empty: 'Vacía', pending: 'Pendiente' };
	const statusColor: Record<string, string> = { valid: 'var(--lime)', invalid: 'var(--cherry)', doubtful: 'var(--tangerine)', empty: 'gray', pending: 'gray' };

	// Impugnar
	let kind = $state('');
	let justification = $state('');
	let sending = $state(false), error = $state<string | null>(null), resolved = $state<Dispute | null>(null);
	const kinds = $derived(isMine
		? [['my_valid', 'Mi respuesta debió ser válida'], ['not_duplicate', 'No debió contarse como repetida']]
		: [['other_invalid', 'La respuesta de este jugador es inválida']]);
	$effect(() => { if (!kinds.some(([k]) => k === kind)) kind = kinds[0][0]; });

	async function send() {
		sending = true; error = null;
		try {
			resolved = await game.dispute(current, kind, justification);
			sfx(resolved.status === 'accepted' ? 'valid' : 'invalid');
		} catch (e) { error = friendlyError(e); } finally { sending = false; }
	}

	// Reportar
	const reasons = ['Lenguaje ofensivo en el chat', 'Nombre de usuario inapropiado', 'Abandona partidas a propósito', 'Sospecha de trampa', 'Otro'];
	let reason = $state(reasons[0]), details = $state(''), mute = $state(false);
	async function sendReport() {
		sending = true; error = null;
		try {
			await API.report(current.user_id, game.roomId, reason, details.trim(), mute);
			if (mute) app.muted = new Set([...app.muted, current.user_id]);
			app.showToast('Reporte enviado. Gracias, lo revisaremos.', false);
			onclose();
		} catch (e) { error = friendlyError(e); } finally { sending = false; }
	}

	const checks = $derived(current.checks ? [
		[`Empieza con la letra ${letter}`, current.checks.letter],
		['Pertenece a la categoría', current.checks.category],
		['Palabra real en español', current.checks.real_word],
		['Sin errores ortográficos', current.checks.spelling]
	] as [string, boolean | null | undefined][] : []);
</script>

<Sheet title={`${current.category} · “${current.value || '—'}”`} {onclose}>
	{#if resolved}
		<div class="done">
			<Mascot pose={resolved.status === 'accepted' ? 'party' : 'judge'} size={120} />
			<h3>{resolved.status === 'accepted' ? 'Impugnación aceptada' : 'Impugnación rechazada'}</h3>
			<p>{resolved.resolution ?? ''}</p>
			{#if resolved.points_delta}<b class="delta">{resolved.points_delta > 0 ? '+' : ''}{resolved.points_delta} pts</b>{/if}
			<CandyButton color="var(--lemon)" ink height={50} onclick={onclose}>Entendido</CandyButton>
		</div>
	{:else if mode === 'detail'}
		<div class="row tags">
			<span class="badge" style:--c={statusColor[current.status]}>{statusText[current.status]}{current.status === 'valid' ? ` · +${current.points}` : ''}</span>
			<span class="muted small">{owner}{isMine ? ' (tú)' : ''} · Letra {letter}</span>
			{#if dispute}<span class="badge" style:--c={dispute.status === 'accepted' ? 'var(--lime)' : dispute.status === 'rejected' ? 'var(--cherry)' : 'var(--sky)'}>{dispute.status === 'pending' ? 'En revisión' : dispute.status === 'accepted' ? 'Impugnación aceptada' : 'Impugnación rechazada'}</span>{/if}
		</div>
		<section class="panel judge">
			<Mascot pose="judge" size={64} />
			<div><span class="section-title">Explicación del árbitro</span><p>{current.reason ?? 'Sin explicación.'}</p></div>
		</section>
		{#if checks.length}
			<section class="panel checks">
				{#each checks as [label, ok]}
					<div class="row"><span class="grow">{label}</span>
						<span class="ic" style:background={ok == null ? 'var(--tangerine)' : ok ? 'var(--lime)' : 'var(--cherry)'}>{#if ok == null}<Minus size={13} strokeWidth={4} />{:else if ok}<Check size={13} strokeWidth={4} />{:else}<X size={13} strokeWidth={4} />{/if}</span></div>
				{/each}
			</section>
		{/if}
		{#if dispute && dispute.status !== 'pending'}
			<section class="panel"><span class="section-title">Segunda evaluación</span><p>{dispute.resolution}</p>
				{#if dispute.points_delta}<b class="delta">{dispute.points_delta > 0 ? '+' : ''}{dispute.points_delta} pts</b>{/if}</section>
		{/if}
		<div class="acts">
			{#if !current.disputed && current.status !== 'empty'}
				<CandyButton color="var(--sky)" icon={Flag} ink height={50} disabled={left <= 0} onclick={() => (mode = 'dispute')}>Impugnar evaluación</CandyButton>
			{/if}
			<p class="muted small center">Te quedan {left} {left === 1 ? 'impugnación' : 'impugnaciones'} en esta partida.</p>
			{#if !isMine}<button class="link danger" onclick={() => (mode = 'report')}><MessageSquareWarning size={16} /> Reportar a {owner}</button>{/if}
		</div>
	{:else if mode === 'dispute'}
		<span class="section-title">¿Qué quieres impugnar?</span>
		<div class="opts">
			{#each kinds as [k, label]}
				<label class="opt" class:on={kind === k}><input type="radio" bind:group={kind} value={k} />{label}</label>
			{/each}
		</div>
		<span class="section-title">Justificación</span>
		<textarea class="field" rows="3" maxlength="300" placeholder="Mago es una profesión reconocida: ilusionista de espectáculos." bind:value={justification}></textarea>
		<p class="muted small info"><Info size={15} /> Una segunda IA evaluará de forma independiente. Solo puedes impugnar una vez cada respuesta.</p>
		{#if error}<p class="err">{error}</p>{/if}
		<CandyButton color="var(--sky)" icon={Flag} ink height={52} disabled={sending || justification.trim().length < 5} onclick={send}>{sending ? 'La IA está revisando…' : 'Enviar impugnación'}</CandyButton>
		<button class="link" onclick={() => (mode = 'detail')}>Volver</button>
	{:else}
		<span class="section-title">Motivo</span>
		<div class="opts">
			{#each reasons as r}<label class="opt" class:on={reason === r}><input type="radio" bind:group={reason} value={r} />{r}</label>{/each}
		</div>
		<textarea class="field" rows="3" maxlength="500" placeholder="Describe lo ocurrido (opcional)" bind:value={details}></textarea>
		<label class="row mute"><input type="checkbox" bind:checked={mute} /> Silenciar a este jugador en el chat</label>
		{#if error}<p class="err">{error}</p>{/if}
		<CandyButton color="var(--cherry)" icon={MessageSquareWarning} height={52} disabled={sending} onclick={sendReport}>{sending ? 'Enviando…' : 'Enviar reporte'}</CandyButton>
		<button class="link" onclick={() => (mode = 'detail')}>Volver</button>
	{/if}
</Sheet>

<style>
	.tags { flex-wrap: wrap; gap: 8px; }
	.badge { padding: 4px 10px; border-radius: 99px; font-weight: 900; font-size: 13px; color: var(--ink); background: var(--c); }
	.judge { display: flex; gap: 10px; align-items: flex-start; }
	.judge p, .panel p { margin: 4px 0 0; font-weight: 700; line-height: 1.45; }
	.checks { display: grid; gap: 8px; font-weight: 800; }
	.ic { display: grid; place-items: center; width: 22px; height: 22px; border-radius: 50%; color: var(--ink); }
	.acts { display: grid; gap: 8px; }
	.center { text-align: center; margin: 0; }
	.link { background: none; border: 0; color: var(--lemon); font-weight: 900; cursor: pointer; display: inline-flex; gap: 6px; align-items: center; justify-content: center; padding: 8px; }
	.link.danger { color: #ff8aa0; }
	.opts { display: grid; gap: 8px; }
	.opt { display: flex; gap: 10px; align-items: center; padding: 12px 14px; border-radius: 16px; background: var(--panel); border: 1.5px solid var(--panel-stroke); font-weight: 800; cursor: pointer; }
	.opt.on { border-color: var(--lemon); background: rgba(255,210,63,.12); }
	.opt input { accent-color: var(--lemon); }
	textarea.field { height: auto; resize: vertical; min-height: 80px; padding: 12px; font: inherit; font-weight: 700; }
	.info { display: flex; gap: 6px; align-items: flex-start; margin: 0; }
	.mute { font-weight: 800; } .mute input { accent-color: var(--lemon); width: 18px; height: 18px; }
	.err { color: #ff8aa0; font-weight: 800; margin: 0; text-align: center; }
	.done { display: flex; flex-direction: column; align-items: center; text-align: center; gap: 6px; }
	.done h3 { margin: 0; font-size: 22px; } .done p { margin: 0 0 8px; font-weight: 700; }
	.delta { color: var(--lemon); font-size: 20px; }
</style>
