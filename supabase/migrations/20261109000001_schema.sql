-- Tutifruti AI · Esquema base
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.norm(t text) returns text
language sql immutable as $$ select lower(extensions.unaccent(btrim(coalesce(t, '')))) $$;

-- ---------- Perfiles ----------
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._]{3,20}$'),
  avatar text not null default '🦊',
  level int not null default 1,
  xp int not null default 0,                 -- progreso dentro del nivel actual
  total_points int not null default 0,
  games_played int not null default 0,
  games_won int not null default 0,
  best_score int not null default 0,
  win_streak int not null default 0,
  valid_answers int not null default 0,
  is_plus boolean not null default false,
  theme text not null default 'clasico',
  language text not null default 'es',
  notif_prefs jsonb not null default '{"invites":true,"friend_requests":true,"friends_online":true,"results":true,"achievements":true,"seasons":true}',
  username_changed_at timestamptz,
  last_seen timestamptz not null default now(),
  current_room uuid,
  created_at timestamptz not null default now()
);

-- ---------- Categorías ----------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  kind text not null check (kind in ('default','thematic','custom')),
  theme text,
  is_premium boolean not null default false,
  owner_id uuid references auth.users on delete cascade,
  sort int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.categories (owner_id);

create table public.category_sets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users on delete cascade default auth.uid(),
  name text not null,
  categories text[] not null,
  created_at timestamptz not null default now()
);

-- ---------- Salas y partidas ----------
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  host_id uuid references auth.users on delete set null,
  is_public boolean not null default false,
  ranked boolean not null default false,
  status text not null default 'waiting' check (status in ('waiting','playing','finished','cancelled')),
  max_players int not null default 8 check (max_players between 2 and 12),
  min_players int not null default 2,
  rounds_total int not null default 5 check (rounds_total between 1 and 10),
  round_seconds int not null default 90 check (round_seconds between 30 and 300),
  stop_seconds int not null default 10 check (stop_seconds between 3 and 30),
  exclude_hard boolean not null default true,
  categories text[] not null,
  allow_custom boolean not null default true,
  current_round int not null default 0,
  used_letters text[] not null default '{}',
  starts_at timestamptz,               -- inicio automático (públicas)
  level_min int not null default 1,
  level_max int not null default 999,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index on public.rooms (is_public, status);

create table public.room_players (
  room_id uuid not null references public.rooms on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  joined_at timestamptz not null default now(),
  ready boolean not null default false,
  score int not null default 0,
  left_at timestamptz,
  last_seen timestamptz not null default now(),
  disputes_left int not null default 2,
  final_rank int,
  xp_gained int,
  primary key (room_id, user_id)
);
create index on public.room_players (user_id);

create table public.rounds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms on delete cascade,
  number int not null,
  letter text not null,
  status text not null default 'playing' check (status in ('playing','validating','results')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  close_at timestamptz not null,
  stop_by uuid references public.profiles on delete set null,
  stop_at timestamptz,
  validation_started_at timestamptz,
  validation_attempts int not null default 0,
  validated_by_ai boolean not null default false,
  next_at timestamptz,
  unique (room_id, number)
);

create table public.answers (
  round_id uuid not null references public.rounds on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  category text not null,
  value text not null default '',
  updated_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','valid','invalid','doubtful','empty')),
  reason text,
  checks jsonb,
  points int not null default 0,
  disputed boolean not null default false,
  primary key (round_id, user_id, category)
);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.rounds on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  target_user uuid not null references public.profiles on delete cascade,
  category text not null,
  kind text not null check (kind in ('my_valid','other_invalid','not_duplicate')),
  justification text not null,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  resolution text,
  old_status text,
  new_status text,
  points_delta int not null default 0,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.reactions (
  round_id uuid not null references public.rounds on delete cascade,
  user_id uuid not null references public.profiles on delete cascade default auth.uid(),
  category text not null,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (round_id, user_id, category)
);

create table public.chat_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms on delete cascade,
  user_id uuid references public.profiles on delete cascade default auth.uid(),
  body text not null check (char_length(body) between 1 and 300),
  kind text not null default 'msg' check (kind in ('msg','system')),
  created_at timestamptz not null default now()
);
create index on public.chat_messages (room_id, created_at);

-- ---------- Social ----------
create table public.friendships (
  requester uuid not null references public.profiles on delete cascade,
  addressee uuid not null references public.profiles on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  kind text not null,                 -- room_invite | friend_request | achievement | results | season | friend_online | level_up
  title text not null,
  body text,
  payload jsonb not null default '{}',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index on public.notifications (user_id, created_at desc);

create table public.activity (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  text text not null,
  detail text,
  created_at timestamptz not null default now()
);
create index on public.activity (user_id, created_at desc);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references public.profiles on delete cascade default auth.uid(),
  reported uuid not null references public.profiles on delete cascade,
  room_id uuid references public.rooms on delete set null,
  reason text not null,
  details text,
  created_at timestamptz not null default now()
);

create table public.mutes (
  user_id uuid not null references public.profiles on delete cascade default auth.uid(),
  muted_id uuid not null references public.profiles on delete cascade,
  primary key (user_id, muted_id)
);

-- ---------- Progresión ----------
create table public.achievements (
  id text primary key,
  title text not null,
  description text not null,
  icon text not null,
  sort int not null default 0
);
create table public.user_achievements (
  user_id uuid not null references public.profiles on delete cascade,
  achievement_id text not null references public.achievements,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create table public.challenges (
  id text primary key,
  period text not null check (period in ('daily','weekly')),
  title text not null,
  metric text not null,     -- wins | valid_answers | friend_games | public_wins | thematic_used | games
  goal int not null,
  xp int not null,
  sort int not null default 0
);
create table public.user_challenges (
  user_id uuid not null references public.profiles on delete cascade,
  challenge_id text not null references public.challenges,
  period_key text not null,
  progress int not null default 0,
  claimed boolean not null default false,
  primary key (user_id, challenge_id, period_key)
);

create table public.seasons (
  id int primary key,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);

create table public.user_items (
  user_id uuid not null references public.profiles on delete cascade default auth.uid(),
  item_id text not null,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- ================= RLS =================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.category_sets enable row level security;
alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.rounds enable row level security;
alter table public.answers enable row level security;
alter table public.disputes enable row level security;
alter table public.reactions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.friendships enable row level security;
alter table public.notifications enable row level security;
alter table public.activity enable row level security;
alter table public.reports enable row level security;
alter table public.mutes enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.challenges enable row level security;
alter table public.user_challenges enable row level security;
alter table public.seasons enable row level security;
alter table public.user_items enable row level security;

create or replace function public.is_member(r uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from room_players where room_id = r and user_id = auth.uid())
$$;

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from friendships where status = 'accepted'
    and ((requester = a and addressee = b) or (requester = b and addressee = a)))
$$;

create policy "perfiles visibles" on public.profiles for select to authenticated using (true);
create policy "editar mi perfil" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated, anon;
grant update (avatar, theme, language, notif_prefs) on public.profiles to authenticated;

create policy "ver categorías" on public.categories for select to authenticated using (owner_id is null or owner_id = auth.uid());
create policy "crear mis categorías" on public.categories for insert to authenticated with check (owner_id = auth.uid() and kind = 'custom');
create policy "borrar mis categorías" on public.categories for delete to authenticated using (owner_id = auth.uid());

create policy "mis conjuntos" on public.category_sets for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "ver salas" on public.rooms for select to authenticated using (true);
create policy "ver jugadores" on public.room_players for select to authenticated using (true);
create policy "ver rondas" on public.rounds for select to authenticated using (true);

create policy "ver respuestas" on public.answers for select to authenticated using (
  user_id = auth.uid()
  or exists (select 1 from rounds r where r.id = round_id and r.status = 'results' and public.is_member(r.room_id))
  or exists (select 1 from rounds r join rooms ro on ro.id = r.room_id where r.id = round_id and ro.status = 'finished' and public.is_member(r.room_id))
);

create policy "ver impugnaciones" on public.disputes for select to authenticated using (
  user_id = auth.uid() or exists (select 1 from rounds r where r.id = round_id and public.is_member(r.room_id)));

create policy "ver reacciones" on public.reactions for select to authenticated using (
  exists (select 1 from rounds r where r.id = round_id and public.is_member(r.room_id)));
create policy "reaccionar" on public.reactions for insert to authenticated with check (
  user_id = auth.uid() and exists (select 1 from rounds r where r.id = round_id and public.is_member(r.room_id)));
create policy "cambiar reacción" on public.reactions for update to authenticated using (user_id = auth.uid());
create policy "quitar reacción" on public.reactions for delete to authenticated using (user_id = auth.uid());

create policy "ver chat" on public.chat_messages for select to authenticated using (public.is_member(room_id));
create policy "escribir chat" on public.chat_messages for insert to authenticated with check (
  user_id = auth.uid() and kind = 'msg' and public.is_member(room_id));

create policy "ver amistades" on public.friendships for select to authenticated using (auth.uid() in (requester, addressee));

create policy "mis notificaciones" on public.notifications for select to authenticated using (user_id = auth.uid());
create policy "marcar notificaciones" on public.notifications for update to authenticated using (user_id = auth.uid());
create policy "borrar notificaciones" on public.notifications for delete to authenticated using (user_id = auth.uid());
revoke update on public.notifications from authenticated;
grant update (read) on public.notifications to authenticated;

create policy "ver actividad" on public.activity for select to authenticated using (
  user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

create policy "reportar" on public.reports for insert to authenticated with check (reporter = auth.uid());
create policy "mis silencios" on public.mutes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "ver logros" on public.achievements for select to authenticated using (true);
create policy "ver logros de usuarios" on public.user_achievements for select to authenticated using (true);
create policy "ver desafíos" on public.challenges for select to authenticated using (true);
create policy "mis desafíos" on public.user_challenges for select to authenticated using (user_id = auth.uid());
create policy "ver temporadas" on public.seasons for select to authenticated using (true);
create policy "mis artículos" on public.user_items for select to authenticated using (user_id = auth.uid());

-- ================= Realtime =================
alter publication supabase_realtime add table
  public.rooms, public.room_players, public.rounds, public.answers, public.chat_messages,
  public.reactions, public.notifications, public.friendships, public.disputes;
alter table public.room_players replica identity full;
alter table public.answers replica identity full;
alter table public.reactions replica identity full;
