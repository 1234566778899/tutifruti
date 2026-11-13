-- Fin de ronda sin errores falsos (2026-11-12).
-- Al vencer el tiempo, todos los clientes mandan sus últimas respuestas y cierran la ronda casi a la vez. El primer
-- close_round ponía la ronda en 'validating' y los save_answer de los demás (autoguardado de 600 ms, vaciado al
-- cerrar, al pasar a segundo plano o al reconectar) fallaban con "La ronda ya cerró", que la app mostraba como alerta
-- ("Algo salió mal" / "Ups") justo al pasar a la revisión. Lo mismo con un STOP en el último instante.
--  * save_answer / call_stop: una respuesta o un STOP tardíos se ignoran en silencio (la ronda ya cerró; no es un
--    error del jugador). Siguen fallando la ronda o la categoría inválidas.
--  * close_round: 1 s de gracia tras close_at para que lleguen los guardados de todos antes de que nadie cierre;
--    save_answer acepta hasta close_at + 2 s mientras la ronda siga en 'playing'.

create or replace function public.save_answer(p_round uuid, p_category text, p_value text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds;
begin
  select * into rd from rounds where id = p_round;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  -- Tardía: otro jugador ya cerró la ronda o pasó la gracia. No es un error: se ignora.
  if rd.status <> 'playing' or now() > rd.close_at + interval '2 seconds' then return; end if;
  if now() < rd.starts_at then raise exception 'La ronda aún no empieza'; end if;
  if not exists (select 1 from rooms where id = rd.room_id and p_category = any (categories)) then raise exception 'Categoría no válida'; end if;
  insert into answers (round_id, user_id, category, value, updated_at)
  values (p_round, me, p_category, left(btrim(p_value), 40), now())
  on conflict (round_id, user_id, category) do update set value = excluded.value, updated_at = now();
end $$;

create or replace function public.call_stop(p_round uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); rd rounds; r rooms; filled int; needed int;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  -- STOP tardío (la ronda ya cerró o se está cerrando): no hace nada.
  if rd.status <> 'playing' or now() > rd.close_at then return; end if;
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

-- Cierra la ronda cuando venció el tiempo (+ 1 s de gracia). Cualquier jugador puede llamarla (idempotente).
create or replace function public.close_round(p_round uuid) returns text
language plpgsql security definer set search_path = public as $$
declare rd rounds; r rooms;
begin
  select * into rd from rounds where id = p_round for update;
  if rd is null or not is_member(rd.room_id) then raise exception 'Ronda no válida'; end if;
  if rd.status <> 'playing' then return rd.status; end if;
  if now() < rd.close_at + interval '1 second' then return 'playing'; end if;
  select * into r from rooms where id = rd.room_id;
  -- completa respuestas vacías
  insert into answers (round_id, user_id, category, value)
  select p_round, rp.user_id, c, '' from room_players rp cross join unnest(r.categories) c
  where rp.room_id = rd.room_id and rp.left_at is null
  on conflict do nothing;
  update rounds set status = 'validating', validation_started_at = now() where id = p_round;
  return 'validating';
end $$;
