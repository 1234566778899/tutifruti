-- Notificaciones push (APNs).
-- · La app registra su device token con register_push_token.
-- · Cada fila nueva en notifications (que ya respeta notif_prefs en _notify) dispara, vía pg_net, la Edge Function
--   send-push, que la envía a APNs. El trigger no hace nada mientras no exista el secreto del webhook en Vault:
--     select vault.create_secret('<cadena aleatoria>', 'push_webhook_secret');
--   (el mismo valor va como PUSH_WEBHOOK_SECRET en los secretos de las Edge Functions).

create extension if not exists pg_net with schema extensions;

create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles on delete cascade,
  platform text not null default 'ios' check (platform in ('ios')),
  sandbox boolean not null default false,
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
-- sin políticas: solo las RPC y el service role tocan la tabla

create or replace function public.register_push_token(p_token text, p_sandbox boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid();
begin
  if p_token !~ '^[0-9a-fA-F]{32,200}$' then raise exception 'Token no válido'; end if;
  insert into push_tokens (token, user_id, sandbox, updated_at) values (lower(p_token), me, p_sandbox, now())
  on conflict (token) do update set user_id = me, sandbox = p_sandbox, updated_at = now();
end $$;

create or replace function public.unregister_push_token(p_token text) returns void
language sql security definer set search_path = public as $$
  delete from push_tokens where token = lower(p_token) and user_id = auth.uid();
$$;

revoke execute on function public.register_push_token(text, boolean), public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text, boolean), public.unregister_push_token(text) to authenticated;

create or replace function public._push_notification() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare secret text;
begin
  if not exists (select 1 from push_tokens where user_id = new.user_id) then return new; end if;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_webhook_secret' limit 1;
  if secret is null then return new; end if;
  perform net.http_post(
    url := 'https://liejnmzxlpctqybecrbu.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', secret),
    body := jsonb_build_object('id', new.id, 'user_id', new.user_id, 'kind', new.kind, 'title', new.title,
                               'body', new.body, 'payload', new.payload),
    timeout_milliseconds := 5000);
  return new;
exception when others then
  return new;  -- un fallo de push nunca debe romper el juego
end $$;
revoke execute on function public._push_notification() from public, anon, authenticated;

drop trigger if exists push_notification on public.notifications;
create trigger push_notification after insert on public.notifications
  for each row execute function public._push_notification();
