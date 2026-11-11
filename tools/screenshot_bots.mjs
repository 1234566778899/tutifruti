// Jugadores simulados para las capturas de App Store (ver TutifrutiUITests/ScreenshotTests.swift).
// Espera a que el simulador cree una sala, mete dos invitados, fija la letra M y responde por ellos.
// Uso: SERVICE_KEY=<service role> SHOTS_DIR=<carpeta> node tools/screenshot_bots.mjs
// Crea datos reales en producción: al final imprime CLEANUP con los ids a borrar.
import { writeFileSync } from 'node:fs';
import { createClient } from '../webapp/node_modules/@supabase/supabase-js/dist/index.mjs';

const URL = 'https://liejnmzxlpctqybecrbu.supabase.co', KEY = 'sb_publishable_kcbf362MFjHNT0ozSuXmOA_zfX9koBw';
const DIR = process.env.SHOTS_DIR, LETTER = 'M';
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(URL, process.env.SERVICE_KEY, opts);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ok = (r, what) => { if (r.error) throw new Error(`${what}: ${r.error.message}`); return r.data; };
const since = new Date().toISOString();

const WORDS = {
	host: { Nombre: 'María', País: 'México', Ciudad: 'Madrid', Animal: 'Mono', Fruta: 'Mango', Color: 'Morado', Profesión: 'Médico', Marca: 'Mazda' },
	bots: [
		{ name: 'lucia', avatar: 'owl', words: { Nombre: 'Mateo', País: 'Marruecos', Ciudad: 'Madrid', Animal: 'Mapache', Fruta: 'Manzana', Color: 'Marrón', Profesión: 'Mecánico', Marca: 'Motorola' } },
		{ name: 'mateo', avatar: 'panda', words: { Nombre: 'Martina', País: 'México', Ciudad: 'Miami', Animal: 'Mono', Fruta: 'Melón', Color: 'Magenta', Profesión: 'Maestro', Marca: 'Mesa' } },
	],
};

// 1) Sala recién creada desde el simulador
let room;
for (let i = 0; i < 240 && !room; i++) {
	const rows = ok(await admin.from('rooms').select('*').eq('status', 'waiting').gte('created_at', since).order('created_at', { ascending: false }).limit(1), 'salas');
	room = rows[0];
	if (!room) await sleep(1000);
}
if (!room) throw new Error('No apareció ninguna sala');
console.log('sala', room.code, room.categories.join(', '));

// 2) Entran los jugadores simulados
const ids = [];
const bots = [];
for (const b of WORDS.bots) {
	const c = createClient(URL, KEY, opts);
	ok(await c.auth.signInAnonymously(), 'anon');
	ok(await c.rpc('create_profile', { p_username: `${b.name}${Math.floor(Math.random() * 9000 + 1000)}`, p_avatar: b.avatar }), 'perfil');
	ids.push((await c.auth.getUser()).data.user.id);
	ok(await c.rpc('join_room_by_code', { p_code: room.code }), 'unirse');
	ok(await c.rpc('set_ready', { p_room: room.id, p_ready: true }), 'listo');
	bots.push({ ...b, c });
	await sleep(1200);
}
const beat = setInterval(() => bots.forEach((b) => b.c.rpc('heartbeat', { p_room: room.id })), 10_000);

// 3) Al empezar: letra fija y respuestas del anfitrión para el test
let round;
for (let i = 0; i < 180 && !round; i++) {
	round = ok(await admin.from('rounds').select('*').eq('room_id', room.id).order('number').limit(1), 'ronda')[0];
	if (!round) await sleep(500);
}
if (!round) throw new Error('La partida no empezó');
ok(await admin.from('rounds').update({ letter: LETTER }).eq('id', round.id), 'letra');
writeFileSync(`${DIR}/answers.json`, JSON.stringify(room.categories.map((c) => WORDS.host[c] ?? `${LETTER}a`)));
console.log('letra fijada', LETTER);

// 4) Los simulados responden
await sleep(Math.max(0, new Date(round.starts_at) - Date.now()) + 1500);
for (const b of bots) {
	for (const cat of room.categories) {
		const r = await b.c.rpc('save_answer', { p_round: round.id, p_category: cat, p_value: b.words[cat] ?? '' });
		if (r.error) console.log('respuesta', cat, r.error.message);
	}
}
console.log('respuestas guardadas');

// 5) Resultados
for (let i = 0; i < 240; i++) {
	const r = ok(await admin.from('rounds').select('status').eq('id', round.id).single(), 'estado');
	if (r.status === 'results') { writeFileSync(`${DIR}/results.flag`, 'ok'); console.log('resultados listos'); break; }
	await sleep(500);
}
await sleep(25_000);
clearInterval(beat);
console.log('CLEANUP', room.id, ids.join(' '));
process.exit(0);
