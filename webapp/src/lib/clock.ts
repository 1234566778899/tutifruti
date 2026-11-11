import { supabase } from './supabase';

/** Diferencia entre el reloj del servidor y el del navegador (temporizadores justos, igual que iOS). */
let offset = 0;
export const serverNow = () => Date.now() + offset;
export async function syncClock() {
	const t0 = Date.now();
	const { data } = await supabase.rpc('server_now');
	const t1 = Date.now();
	if (typeof data === 'string') offset = new Date(data).getTime() - (t0 + t1) / 2;
}
