-- Salas públicas y privadas (reemplaza la "partida rápida"/matchmaking automático).
-- · Privada: solo con código o invitación (como antes).
-- · Pública: aparece en la lista de salas públicas; cualquiera puede unirse mientras está en espera.
-- Ambas las inicia el anfitrión cuando hay al menos 2 jugadores listos. Las públicas cuentan para rankings.

-- Crear sala con tipo ------------------------------------------------------------------------------
drop function if exists public.create_room(text, int, int, int, int, boolean, text[], boolean);
create or replace function public.create_room(
  p_name text, p_max_players int, p_rounds int, p_round_seconds int, p_stop_seconds int,
  p_exclude_hard boolean, p_categories text[], p_allow_custom boolean, p_is_public boolean default false) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; plus boolean;
begin
  select is_plus into plus from profiles where id = me;
  if p_max_players > 8 and not plus then raise exception 'Las salas de más de 8 jugadores requieren Tutifruti Plus'; end if;
  if coalesce(array_length(p_categories, 1), 0) < 3 then raise exception 'Elige al menos 3 categorías'; end if;
  if array_length(p_categories, 1) > 12 then raise exception 'Máximo 12 categorías'; end if;
  -- una sola sala pública abierta por anfitrión: cierra las anteriores que sigan en espera
  if p_is_public then
    update rooms set status = 'cancelled' where host_id = me and is_public and status = 'waiting';
  end if;
  insert into rooms (code, name, host_id, is_public, ranked, max_players, rounds_total, round_seconds, stop_seconds,
                     exclude_hard, categories, allow_custom)
  values (_room_code(), coalesce(nullif(btrim(p_name), ''), 'Sala de Stop'), me, p_is_public, p_is_public, p_max_players,
          p_rounds, p_round_seconds, p_stop_seconds, p_exclude_hard, p_categories, p_allow_custom)
  returning * into r;
  insert into room_players (room_id, user_id, ready) values (r.id, me, true);
  return r;
end $$;

drop function if exists public.update_room(uuid, text, int, int, int, int, boolean, text[], boolean);
create or replace function public.update_room(
  p_room uuid, p_name text, p_max_players int, p_rounds int, p_round_seconds int, p_stop_seconds int,
  p_exclude_hard boolean, p_categories text[], p_allow_custom boolean, p_is_public boolean default null) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms;
begin
  update rooms set name = p_name, max_players = p_max_players, rounds_total = p_rounds, round_seconds = p_round_seconds,
    stop_seconds = p_stop_seconds, exclude_hard = p_exclude_hard, categories = p_categories, allow_custom = p_allow_custom,
    is_public = coalesce(p_is_public, is_public), ranked = coalesce(p_is_public, is_public)
  where id = p_room and host_id = me and status = 'waiting' returning * into r;
  if r is null then raise exception 'Solo el anfitrión puede editar la sala antes de empezar'; end if;
  return r;
end $$;

-- Revancha: mismo tipo de sala --------------------------------------------------------------------
create or replace function public.rematch(p_room uuid) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); o rooms; r rooms; u uuid;
begin
  select * into o from rooms where id = p_room;
  if o is null then raise exception 'La sala no existe'; end if;
  r := create_room(o.name, least(o.max_players, 12), o.rounds_total, o.round_seconds, o.stop_seconds, o.exclude_hard,
                   o.categories, o.allow_custom, o.is_public);
  for u in select user_id from room_players where room_id = p_room and user_id <> me loop
    perform _notify(u, 'room_invite', (select username from profiles where id = me) || ' quiere la revancha',
                    'Sala "' || r.name || '"', jsonb_build_object('room_id', r.id, 'code', r.code));
  end loop;
  return r;
end $$;

-- Unirse: en salas con anfitrión todos marcan "listo" a mano ------------------------------------------
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
  if r.status = 'cancelled' then raise exception 'La sala se cerró'; end if;
  if r.status <> 'waiting' then raise exception 'La partida ya empezó: espera a que termine o busca otra sala'; end if;
  select count(*) into n from room_players where room_id = p_room and left_at is null;
  if n >= r.max_players then raise exception 'La sala está llena'; end if;
  -- salas automáticas antiguas (sin anfitrión) entran listos; el resto marca "listo"
  insert into room_players (room_id, user_id, ready) values (p_room, p_user, r.host_id is null);
  perform _system_msg(p_room, (select username from profiles where id = p_user) || ' entró a la sala');
end $$;

-- Iniciar: el anfitrión inicia (pública o privada) ---------------------------------------------------
create or replace function public.start_game(p_room uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms; n int;
begin
  select * into r from rooms where id = p_room for update;
  if r is null or r.status <> 'waiting' then return; end if;  -- idempotente
  if not is_member(p_room) then raise exception 'No estás en esta sala'; end if;
  if r.host_id is null then
    -- salas automáticas antiguas: cuenta regresiva
    if r.starts_at is null or r.starts_at > now() then raise exception 'Aún no es hora de empezar'; end if;
  elsif r.host_id <> me then
    raise exception 'Solo el anfitrión puede iniciar la partida';
  end if;
  select count(*) into n from room_players where room_id = p_room and ready and left_at is null;
  if n < 2 then raise exception 'Se necesitan al menos 2 jugadores listos'; end if;
  delete from room_players where room_id = p_room and not ready;
  perform _system_msg(p_room, '¡Empieza la partida!');
  perform _new_round(p_room);
end $$;

-- Lista de salas públicas abiertas -----------------------------------------------------------------
create or replace function public.list_public_rooms() returns table (
  room_id uuid, code text, name text, host_id uuid, host_name text, host_avatar text, host_level int,
  players int, max_players int, rounds_total int, round_seconds int, categories text[], exclude_hard boolean,
  created_at timestamptz, is_member boolean)
language sql stable security definer set search_path = public as $$
  select r.id, r.code, r.name, r.host_id, h.username, h.avatar, h.level,
         (select count(*)::int from room_players rp where rp.room_id = r.id and rp.left_at is null),
         r.max_players, r.rounds_total, r.round_seconds, r.categories, r.exclude_hard, r.created_at,
         exists (select 1 from room_players rp where rp.room_id = r.id and rp.user_id = auth.uid())
  from rooms r
  join profiles h on h.id = r.host_id
  where r.is_public and r.status = 'waiting' and r.host_id is not null
    and r.created_at > now() - interval '3 hours'
    -- el anfitrión sigue conectado (si no, la sala está abandonada)
    and exists (select 1 from room_players rp where rp.room_id = r.id and rp.user_id = r.host_id
                and rp.left_at is null and rp.last_seen > now() - interval '2 minutes')
    and (select count(*) from room_players rp where rp.room_id = r.id and rp.left_at is null) < r.max_players
  order by r.created_at desc
  limit 50;
$$;

create or replace function public.join_public_room(p_room uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms;
begin
  select * into r from rooms where id = p_room;
  if r is null or not r.is_public then raise exception 'La sala no existe o es privada'; end if;
  perform _join(p_room, me);
  update profiles set current_room = p_room where id = me;
  return p_room;
end $$;

-- Si el anfitrión se va del lobby, pasa a otro jugador (ya existía para privadas; también aplica a públicas).

revoke execute on function public.create_room(text, int, int, int, int, boolean, text[], boolean, boolean) from public, anon;
revoke execute on function public.update_room(uuid, text, int, int, int, int, boolean, text[], boolean, boolean) from public, anon;
revoke execute on function public.list_public_rooms() from public, anon;
revoke execute on function public.join_public_room(uuid) from public, anon;
revoke execute on function public._join(uuid, uuid) from public, anon, authenticated;
grant execute on function public.create_room(text, int, int, int, int, boolean, text[], boolean, boolean) to authenticated;
grant execute on function public.update_room(uuid, text, int, int, int, int, boolean, text[], boolean, boolean) to authenticated;
grant execute on function public.list_public_rooms() to authenticated;
grant execute on function public.join_public_room(uuid) to authenticated;
