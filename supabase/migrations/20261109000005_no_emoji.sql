-- Avatares y reacciones sin emojis: se guardan claves (las imágenes/símbolos viven en la app).

alter table public.profiles alter column avatar set default 'fox';

update public.profiles set avatar = case avatar
  when U&'\+01F98A' then 'fox'      when U&'\+01F989' then 'owl'     when U&'\+01F43C' then 'panda'
  when U&'\+01F438' then 'frog'     when U&'\+01F419' then 'octopus' when U&'\+01F981' then 'lion'
  when U&'\+01F428' then 'koala'    when U&'\+01F42F' then 'tiger'   when U&'\+01F435' then 'monkey'
  when U&'\+01F427' then 'penguin'  when U&'\+01F984' then 'unicorn' when U&'\+01F422' then 'turtle'
  when U&'\+01F916' then 'robot'    when U&'\+01F999' then 'llama'   when U&'\+01F63C' then 'stop_cat'
  when U&'\+01F409' then 'dragon'
  else 'fox' end
where avatar !~ '^(https?://|[a-z_]+$)';

update public.reactions set emoji = case emoji
  when U&'\+01F602' then 'haha' when U&'\+01F525' then 'fire' when U&'\+01F62E' then 'wow'
  when U&'\+01F44F' then 'clap' when U&'\+01F914' then 'hmm'  when U&'\+01F480' then 'ouch'
  else 'wow' end
where emoji !~ '^[a-z]+$';

create or replace function public.create_profile(p_username text, p_avatar text) returns profiles
language plpgsql security definer set search_path = public as $$
declare me uuid := _uid(); p profiles;
begin
  insert into profiles (id, username, avatar) values (me, lower(p_username), coalesce(nullif(p_avatar, ''), 'fox'))
  on conflict (id) do update set username = excluded.username, avatar = excluded.avatar
  returning * into p;
  return p;
end $$;
