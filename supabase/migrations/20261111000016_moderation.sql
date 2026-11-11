-- Moderación:
-- · Los silencios se aplican en el servidor: no recibes mensajes de chat de quien silenciaste (RLS + realtime).
-- · Panel de moderación (web /moderacion) para administradores (profiles.is_admin, se asigna a mano por SQL):
--   lista reportes, los descarta o suspende al jugador por N días o para siempre.
-- · Un jugador suspendido no puede crear salas, unirse ni escribir en el chat.

alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists banned_until timestamptz;

alter table public.reports add column if not exists status text not null default 'open';
alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add constraint reports_status_check check (status in ('open', 'dismissed', 'actioned'));
alter table public.reports add column if not exists resolved_by uuid references public.profiles on delete set null;
alter table public.reports add column if not exists resolved_at timestamptz;
alter table public.reports add column if not exists resolution text;
create index if not exists reports_status_idx on public.reports (status, created_at desc);

create or replace function public._is_banned(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select banned_until > now() from profiles where id = p_user), false);
$$;

create or replace function public._is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;

-- Bloqueos para suspendidos (triggers: cubren create_room, rematch, unirse por código o sala pública).
create or replace function public._block_banned() returns trigger
language plpgsql security definer set search_path = public as $$
declare u uuid := (to_jsonb(new) ->> case tg_table_name when 'rooms' then 'host_id' else 'user_id' end)::uuid;
begin
  if u is not null and _is_banned(u) then
    raise exception 'Tu cuenta está suspendida hasta el %',
      to_char((select banned_until from profiles where id = u) at time zone 'America/Mexico_City', 'DD/MM/YYYY');
  end if;
  return new;
end $$;
drop trigger if exists block_banned on public.rooms;
create trigger block_banned before insert on public.rooms for each row execute function public._block_banned();
drop trigger if exists block_banned on public.room_players;
create trigger block_banned before insert on public.room_players for each row execute function public._block_banned();

-- Chat: los silenciados no te llegan; los suspendidos no escriben.
drop policy if exists "ver chat" on public.chat_messages;
create policy "ver chat" on public.chat_messages for select to authenticated using (
  public.is_member(room_id)
  and not exists (select 1 from mutes m where m.user_id = auth.uid() and m.muted_id = chat_messages.user_id));
drop policy if exists "escribir chat" on public.chat_messages;
create policy "escribir chat" on public.chat_messages for insert to authenticated with check (
  user_id = auth.uid() and kind = 'msg' and public.is_member(room_id) and not public._is_banned(auth.uid()));

-- ---------- Panel de administración ----------
create or replace function public.admin_reports(p_status text default 'open') returns table (
  id uuid, created_at timestamptz, reason text, details text, status text, resolution text,
  room_id uuid, room_code text,
  reporter uuid, reporter_name text,
  reported uuid, reported_name text, reported_avatar text, reported_banned_until timestamptz,
  reports_against int, recent_messages jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not _is_admin() then raise exception 'Solo administradores'; end if;
  return query
  select r.id, r.created_at, r.reason, r.details, r.status, r.resolution,
         r.room_id, ro.code,
         r.reporter, pr.username,
         r.reported, pd.username, pd.avatar, pd.banned_until,
         (select count(*)::int from reports x where x.reported = r.reported),
         coalesce((select jsonb_agg(jsonb_build_object('body', c.body, 'at', c.created_at) order by c.created_at desc)
                     from (select body, created_at from chat_messages c
                            where c.user_id = r.reported and c.kind = 'msg'
                              and (r.room_id is null or c.room_id = r.room_id)
                            order by created_at desc limit 10) c), '[]'::jsonb)
    from reports r
    join profiles pd on pd.id = r.reported
    left join profiles pr on pr.id = r.reporter
    left join rooms ro on ro.id = r.room_id
   where p_status = 'all' or r.status = p_status
   order by r.created_at desc
   limit 200;
end $$;

-- p_action: 'dismiss' | 'ban'. p_days: días de suspensión (null = para siempre). 'ban' borra sus mensajes de chat
-- en la sala reportada.
create or replace function public.admin_resolve_report(p_report uuid, p_action text, p_days int default 7) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); r reports; until timestamptz;
begin
  if not _is_admin() then raise exception 'Solo administradores'; end if;
  select * into r from reports where id = p_report for update;
  if r is null then raise exception 'El reporte no existe'; end if;
  if p_action = 'dismiss' then
    update reports set status = 'dismissed', resolved_by = me, resolved_at = now(), resolution = 'Descartado'
     where id = p_report;
  elsif p_action = 'ban' then
    until := case when p_days is null then 'infinity'::timestamptz else now() + make_interval(days => p_days) end;
    update profiles set banned_until = until where id = r.reported;
    if r.room_id is not null then delete from chat_messages where room_id = r.room_id and user_id = r.reported; end if;
    -- todos los reportes abiertos contra ese jugador quedan resueltos
    update reports set status = 'actioned', resolved_by = me, resolved_at = now(),
           resolution = case when p_days is null then 'Suspendido para siempre' else 'Suspendido ' || p_days || ' días' end
     where reported = r.reported and status = 'open';
  else
    raise exception 'Acción no válida';
  end if;
end $$;

create or replace function public.admin_unban(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not _is_admin() then raise exception 'Solo administradores'; end if;
  update profiles set banned_until = null where id = p_user;
end $$;

revoke execute on function public._is_banned(uuid), public._block_banned() from public, anon, authenticated;
grant execute on function public._is_banned(uuid) to authenticated;  -- lo usa la política del chat
revoke execute on function public.admin_reports(text), public.admin_resolve_report(uuid, text, int),
  public.admin_unban(uuid), public._is_admin() from public, anon;
grant execute on function public.admin_reports(text), public.admin_resolve_report(uuid, text, int),
  public.admin_unban(uuid), public._is_admin() to authenticated;
