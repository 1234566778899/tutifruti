-- STOP disponible al completar el 75% de las categorías (redondeado hacia arriba), no todas:
-- a veces no hay palabra posible con la letra y hay que poder cerrar la ronda.
create or replace function public.stop_threshold(p_count int) returns int
language sql immutable as $$ select greatest(1, ceil(p_count * 0.75)::int) $$;

create or replace function public.call_stop(p_round uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds; r rooms; filled int; needed int;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'playing' or now() > rd.close_at then raise exception 'La ronda ya cerró'; end if;
  if rd.stop_by is not null then return; end if;
  select * into r from rooms where id = rd.room_id;
  select count(*) into filled from answers where round_id = p_round and user_id = me and btrim(value) <> '';
  needed := stop_threshold(array_length(r.categories, 1));
  if filled < needed then
    raise exception 'Completa al menos % de % categorías para decir STOP', needed, array_length(r.categories, 1);
  end if;
  update rounds set stop_by = me, stop_at = now(),
         close_at = least(close_at, now() + make_interval(secs => r.stop_seconds))
   where id = p_round;
end $$;
