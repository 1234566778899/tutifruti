-- Tareas programadas (pg_cron):
--  * cleanup_rooms(): cancela salas abandonadas ('waiting' o 'playing' sin nadie conectado hace > 30 min).
--  * cleanup_guests(): borra invitados sin actividad hace > 7 días (definida en 20261109000008_guests.sql).

create extension if not exists pg_cron;

create or replace function public.cleanup_rooms() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update rooms r set status = 'cancelled', finished_at = now()
   where r.status in ('waiting', 'playing')
     and r.created_at < now() - interval '30 minutes'
     and not exists (
       select 1 from room_players p
        where p.room_id = r.id and p.left_at is null
          and coalesce(p.last_seen, p.joined_at) > now() - interval '30 minutes');
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.cleanup_rooms() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname in ('tutifruti-cleanup-rooms', 'tutifruti-cleanup-guests');
select cron.schedule('tutifruti-cleanup-rooms', '*/15 * * * *', 'select public.cleanup_rooms()');
select cron.schedule('tutifruti-cleanup-guests', '30 4 * * *', 'select public.cleanup_guests()');
