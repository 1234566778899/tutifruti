-- Todo es gratis: la app ya no tiene compras ni Tutifruti Plus.
-- · Las salas de 12 jugadores dejan de exigir Plus.
-- · Los clientes ya no pueden llamar a grant_item (nadie la usa; antes permitía darse Plus).
-- Los avatares y temas se desbloquean por nivel en el cliente. La migración 20261111000018_purchases.sql y la
-- Edge Function app-store quedan sin uso (no aplicar la 18).

create or replace function public.create_room(
  p_name text, p_max_players int, p_rounds int, p_round_seconds int, p_stop_seconds int,
  p_exclude_hard boolean, p_categories text[], p_allow_custom boolean, p_is_public boolean default false) returns rooms
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); r rooms;
begin
  if p_max_players > 12 then raise exception 'Máximo 12 jugadores por sala'; end if;
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

revoke execute on function public.grant_item(text) from public, anon, authenticated;
