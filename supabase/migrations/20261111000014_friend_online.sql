-- "Amigo conectado": cuando alguien vuelve después de 15 min o más sin latido, avisa a sus amigos que estén
-- conectados en ese momento (preferencia friends_online). Máximo un aviso por amigo cada 2 horas.
-- Las temporadas ya no se usan en la app: se quita esa preferencia y el logro season_top100.

create or replace function public.heartbeat(p_room uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); prev timestamptz; myname text; f uuid;
begin
  select last_seen, username into prev, myname from profiles where id = me;
  update profiles set last_seen = now(), current_room = p_room where id = me;
  if p_room is not null then
    update room_players set last_seen = now() where room_id = p_room and user_id = me;
  end if;

  if prev is not null and prev < now() - interval '15 minutes' then
    for f in
      select case when fr.requester = me then fr.addressee else fr.requester end
        from friendships fr
       where fr.status = 'accepted' and me in (fr.requester, fr.addressee)
    loop
      continue when not exists (select 1 from profiles where id = f and last_seen > now() - interval '2 minutes');
      continue when exists (select 1 from notifications n where n.user_id = f and n.kind = 'friend_online'
                              and n.payload ->> 'user_id' = me::text and n.created_at > now() - interval '2 hours');
      perform _notify(f, 'friend_online', myname || ' está conectado', '¿Le propones una partida?',
                      jsonb_build_object('user_id', me));
    end loop;
  end if;
end $$;

-- Temporadas: sin uso en la app minimalista.
delete from public.user_achievements where achievement_id = 'season_top100';
delete from public.achievements where id = 'season_top100';
update public.profiles set notif_prefs = notif_prefs - 'seasons' where notif_prefs ? 'seasons';
alter table public.profiles alter column notif_prefs
  set default '{"invites":true,"friend_requests":true,"friends_online":true,"results":true,"achievements":true}';
