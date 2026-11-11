export interface Profile {
	id: string; username: string; avatar: string; level: number; xp: number;
	total_points: number; games_played: number; games_won: number; best_score: number;
	win_streak: number; valid_answers?: number; is_plus: boolean; current_room: string | null; last_seen: string;
	notif_prefs?: Record<string, boolean> | null; username_changed_at?: string | null; created_at?: string;
}
export interface Room {
	id: string; code: string; name: string; host_id: string | null; is_public: boolean; ranked: boolean;
	status: 'waiting' | 'playing' | 'finished' | 'cancelled'; max_players: number; min_players: number;
	rounds_total: number; round_seconds: number; stop_seconds: number; exclude_hard: boolean;
	categories: string[]; allow_custom: boolean; current_round: number; used_letters: string[];
	starts_at: string | null; created_at: string;
}
export interface RoomPlayer {
	room_id: string; user_id: string; joined_at: string; ready: boolean; score: number;
	left_at: string | null; last_seen: string; disputes_left: number; final_rank: number | null;
	xp_gained: number | null; profile: Profile | null;
}
export interface Round {
	id: string; room_id: string; number: number; letter: string;
	status: 'playing' | 'validating' | 'results';
	starts_at: string; ends_at: string; close_at: string; stop_by: string | null; stop_at: string | null;
	validation_started_at: string | null; validation_attempts: number; validated_by_ai: boolean;
	next_at: string | null; ready_users: string[] | null;
}
export interface Answer {
	round_id: string; user_id: string; category: string; value: string;
	status: 'pending' | 'valid' | 'invalid' | 'doubtful' | 'empty';
	reason: string | null; points: number; disputed: boolean;
	checks?: { letter?: boolean | null; category?: boolean | null; real_word?: boolean | null; spelling?: boolean | null } | null;
}
export interface Dispute {
	id: string; round_id: string; user_id: string; target_user: string; category: string; kind: string; justification: string;
	status: 'pending' | 'accepted' | 'rejected'; resolution: string | null; old_status: string | null; new_status: string | null; points_delta: number;
}
export interface Reaction { round_id: string; user_id: string; category: string; emoji: string; }
export interface AppNotification {
	id: number; kind: string; title: string; body: string | null; read: boolean; created_at: string;
	payload: { room_id?: string; code?: string; user_id?: string; achievement?: string; level?: number } | null;
}
export interface Achievement { id: string; title: string; description: string; icon: string; sort: number; }
export interface UserAchievement { user_id: string; achievement_id: string; unlocked_at: string; }
export interface HistoryRow {
	room_id: string; code: string; name: string; is_public: boolean; finished_at: string | null; players: number;
	rounds: number; score: number; final_rank: number | null; xp_gained: number | null;
}
export interface SearchUser { user_id: string; username: string; avatar: string; level: number; relation: 'none' | 'sent' | 'received' | 'friends'; }
export interface ChatMessage { id: number; room_id: string; user_id: string | null; body: string; kind: string; created_at: string; }
export interface PublicRoom {
	room_id: string; code: string; name: string; host_id: string; host_name: string; host_avatar: string;
	host_level: number; players: number; max_players: number; rounds_total: number; round_seconds: number;
	categories: string[]; exclude_hard: boolean; created_at: string; is_member: boolean;
}
export interface Category { id: string; name: string; kind: 'default' | 'thematic' | 'custom'; theme: string | null; }
export interface FriendRow {
	user_id: string; username: string; avatar: string; level: number; last_seen: string; current_room: string | null;
	playing: boolean; status: 'pending' | 'accepted'; incoming: boolean; games_together: number;
}
export interface FriendLinkResult { status: 'added' | 'already' | 'accepted_request'; user_id: string; username: string; avatar: string; level: number; }

export const playerName = (p: RoomPlayer | undefined) => p?.profile?.username ?? 'jugador';
export const playerAvatar = (p: RoomPlayer | undefined) => p?.profile?.avatar ?? 'fox';
export const isConnected = (p: RoomPlayer, now: number) => new Date(p.last_seen).getTime() > now - 45_000;
/** Reacciones a respuestas: claves guardadas en reactions.emoji (iguales a iOS). */
export const REACTIONS = ['haha', 'fire', 'wow', 'clap', 'hmm', 'ouch'] as const;
export const xpForNext = (level: number) => 250 * level;
