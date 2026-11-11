-- Compras validadas en el servidor (Edge Function app-store). La app ya no puede darse Plus ni artículos:
-- grant_item queda solo para el service role.
-- APLICAR DESPUÉS de desplegar app-store y publicar la versión de la app que usa API.verifyPurchase.

create table if not exists public.purchases (
  transaction_id text primary key,
  original_transaction_id text not null,
  user_id uuid not null references public.profiles on delete cascade,
  product_id text not null,
  environment text not null,
  purchased_at timestamptz not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists purchases_user_idx on public.purchases (user_id);
create index if not exists purchases_original_idx on public.purchases (original_transaction_id);
alter table public.purchases enable row level security;
drop policy if exists "mis compras" on public.purchases;
create policy "mis compras" on public.purchases for select to authenticated using (user_id = auth.uid());

alter table public.profiles add column if not exists plus_until timestamptz;

-- Recalcula Plus y artículos de un jugador a partir de sus compras.
create or replace function public._apply_purchases(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare until timestamptz;
begin
  select max(coalesce(expires_at, 'infinity'::timestamptz)) into until from purchases
   where user_id = p_user and revoked_at is null
     and product_id in ('com.carlosordaz.tutifruti.plus.monthly', 'com.carlosordaz.tutifruti.plus.yearly');
  update profiles set plus_until = until, is_plus = coalesce(until > now(), false) where id = p_user;
  insert into user_items (user_id, item_id)
  select distinct p_user, product_id from purchases
   where user_id = p_user and revoked_at is null and product_id not like 'com.carlosordaz.tutifruti.plus.%'
  on conflict do nothing;
  delete from user_items ui where ui.user_id = p_user
     and exists (select 1 from purchases pu where pu.user_id = p_user and pu.product_id = ui.item_id and pu.revoked_at is not null)
     and not exists (select 1 from purchases pu where pu.user_id = p_user and pu.product_id = ui.item_id and pu.revoked_at is null);
end $$;
revoke execute on function public._apply_purchases(uuid) from public, anon, authenticated;
grant execute on function public._apply_purchases(uuid) to service_role;

revoke execute on function public.grant_item(text) from public, anon, authenticated;
grant execute on function public.grant_item(text) to service_role;

-- Plus vencido: se apaga cada hora (por si Apple no avisa el vencimiento).
create or replace function public.expire_plus() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update profiles set is_plus = false where is_plus and plus_until is not null and plus_until < now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.expire_plus() from public, anon, authenticated;
select cron.unschedule(jobid) from cron.job where jobname = 'tutifruti-expire-plus';
select cron.schedule('tutifruti-expire-plus', '7 * * * *', 'select public.expire_plus()');
