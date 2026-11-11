-- Idioma de juego: cada sala juega en el idioma del anfitrión (profiles.language: es | en | pt).
-- · Las letras dependen del idioma (la Ñ solo en español).
-- · El árbitro IA (validate-round) valida las respuestas en ese idioma.
-- · Logro "Políglota": terminar partidas en dos idiomas distintos.

update public.profiles set language = 'es' where language not in ('es', 'en', 'pt');
alter table public.profiles drop constraint if exists profiles_language_check;
alter table public.profiles add constraint profiles_language_check check (language in ('es', 'en', 'pt'));

alter table public.rooms add column if not exists language text not null default 'es';
alter table public.rooms drop constraint if exists rooms_language_check;
alter table public.rooms add constraint rooms_language_check check (language in ('es', 'en', 'pt'));

create or replace function public._room_language() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.host_id is not null then
    new.language := coalesce((select language from profiles where id = new.host_id), 'es');
  end if;
  return new;
end $$;
drop trigger if exists room_language on public.rooms;
create trigger room_language before insert on public.rooms for each row execute function public._room_language();

create or replace function public._new_round(p_room uuid) returns rounds
language plpgsql security definer set search_path = public as $$
declare r rooms; letters text[]; l text; rd rounds;
begin
  select * into r from rooms where id = p_room for update;
  letters := array['A','B','C','D','E','F','G','H','I','J','K','L','M','N','Ñ','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
  if r.language <> 'es' then letters := array_remove(letters, 'Ñ'); end if;
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
revoke execute on function public._new_round(uuid) from public, anon, authenticated;

-- Políglota: al terminar una partida, quien la jugó completa en 2 idiomas distintos lo desbloquea.
create or replace function public._polyglot_check() returns trigger
language plpgsql security definer set search_path = public as $$
declare p uuid;
begin
  for p in select user_id from room_players where room_id = new.id and left_at is null loop
    if (select count(distinct ro.language) from room_players rp join rooms ro on ro.id = rp.room_id
         where rp.user_id = p and rp.left_at is null and ro.status = 'finished') >= 2 then
      perform _unlock(p, 'polyglot');
    end if;
  end loop;
  return new;
end $$;
drop trigger if exists polyglot_check on public.rooms;
create trigger polyglot_check after update of status on public.rooms
  for each row when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function public._polyglot_check();

update public.achievements set description = 'Termina partidas en dos idiomas distintos' where id = 'polyglot';

-- La lista de salas públicas muestra el idioma.
drop function if exists public.list_public_rooms();
create or replace function public.list_public_rooms() returns table (
  room_id uuid, code text, name text, host_id uuid, host_name text, host_avatar text, host_level int,
  players int, max_players int, rounds_total int, round_seconds int, categories text[], exclude_hard boolean,
  created_at timestamptz, is_member boolean, language text)
language sql stable security definer set search_path = public as $$
  select r.id, r.code, r.name, r.host_id, h.username, h.avatar, h.level,
         (select count(*)::int from room_players rp where rp.room_id = r.id and rp.left_at is null),
         r.max_players, r.rounds_total, r.round_seconds, r.categories, r.exclude_hard, r.created_at,
         exists (select 1 from room_players rp where rp.room_id = r.id and rp.user_id = auth.uid()),
         r.language
  from rooms r
  join profiles h on h.id = r.host_id
  where r.is_public and r.status = 'waiting' and r.host_id is not null
    and r.created_at > now() - interval '3 hours'
    and exists (select 1 from room_players rp where rp.room_id = r.id and rp.user_id = r.host_id
                and rp.left_at is null and rp.last_seen > now() - interval '2 minutes')
    and (select count(*) from room_players rp where rp.room_id = r.id and rp.left_at is null) < r.max_players
  order by r.created_at desc
  limit 50;
$$;
revoke execute on function public.list_public_rooms() from public, anon;
grant execute on function public.list_public_rooms() to authenticated;
