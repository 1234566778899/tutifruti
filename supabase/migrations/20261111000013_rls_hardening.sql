-- RLS más estricta: salas, jugadores y rondas solo los ven sus miembros (o cualquiera si la sala es pública).
-- Unirse sigue yendo por RPC (join_room_by_code / join_public_room), que son SECURITY DEFINER.
-- Los perfiles siguen siendo legibles (nombres y avatares en salas, amigos y búsqueda).

drop policy if exists "ver salas" on public.rooms;
create policy "ver salas" on public.rooms for select to authenticated
  using (is_public or public.is_member(id));

drop policy if exists "ver jugadores" on public.room_players;
create policy "ver jugadores" on public.room_players for select to authenticated
  using (user_id = auth.uid() or public.is_member(room_id)
         or exists (select 1 from rooms r where r.id = room_id and r.is_public));

drop policy if exists "ver rondas" on public.rounds;
create policy "ver rondas" on public.rounds for select to authenticated
  using (public.is_member(room_id));

-- Actividad: solo la propia y la de amigos (ya era así); logros de usuarios siguen públicos (perfil de otros).
