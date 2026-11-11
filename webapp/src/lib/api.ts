import { supabase } from './supabase';
import type { AdminReport, Achievement, Answer, AppNotification, Category, ChatMessage, Dispute, FriendLinkResult, FriendRow, HistoryRow, Profile, PublicRoom, Reaction, Room, RoomPlayer, Round, SearchUser, UserAchievement } from './types';

/** Mismas RPC y tablas que la app iOS (Services/API.swift): ambas versiones juegan en las mismas salas. */

async function rpc<T>(fn: string, args?: Record<string, unknown>): Promise<T> {
	const { data, error } = await supabase.rpc(fn, args);
	if (error) throw error;
	return data as T;
}

export const myId = async () => (await supabase.auth.getSession()).data.session?.user.id ?? null;

// Perfil
export async function myProfile(): Promise<Profile | null> {
	const id = await myId();
	if (!id) return null;
	const { data, error } = await supabase.from('profiles').select().eq('id', id).limit(1);
	if (error) throw error;
	return (data?.[0] as Profile) ?? null;
}
export const usernameAvailable = (name: string) => rpc<boolean>('username_available', { p_username: name }).catch(() => false);
export const createProfile = (username: string, avatar: string) => rpc<Profile>('create_profile', { p_username: username, p_avatar: avatar });
export async function updateProfile(patch: { avatar?: string; notif_prefs?: Record<string, boolean>; theme?: string; language?: string }) {
	const id = await myId();
	const { error } = await supabase.from('profiles').update(patch).eq('id', id!);
	if (error) throw error;
}
export const updateAvatar = (avatar: string) => updateProfile({ avatar });
export const changeUsername = (name: string) => rpc<Profile>('change_username', { p_username: name });
export const heartbeat = (room: string | null) => supabase.rpc('heartbeat', { p_room: room }).then(() => undefined, () => undefined);
export const deleteAccount = () => rpc<void>('delete_my_account');

// Salas
export interface RoomSettings {
	name: string; maxPlayers: number; rounds: number; roundSeconds: number; stopSeconds: number;
	excludeHard: boolean; categories: string[]; allowCustom: boolean; isPublic: boolean;
}
export const defaultSettings = (): RoomSettings => ({
	name: 'Viernes de Stop', maxPlayers: 8, rounds: 5, roundSeconds: 90, stopSeconds: 10, excludeHard: true,
	categories: ['Nombre', 'País', 'Ciudad', 'Animal', 'Fruta', 'Color', 'Profesión', 'Marca'], allowCustom: true, isPublic: false
});
const settingsParams = (s: RoomSettings) => ({
	p_name: s.name, p_max_players: s.maxPlayers, p_rounds: s.rounds, p_round_seconds: s.roundSeconds,
	p_stop_seconds: s.stopSeconds, p_exclude_hard: s.excludeHard, p_categories: s.categories,
	p_allow_custom: s.allowCustom, p_is_public: s.isPublic
});
export const settingsFromRoom = (r: Room): RoomSettings => ({
	name: r.name, maxPlayers: r.max_players, rounds: r.rounds_total, roundSeconds: r.round_seconds,
	stopSeconds: r.stop_seconds, excludeHard: r.exclude_hard, categories: [...r.categories], allowCustom: r.allow_custom, isPublic: r.is_public
});
export const createRoom = (s: RoomSettings) => rpc<Room>('create_room', settingsParams(s));
export const updateRoom = (id: string, s: RoomSettings) => rpc<Room>('update_room', { p_room: id, ...settingsParams(s) });
export const joinByCode = (code: string) => rpc<string>('join_room_by_code', { p_code: code });
export const publicRooms = () => rpc<PublicRoom[]>('list_public_rooms');
export const joinPublicRoom = (id: string) => rpc<string>('join_public_room', { p_room: id });
export const setReady = (room: string, ready: boolean) => rpc<void>('set_ready', { p_room: room, p_ready: ready });
export const leaveRoom = (room: string) => rpc<void>('leave_room', { p_room: room });
export const startGame = (room: string) => rpc<void>('start_game', { p_room: room });
export const inviteToRoom = (room: string, users: string[]) => rpc<number>('invite_to_room', { p_room: room, p_users: users });
export const rematch = (room: string) => rpc<Room>('rematch', { p_room: room });

export async function room(id: string): Promise<Room> {
	const { data, error } = await supabase.from('rooms').select().eq('id', id).single();
	if (error) throw error;
	return data as Room;
}
export async function players(room: string): Promise<RoomPlayer[]> {
	const { data, error } = await supabase.from('room_players').select('*, profile:profiles(*)').eq('room_id', room).order('joined_at');
	if (error) throw error;
	return data as RoomPlayer[];
}
export async function rounds(room: string): Promise<Round[]> {
	const { data, error } = await supabase.from('rounds').select().eq('room_id', room).order('number');
	if (error) throw error;
	return data as Round[];
}

// Ronda
export const saveAnswer = (round: string, category: string, value: string) =>
	rpc<void>('save_answer', { p_round: round, p_category: category, p_value: value });
export const callStop = (round: string) => rpc<void>('call_stop', { p_round: round });
export const closeRound = (round: string) => rpc<string>('close_round', { p_round: round });
export async function validateWithAI(round: string) {
	const { error } = await supabase.functions.invoke('validate-round', { body: { round_id: round } });
	if (error) throw error;
}
export const validateBasic = (round: string) => rpc<void>('validate_round_basic', { p_round: round });
export const setRoundReady = (round: string, ready: boolean) => rpc<string>('set_round_ready', { p_round: round, p_ready: ready });
export const advance = (room: string) => rpc<string>('advance_room', { p_room: room, p_force: false });

export async function answers(round: string): Promise<Answer[]> {
	const { data, error } = await supabase.from('answers').select().eq('round_id', round);
	if (error) throw error;
	return data as Answer[];
}
export async function myAnswers(round: string): Promise<Answer[]> {
	const id = await myId();
	const { data, error } = await supabase.from('answers').select().eq('round_id', round).eq('user_id', id!);
	if (error) throw error;
	return data as Answer[];
}

// Impugnaciones
export const submitDispute = (round: string, target: string, category: string, kind: string, justification: string) =>
	rpc<string>('submit_dispute', { p_round: round, p_target: target, p_category: category, p_kind: kind, p_justification: justification });
/** Segunda IA (Edge Function); si falla, la resolución básica en SQL (igual que iOS). */
export async function resolveDispute(id: string): Promise<Dispute> {
	const { data, error } = await supabase.functions.invoke('resolve-dispute', { body: { dispute_id: id } });
	if (!error && data) return data as Dispute;
	return rpc<Dispute>('resolve_dispute_basic', { p_dispute: id });
}
export async function disputes(round: string): Promise<Dispute[]> {
	const { data, error } = await supabase.from('disputes').select().eq('round_id', round);
	if (error) throw error;
	return data as Dispute[];
}

// Reacciones y moderación
export async function reactions(round: string): Promise<Reaction[]> {
	const { data, error } = await supabase.from('reactions').select('round_id, user_id, category, emoji').eq('round_id', round);
	if (error) throw error;
	return data as Reaction[];
}
export async function react(round: string, category: string, emoji: string) {
	const id = await myId();
	const { error } = await supabase.from('reactions').upsert({ round_id: round, user_id: id, category, emoji });
	if (error) throw error;
}
export async function report(user: string, room: string | null, reason: string, details: string, mute: boolean) {
	const { error } = await supabase.from('reports').insert({ reported: user, room_id: room, reason, details });
	if (error) throw error;
	if (mute) await supabase.from('mutes').upsert({ muted_id: user });
}
export async function mutedIds(): Promise<Set<string>> {
	const { data } = await supabase.from('mutes').select('muted_id');
	return new Set((data ?? []).map((r: { muted_id: string }) => r.muted_id));
}

// Chat
export async function chat(room: string): Promise<ChatMessage[]> {
	const { data, error } = await supabase.from('chat_messages').select().eq('room_id', room).order('created_at').limit(200);
	if (error) throw error;
	return data as ChatMessage[];
}
export async function sendChat(room: string, body: string) {
	const { error } = await supabase.from('chat_messages').insert({ room_id: room, body });
	if (error) throw error;
}

// Categorías
export async function categories(): Promise<Category[]> {
	const { data, error } = await supabase.from('categories').select().order('kind').order('sort');
	if (error) throw error;
	return data as Category[];
}

// Amigos
export const friends = () => rpc<FriendRow[]>('my_friends');
export const myFriendInvite = (renew = false) => rpc<string>('my_friend_invite', { p_renew: renew });
export const searchUsers = (q: string) => rpc<SearchUser[]>('search_users', { p_query: q });
export const sendFriendRequest = (user: string) => rpc<void>('send_friend_request', { p_user: user });
export const respondFriendRequest = (user: string, accept: boolean) => rpc<void>('respond_friend_request', { p_user: user, p_accept: accept });
export const removeFriend = (user: string) => rpc<void>('remove_friend', { p_user: user });
export const acceptFriendInvite = (token: string) => rpc<FriendLinkResult>('accept_friend_invite', { p_token: token });

// Categorías con IA
export async function generateCategories(theme: string): Promise<string[]> {
	const { data, error } = await supabase.functions.invoke('categories-ai', { body: { action: 'generate', theme } });
	if (error) throw error;
	return (data as { categories: string[] }).categories ?? [];
}

// Notificaciones
export async function notifications(): Promise<AppNotification[]> {
	const { data, error } = await supabase.from('notifications').select().order('created_at', { ascending: false }).limit(100);
	if (error) throw error;
	return data as AppNotification[];
}
export async function markAllRead() {
	const id = await myId();
	await supabase.from('notifications').update({ read: true }).eq('user_id', id!).eq('read', false);
}
export async function deleteNotification(id: number) {
	await supabase.from('notifications').delete().eq('id', id);
}

// Progresión
export async function achievements(): Promise<Achievement[]> {
	const { data, error } = await supabase.from('achievements').select().order('sort');
	if (error) throw error;
	return data as Achievement[];
}
export async function userAchievements(user: string): Promise<UserAchievement[]> {
	const { data, error } = await supabase.from('user_achievements').select().eq('user_id', user).order('unlocked_at', { ascending: false });
	if (error) throw error;
	return data as UserAchievement[];
}
export const history = (filter: 'all' | 'public' | 'private' = 'all') => rpc<HistoryRow[]>('my_history', { p_filter: filter });

// Moderación (solo administradores: profiles.is_admin)
export const adminReports = (status: 'open' | 'all' = 'open') => rpc<AdminReport[]>('admin_reports', { p_status: status });
export const adminResolveReport = (id: string, action: 'dismiss' | 'ban', days: number | null = 7) =>
	rpc<void>('admin_resolve_report', { p_report: id, p_action: action, p_days: days });
export const adminUnban = (user: string) => rpc<void>('admin_unban', { p_user: user });
