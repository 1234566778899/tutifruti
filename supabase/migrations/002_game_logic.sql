-- Tutifruti AI · Lógica del juego (RPCs)
-- Todas las funciones son SECURITY DEFINER y validan auth.uid().

-- ---------- utilidades ----------
create or replace function public.server_now() returns timestamptz language sql stable as $$ select now() $$;

create or replace function public._uid() returns uuid language plpgsql stable as $$
begin
  if auth.uid() is null then raise exception 'No autenticado' using errcode = '28000'; end if;
  return auth.uid();
end $$;

create or replace function public._room_code() returns text language plpgsql as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := 'TUTI-';
    for i in 1..4 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from rooms where code = c and status <> 'finished');
  end loop;
  return c;
end $$;

create or replace function public._notify(p_user uuid, p_kind text, p_title text, p_body text, p_payload jsonb default '{}')
returns void language plpgsql security definer set search_path = public as $$
declare pref text := case p_kind
  when 'room_invite' then 'invites' when 'friend_request' then 'friend_requests'
  when 'results' then 'results' when 'achievement' then 'achievements'
  when 'season' then 'seasons' when 'friend_online' then 'friends_online' else null end;
begin
  if pref is not null and coalesce((select (notif_prefs ->> pref)::boolean from profiles where id = p_user), true) = false then
    return;
  end if;
  insert into notifications (user_id, kind, title, body, payload) values (p_user, p_kind, p_title, p_body, p_payload);
end $$;

create or replace function public._system_msg(p_room uuid, p_body text) returns void
language sql security definer set search_path = public as $$
  insert into chat_messages (room_id, user_id, body, kind) values (p_room, null, p_body, 'system');
$$;

-- ---------- perfil ----------
create or replace function public.username_available(p_username text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_username ~ '^[a-z0-9._]{3,20}$' and not exists (select 1 from profiles where username = lower(p_username))
$$;

create or replace function public.create_profile(p_username text, p_avatar text) returns profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); p profiles;
begin
  insert into profiles (id, username, avatar) values (me, lower(p_username), coalesce(p_avatar, '🦊'))
  on conflict (id) do update set username = excluded.username, avatar = excluded.avatar
  returning * into p;
  return p;
end $$;

create or replace function public.change_username(p_username text) returns profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); p profiles;
begin
  select * into p from profiles where id = me;
  if p.username = lower(p_username) then return p; end if;
  if p.username_changed_at is not null and p.username_changed_at > now() - interval '30 days' then
    raise exception 'Solo puedes cambiar tu nombre de usuario una vez cada 30 días';
  end if;
  update profiles set username = lower(p_username), username_changed_at = now() where id = me returning * into p;
  return p;
end $$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  delete from auth.users where id = _uid();
end $$;

create or replace function public.online_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from profiles where last_seen > now() - interval '2 minutes'
$$;

create or replace function public.heartbeat(p_room uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid();
begin
  update profiles set last_seen = now(), current_room = p_room where id = me;
  if p_room is not null then
    update room_players set last_seen = now() where room_id = p_room and user_id = me;
  end if;
end $$;

-- ---------- niveles / xp ----------
create or replace function public._add_xp(p_user uuid, p_xp int) returns int
language plpgsql security definer set search_path = public as $$
declare lv int; x int; gained int := 0;
begin
  select level, xp + p_xp into lv, x from profiles where id = p_user for update;
  while x >= 250 * lv loop
    x := x - 250 * lv; lv := lv + 1; gained := gained + 1;
    perform _notify(p_user, 'level_up', '¡Subiste a nivel ' || lv || '!', 'Sigue jugando para desbloquear más recompensas.', jsonb_build_object('level', lv));
    insert into activity (user_id, text, detail) values (p_user, 'subió a nivel ' || lv, null);
  end loop;
  update profiles set level = lv, xp = x where id = p_user;
  return gained;
end $$;

create or replace function public._unlock(p_user uuid, p_ach text) returns void
language plpgsql security definer set search_path = public as $$
declare t text;
begin
  insert into user_achievements (user_id, achievement_id) values (p_user, p_ach) on conflict do nothing;
  if found then
    select title into t from achievements where id = p_ach;
    perform _notify(p_user, 'achievement', 'Logro desbloqueado', t, jsonb_build_object('achievement', p_ach));
    insert into activity (user_id, text, detail) values (p_user, 'desbloqueó un logro', t);
  end if;
end $$;

create or replace function public._progress(p_user uuid, p_metric text, p_amount int) returns void
language plpgsql security definer set search_path = public as $$
declare c record; k text;
begin
  if p_amount <= 0 then return; end if;
  for c in select * from challenges where metric = p_metric loop
    k := case c.period when 'daily' then to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM-DD')
                       else to_char(now() at time zone 'America/Mexico_City', 'IYYY-IW') end;
    insert into user_challenges (user_id, challenge_id, period_key, progress)
    values (p_user, c.id, k, least(p_amount, c.goal))
    on conflict (user_id, challenge_id, period_key)
    do update set progress = least(user_challenges.progress + p_amount, c.goal);
  end loop;
end $$;

create or replace function public.my_challenges() returns table (
  id text, period text, title text, goal int, xp int, progress int, claimed boolean, period_key text)
language sql stable security definer set search_path = public as $$
  with keys as (
    select to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM-DD') d,
           to_char(now() at time zone 'America/Mexico_City', 'IYYY-IW') w)
  select c.id, c.period, c.title, c.goal, c.xp,
         coalesce(uc.progress, 0), coalesce(uc.claimed, false),
         case c.period when 'daily' then keys.d else keys.w end
  from challenges c cross join keys
  left join user_challenges uc on uc.challenge_id = c.id and uc.user_id = auth.uid()
       and uc.period_key = case c.period when 'daily' then keys.d else keys.w end
  order by c.period, c.sort
$$;

create or replace function public.claim_challenge(p_challenge text) returns int
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); c challenges; k text; uc user_challenges;
begin
  select * into c from challenges where id = p_challenge;
  k := case c.period when 'daily' then to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM-DD')
                     else to_char(now() at time zone 'America/Mexico_City', 'IYYY-IW') end;
  select * into uc from user_challenges where user_id = me and challenge_id = p_challenge and period_key = k for update;
  if uc is null or uc.progress < c.goal then raise exception 'El desafío aún no está completo'; end if;
  if uc.claimed then raise exception 'Ya reclamaste este desafío'; end if;
  update user_challenges set claimed = true where user_id = me and challenge_id = p_challenge and period_key = k;
  return _add_xp(me, c.xp);
end $$;

-- ---------- salas ----------
create or replace function public._join(p_room uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r rooms; n int;
begin
  select * into r from rooms where id = p_room for update;
  if r is null then raise exception 'La sala no existe'; end if;
  if exists (select 1 from room_players where room_id = p_room and user_id = p_user) then
    update room_players set left_at = null, last_seen = now() where room_id = p_room and user_id = p_user;
    return;
  end if;
  if r.status <> 'waiting' then raise exception 'La partida ya empezó'; end if;
  select count(*) into n from room_players where room_id = p_room and left_at is null;
  if n >= r.max_players then raise exception 'La sala está llena'; end if;
  insert into room_players (room_id, user_id, ready) values (p_room, p_user, r.is_public);
  perform _system_msg(p_room, (select username from profiles where id = p_user) || ' entró a la sala');
end $$;

create or replace function public.create_room(
  p_name text, p_max_players int, p_rounds int, p_round_seconds int, p_stop_seconds int,
  p_exclude_hard boolean, p_categories text[], p_allow_custom boolean) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; plus boolean;
begin
  select is_plus into plus from profiles where id = me;
  if p_max_players > 8 and not plus then raise exception 'Las salas de más de 8 jugadores requieren Tutifruti Plus'; end if;
  if coalesce(array_length(p_categories, 1), 0) < 3 then raise exception 'Elige al menos 3 categorías'; end if;
  if array_length(p_categories, 1) > 12 then raise exception 'Máximo 12 categorías'; end if;
  insert into rooms (code, name, host_id, max_players, rounds_total, round_seconds, stop_seconds, exclude_hard, categories, allow_custom)
  values (_room_code(), coalesce(nullif(btrim(p_name), ''), 'Sala de Stop'), me, p_max_players, p_rounds,
          p_round_seconds, p_stop_seconds, p_exclude_hard, p_categories, p_allow_custom)
  returning * into r;
  insert into room_players (room_id, user_id, ready) values (r.id, me, true);
  return r;
end $$;

create or replace function public.update_room(
  p_room uuid, p_name text, p_max_players int, p_rounds int, p_round_seconds int, p_stop_seconds int,
  p_exclude_hard boolean, p_categories text[], p_allow_custom boolean) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms;
begin
  update rooms set name = p_name, max_players = p_max_players, rounds_total = p_rounds, round_seconds = p_round_seconds,
    stop_seconds = p_stop_seconds, exclude_hard = p_exclude_hard, categories = p_categories, allow_custom = p_allow_custom
  where id = p_room and host_id = me and status = 'waiting' returning * into r;
  if r is null then raise exception 'Solo el anfitrión puede editar la sala antes de empezar'; end if;
  return r;
end $$;

create or replace function public.join_room_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rid uuid;
begin
  select id into rid from rooms
  where code = upper(btrim(p_code)) and status in ('waiting','playing') order by created_at desc limit 1;
  if rid is null then raise exception 'No encontramos una sala con ese código'; end if;
  perform _join(rid, me);
  return rid;
end $$;

create or replace function public.set_ready(p_room uuid, p_ready boolean) returns void
language sql security definer set search_path = public as $$
  update room_players set ready = p_ready where room_id = p_room and user_id = auth.uid();
$$;

create or replace function public.leave_room(p_room uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; nh uuid;
begin
  select * into r from rooms where id = p_room for update;
  if r is null then return; end if;
  if r.status = 'waiting' then
    delete from room_players where room_id = p_room and user_id = me;
    perform _system_msg(p_room, (select username from profiles where id = me) || ' salió de la sala');
    if r.host_id = me then
      select user_id into nh from room_players where room_id = p_room order by joined_at limit 1;
      if nh is null then update rooms set status = 'cancelled' where id = p_room;
      else update rooms set host_id = nh where id = p_room; end if;
    end if;
    if r.is_public and (select count(*) from room_players where room_id = p_room) < r.min_players then
      update rooms set starts_at = null where id = p_room;
    end if;
  else
    update room_players set left_at = now() where room_id = p_room and user_id = me and left_at is null;
    perform _system_msg(p_room, (select username from profiles where id = me) || ' abandonó la partida');
  end if;
  update profiles set current_room = null where id = me;
end $$;

create or replace function public.invite_to_room(p_room uuid, p_users uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; u uuid; n int := 0; myname text;
begin
  if not is_member(p_room) then raise exception 'No estás en esta sala'; end if;
  select * into r from rooms where id = p_room;
  select username into myname from profiles where id = me;
  foreach u in array p_users loop
    if are_friends(me, u) then
      perform _notify(u, 'room_invite', myname || ' te invitó a una sala', 'Sala "' || r.name || '"',
                      jsonb_build_object('room_id', r.id, 'code', r.code));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.rematch(p_room uuid) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); o rooms; r rooms; u uuid;
begin
  select * into o from rooms where id = p_room;
  if o is null then raise exception 'La sala no existe'; end if;
  r := create_room(o.name, o.max_players, o.rounds_total, o.round_seconds, o.stop_seconds, o.exclude_hard, o.categories, o.allow_custom);
  for u in select user_id from room_players where room_id = p_room and user_id <> me loop
    perform _notify(u, 'room_invite', (select username from profiles where id = me) || ' quiere la revancha',
                    'Sala "' || r.name || '"', jsonb_build_object('room_id', r.id, 'code', r.code));
  end loop;
  return r;
end $$;

-- ---------- matchmaking público ----------
create or replace function public.find_public_match(p_wide boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); lv int; rid uuid; n int; r rooms;
begin
  select level into lv from profiles where id = me;
  -- salir de otras salas públicas en espera
  delete from room_players rp using rooms ro
   where rp.room_id = ro.id and rp.user_id = me and ro.is_public and ro.status = 'waiting';

  select ro.id into rid from rooms ro
   where ro.is_public and ro.status = 'waiting'
     and (p_wide or lv between ro.level_min and ro.level_max)
     and (select count(*) from room_players where room_id = ro.id) < ro.max_players
   order by ro.created_at
   limit 1 for update skip locked;

  if rid is null then
    insert into rooms (code, name, host_id, is_public, ranked, max_players, min_players, rounds_total, round_seconds,
                       stop_seconds, exclude_hard, categories, level_min, level_max)
    values (_room_code(), 'Partida pública', null, true, true, 8, 2, 5, 60, 10, true,
            array['Nombre','Apellido','País','Ciudad','Animal','Fruta','Color','Objeto','Profesión','Marca'],
            case when p_wide then 1 else greatest(1, lv - 3) end, case when p_wide then 999 else lv + 3 end)
    returning id into rid;
  end if;

  insert into room_players (room_id, user_id, ready) values (rid, me, true) on conflict do nothing;
  select * into r from rooms where id = rid;
  select count(*) into n from room_players where room_id = rid;
  if n >= r.min_players and r.starts_at is null then
    update rooms set starts_at = now() + interval '15 seconds' where id = rid;
  end if;
  return rid;
end $$;

create or replace function public.widen_match(p_room uuid) returns void
language sql security definer set search_path = public as $$
  update rooms set level_min = 1, level_max = 999 where id = p_room and is_public and status = 'waiting' and public.is_member(p_room);
$$;

-- ---------- rondas ----------
create or replace function public._new_round(p_room uuid) returns rounds
language plpgsql security definer set search_path = public as $$
declare r rooms; letters text[]; l text; rd rounds;
begin
  select * into r from rooms where id = p_room for update;
  letters := array['A','B','C','D','E','F','G','H','I','J','K','L','M','N','Ñ','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
  if r.exclude_hard then
    letters := array(select x from unnest(letters) x where x <> all (array['Ñ','Q','W','X','Y','Z','K']));
  end if;
  letters := array(select x from unnest(letters) x where x <> all (r.used_letters));
  if array_length(letters, 1) is null then letters := array['A','C','M','P','S']; end if;
  l := letters[1 + floor(random() * array_length(letters, 1))::int];

  insert into rounds (room_id, number, letter, starts_at, ends_at, close_at)
  values (p_room, r.current_round + 1, l, now() + interval '5 seconds',
          now() + interval '5 seconds' + make_interval(secs => r.round_seconds),
          now() + interval '5 seconds' + make_interval(secs => r.round_seconds))
  returning * into rd;
  update rooms set current_round = rd.number, used_letters = used_letters || l, status = 'playing' where id = p_room;
  return rd;
end $$;

create or replace function public.start_game(p_room uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; n int;
begin
  select * into r from rooms where id = p_room for update;
  if r is null or r.status <> 'waiting' then return; end if;  -- idempotente
  if not is_member(p_room) then raise exception 'No estás en esta sala'; end if;
  if r.is_public then
    if r.starts_at is null or r.starts_at > now() then raise exception 'Aún no es hora de empezar'; end if;
  elsif r.host_id <> me then
    raise exception 'Solo el anfitrión puede iniciar la partida';
  end if;
  select count(*) into n from room_players where room_id = p_room and ready and left_at is null;
  if n < 2 then raise exception 'Se necesitan al menos 2 jugadores listos'; end if;
  -- quienes no están listos en salas privadas no juegan
  delete from room_players where room_id = p_room and not ready;
  perform _system_msg(p_room, '¡Empieza la partida!');
  perform _new_round(p_room);
end $$;

create or replace function public.save_answer(p_round uuid, p_category text, p_value text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds;
begin
  select * into rd from rounds where id = p_round;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'playing' or now() > rd.close_at + interval '2 seconds' then raise exception 'La ronda ya cerró'; end if;
  if now() < rd.starts_at then raise exception 'La ronda aún no empieza'; end if;
  if not exists (select 1 from rooms where id = rd.room_id and p_category = any (categories)) then raise exception 'Categoría no válida'; end if;
  insert into answers (round_id, user_id, category, value, updated_at)
  values (p_round, me, p_category, left(btrim(p_value), 40), now())
  on conflict (round_id, user_id, category) do update set value = excluded.value, updated_at = now();
end $$;

create or replace function public.call_stop(p_round uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds; r rooms; filled int;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'playing' or now() > rd.close_at then raise exception 'La ronda ya cerró'; end if;
  if rd.stop_by is not null then return; end if;
  select * into r from rooms where id = rd.room_id;
  select count(*) into filled from answers where round_id = p_round and user_id = me and btrim(value) <> '';
  if filled < array_length(r.categories, 1) then raise exception 'Completa todas las categorías para decir STOP'; end if;
  update rounds set stop_by = me, stop_at = now(),
         close_at = least(close_at, now() + make_interval(secs => r.stop_seconds))
   where id = p_round;
end $$;

-- Cierra la ronda cuando venció el tiempo. Cualquier jugador puede llamarla (idempotente).
create or replace function public.close_round(p_round uuid) returns text
language plpgsql security definer set search_path = public as $$
declare rd rounds; r rooms;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'playing' then return rd.status; end if;
  if now() < rd.close_at then return 'playing'; end if;
  select * into r from rooms where id = rd.room_id;
  -- completa respuestas vacías
  insert into answers (round_id, user_id, category, value)
  select p_round, rp.user_id, c, '' from room_players rp cross join unnest(r.categories) c
  where rp.room_id = rd.room_id and rp.left_at is null
  on conflict do nothing;
  update rounds set status = 'validating', validation_started_at = now() where id = p_round;
  return 'validating';
end $$;

-- Validación básica sin IA (letra, vacías). La IA (Edge Function) puede sobrescribir antes.
create or replace function public._basic_check(p_value text, p_letter text) returns text
language sql immutable as $$
  select case
    when btrim(coalesce(p_value, '')) = '' then 'empty'
    when p_letter = 'Ñ' and lower(left(btrim(p_value), 1)) <> 'ñ' then 'invalid'
    when p_letter <> 'Ñ' and upper(left(public.norm(p_value), 1)) <> p_letter then 'invalid'
    when char_length(btrim(p_value)) < 2 or btrim(p_value) !~ '[[:alpha:]]{2,}' then 'invalid'
    else 'valid' end
$$;

create or replace function public._score_round(p_round uuid) returns void
language plpgsql security definer set search_path = public as $$
declare rd rounds;
begin
  select * into rd from rounds where id = p_round;
  -- puntos: 10 única, 5 repetida, 0 inválida/vacía/dudosa
  update answers a set points = case
      when a.status <> 'valid' then 0
      when (select count(*) from answers b where b.round_id = a.round_id and b.category = a.category
              and b.status = 'valid' and norm(b.value) = norm(a.value)) > 1 then 5
      else 10 end
  where a.round_id = p_round;
  -- puntuación acumulada de la sala
  update room_players rp set score = coalesce((
      select sum(a.points) from answers a join rounds r on r.id = a.round_id
      where r.room_id = rd.room_id and a.user_id = rp.user_id), 0)
  where rp.room_id = rd.room_id;
end $$;

create or replace function public.validate_round_basic(p_round uuid) returns void
language plpgsql security definer set search_path = public as $$
declare rd rounds;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'validating' then return; end if;
  update answers set
    status = _basic_check(value, rd.letter),
    reason = case _basic_check(value, rd.letter)
      when 'empty' then 'Sin respuesta.'
      when 'invalid' then 'No empieza con la letra ' || rd.letter || ' o no es una palabra.'
      else 'Validación básica: empieza con ' || rd.letter || '. (Árbitro IA no disponible)' end,
    checks = jsonb_build_object('letter', _basic_check(value, rd.letter) <> 'invalid' and btrim(value) <> '',
                                'category', null, 'real_word', null, 'spelling', null)
  where round_id = p_round and status = 'pending';
  perform _finish_validation(p_round, false);
end $$;

-- Llamada por la Edge Function (service_role) tras escribir los veredictos de la IA.
create or replace function public._finish_validation(p_round uuid, p_ai boolean) returns void
language plpgsql security definer set search_path = public as $$
declare rd rounds; r rooms; u record;
begin
  select * into rd from rounds where id = p_round for update;
  if rd.status <> 'validating' then return; end if;
  perform _score_round(p_round);
  update rounds set status = 'results', validated_by_ai = p_ai, next_at = now() + interval '20 seconds' where id = p_round;
end $$;
revoke execute on function public._finish_validation(uuid, boolean) from public, anon, authenticated;
grant execute on function public._finish_validation(uuid, boolean) to service_role;

create or replace function public.mark_validation_attempt(p_round uuid) returns int
language sql security definer set search_path = public as $$
  update rounds set validation_attempts = validation_attempts + 1
  where id = p_round and status = 'validating' and public.is_member(room_id)
  returning validation_attempts;
$$;

-- Avanza a la siguiente ronda o termina la partida. Idempotente.
create or replace function public.advance_room(p_room uuid, p_force boolean default false) returns text
language plpgsql security definer set search_path = public as $$
declare r rooms; rd rounds;
begin
  select * into r from rooms where id = p_room for update;
  if r is null or not is_member(p_room) then raise exception 'Sala no válida'; end if;
  if r.status <> 'playing' then return r.status; end if;
  select * into rd from rounds where room_id = p_room and number = r.current_round;
  if rd.status <> 'results' then return 'not_ready'; end if;
  if now() < rd.next_at and not (p_force and r.host_id = auth.uid()) then return 'waiting'; end if;
  if rd.number >= r.rounds_total then
    perform _finish_game(p_room);
    return 'finished';
  end if;
  perform _new_round(p_room);
  return 'next';
end $$;

create or replace function public._finish_game(p_room uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r rooms; p record; top int; xp int; nvalid int; nempty int; ntotal int; won boolean; winner text;
        has_friend boolean; thematic int;
begin
  select * into r from rooms where id = p_room;
  update rooms set status = 'finished', finished_at = now() where id = p_room;

  with ranked as (
    select user_id, rank() over (order by score desc) rk from room_players where room_id = p_room)
  update room_players rp set final_rank = ranked.rk from ranked
   where rp.room_id = p_room and rp.user_id = ranked.user_id;

  select max(score) into top from room_players where room_id = p_room and left_at is null;
  select string_agg(pr.username, ', ') into winner from room_players rp join profiles pr on pr.id = rp.user_id
   where rp.room_id = p_room and rp.final_rank = 1;

  select count(*) into thematic from unnest(r.categories) c
   where exists (select 1 from categories where kind = 'thematic' and name = c);

  for p in select * from room_players where room_id = p_room loop
    select count(*) filter (where a.status = 'valid'), count(*) filter (where a.status = 'empty'), count(*)
      into nvalid, nempty, ntotal
      from answers a join rounds rd on rd.id = a.round_id
     where rd.room_id = p_room and a.user_id = p.user_id;
    won := p.final_rank = 1 and p.left_at is null;
    xp := case when p.left_at is not null then 0 else 40 + nvalid * 2 + case when won then 50 else 0 end end;
    update room_players set xp_gained = xp where room_id = p_room and user_id = p.user_id;

    update profiles set
      games_played = games_played + 1,
      games_won = games_won + case when won then 1 else 0 end,
      win_streak = case when won then win_streak + 1 else 0 end,
      total_points = total_points + p.score,
      best_score = greatest(best_score, p.score),
      valid_answers = valid_answers + nvalid,
      current_room = null
    where id = p.user_id;
    perform _add_xp(p.user_id, xp);

    -- desafíos
    perform _progress(p.user_id, 'games', 1);
    perform _progress(p.user_id, 'valid_answers', nvalid);
    if won then perform _progress(p.user_id, 'wins', 1); end if;
    if won and r.is_public then perform _progress(p.user_id, 'public_wins', 1); end if;
    perform _progress(p.user_id, 'thematic_used', thematic);
    select exists (select 1 from room_players o where o.room_id = p_room and o.user_id <> p.user_id
                   and are_friends(o.user_id, p.user_id)) into has_friend;
    if has_friend then perform _progress(p.user_id, 'friend_games', 1); end if;

    -- logros
    if won then perform _unlock(p.user_id, 'first_win'); end if;
    if (select games_played from profiles where id = p.user_id) >= 10 then perform _unlock(p.user_id, 'ten_games'); end if;
    if (select win_streak from profiles where id = p.user_id) >= 5 then perform _unlock(p.user_id, 'five_streak'); end if;
    if (select valid_answers from profiles where id = p.user_id) >= 100 then perform _unlock(p.user_id, 'hundred_valid'); end if;
    if ntotal > 0 and nvalid = ntotal then perform _unlock(p.user_id, 'perfect_game'); end if;
    if p.score >= 300 then perform _unlock(p.user_id, 'score_300'); end if;
    if ntotal > 0 and nempty = 0 and p.left_at is null then perform _unlock(p.user_id, 'no_empty'); end if;
    if thematic > 0 then perform _unlock(p.user_id, 'thematic'); end if;
    if has_friend then perform _unlock(p.user_id, 'with_friend'); end if;
    if (select games_played from profiles where id = p.user_id) >= 50 then perform _unlock(p.user_id, 'fifty_games'); end if;

    if won then
      insert into activity (user_id, text, detail) values (p.user_id, 'ganó una partida', p.score || ' pts');
    end if;
    perform _notify(p.user_id, 'results', 'Resultados listos',
      case when won then 'Ganaste la partida ' || r.code || ' con ' || p.score || ' pts'
           else winner || ' ganó la partida ' || r.code end,
      jsonb_build_object('room_id', p_room));
  end loop;
end $$;

-- ---------- impugnaciones ----------
create or replace function public.submit_dispute(p_round uuid, p_target uuid, p_category text, p_kind text, p_justification text)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds; a answers; d uuid; left_ int;
begin
  select * into rd from rounds where id = p_round;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'results' then raise exception 'Solo puedes impugnar cuando hay resultados'; end if;
  if p_kind = 'my_valid' and p_target <> me then raise exception 'Solo puedes defender tu propia respuesta'; end if;
  select disputes_left into left_ from room_players where room_id = rd.room_id and user_id = me for update;
  if left_ <= 0 then raise exception 'Ya no te quedan impugnaciones en esta partida'; end if;
  select * into a from answers where round_id = p_round and user_id = p_target and category = p_category for update;
  if a is null then raise exception 'Respuesta no encontrada'; end if;
  if a.disputed then raise exception 'Esta respuesta ya fue impugnada'; end if;
  if char_length(btrim(p_justification)) < 5 then raise exception 'Escribe una justificación'; end if;
  update answers set disputed = true where round_id = p_round and user_id = p_target and category = p_category;
  update room_players set disputes_left = disputes_left - 1 where room_id = rd.room_id and user_id = me;
  -- dar tiempo a resolver antes de avanzar
  update rounds set next_at = greatest(next_at, now() + interval '15 seconds') where id = p_round;
  insert into disputes (round_id, user_id, target_user, category, kind, justification, old_status)
  values (p_round, me, p_target, p_category, p_kind, btrim(p_justification), a.status) returning id into d;
  return d;
end $$;

create or replace function public._apply_dispute(p_dispute uuid, p_accept boolean, p_resolution text) returns disputes
language plpgsql security definer set search_path = public as $$
declare d disputes; a answers; rd rooms; newst text; before_pts int; after_pts int; r rounds;
begin
  select * into d from disputes where id = p_dispute for update;
  if d.status <> 'pending' then return d; end if;
  select * into a from answers where round_id = d.round_id and user_id = d.target_user and category = d.category;
  select * into r from rounds where id = d.round_id;
  select coalesce(sum(points), 0) into before_pts from answers where round_id = d.round_id and user_id = d.target_user;
  newst := case when not p_accept then a.status
                when d.kind = 'my_valid' then 'valid'
                when d.kind = 'other_invalid' then 'invalid'
                else a.status end;
  update answers set status = newst, reason = coalesce(p_resolution, reason)
   where round_id = d.round_id and user_id = d.target_user and category = d.category;
  perform _score_round(d.round_id);
  select coalesce(sum(points), 0) into after_pts from answers where round_id = d.round_id and user_id = d.target_user;
  update disputes set status = case when p_accept then 'accepted' else 'rejected' end,
    resolution = p_resolution, new_status = newst, points_delta = after_pts - before_pts, resolved_at = now()
   where id = p_dispute returning * into d;
  -- si la partida ya terminó, corrige el total del perfil
  select * into rd from rooms where id = r.room_id;
  if rd.status = 'finished' then
    update profiles set total_points = total_points + (after_pts - before_pts) where id = d.target_user;
  end if;
  return d;
end $$;
revoke execute on function public._apply_dispute(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public._apply_dispute(uuid, boolean, text) to service_role;

-- Resolución sin IA (respaldo): acepta si la respuesta empieza con la letra y no está vacía.
create or replace function public.resolve_dispute_basic(p_dispute uuid) returns disputes
language plpgsql security definer set search_path = public as $$
declare d disputes; a answers; r rounds; ok boolean;
begin
  select * into d from disputes where id = p_dispute;
  if d is null or d.user_id <> _uid() then raise exception 'Impugnación no válida'; end if;
  if d.status <> 'pending' then return d; end if;
  select * into r from rounds where id = d.round_id;
  select * into a from answers where round_id = d.round_id and user_id = d.target_user and category = d.category;
  ok := case d.kind
    when 'my_valid' then _basic_check(a.value, r.letter) = 'valid'
    when 'other_invalid' then _basic_check(a.value, r.letter) <> 'valid'
    else false end;
  return _apply_dispute(p_dispute, ok,
    case when ok then 'Revisión automática: la impugnación procede.'
         else 'Revisión automática: no hay motivos suficientes para cambiar la evaluación.' end);
end $$;

-- ---------- amigos ----------
create or replace function public.send_friend_request(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid();
begin
  if p_user = me then raise exception 'No puedes agregarte a ti mismo'; end if;
  if exists (select 1 from friendships where requester = p_user and addressee = me) then
    update friendships set status = 'accepted' where requester = p_user and addressee = me;
    return;
  end if;
  insert into friendships (requester, addressee) values (me, p_user) on conflict do nothing;
  if found then
    perform _notify(p_user, 'friend_request', (select username from profiles where id = me) || ' quiere ser tu amigo',
                    'Solicitud de amistad', jsonb_build_object('user_id', me));
  end if;
end $$;

create or replace function public.respond_friend_request(p_user uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid();
begin
  if p_accept then
    update friendships set status = 'accepted' where requester = p_user and addressee = me;
    insert into activity (user_id, text) values (me, 'tiene un nuevo amigo');
  else
    delete from friendships where requester = p_user and addressee = me and status = 'pending';
  end if;
end $$;

create or replace function public.remove_friend(p_user uuid) returns void
language sql security definer set search_path = public as $$
  delete from friendships where (requester = auth.uid() and addressee = p_user) or (requester = p_user and addressee = auth.uid());
$$;

create or replace function public.my_friends() returns table (
  user_id uuid, username text, avatar text, level int, last_seen timestamptz, current_room uuid,
  playing boolean, status text, incoming boolean, games_together int)
language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.avatar, p.level, p.last_seen, p.current_room,
         exists (select 1 from rooms r where r.id = p.current_room and r.status = 'playing'),
         f.status, f.addressee = auth.uid(),
         (select count(*)::int from room_players a join room_players b on a.room_id = b.room_id
           where a.user_id = auth.uid() and b.user_id = p.id)
  from friendships f
  join profiles p on p.id = case when f.requester = auth.uid() then f.addressee else f.requester end
  where auth.uid() in (f.requester, f.addressee)
  order by p.last_seen desc
$$;

create or replace function public.search_users(p_query text) returns table (
  user_id uuid, username text, avatar text, level int, relation text)
language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.avatar, p.level,
    coalesce((select case when f.status = 'accepted' then 'friends'
                          when f.requester = auth.uid() then 'sent' else 'received' end
              from friendships f where (f.requester = auth.uid() and f.addressee = p.id)
                                    or (f.requester = p.id and f.addressee = auth.uid())), 'none')
  from profiles p
  where p.id <> auth.uid() and p.username ilike '%' || p_query || '%' and char_length(p_query) >= 2
  order by (p.username = lower(p_query)) desc, char_length(p.username), p.username
  limit 25
$$;

create or replace function public.head_to_head(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'duels_me', (select count(*) from room_players a join room_players b on a.room_id = b.room_id
                  join rooms r on r.id = a.room_id
                 where a.user_id = auth.uid() and b.user_id = p_user and r.status = 'finished' and a.final_rank < b.final_rank),
    'duels_them', (select count(*) from room_players a join room_players b on a.room_id = b.room_id
                  join rooms r on r.id = a.room_id
                 where a.user_id = auth.uid() and b.user_id = p_user and r.status = 'finished' and a.final_rank > b.final_rank))
$$;

-- ---------- rankings ----------
create or replace function public.leaderboard(p_scope text, p_period text) returns table (
  rank bigint, user_id uuid, username text, avatar text, level int, points bigint, is_me boolean)
language sql stable security definer set search_path = public as $$
  with since as (
    select case p_period
      when 'week' then date_trunc('week', now())
      when 'month' then date_trunc('month', now())
      else coalesce((select starts_at from seasons where now() between starts_at and ends_at limit 1), date_trunc('quarter', now()))
    end as t),
  pts as (
    select rp.user_id, sum(rp.score)::bigint pts
    from room_players rp join rooms r on r.id = rp.room_id, since
    where r.ranked and r.status = 'finished' and r.finished_at >= since.t and rp.left_at is null
    group by rp.user_id),
  pool as (
    select p.id, p.username, p.avatar, p.level, coalesce(pts.pts, 0) pts
    from profiles p left join pts on pts.user_id = p.id
    where (p_scope = 'global' and pts.pts is not null)
       or p.id = auth.uid()
       or (p_scope = 'friends' and public.are_friends(auth.uid(), p.id))),
  ranked as (select rank() over (order by pts desc, username) rk, * from pool)
  select rk, id, username, avatar, level, pts, id = auth.uid() from ranked
  where rk <= 100 or id = auth.uid()
  order by rk
$$;

-- ---------- historial ----------
create or replace function public.my_history(p_filter text default 'all') returns table (
  room_id uuid, code text, name text, is_public boolean, finished_at timestamptz,
  players int, rounds int, score int, final_rank int, xp_gained int)
language sql stable security definer set search_path = public as $$
  select r.id, r.code, r.name, r.is_public, r.finished_at,
    (select count(*)::int from room_players x where x.room_id = r.id), r.rounds_total, rp.score, rp.final_rank, rp.xp_gained
  from room_players rp join rooms r on r.id = rp.room_id
  where rp.user_id = auth.uid() and r.status = 'finished'
    and (p_filter = 'all' or (p_filter = 'public' and r.is_public) or (p_filter = 'private' and not r.is_public))
  order by r.finished_at desc
  limit 200
$$;

-- ---------- compras (cliente StoreKit; validar recibos en servidor en producción) ----------
create or replace function public.grant_item(p_item text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_item = 'plus' then update profiles set is_plus = true where id = _uid();
  else insert into user_items (user_id, item_id) values (_uid(), p_item) on conflict do nothing; end if;
end $$;

-- Permisos de ejecución
revoke execute on all functions in schema public from anon;
revoke execute on function public._notify, public._system_msg, public._add_xp, public._unlock, public._progress,
  public._join, public._new_round, public._score_round, public._finish_game from public, authenticated;
