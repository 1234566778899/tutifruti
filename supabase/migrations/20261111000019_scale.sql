-- Escala: ajustes para que el juego aguante muchas salas a la vez sin ponerse lento.

-- 1) Veredictos de la IA en una sola llamada -----------------------------------------------------------------
-- validate-round escribía una respuesta por petición (hasta ~64 idas y vueltas por ronda). Ahora manda todos los
-- veredictos juntos y, si no queda nada pendiente, se puntúa la ronda en la misma transacción.
create or replace function public._apply_verdicts(p_round uuid, p_verdicts jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare pending int;
begin
  update answers a set status = v.status, reason = v.reason, checks = v.checks
    from jsonb_to_recordset(p_verdicts) as v(user_id uuid, category text, status text, reason text, checks jsonb)
   where a.round_id = p_round and a.user_id = v.user_id and a.category = v.category and a.status = 'pending';
  select count(*) into pending from answers where round_id = p_round and status = 'pending';
  if pending = 0 then perform _finish_validation(p_round, true); end if;
  return pending;
end $$;
revoke execute on function public._apply_verdicts(uuid, jsonb) from public, anon, authenticated;
grant execute on function public._apply_verdicts(uuid, jsonb) to service_role;

-- 2) Reacciones e impugnaciones filtrables por sala -----------------------------------------------------------
-- Los clientes escuchaban estas tablas sin filtro: cada reacción obligaba a Realtime a comprobar el permiso de
-- todos los jugadores conectados (de todas las salas). Con room_id se suscriben solo a su sala.
alter table public.reactions add column if not exists room_id uuid references public.rooms on delete cascade;
alter table public.disputes add column if not exists room_id uuid references public.rooms on delete cascade;

create or replace function public._set_room_id() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select room_id into new.room_id from rounds where id = new.round_id;
  return new;
end $$;
revoke execute on function public._set_room_id() from public, anon, authenticated;

drop trigger if exists set_room_id on public.reactions;
create trigger set_room_id before insert on public.reactions for each row execute function public._set_room_id();
drop trigger if exists set_room_id on public.disputes;
create trigger set_room_id before insert on public.disputes for each row execute function public._set_room_id();

update public.reactions x set room_id = r.room_id from public.rounds r where r.id = x.round_id and x.room_id is null;
update public.disputes x set room_id = r.room_id from public.rounds r where r.id = x.round_id and x.room_id is null;

-- 3) Realtime: fuera las tablas que ningún cliente escucha ---------------------------------------------------
-- answers cambia con cada tecla guardada; nadie se suscribe a ella (ni a friendships).
do $$
declare t text;
begin
  foreach t in array array['answers', 'friendships'] loop
    if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end $$;

-- 4) Índices que faltaban para búsquedas frecuentes -----------------------------------------------------------
create index if not exists disputes_round_id_idx on public.disputes (round_id);
create index if not exists friendships_addressee_idx on public.friendships (addressee);
create index if not exists rooms_status_idx on public.rooms (status) where status in ('waiting', 'playing');
