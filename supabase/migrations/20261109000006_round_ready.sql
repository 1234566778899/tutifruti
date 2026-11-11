-- Entre rondas ya no se avanza solo: cada jugador marca "Listo" y se pasa a la siguiente ronda
-- (o a la clasificación final) cuando todos los jugadores conectados están listos.
-- Los desconectados (sin latido en 45 s) o que abandonaron no bloquean.

alter table public.rounds add column if not exists ready_users uuid[] not null default '{}';

-- ¿Están listos todos los jugadores activos y conectados de la ronda?
create or replace function public._round_all_ready(p_round uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(bool_and(rp.user_id = any (rd.ready_users)), false)
  from rounds rd
  join room_players rp on rp.room_id = rd.room_id
  where rd.id = p_round
    and rp.left_at is null
    and (rp.last_seen > now() - interval '45 seconds' or rp.user_id = any (rd.ready_users));
$$;

create or replace function public.advance_room(p_room uuid, p_force boolean default false) returns text
language plpgsql security definer set search_path = public as $$
declare r rooms; rd rounds;
begin
  select * into r from rooms where id = p_room for update;
  if r is null or not is_member(p_room) then raise exception 'Sala no válida'; end if;
  if r.status <> 'playing' then return r.status; end if;
  select * into rd from rounds where room_id = p_room and number = r.current_round;
  if rd.status <> 'results' then return 'not_ready'; end if;
  if not _round_all_ready(rd.id) then return 'waiting'; end if;
  if exists (select 1 from disputes where round_id = rd.id and status = 'pending') then return 'waiting'; end if;
  if rd.number >= r.rounds_total then
    perform _finish_game(p_room);
    return 'finished';
  end if;
  perform _new_round(p_room);
  return 'next';
end $$;

-- Marca (o desmarca) al jugador como listo para continuar. Si ya están todos, avanza.
create or replace function public.set_round_ready(p_round uuid, p_ready boolean default true) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'results' then return rd.status; end if;
  update rounds set ready_users = case
      when p_ready then array(select distinct unnest(ready_users || me))
      else array_remove(ready_users, me) end
  where id = p_round;
  update room_players set last_seen = now() where room_id = rd.room_id and user_id = me;
  return advance_room(rd.room_id);
end $$;

grant execute on function public.set_round_ready(uuid, boolean) to authenticated;
revoke execute on function public._round_all_ready(uuid) from public, anon, authenticated;
revoke execute on function public.set_round_ready(uuid, boolean) from public, anon;
