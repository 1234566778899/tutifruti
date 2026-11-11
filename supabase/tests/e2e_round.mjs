// Prueba de punta a punta contra producción: 2 invitados, sala privada, ronda real con validate-round (IA).
// Uso: node supabase/tests/e2e_round.mjs [es|en|pt]. Crea datos reales: al final imprime CLEANUP con los ids a borrar.
import { createClient } from '../../webapp/node_modules/@supabase/supabase-js/dist/index.mjs';
const URL = 'https://liejnmzxlpctqybecrbu.supabase.co', KEY = 'sb_publishable_kcbf362MFjHNT0ozSuXmOA_zfX9koBw';
const mk = () => createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ok = (r, what) => { if (r.error) throw new Error(`${what}: ${r.error.message}`); return r.data; };
const lang = process.argv[2] ?? 'es';
const A = mk(), B = mk();
const n = Math.floor(Math.random() * 9000 + 1000);
ok(await A.auth.signInAnonymously(), 'anon A'); ok(await B.auth.signInAnonymously(), 'anon B');
ok(await A.rpc('create_profile', { p_username: `e2ea${n}`, p_avatar: 'fox' }), 'perfil A');
ok(await B.rpc('create_profile', { p_username: `e2eb${n}`, p_avatar: 'owl' }), 'perfil B');
const idA = (await A.auth.getUser()).data.user.id;
if (lang !== 'es') ok(await A.from('profiles').update({ language: lang }).eq('id', idA), 'idioma');
const room = ok(await A.rpc('create_room', { p_name: `E2E ${lang}`, p_max_players: 4, p_rounds: 1, p_round_seconds: 30, p_stop_seconds: 3,
  p_exclude_hard: true, p_categories: ['Nombre', 'Animal', 'Fruta'], p_allow_custom: false, p_is_public: false }), 'crear sala');
console.log('sala', room.code, 'idioma', room.language);
ok(await B.rpc('join_room_by_code', { p_code: room.code }), 'unirse');
ok(await B.rpc('set_ready', { p_room: room.id, p_ready: true }), 'listo');
// RLS: un tercero no ve la sala privada
const C = mk(); ok(await C.auth.signInAnonymously(), 'anon C');
const seen = await C.from('rooms').select('id').eq('id', room.id);
console.log('tercero ve la sala privada:', (seen.data ?? []).length > 0);
ok(await A.rpc('start_game', { p_room: room.id }), 'empezar');
const rd = ok(await A.from('rounds').select().eq('room_id', room.id).single(), 'ronda');
console.log('letra', rd.letter);
await sleep(Math.max(0, new Date(rd.starts_at) - Date.now()) + 800);
const L = rd.letter;
const wrong = L === 'M' ? 'Pera' : 'Mesa';
const answers = lang === 'en'
  ? { A: { Nombre: `${L}ichael`, Animal: wrong, Fruta: `${L}pple` }, B: { Nombre: `${L}ohn`, Animal: `${L}og`, Fruta: '' } }
  : { A: { Nombre: `${L}ariana`, Animal: wrong, Fruta: `${L}anzana` }, B: { Nombre: `${L}uis`, Animal: `${L}obo`, Fruta: '' } };
for (const [cli, who] of [[A, 'A'], [B, 'B']]) for (const [c, v] of Object.entries(answers[who]))
  ok(await cli.rpc('save_answer', { p_round: rd.id, p_category: c, p_value: v }), `respuesta ${who}`);
ok(await A.rpc('call_stop', { p_round: rd.id }), 'stop');
await sleep(4500);
console.log('close_round:', ok(await A.rpc('close_round', { p_round: rd.id }), 'cerrar'));
const t0 = Date.now();
const v = await A.functions.invoke('validate-round', { body: { round_id: rd.id } });
console.log('validate-round', v.error ? `ERROR ${v.error.message}` : JSON.stringify(v.data), `${Date.now() - t0} ms`);
const res = ok(await A.from('answers').select('user_id, category, value, status, points, reason, checks').eq('round_id', rd.id), 'respuestas');
const r2 = ok(await A.from('rounds').select('status, validated_by_ai').eq('id', rd.id).single(), 'estado');
console.log('ronda', JSON.stringify(r2));
for (const a of res) console.log(a.user_id === idA ? 'A' : 'B', a.category.padEnd(7), (a.value || '—').padEnd(10), a.status.padEnd(8), a.points, '|', a.reason, JSON.stringify(a.checks));
console.log('CLEANUP', room.id, `e2ea${n}`, `e2eb${n}`, (await C.auth.getUser()).data.user.id);
