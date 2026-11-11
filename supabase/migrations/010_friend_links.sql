-- Enlaces de amistad: https://tutifruti-ai.vercel.app/a/<token>
-- Quien abre el enlace queda como amigo del dueño del enlace automáticamente.
-- Validaciones: sesión iniciada, ninguno es invitado, token existente/no revocado/no vencido, no es uno mismo,
-- ya eran amigos (no duplica), solicitud pendiente en cualquier sentido (se acepta), límite de usos y de amigos,
-- y protección contra abuso (máx. 20 aceptaciones por hora por usuario).

create table if not exists public.friend_invites (
  token text primary key,
  user_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  revoked boolean not null default false,
  uses int not null default 0,
  max_uses int not null default 200
);
create index if not exists friend_invites_user_idx on public.friend_invites (user_id);
alter table public.friend_invites enable row level security;
-- Sin políticas: solo se accede por las funciones SECURITY DEFINER.

create table if not exists public.friend_invite_uses (
  token text not null references public.friend_invites on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  used_at timestamptz not null default now(),
  primary key (token, user_id)
);
alter table public.friend_invite_uses enable row level security;

create or replace function public._friend_token() returns text language plpgsql as $$
declare chars text := 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'; t text; i int;
begin
  loop
    t := '';
    for i in 1..12 loop t := t || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from friend_invites where token = t);
  end loop;
  return t;
end $$;

-- Devuelve mi enlace vigente (lo crea si no hay uno). p_renew = true revoca el anterior y crea uno nuevo.
create or replace function public.my_friend_invite(p_renew boolean default false) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); t text;
begin
  if _is_guest(me) then raise exception 'Crea una cuenta para invitar amigos'; end if;
  if not exists (select 1 from profiles where id = me) then raise exception 'Completa tu perfil primero'; end if;
  if p_renew then
    update friend_invites set revoked = true where user_id = me and not revoked;
  end if;
  select token into t from friend_invites
   where user_id = me and not revoked and expires_at > now() + interval '1 day' and uses < max_uses
   order by created_at desc limit 1;
  if t is null then
    t := _friend_token();
    insert into friend_invites (token, user_id) values (t, me);
  end if;
  return t;
end $$;

-- Vista previa de un enlace (para mostrar quién invita antes o después de aceptar).
create or replace function public.friend_invite_info(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare inv friend_invites; p profiles;
begin
  select * into inv from friend_invites where token = btrim(p_token);
  if inv is null or inv.revoked or inv.expires_at < now() then return jsonb_build_object('valid', false); end if;
  select * into p from profiles where id = inv.user_id;
  return jsonb_build_object('valid', true, 'user_id', p.id, 'username', p.username, 'avatar', p.avatar, 'level', p.level);
end $$;

-- Acepta un enlace: crea la amistad (o acepta la solicitud pendiente) y avisa al dueño.
-- Devuelve {status: 'added' | 'already' | 'accepted_request', user_id, username, avatar, level}.
create or replace function public.accept_friend_invite(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); inv friend_invites; p profiles; st text; recent int; myname text;
begin
  if _is_guest(me) then raise exception 'Crea una cuenta para agregar amigos'; end if;
  if not exists (select 1 from profiles where id = me) then raise exception 'Completa tu perfil primero'; end if;
  if p_token is null or btrim(p_token) !~ '^[A-Za-z0-9]{8,32}$' then raise exception 'El enlace de amistad no es válido'; end if;

  select * into inv from friend_invites where token = btrim(p_token) for update;
  if inv is null then raise exception 'El enlace de amistad no es válido'; end if;
  if inv.revoked then raise exception 'Este enlace de amistad ya no está activo'; end if;
  if inv.expires_at < now() then raise exception 'Este enlace de amistad venció. Pide uno nuevo'; end if;
  if inv.user_id = me then raise exception 'Este es tu propio enlace: compártelo con tus amigos'; end if;
  if _is_guest(inv.user_id) then raise exception 'Ese jugador ya no tiene cuenta'; end if;

  select * into p from profiles where id = inv.user_id;
  if p is null then raise exception 'Ese jugador ya no existe'; end if;

  if exists (select 1 from friendships where status = 'accepted'
             and ((requester = me and addressee = p.id) or (requester = p.id and addressee = me))) then
    st := 'already';
  else
    if inv.uses >= inv.max_uses then raise exception 'Este enlace alcanzó su límite de usos'; end if;
    select count(*) into recent from friend_invite_uses where user_id = me and used_at > now() - interval '1 hour';
    if recent >= 20 then raise exception 'Demasiados intentos. Prueba más tarde'; end if;
    if (select count(*) from friendships where status = 'accepted' and me in (requester, addressee)) >= 500 then
      raise exception 'Llegaste al máximo de amigos';
    end if;

    if exists (select 1 from friendships where requester = p.id and addressee = me) then
      update friendships set status = 'accepted' where requester = p.id and addressee = me;
      st := 'accepted_request';
    elsif exists (select 1 from friendships where requester = me and addressee = p.id) then
      update friendships set status = 'accepted' where requester = me and addressee = p.id;
      st := 'accepted_request';
    else
      insert into friendships (requester, addressee, status) values (p.id, me, 'accepted');
      st := 'added';
    end if;

    insert into friend_invite_uses (token, user_id) values (inv.token, me) on conflict do nothing;
    update friend_invites set uses = uses + 1 where token = inv.token;
    select username into myname from profiles where id = me;
    perform _notify(p.id, 'friend_request', myname || ' ahora es tu amigo', 'Se unió con tu enlace de amistad',
                    jsonb_build_object('user_id', me));
    insert into activity (user_id, text) values (me, 'tiene un nuevo amigo');
  end if;

  return jsonb_build_object('status', st, 'user_id', p.id, 'username', p.username, 'avatar', p.avatar, 'level', p.level);
end $$;

revoke execute on function public._friend_token() from public, anon, authenticated;
revoke execute on function public.my_friend_invite(boolean) from public, anon;
revoke execute on function public.friend_invite_info(text) from public, anon;
revoke execute on function public.accept_friend_invite(text) from public, anon;
grant execute on function public.my_friend_invite(boolean) to authenticated;
grant execute on function public.friend_invite_info(text) to authenticated;
grant execute on function public.accept_friend_invite(text) to authenticated;
