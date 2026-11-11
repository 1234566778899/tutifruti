-- Borra los datos de prueba del 2026-11-10/11 (sala "Prueba IA" y usuarios anónimos pruebaa*/pruebab*).
-- Revisa primero lo que se va a borrar:
--   select id, name, code, status from rooms where name = 'Prueba IA';
--   select p.id, p.username from profiles p join auth.users u on u.id = p.id
--    where u.is_anonymous and (p.username like 'pruebaa%' or p.username like 'pruebab%');
begin;
delete from public.rooms where name = 'Prueba IA';
delete from auth.users u using public.profiles p
 where p.id = u.id and u.is_anonymous and (p.username like 'pruebaa%' or p.username like 'pruebab%');
commit;
