/** Mensajes de error amigables (mismos criterios que iOS). */
export function isNetworkError(e: unknown): boolean {
	const m = String((e as { message?: string })?.message ?? e).toLowerCase();
	return m.includes('failed to fetch') || m.includes('network') || m.includes('load failed') || m.includes('timeout');
}
export function friendlyError(e: unknown): string {
	if (isNetworkError(e)) return 'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.';
	const m = (e as { message?: string })?.message ?? String(e);
	const l = m.toLowerCase();
	if (l.includes('invalid login')) return 'Correo o contraseña incorrectos.';
	if (l.includes('email not confirmed')) return 'Confirma tu correo antes de iniciar sesión.';
	if (l.includes('already registered')) return 'Ese correo ya tiene una cuenta.';
	if (l.includes('anonymous')) return 'El modo invitado no está activado en el servidor.';
	return m;
}
