/** Efectos de sonido (los mismos WAV de la app iOS). Respeta la preferencia guardada en localStorage. */
export type Sound = 'tap' | 'tick' | 'reveal' | 'count' | 'go' | 'stop' | 'hurry' | 'valid' | 'invalid' | 'doubtful'
	| 'coin' | 'win' | 'levelup' | 'notify' | 'message' | 'join' | 'lose';

const cache = new Map<Sound, HTMLAudioElement>();
const last = new Map<Sound, number>();

export function soundEnabled(): boolean {
	try { return localStorage.getItem('soundEnabled') !== 'false'; } catch { return true; }
}
export function setSoundEnabled(on: boolean) {
	try { localStorage.setItem('soundEnabled', String(on)); } catch { /* sin almacenamiento */ }
}

export function sfx(s: Sound, volume = 1) {
	if (typeof window === 'undefined' || !soundEnabled()) return;
	const now = performance.now();
	if ((last.get(s) ?? 0) > now - 40) return;
	last.set(s, now);
	let base = cache.get(s);
	if (!base) { base = new Audio(`/sounds/${s}.wav`); base.preload = 'auto'; cache.set(s, base); }
	const a = base.cloneNode() as HTMLAudioElement;
	a.volume = Math.max(0, Math.min(1, volume));
	a.play().catch(() => { /* el navegador bloquea audio hasta la primera interacción */ });
}

export function hapticsEnabled(): boolean {
	try { return localStorage.getItem('hapticsEnabled') !== 'false'; } catch { return true; }
}
export function setHapticsEnabled(on: boolean) {
	try { localStorage.setItem('hapticsEnabled', String(on)); } catch { /* sin almacenamiento */ }
}
export function haptic(ms = 10) {
	if (!hapticsEnabled()) return;
	try { navigator.vibrate?.(ms); } catch { /* sin vibración */ }
}
