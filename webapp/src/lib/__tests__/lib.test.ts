import { describe, expect, it } from 'vitest';
import { friendlyError, isNetworkError } from '../errors.ts';
import { isConnected, languageName, xpForNext, type Profile, type RoomPlayer } from '../types.ts';
import { THEMES, themeUnlocked, usableTheme } from '../themes.ts';

const profile = (patch: Partial<Profile> = {}) => ({ level: 1, is_plus: false, theme: 'clasico', ...patch }) as Profile;

describe('errores', () => {
	it('reconoce errores de red', () => {
		expect(isNetworkError(new Error('TypeError: Failed to fetch'))).toBe(true);
		expect(friendlyError(new Error('Failed to fetch'))).toMatch(/Sin conexión/);
	});
	it('traduce errores de autenticación', () => {
		expect(friendlyError({ message: 'Invalid login credentials' })).toBe('Correo o contraseña incorrectos.');
		expect(friendlyError({ message: 'La sala está llena' })).toBe('La sala está llena');
	});
});

describe('progresión y salas', () => {
	it('XP por nivel = 250 × nivel', () => {
		expect(xpForNext(1)).toBe(250);
		expect(xpForNext(4)).toBe(1000);
	});
	it('un jugador está conectado si su latido tiene menos de 45 s', () => {
		const now = Date.parse('2026-11-11T12:00:00Z');
		const p = (s: number) => ({ last_seen: new Date(now - s * 1000).toISOString() }) as RoomPlayer;
		expect(isConnected(p(10), now)).toBe(true);
		expect(isConnected(p(60), now)).toBe(false);
	});
	it('nombres de idioma', () => {
		expect(languageName('en')).toBe('English');
		expect(languageName(null)).toBe('Español');
		expect(languageName('xx')).toBe('Español');
	});
});

describe('temas', () => {
	it('Pizarra se desbloquea en nivel 5 y Neón con Plus', () => {
		expect(themeUnlocked('pizarra', profile({ level: 4 }))).toBe(false);
		expect(themeUnlocked('pizarra', profile({ level: 5 }))).toBe(true);
		expect(themeUnlocked('neon', profile())).toBe(false);
		expect(themeUnlocked('neon', profile({ is_plus: true }))).toBe(true);
	});
	it('un tema equipado pero bloqueado vuelve al clásico', () => {
		expect(usableTheme(profile({ theme: 'neon' }))).toBe('clasico');
		expect(usableTheme(profile({ theme: 'neon', is_plus: true }))).toBe('neon');
		expect(usableTheme(profile({ theme: 'inexistente' }))).toBe('clasico');
		expect(usableTheme(null)).toBe('clasico');
	});
	it('todos los temas tienen los mismos colores definidos', () => {
		for (const t of Object.values(THEMES)) {
			for (const k of ['deep', 'deeper', 'header', 'night'] as const) expect(t[k]).toMatch(/^#[0-9a-f]{6}$/);
			expect(t.glow).toMatch(/^\d{1,3}, \d{1,3}, \d{1,3}$/);
		}
	});
});
