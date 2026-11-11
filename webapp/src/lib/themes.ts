import type { Profile } from './types.ts';

/** Temas visuales (profiles.theme): cambian el fondo. Mismos colores que ThemePalette en iOS (GameTheme.swift). */
export const THEMES = {
	clasico: { name: 'Clásico', deep: '#0d4554', deeper: '#082c38', header: '#125c6b', night: '#0a1733', glow: '255, 148, 31' },
	pizarra: { name: 'Pizarra', deep: '#243830', deeper: '#14211c', header: '#334d42', night: '#121714', glow: '242, 242, 217' },
	neon: { name: 'Neón', deep: '#210d45', deeper: '#120529', header: '#381266', night: '#050217', glow: '255, 51, 191' }
} as const;
export type ThemeKey = keyof typeof THEMES;

/** Nivel necesario para usar cada tema (todo es gratis): Pizarra 5, Neón 10. Igual que en iOS. */
export const THEME_LEVEL: Record<ThemeKey, number> = { clasico: 1, pizarra: 5, neon: 10 };
export function themeUnlocked(key: ThemeKey, p: Profile | null): boolean {
	return (p?.level ?? 1) >= THEME_LEVEL[key];
}

export function usableTheme(p: Profile | null): ThemeKey {
	const k = (p?.theme ?? 'clasico') as ThemeKey;
	return k in THEMES && themeUnlocked(k, p) ? k : 'clasico';
}

export function applyTheme(key: ThemeKey) {
	if (typeof document === 'undefined') return;
	const t = THEMES[key], s = document.documentElement.style;
	s.setProperty('--deep', t.deep); s.setProperty('--deeper', t.deeper);
	s.setProperty('--header', t.header); s.setProperty('--night', t.night); s.setProperty('--glow', t.glow);
}
