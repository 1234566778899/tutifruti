import Foundation
import Supabase

/// Envoltorio de las RPCs del backend. Toda mutación del juego pasa por aquí.
enum API {
    static var myId: UUID? { supabase.auth.currentUser?.id }

    // MARK: Utilidades
    static func serverNow() async throws -> Date {
        let s: String = try await supabase.rpc("server_now").execute().value
        return Coders.parseDate(s) ?? Date()
    }

    static func heartbeat(room: UUID?) async {
        _ = try? await supabase.rpc("heartbeat", params: ["p_room": room.map { AnyJSON.string($0.uuidString) } ?? .null]).execute()
    }


    // MARK: Perfil
    static func myProfile() async throws -> Profile? {
        guard let id = myId else { return nil }
        let rows: [Profile] = try await supabase.from("profiles").select().eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    static func profile(_ id: UUID) async throws -> Profile {
        try await supabase.from("profiles").select().eq("id", value: id).single().execute().value
    }

    static func usernameAvailable(_ name: String) async -> Bool {
        (try? await supabase.rpc("username_available", params: ["p_username": name]).execute().value) ?? false
    }

    static func createProfile(username: String, avatar: String) async throws -> Profile {
        try await supabase.rpc("create_profile", params: ["p_username": username, "p_avatar": avatar]).execute().value
    }

    static func changeUsername(_ name: String) async throws -> Profile {
        try await supabase.rpc("change_username", params: ["p_username": name]).execute().value
    }

    static func updateProfile(avatar: String? = nil, theme: String? = nil, language: String? = nil, notifPrefs: [String: Bool]? = nil) async throws {
        guard let id = myId else { return }
        var patch: [String: AnyJSON] = [:]
        if let avatar { patch["avatar"] = .string(avatar) }
        if let theme { patch["theme"] = .string(theme) }
        if let language { patch["language"] = .string(language) }
        if let notifPrefs { patch["notif_prefs"] = .object(notifPrefs.mapValues { .bool($0) }) }
        try await supabase.from("profiles").update(patch).eq("id", value: id).execute()
    }

    static func uploadAvatar(_ data: Data) async throws -> String {
        guard let id = myId else { throw APIError.message("No autenticado") }
        let path = "\(id.uuidString.lowercased())/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        try await supabase.storage.from("avatars").upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let url = try supabase.storage.from("avatars").getPublicURL(path: path)
        return url.absoluteString
    }

    static func deleteAccount() async throws {
        try await supabase.rpc("delete_my_account").execute()
    }

    // MARK: Salas
    struct RoomSettings: Hashable {
        var name = "Viernes de Stop"
        var maxPlayers = 8
        var rounds = 5
        var roundSeconds = 90
        var stopSeconds = 10
        var excludeHard = true
        var categories = ["Nombre", "País", "Ciudad", "Animal", "Fruta", "Color", "Profesión", "Marca"]
        var allowCustom = true
        /// Pública: aparece en "Salas públicas" y cualquiera puede unirse antes de empezar. Privada: solo con código.
        var isPublic = false

        init() {}
        init(room: Room) {
            name = room.name; maxPlayers = room.maxPlayers; rounds = room.roundsTotal
            roundSeconds = room.roundSeconds; stopSeconds = room.stopSeconds
            excludeHard = room.excludeHard; categories = room.categories; allowCustom = room.allowCustom
            isPublic = room.isPublic
        }

        var params: [String: AnyJSON] {
            ["p_name": .string(name), "p_max_players": .integer(maxPlayers), "p_rounds": .integer(rounds),
             "p_round_seconds": .integer(roundSeconds), "p_stop_seconds": .integer(stopSeconds),
             "p_exclude_hard": .bool(excludeHard), "p_categories": .array(categories.map { .string($0) }),
             "p_allow_custom": .bool(allowCustom), "p_is_public": .bool(isPublic)]
        }
    }

    static func createRoom(_ s: RoomSettings) async throws -> Room {
        try await supabase.rpc("create_room", params: s.params).execute().value
    }

    static func updateRoom(_ id: UUID, _ s: RoomSettings) async throws -> Room {
        var p = s.params
        p["p_room"] = .string(id.uuidString)
        return try await supabase.rpc("update_room", params: p).execute().value
    }

    static func joinByCode(_ code: String) async throws -> UUID {
        try await supabase.rpc("join_room_by_code", params: ["p_code": code]).execute().value
    }

    static func myFriendInvite(renew: Bool = false) async throws -> String {
        try await supabase.rpc("my_friend_invite", params: ["p_renew": renew]).execute().value
    }

    static func acceptFriendInvite(_ token: String) async throws -> FriendLinkResult {
        try await supabase.rpc("accept_friend_invite", params: ["p_token": token]).execute().value
    }

    static func publicRooms() async throws -> [PublicRoom] {
        try await supabase.rpc("list_public_rooms").execute().value
    }

    static func joinPublicRoom(_ room: UUID) async throws -> UUID {
        try await supabase.rpc("join_public_room", params: ["p_room": room]).execute().value
    }

    static func findPublicMatch(wide: Bool = false) async throws -> UUID {
        try await supabase.rpc("find_public_match", params: ["p_wide": wide]).execute().value
    }

    static func widenMatch(_ room: UUID) async throws {
        try await supabase.rpc("widen_match", params: ["p_room": room]).execute()
    }

    static func setReady(_ room: UUID, _ ready: Bool) async throws {
        try await supabase.rpc("set_ready", params: ["p_room": AnyJSON.string(room.uuidString), "p_ready": .bool(ready)]).execute()
    }

    static func leaveRoom(_ room: UUID) async throws {
        try await supabase.rpc("leave_room", params: ["p_room": room]).execute()
    }

    static func invite(_ room: UUID, users: [UUID]) async throws {
        try await supabase.rpc("invite_to_room", params: ["p_room": AnyJSON.string(room.uuidString),
                                                         "p_users": .array(users.map { .string($0.uuidString) })]).execute()
    }

    static func rematch(_ room: UUID) async throws -> Room {
        try await supabase.rpc("rematch", params: ["p_room": room]).execute().value
    }

    static func startGame(_ room: UUID) async throws {
        try await supabase.rpc("start_game", params: ["p_room": room]).execute()
    }

    static func room(_ id: UUID) async throws -> Room {
        try await supabase.from("rooms").select().eq("id", value: id).single().execute().value
    }

    static func players(_ room: UUID) async throws -> [RoomPlayer] {
        try await supabase.from("room_players").select("*, profile:profiles(*)").eq("room_id", value: room)
            .order("joined_at").execute().value
    }

    static func rounds(_ room: UUID) async throws -> [Round] {
        try await supabase.from("rounds").select().eq("room_id", value: room).order("number").execute().value
    }

    // MARK: Ronda
    static func saveAnswer(round: UUID, category: String, value: String) async throws {
        try await supabase.rpc("save_answer", params: ["p_round": round.uuidString, "p_category": category, "p_value": value]).execute()
    }

    static func callStop(_ round: UUID) async throws {
        try await supabase.rpc("call_stop", params: ["p_round": round]).execute()
    }

    static func closeRound(_ round: UUID) async throws -> String {
        try await supabase.rpc("close_round", params: ["p_round": round]).execute().value
    }

    static func validateWithAI(_ round: UUID) async throws {
        try await supabase.functions.invoke("validate-round", options: FunctionInvokeOptions(body: ["round_id": round.uuidString]))
    }

    static func validateBasic(_ round: UUID) async throws {
        try await supabase.rpc("validate_round_basic", params: ["p_round": round]).execute()
    }

    static func setRoundReady(_ round: UUID, _ ready: Bool) async throws -> String {
        try await supabase.rpc("set_round_ready", params: ["p_round": AnyJSON.string(round.uuidString), "p_ready": .bool(ready)]).execute().value
    }

    static func advance(_ room: UUID, force: Bool = false) async throws -> String {
        try await supabase.rpc("advance_room", params: ["p_room": AnyJSON.string(room.uuidString), "p_force": .bool(force)]).execute().value
    }

    static func answers(round: UUID) async throws -> [Answer] {
        try await supabase.from("answers").select().eq("round_id", value: round).execute().value
    }

    static func answers(rounds: [UUID]) async throws -> [Answer] {
        guard !rounds.isEmpty else { return [] }
        return try await supabase.from("answers").select().in("round_id", values: rounds.map(\.uuidString)).execute().value
    }

    static func myAnswers(round: UUID) async throws -> [Answer] {
        guard let me = myId else { return [] }
        return try await supabase.from("answers").select().eq("round_id", value: round).eq("user_id", value: me).execute().value
    }

    // MARK: Impugnaciones
    static func submitDispute(round: UUID, target: UUID, category: String, kind: String, justification: String) async throws -> UUID {
        try await supabase.rpc("submit_dispute", params: [
            "p_round": round.uuidString, "p_target": target.uuidString, "p_category": category,
            "p_kind": kind, "p_justification": justification,
        ]).execute().value
    }

    static func resolveDispute(_ id: UUID) async throws -> Dispute {
        do {
            return try await supabase.functions.invoke("resolve-dispute", options: FunctionInvokeOptions(body: ["dispute_id": id.uuidString]), decoder: Coders.decoder)
        } catch {
            return try await supabase.rpc("resolve_dispute_basic", params: ["p_dispute": id]).execute().value
        }
    }

    static func disputes(round: UUID) async throws -> [Dispute] {
        try await supabase.from("disputes").select().eq("round_id", value: round).execute().value
    }

    // MARK: Chat y reacciones
    static func chat(_ room: UUID) async throws -> [ChatMessage] {
        try await supabase.from("chat_messages").select().eq("room_id", value: room).order("created_at").limit(200).execute().value
    }

    static func sendChat(_ room: UUID, _ body: String) async throws {
        try await supabase.from("chat_messages").insert(["room_id": room.uuidString, "body": body]).execute()
    }

    static func reactions(round: UUID) async throws -> [Reaction] {
        try await supabase.from("reactions").select().eq("round_id", value: round).execute().value
    }

    static func react(round: UUID, category: String, emoji: String) async throws {
        guard let me = myId else { return }
        try await supabase.from("reactions").upsert(Reaction(roundId: round, userId: me, category: category, emoji: emoji)).execute()
    }

    static func report(user: UUID, room: UUID?, reason: String, details: String, mute: Bool) async throws {
        var row: [String: AnyJSON] = ["reported": .string(user.uuidString), "reason": .string(reason), "details": .string(details)]
        if let room { row["room_id"] = .string(room.uuidString) }
        try await supabase.from("reports").insert(row).execute()
        if mute { try await supabase.from("mutes").upsert(["muted_id": user.uuidString]).execute() }
    }

    static func mutedIds() async -> Set<UUID> {
        struct M: Decodable { var mutedId: UUID }
        let rows: [M] = (try? await supabase.from("mutes").select("muted_id").execute().value) ?? []
        return Set(rows.map(\.mutedId))
    }

    // MARK: Categorías
    static func categories() async throws -> [Category] {
        try await supabase.from("categories").select().order("kind").order("sort").execute().value
    }

    static func createCategory(name: String, description: String) async throws -> Category {
        guard let me = myId else { throw APIError.message("No autenticado") }
        return try await supabase.from("categories")
            .insert(["name": name, "description": description, "kind": "custom", "owner_id": me.uuidString])
            .select().single().execute().value
    }

    static func deleteCategory(_ id: UUID) async throws {
        try await supabase.from("categories").delete().eq("id", value: id).execute()
    }

    static func categorySets() async throws -> [CategorySet] {
        try await supabase.from("category_sets").select().order("created_at").execute().value
    }

    static func saveCategorySet(name: String, categories: [String]) async throws {
        try await supabase.from("category_sets").insert(["name": AnyJSON.string(name), "categories": .array(categories.map { .string($0) })]).execute()
    }

    static func deleteCategorySet(_ id: UUID) async throws {
        try await supabase.from("category_sets").delete().eq("id", value: id).execute()
    }

    struct Generated: Decodable { var categories: [String] }
    static func generateCategories(theme: String) async throws -> [String] {
        let r: Generated = try await supabase.functions.invoke("categories-ai", options: FunctionInvokeOptions(body: ["action": "generate", "theme": theme]))
        return r.categories
    }

    struct CategoryCheck: Decodable { var ok: Bool; var reason: String }
    static func checkCategory(name: String, description: String) async throws -> CategoryCheck {
        try await supabase.functions.invoke("categories-ai", options: FunctionInvokeOptions(body: ["action": "check", "name": name, "description": description]))
    }

    // MARK: Amigos
    static func friends() async throws -> [FriendRow] {
        try await supabase.rpc("my_friends").execute().value
    }

    static func searchUsers(_ q: String) async throws -> [SearchUser] {
        try await supabase.rpc("search_users", params: ["p_query": q]).execute().value
    }

    static func sendFriendRequest(_ user: UUID) async throws {
        try await supabase.rpc("send_friend_request", params: ["p_user": user]).execute()
    }

    static func respondFriendRequest(_ user: UUID, accept: Bool) async throws {
        try await supabase.rpc("respond_friend_request", params: ["p_user": AnyJSON.string(user.uuidString), "p_accept": .bool(accept)]).execute()
    }

    static func removeFriend(_ user: UUID) async throws {
        try await supabase.rpc("remove_friend", params: ["p_user": user]).execute()
    }

    static func headToHead(_ user: UUID) async throws -> HeadToHead {
        try await supabase.rpc("head_to_head", params: ["p_user": user]).execute().value
    }

    static func activity() async throws -> [ActivityItem] {
        try await supabase.from("activity").select("*, profile:profiles(*)").neq("user_id", value: myId ?? UUID())
            .order("created_at", ascending: false).limit(50).execute().value
    }

    // MARK: Notificaciones
    static func notifications() async throws -> [AppNotification] {
        try await supabase.from("notifications").select().order("created_at", ascending: false).limit(100).execute().value
    }

    static func markAllRead() async throws {
        guard let me = myId else { return }
        try await supabase.from("notifications").update(["read": true]).eq("user_id", value: me).eq("read", value: false).execute()
    }

    static func deleteNotification(_ id: Int) async throws {
        try await supabase.from("notifications").delete().eq("id", value: id).execute()
    }

    // MARK: Progresión


    static func achievements() async throws -> [Achievement] {
        try await supabase.from("achievements").select().order("sort").execute().value
    }

    static func userAchievements(_ user: UUID) async throws -> [UserAchievement] {
        try await supabase.from("user_achievements").select().eq("user_id", value: user).order("unlocked_at", ascending: false).execute().value
    }

    // MARK: Rankings e historial


    static func history(filter: String) async throws -> [HistoryRow] {
        try await supabase.rpc("my_history", params: ["p_filter": filter]).execute().value
    }

    // MARK: Push
    static func registerPushToken(_ token: String, sandbox: Bool) async {
        _ = try? await supabase.rpc("register_push_token", params: ["p_token": AnyJSON.string(token), "p_sandbox": .bool(sandbox)]).execute()
    }

    static func unregisterPushToken(_ token: String) async {
        _ = try? await supabase.rpc("unregister_push_token", params: ["p_token": token]).execute()
    }
}

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}

/// Convierte errores de Supabase/Postgres en mensajes legibles en español.
/// Errores por cancelar una tarea o petición (p. ej. al reemplazar un autoguardado): no son fallos reales.
func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let e = error as? URLError, e.code == .cancelled { return true }
    let ns = error as NSError
    return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
}

/// Errores de red transitorios (sin conexión, tiempo agotado, conexión perdida al volver de segundo plano).
func isNetworkError(_ error: Error) -> Bool {
    let codes: Set<Int> = [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                           NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
                           NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed, NSURLErrorSecureConnectionFailed]
    let ns = error as NSError
    return ns.domain == NSURLErrorDomain && codes.contains(ns.code)
}

func friendlyError(_ error: Error) -> String {
    if let e = error as? PostgrestError { return e.message }
    if let e = error as? AuthError {
        let m = e.localizedDescription.lowercased()
        if m.contains("invalid login") { return "Correo o contraseña incorrectos." }
        if m.contains("email not confirmed") { return "Confirma tu correo antes de iniciar sesión." }
        if m.contains("already registered") { return "Ese correo ya tiene una cuenta." }
        if m.contains("password") && m.contains("6") { return "La contraseña es demasiado corta." }
        if m.contains("anonymous") { return "El modo invitado no está activado en el servidor." }
        return e.localizedDescription
    }
    if isNetworkError(error) { return "Sin conexión a internet. Revisa tu red e inténtalo de nuevo." }
    return error.localizedDescription
}
