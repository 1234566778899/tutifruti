import Foundation
import Observation
import Network
import Supabase

/// Estado en vivo de una sala: realtime + reloj + transiciones automáticas de la ronda.
/// El servidor es la autoridad; este store solo refleja su estado y dispara las RPCs idempotentes.
@MainActor @Observable
final class GameStore {
    enum Phase: Equatable { case loading, lobby, matchmaking, letterDraw, answering, validating, results, finished, cancelled }

    let roomId: UUID
    let me: UUID?

    var room: Room?
    var players: [RoomPlayer] = []
    var rounds: [Round] = []
    var chat: [ChatMessage] = []
    var now = Date()

    // Respuestas de la ronda en curso
    var drafts: [String: String] = [:]
    var saved: [String: String] = [:]

    // Resultados de la ronda mostrada
    var roundAnswers: [Answer] = []
    var reactions: [Reaction] = []
    var disputes: [Dispute] = []
    private(set) var loadedResultsFor: UUID?

    // Estado de la validación / red
    var aiFailed = false
    var aiAttempt = 0
    var isOffline = false
    var errorMessage: String?
    var unreadChat = 0
    /// Último mensaje recibido con el chat cerrado (para el aviso flotante).
    var incomingMessage: ChatMessage?
    var chatOpen = false { didSet { if chatOpen { unreadChat = 0 } } }
    var muted: Set<UUID> = []

    private var channel: RealtimeChannelV2?
    private var tasks: [Task<Void, Never>] = []
    private var saveTasks: [String: Task<Void, Never>] = [:]
    private var throttles: [String: Date] = [:]
    private var refreshTask: Task<Void, Never>?
    private var lastRoundId: UUID?
    private var validatingNow = false
    private let monitor = NWPathMonitor()
    private var lastRefresh = Date.distantPast
    private var resyncing = false
    private var resyncFailures = 0
    /// Verdadero mientras se reconecta tras volver a la app o recuperar la red (para la UI).
    var reconnecting = false

    init(roomId: UUID) {
        self.roomId = roomId
        self.me = API.myId
    }

    // MARK: Derivados
    var currentRound: Round? { rounds.last }
    var activePlayers: [RoomPlayer] { players.filter { $0.leftAt == nil } }
    var myPlayer: RoomPlayer? { players.first { $0.userId == me } }
    var isHost: Bool { room?.hostId != nil && room?.hostId == me }
    var categories: [String] { room?.categories ?? [] }

    var phase: Phase {
        guard let room else { return .loading }
        switch room.status {
        // Solo las salas automáticas antiguas (sin anfitrión) usan la cuenta regresiva de matchmaking.
        case "waiting": return room.hostId == nil ? .matchmaking : .lobby
        case "finished": return .finished
        case "cancelled": return .cancelled
        default:
            guard let r = currentRound else { return .loading }
            switch r.status {
            case "playing": return now < r.startsAt ? .letterDraw : .answering
            case "validating": return .validating
            default: return .results
            }
        }
    }

    var secondsLeft: Int {
        guard let r = currentRound else { return 0 }
        return max(0, Int(ceil(r.closeAt.timeIntervalSince(now))))
    }

    var stopCaller: RoomPlayer? {
        guard let id = currentRound?.stopBy else { return nil }
        return players.first { $0.userId == id }
    }

    func player(_ id: UUID) -> RoomPlayer? { players.first { $0.userId == id } }

    func isSaved(_ category: String) -> Bool {
        let d = drafts[category]?.trimmingCharacters(in: .whitespaces) ?? ""
        return !d.isEmpty && saved[category] == d
    }

    /// Respuestas que empiezan con la letra de la ronda.
    var filledCount: Int {
        guard let letter = currentRound?.letter else { return 0 }
        return categories.filter {
            let v = (drafts[$0] ?? "").trimmingCharacters(in: .whitespaces)
            return v.count >= 2 && v.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .uppercased().hasPrefix(letter == "Ñ" ? "N" : letter)
        }.count
    }

    /// Mínimo para decir STOP: 75 % de las categorías, redondeado hacia arriba (igual que `stop_threshold` en el servidor).
    var stopThreshold: Int { max(1, Int((Double(categories.count) * 0.75).rounded(.up))) }

    /// Se puede decir STOP (aparece el botón).
    var canStop: Bool { filledCount >= stopThreshold }

    // MARK: Ciclo de vida
    func start() async {
        muted = await API.mutedIds()
        await refresh()
        chat = (try? await API.chat(roomId)) ?? []
        await subscribe()
        let ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.now = ClockSync.shared.now
                await self.healthCheck()
                await self.drive()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        tasks.append(ticker)
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = self.isOffline
                self.isOffline = path.status != .satisfied
                if wasOffline && !self.isOffline { await self.resync() }
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    func stop() async {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        saveTasks.values.forEach { $0.cancel() }
        monitor.cancel()
        if let channel { await supabase.removeChannel(channel) }
        channel = nil
    }

    /// Reconecta todo: reloj, canal en tiempo real y estado completo. Idempotente y sin solaparse.
    func resync() async {
        guard !resyncing else { return }
        resyncing = true
        reconnecting = true
        defer { resyncing = false; reconnecting = false }
        await ClockSync.shared.sync()
        await API.heartbeat(room: roomId)
        if let channel { await supabase.removeChannel(channel) }
        channel = nil
        await subscribe()
        await refresh()
        if let r = currentRound, r.status == "results" { await loadResults(r.id, force: true) }
        if let r = currentRound, r.status == "playing" { await flushAll(r.id) }  // reenvía lo no guardado
        chat = (try? await API.chat(roomId)) ?? chat
        resyncFailures = channel?.status == .subscribed ? 0 : resyncFailures + 1
    }

    /// La app volvió al primer plano: el socket suele haberse cerrado en segundo plano.
    func appBecameActive() async {
        await resync()
    }

    /// La app pasa a segundo plano: guarda ya lo escrito para no perderlo.
    func appWillResignActive() async {
        if let r = currentRound, r.status == "playing" { await flushAll(r.id) }
    }

    /// Red de seguridad: si el canal en tiempo real cayó o no hubo cambios en un rato, se reconecta/recarga.
    private func healthCheck() async {
        guard !isOffline, !resyncing else { return }
        let channelDown = channel == nil || channel?.status == .unsubscribed
        let backoff = min(30.0, 3.0 * pow(2.0, Double(min(resyncFailures, 4))))
        if channelDown, throttle("resync", backoff) {
            await resync()
        } else if Date().timeIntervalSince(lastRefresh) > 10, throttle("poll", 10) {
            await refresh()
        }
    }

    private func subscribe() async {
        let ch = supabase.channel("room-\(roomId.uuidString)-\(Int.random(in: 0...99999))")
        let roomChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "rooms", filter: .eq("id", value: roomId))
        let playerChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "room_players", filter: .eq("room_id", value: roomId))
        let roundChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "rounds", filter: .eq("room_id", value: roomId))
        let chatInserts = ch.postgresChange(InsertAction.self, schema: "public", table: "chat_messages", filter: .eq("room_id", value: roomId))
        let reactionChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "reactions")
        let disputeChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "disputes")
        // Si falla, healthCheck reintenta con espera creciente (sin molestar con alertas).
        try? await ch.subscribeWithError()
        channel = ch

        tasks.append(Task { [weak self] in for await _ in roomChanges { self?.scheduleRefresh() } })
        tasks.append(Task { [weak self] in for await _ in playerChanges { self?.scheduleRefresh() } })
        tasks.append(Task { [weak self] in for await _ in roundChanges { self?.scheduleRefresh() } })
        tasks.append(Task { [weak self] in
            for await insert in chatInserts {
                guard let self, let m = try? insert.decodeRecord(as: ChatMessage.self, decoder: Coders.decoder) else { continue }
                if !self.chat.contains(where: { $0.id == m.id }) { self.chat.append(m) }
                if !self.chatOpen && m.userId != self.me && m.kind == "msg" && !(m.userId.map { self.muted.contains($0) } ?? false) {
                    self.unreadChat += 1
                    self.incomingMessage = m
                }
            }
        })
        tasks.append(Task { [weak self] in
            for await _ in reactionChanges {
                guard let self, let rid = self.loadedResultsFor else { continue }
                self.reactions = (try? await API.reactions(round: rid)) ?? self.reactions
            }
        })
        tasks.append(Task { [weak self] in
            for await _ in disputeChanges {
                guard let self, let rid = self.loadedResultsFor else { continue }
                await self.loadResults(rid, force: true)
            }
        })
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            // Solo se cancela la espera (para agrupar cambios): la recarga en curso no se interrumpe,
            // así sus peticiones no fallan con "cancelado" a mitad de camino.
            await Task { [weak self] in await self?.refresh() }.value
        }
    }

    func refresh() async {
        do {
            async let r = API.room(roomId)
            async let p = API.players(roomId)
            async let rs = API.rounds(roomId)
            let (room, players, rounds) = try await (r, p, rs)
            self.room = room
            self.players = players
            self.rounds = rounds
            lastRefresh = Date()
        } catch {
            // Fallos de red transitorios no se muestran: el overlay de reconexión y los reintentos se encargan.
            if isCancellation(error) || isNetworkError(error) { return }
            errorMessage = friendlyError(error)
            return
        }
        if let r = currentRound {
            if r.id != lastRoundId {
                lastRoundId = r.id
                aiFailed = false
                aiAttempt = 0
                drafts = [:]
                saved = [:]
                // Restaura respuestas guardadas (reconexión).
                for a in (try? await API.myAnswers(round: r.id)) ?? [] {
                    drafts[a.category] = a.value
                    saved[a.category] = a.value
                }
            }
            if r.status == "results" { await loadResults(r.id, force: loadedResultsFor == r.id && roundAnswers.isEmpty) }
        }
    }

    func loadResults(_ roundId: UUID, force: Bool = false) async {
        if loadedResultsFor == roundId && !force { return }
        do {
            async let a = API.answers(round: roundId)
            async let re = API.reactions(round: roundId)
            async let d = API.disputes(round: roundId)
            let (answers, reacts, disps) = try await (a, re, d)
            roundAnswers = answers
            reactions = reacts
            disputes = disps
            loadedResultsFor = roundId
        } catch {
            // Sin marcar como cargado: el siguiente refresco lo reintenta (los cortes de red no se muestran).
            if !isCancellation(error) && !isOffline && !isNetworkError(error) { report(error) }
        }
    }

    // MARK: Motor de transiciones
    private func throttle(_ key: String, _ seconds: TimeInterval) -> Bool {
        if let last = throttles[key], Date().timeIntervalSince(last) < seconds { return false }
        throttles[key] = Date()
        return true
    }

    private var validatorId: UUID? {
        let active = activePlayers.filter(\.isConnected)
        if let host = room?.hostId, active.contains(where: { $0.userId == host }) { return host }
        return (active.first ?? activePlayers.first)?.userId
    }

    private func drive() async {
        guard !isOffline, let room else { return }
        switch phase {
        case .matchmaking:
            if let s = room.startsAt, now >= s, throttle("start", 3) {
                try? await API.startGame(roomId)
                await refresh()
            }
        case .answering:
            if let r = currentRound, now >= r.closeAt, throttle("close-\(r.id)", 2) {
                await flushAll(r.id)
                if (try? await API.closeRound(r.id)) == "validating" { await refresh() }
            }
        case .validating:
            guard let r = currentRound else { return }
            let started = r.validationStartedAt ?? now
            if validatorId == me, !validatingNow, throttle("ai-\(r.id)-\(aiAttempt)", 4) {
                await runAIValidation(r.id)
            } else if now.timeIntervalSince(started) > 25, throttle("basic-\(r.id)", 5) {
                // Si el validador se cayó, cualquiera completa con la validación básica.
                try? await API.validateBasic(r.id)
                await refresh()
            }
        case .results:
            if let r = currentRound, loadedResultsFor != r.id, throttle("res-\(r.id)", 2) {
                await loadResults(r.id)
            }
            // Solo se avanza cuando todos están listos (el servidor lo vuelve a comprobar).
            if let r = currentRound, everyoneReady, throttle("adv-\(r.id)", 3) {
                _ = try? await API.advance(roomId)
                await refresh()
            }
        default: break
        }
    }

    private func runAIValidation(_ roundId: UUID) async {
        validatingNow = true
        defer { validatingNow = false }
        do {
            try await API.validateWithAI(roundId)
            aiFailed = false
        } catch {
            aiAttempt += 1
            aiFailed = true
            if aiAttempt >= 3 { try? await API.validateBasic(roundId) }
        }
        await refresh()
    }

    func retryAI() {
        guard let r = currentRound else { return }
        throttles["ai-\(r.id)-\(aiAttempt)"] = nil
        Task { await runAIValidation(r.id) }
    }

    // MARK: Acciones del jugador
    func setDraft(_ category: String, _ value: String) {
        drafts[category] = value
        saveTasks[category]?.cancel()
        saveTasks[category] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self, let r = self.currentRound else { return }
            await self.save(r.id, category)
        }
    }

    private func save(_ roundId: UUID, _ category: String) async {
        let value = (drafts[category] ?? "").trimmingCharacters(in: .whitespaces)
        guard saved[category] != value else { return }
        do {
            try await API.saveAnswer(round: roundId, category: category, value: value)
            saved[category] = value
        } catch {
            if !isOffline && !isCancellation(error) && !isNetworkError(error) { errorMessage = friendlyError(error) }
        }
    }

    func flushAll(_ roundId: UUID) async {
        await withTaskGroup(of: Void.self) { group in
            for c in categories { group.addTask { await self.save(roundId, c) } }
        }
    }

    func callStop() async {
        guard let r = currentRound else { return }
        await flushAll(r.id)
        do { try await retrying { try await API.callStop(r.id) } } catch { report(error) }
        await refresh()
    }

    func setReady(_ ready: Bool) async {
        try? await API.setReady(roomId, ready)
        await refresh()
    }

    func startGame() async {
        do { try await retrying { try await API.startGame(self.roomId) } } catch { report(error) }
        await refresh()
    }

    // MARK: Listos para la siguiente ronda
    var readyIds: Set<UUID> { Set(currentRound?.readyUsers ?? []) }
    var iAmReady: Bool { me.map { readyIds.contains($0) } ?? false }
    /// Jugadores que cuentan para avanzar: activos y conectados (o que ya marcaron listo).
    var playersToWait: [RoomPlayer] { activePlayers.filter { $0.isConnected || readyIds.contains($0.userId) } }
    var everyoneReady: Bool { !playersToWait.isEmpty && playersToWait.allSatisfy { readyIds.contains($0.userId) } }

    func toggleReady() async {
        guard let r = currentRound else { return }
        let want = !iAmReady
        // optimista: refleja el cambio al instante
        if let i = rounds.lastIndex(where: { $0.id == r.id }), let me {
            var set = Set(rounds[i].readyUsers ?? [])
            if want { set.insert(me) } else { set.remove(me) }
            rounds[i].readyUsers = Array(set)
        }
        do { _ = try await retrying { try await API.setRoundReady(r.id, want) } } catch { report(error) }
        await refresh()
    }

    /// Error para el usuario: los cortes de red van como aviso discreto (y se reconecta);
    /// solo los errores reales abren la alerta "Algo salió mal".
    private func report(_ error: Error) {
        guard !isCancellation(error) else { return }
        if isNetworkError(error) {
            showNotice("Sin conexión · reintentando…")
            Task { await resync() }
            return
        }
        errorMessage = friendlyError(error)
    }

    /// Aviso breve que se oculta solo (cápsula arriba de la pantalla).
    var notice: String?
    private var noticeTask: Task<Void, Never>?
    func showNotice(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// Reintenta una acción ante cortes de red transitorios (hasta 3 intentos con espera creciente).
    @discardableResult
    private func retrying<T>(_ op: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do { return try await op() }
            catch {
                attempt += 1
                guard isNetworkError(error), attempt < 3 else { throw error }
                try? await Task.sleep(for: .milliseconds(600 * attempt))
            }
        }
    }

    func leave() async {
        try? await API.leaveRoom(roomId)
    }

    func sendChat(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do { try await retrying { try await API.sendChat(self.roomId, String(t.prefix(300))) } } catch { report(error) }
    }

    func react(category: String, emoji: String) async {
        guard let rid = loadedResultsFor else { return }
        try? await API.react(round: rid, category: category, emoji: emoji)
        reactions = (try? await API.reactions(round: rid)) ?? reactions
    }

    // MARK: Resultados
    func points(of user: UUID, in answers: [Answer]? = nil) -> Int {
        (answers ?? roundAnswers).filter { $0.userId == user }.reduce(0) { $0 + $1.points }
    }

    var roundRanking: [(player: RoomPlayer, points: Int)] {
        activePlayers.map { ($0, points(of: $0.userId)) }.sorted { $0.points > $1.points }
    }

    func answers(for category: String) -> [Answer] {
        roundAnswers.filter { $0.category == category }
            .sorted { (player($0.userId)?.joinedAt ?? .distantPast) < (player($1.userId)?.joinedAt ?? .distantPast) }
    }

    func dispute(for a: Answer) -> Dispute? {
        disputes.first { $0.targetUser == a.userId && $0.category == a.category }
    }
}
