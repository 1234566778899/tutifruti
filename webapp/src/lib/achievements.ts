import { Trophy, Gamepad2, Flame, BadgeCheck, Star, Zap, Grid3x3, Drama, Users, Medal, Globe, Crown } from '@lucide/svelte';
/** Íconos de logros: la base guarda nombres de SF Symbols (iOS); aquí se mapean a Lucide. */
export const ACHIEVEMENT_ICONS: Record<string, any> = {
	'trophy.fill': Trophy, '10.circle.fill': Gamepad2, 'flame.fill': Flame, 'checkmark.seal.fill': BadgeCheck, 'star.fill': Star,
	'bolt.fill': Zap, 'square.grid.3x3.fill': Grid3x3, 'theatermasks.fill': Drama, 'person.2.fill': Users, 'medal.fill': Medal,
	globe: Globe, 'crown.fill': Crown
};
export const ACHIEVEMENT_COLORS = ['var(--lemon)', 'var(--sky)', 'var(--tangerine)', 'var(--lime)', 'var(--cherry)', '#b07cff'];
