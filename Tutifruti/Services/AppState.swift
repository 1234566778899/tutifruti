import Foundation
import Observation
import Supabase
import AuthenticationServices
import CryptoKit

/// Sesión, perfil y navegación global de la app.
@MainActor @Observable
final class AppState {
    enum Phase: Equatable { case loading, signedOut, needsProfile, ready }
    enum Tab: Hashable { case home, friends, profile }

    var phase: Phase = .loading
    var profile: Profile?
    /// Sesión de invitado (usuario anónimo): solo juega; sin amigos ni perfil persistente.
    var isGuest = false
    /// Solo en DEBUG: `-forceMember YES` muestra la interfaz de cuenta normal (para revisar pantallas en el simulador).
    #if DEBUG
    static let debugForceMember = UserDefaults.standard.bool(forKey: "forceMember")
    #else
    static let debugForceMember = false
    #endif
    var selectedTab: Tab = .home
    /// Sala activa: si no es nil, se presenta el juego a pantalla completa.
    var activeRoom: UUID?
    var pendingJoinCode: String?
    /// Enlace de amistad abierto antes de tener sesión lista.
    var pendingFriendToken: String?
    /// Amistad recién creada por enlace (muestra la pantalla de celebración).
    var friendAdded: FriendLinkResult?
    /// El invitado abrió un enlace de amistad: se le muestra cómo crear cuenta.
    var guestNeedsAccount = false
    /// Cambia cuando cambian los amigos (para recargar listas).
    var friendsVersion = 0
    var unreadNotifications = 0
    var toast: String?
    /// Nivel al entrar a una partida, para detectar "¡Subiste de nivel!".
    var levelAtGameStart: Int?

    private var heartbeatTask: Task<Void, Never>?
    private var notificationsChannel: RealtimeChannelV2?
    private var currentNonce: String?

    init() {
        Task { await listenAuth() }
    }

    // MARK: Auth
    private func listenAuth() async {
        for await (event, session) in supabase.auth.authStateChanges {
            isGuest = (session?.user.isAnonymous ?? false) && !Self.debugForceMember
            switch event {
            case .initialSession:
                if session == nil { phase = .signedOut } else { await loadProfile() }
            case .signedIn, .userUpdated, .tokenRefreshed:
                if phase != .ready { await loadProfile() }
            case .signedOut, .userDeleted:
                stopRealtime()
                profile = nil
                activeRoom = nil
                phase = .signedOut
            default: break
            }
        }
    }

    func loadProfile() async {
        do {
            if let p = try await API.myProfile() {
                profile = p
                if phase != .ready {
                    phase = .ready
                    startRealtime()
                    await ClockSync.shared.sync()
                    // Si había una partida en curso, volvemos a ella.
                    if let room = p.currentRoom, let r = try? await API.room(room), r.status == "playing" || r.status == "waiting" {
                        activeRoom = room
                    }
                }
            } else {
                phase = .needsProfile
            }
        } catch {
            if phase == .loading { phase = .signedOut }
        }
    }

    func refreshProfile() async {
        if let p = try? await API.myProfile() { profile = p }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }

    // MARK: Sign in with Apple
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    /// Convierte la sesión de invitado en una cuenta real vinculando Apple (conserva perfil y progreso).
    func upgradeGuestWithApple(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            throw error
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { throw APIError.message("No se pudo leer la credencial de Apple.") }
            do {
                _ = try await supabase.auth.linkIdentityWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
            } catch {
                let m = error.localizedDescription.lowercased()
                if m.contains("manual linking") || m.contains("linking is disabled") {
                    throw APIError.message("Guardar la cuenta con Apple aún no está activado en el servidor.")
                }
                if m.contains("already") { throw APIError.message("Ese Apple ID ya tiene una cuenta. Sal del modo invitado e inicia sesión con Apple.") }
                throw error
            }
            isGuest = supabase.auth.currentUser?.isAnonymous ?? false
            await refreshProfile()
            toast = "¡Listo! Tu progreso quedó guardado."
        }
    }

    /// Sale del modo invitado: borra la cuenta temporal (libera el nombre) y cierra la sesión.
    func leaveGuestMode() async {
        if isGuest { try? await API.deleteAccount() }
        await signOut()
    }

    func handleApple(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            throw error
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { throw APIError.message("No se pudo leer la credencial de Apple.") }
            _ = try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Ciclo de vida de la app
    /// Al volver al primer plano: reloj, latido, notificaciones y, si había una partida en curso, regresar a ella.
    func sceneBecameActive() async {
        guard phase == .ready else { return }
        await ClockSync.shared.sync()
        await API.heartbeat(room: activeRoom)
        if notificationsChannel == nil || notificationsChannel?.status == .unsubscribed { startRealtime() }
        await refreshUnread()
        await refreshProfile()
        if activeRoom == nil, !joiningFromLink, pendingJoinCode == nil, let room = profile?.currentRoom,
           let r = try? await API.room(room), r.status == "playing" {
            activeRoom = room
        }
        if let code = pendingJoinCode {
            pendingJoinCode = nil
            try? await join(code: code)
        }
        if let token = pendingFriendToken {
            pendingFriendToken = nil
            await acceptFriendLink(token)
        }
    }

    // MARK: Realtime de notificaciones + presencia
    private func startRealtime() {
        guard let me = API.myId else { return }
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await API.heartbeat(room: self?.activeRoom)
                try? await Task.sleep(for: .seconds(20))
            }
        }
        if let old = notificationsChannel { Task { await supabase.removeChannel(old) } }
        notificationsChannel = nil
        Task {
            await refreshUnread()
            let channel = supabase.channel("notif-\(me.uuidString)-\(Int.random(in: 0...99999))")
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "notifications",
                                                 filter: .eq("user_id", value: me))
            try? await channel.subscribeWithError()
            notificationsChannel = channel
            for await insert in inserts {
                if let n = try? insert.decodeRecord(as: AppNotification.self, decoder: Coders.decoder) {
                    toast = n.title
                    Sfx.play(.notify)
                }
                await refreshUnread()
            }
        }
    }

    private func stopRealtime() {
        heartbeatTask?.cancel()
        if let c = notificationsChannel { Task { await supabase.removeChannel(c) } }
        notificationsChannel = nil
    }

    func refreshUnread() async {
        let list = (try? await API.notifications()) ?? []
        unreadNotifications = list.filter { !$0.read }.count
    }

    // MARK: Navegación a partidas
    func enterRoom(_ id: UUID) {
        levelAtGameStart = profile?.level
        activeRoom = id
    }

    /// Acepta un enlace de amistad con todas las validaciones del servidor.
    func acceptFriendLink(_ token: String) async {
        if isGuest {
            guestNeedsAccount = true
            toast = "Crea una cuenta para agregar amigos."
            return
        }
        do {
            let result = try await API.acceptFriendInvite(token)
            friendsVersion += 1
            if result.status != "already" { Sfx.play(.levelup) }
            if activeRoom != nil {
                // Dentro de una partida la hoja quedaría tapada: basta con el aviso flotante.
                toast = result.status == "already" ? "Ya eras amigo de \(result.username)" : "¡Ahora eres amigo de \(result.username)!"
                return
            }
            selectedTab = .friends
            // Espera a que la app esté activa y el cambio de pestaña termine; si no, la hoja se descarta.
            try? await Task.sleep(for: .milliseconds(700))
            friendAdded = result
        } catch {
            if isNetworkError(error) { pendingFriendToken = token }  // se reintenta al volver la conexión
            toast = friendlyError(error)
        }
    }

    /// Código de la sala abierta (para no reentrar si tocas el mismo enlace).
    var currentRoomCode: String?

    /// Hay una unión por enlace en curso (evita que "volver a la app" reabra la sala anterior).
    private(set) var joiningFromLink = false

    func join(code: String) async throws {
        joiningFromLink = true
        defer { joiningFromLink = false }
        do {
            let id = try await API.joinByCode(code)
            currentRoomCode = code
            // Si estabas en el lobby de otra sala, la dejas (en una partida en curso sigues siendo miembro y puedes volver).
            if let old = activeRoom, old != id, let r = try? await API.room(old), r.status == "waiting" {
                try? await API.leaveRoom(old)
            }
            enterRoom(id)  // el cover del juego se recrea con la nueva sala (.id en RootView)
            await API.heartbeat(room: id)
            Sfx.play(.join)
        } catch {
            toast = friendlyError(error)
            throw error
        }
    }

    /// Acepta salas (`tutifruti://join/TUTI-4F7K`, `https://<inviteHost>/j/TUTI-4F7K`)
    /// y amistades (`tutifruti://friend/<token>`, `https://<inviteHost>/a/<token>`).
    func handleDeepLink(_ url: URL) {
        let isScheme = url.scheme == Config.deepLinkScheme
        let isWeb = (url.scheme == "https" || url.scheme == "http") && url.host == Config.inviteHost
        guard isScheme || isWeb else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        let kind = isScheme ? (url.host ?? "") : (parts.first ?? "")
        if kind == "friend" || kind == "a" {
            guard let token = parts.last, token.range(of: "^[A-Za-z0-9]{8,32}$", options: .regularExpression) != nil else {
                toast = "El enlace de amistad no es válido."
                return
            }
            if phase == .ready { Task { await acceptFriendLink(token) } } else { pendingFriendToken = token }
            return
        }
        let raw = (url.pathComponents.last.flatMap { $0 == "/" ? nil : $0 } ?? url.host ?? "").uppercased()
        guard raw.hasPrefix("TUTI-") else { return }
        let code = raw
        if activeRoom != nil, let current = currentRoomCode, current == code { return }  // ya estás en esa sala
        if phase == .ready {
            joiningFromLink = true
            Task { try? await join(code: code) }
        } else {
            pendingJoinCode = code
        }
    }
}

/// Diferencia entre el reloj del servidor y el del dispositivo (para temporizadores justos).
@MainActor
final class ClockSync {
    static let shared = ClockSync()
    private(set) var offset: TimeInterval = 0

    var now: Date { Date().addingTimeInterval(offset) }

    func sync() async {
        let t0 = Date()
        guard let server = try? await API.serverNow() else { return }
        let rtt = Date().timeIntervalSince(t0)
        offset = server.timeIntervalSince(t0.addingTimeInterval(rtt / 2))
    }
}
