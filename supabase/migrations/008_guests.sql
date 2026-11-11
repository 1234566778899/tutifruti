-- Invitados (usuarios anónimos): solo juegan. No tienen amigos ni aparecen en búsquedas.
-- Al pasar a cuenta real (vincular Apple/correo) deja de ser anónimo y todo esto se habilita.

create or replace function public._is_guest(p_user uuid) returns boolean
language sql stable security definer set search_path = public, auth as $$
  select coalesce((select is_anonymous from auth.users where id = p_user), false);
$$;
revoke execute on function public._is_guest(uuid) from public, anon, authenticated;

create or replace function public.send_friend_request(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid();
begin
  if _is_guest(me) then raise exception 'Crea una cuenta para agregar amigos'; end if;
  if _is_guest(p_user) then raise exception 'Ese jugador es invitado y no puede tener amigos'; end if;
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
    and not _is_guest(p.id)
  order by (p.username = lower(p_query)) desc, char_length(p.username), p.username
  limit 25
$$;

-- Limpieza: borra invitados sin actividad hace más de 7 días (sus perfiles caen en cascada).
create or replace function public.cleanup_guests() returns int
language plpgsql security definer set search_path = public, auth as $$
declare n int;
begin
  delete from auth.users u
   where u.is_anonymous
     and coalesce((select last_seen from profiles where id = u.id), u.created_at) < now() - interval '7 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.cleanup_guests() from public, anon, authenticated;
