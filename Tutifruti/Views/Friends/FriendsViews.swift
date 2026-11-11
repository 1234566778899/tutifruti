import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var app
    @State private var tab = 0
    @State private var friends: [FriendRow] = []
    @State private var activity: [ActivityItem] = []
    @State private var query = ""
    @State private var inviteTo: FriendRow?
    @State private var goAdd = false
    @State private var error: String?

    private var accepted: [FriendRow] {
        friends.filter { $0.status == "accepted" && (query.isEmpty || $0.username.localizedCaseInsensitiveContains(query)) }
    }
    private var received: [FriendRow] { friends.filter { $0.status == "pending" && $0.incoming } }
    private var sent: [FriendRow] { friends.filter { $0.status == "pending" && !$0.incoming } }

    var body: some View {
        GameList {
            GameSegmented(selection: $tab, options: [(0, "Amigos"), (1, received.isEmpty ? "Solicitudes" : "Solicitudes (\(received.count))"), (2, "Actividad")])
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

            switch tab {
            case 0:
                let online = accepted.filter { $0.isOnline }
                let offline = accepted.filter { !$0.isOnline }
                if accepted.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            GameEmptyState(pose: .hello, title: query.isEmpty ? "Aún no tienes amigos" : "Sin resultados",
                                           message: query.isEmpty ? "Comparte tu enlace de amistad o búscalos por su nombre de usuario." : nil)
                            if query.isEmpty {
                                FriendLinkCard()
                                Button("Buscar por nombre") { goAdd = true }
                                    .buttonStyle(CandyButtonStyle(color: Game.sky, icon: "magnifyingglass", height: 50))
                                    .padding(.horizontal, 30)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    if !online.isEmpty {
                        Section {
                            ForEach(online) { f in friendRow(f) }
                        } header: { SectionTitle(text: "En línea", trailing: "\(online.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
                    }
                    if !offline.isEmpty {
                        Section {
                            ForEach(offline) { f in friendRow(f) }
                        } header: { SectionTitle(text: "Desconectados", trailing: "\(offline.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
                    }
                }
            case 1:
                if received.isEmpty && sent.isEmpty {
                    Section {
                        GameEmptyState(pose: .sleep, title: "Sin solicitudes", message: "Cuando alguien quiera ser tu amigo aparecerá aquí.")
                            .listRowBackground(Color.clear)
                    }
                }
                if !received.isEmpty {
                Section {
                    ForEach(received) { f in
                        HStack(spacing: 12) {
                            AvatarView(avatar: f.avatar, name: f.username, size: 40)
                            VStack(alignment: .leading) {
                                Text(f.username)
                                Text("Nivel \(f.level)" + (f.gamesTogether > 0 ? " · \(f.gamesTogether) partidas juntos" : ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { respond(f, true) } label: { Image(systemName: "checkmark") }
                                .buttonStyle(RoundIconButtonStyle(color: Game.lime, size: 40))
                            Button { respond(f, false) } label: { Image(systemName: "xmark") }
                                .buttonStyle(RoundIconButtonStyle(color: Game.cherry, iconColor: .white, size: 40))
                        }
                    }
                } header: { SectionTitle(text: "Recibidas", trailing: "\(received.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
                }
                if !sent.isEmpty {
                Section {
                    ForEach(sent) { f in
                        HStack(spacing: 12) {
                            AvatarView(avatar: f.avatar, name: f.username, size: 40)
                            VStack(alignment: .leading) { Text(f.username); Text("Pendiente").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button { Task { try? await API.removeFriend(f.userId); await load() } } label: { Image(systemName: "xmark") }
                                .buttonStyle(RoundIconButtonStyle(size: 40))
                        }
                    }
                } header: { SectionTitle(text: "Enviadas", trailing: "\(sent.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
                }
            default:
                Section {
                    if activity.isEmpty {
                        GameEmptyState(pose: .sleep, title: "Todo tranquilo", message: "Aquí verás lo que hacen tus amigos.")
                            .listRowBackground(Color.clear)
                    }
                    ForEach(activity) { a in
                        HStack(spacing: 12) {
                            AvatarView(avatar: a.profile?.avatar ?? "", name: a.profile?.username ?? "", size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("**\(a.profile?.username ?? "")** \(a.text)")
                                Text([a.detail, a.createdAt.formatted(.relative(presentation: .named))].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Buscar en tus amigos")
        .gameTitle("Amigos")
        .navigationDestination(isPresented: $goAdd) { AddFriendView() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { AddFriendView() } label: { Label("Agregar", systemImage: "person.badge.plus") }
            }
        }
        .task(id: app.friendsVersion) { await load() }
        .refreshable { await load() }
        .confirmationDialog("Invitar a \(inviteTo?.username ?? "")", isPresented: Binding(get: { inviteTo != nil }, set: { if !$0 { inviteTo = nil } }), titleVisibility: .visible) {
            Button("Crear sala e invitar") {
                guard let f = inviteTo else { return }
                Task {
                    do {
                        let room = try await API.createRoom(API.RoomSettings())
                        try await API.invite(room.id, users: [f.userId])
                        app.enterRoom(room.id)
                    } catch { self.error = friendlyError(error) }
                }
            }
        } message: {
            Text("Se creará una sala privada con la configuración clásica.")
        }
        .errorAlert($error)
    }

    @ViewBuilder
    private func friendRow(_ f: FriendRow) -> some View {
        NavigationLink { FriendProfileView(userId: f.userId) } label: {
            HStack(spacing: 12) {
                AvatarView(avatar: f.avatar, name: f.username, size: 40)
                    .overlay(alignment: .bottomTrailing) {
                        if f.isOnline { Circle().fill(.green).frame(width: 11, height: 11).overlay(Circle().stroke(.background, lineWidth: 2)) }
                    }
                VStack(alignment: .leading) {
                    Text(f.username)
                    Text("Nivel \(f.level) · \(f.statusText)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if f.playing {
                    StatusBadge(status: "doubtful", label: "Jugando")
                } else if f.isOnline {
                    Button("Invitar") { inviteTo = f }.buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private func respond(_ f: FriendRow, _ accept: Bool) {
        Task {
            do { try await API.respondFriendRequest(f.userId, accept: accept); await load() }
            catch { self.error = friendlyError(error) }
        }
    }

    private func load() async {
        friends = (try? await API.friends()) ?? friends
        activity = (try? await API.activity()) ?? activity
    }
}

struct AddFriendView: View {
    @Environment(AppState.self) private var app
    @State private var query = ""
    @State private var results: [SearchUser] = []
    @State private var error: String?

    var body: some View {
        GameList {
            ForEach(results) { u in
                HStack(spacing: 12) {
                    AvatarView(avatar: u.avatar, name: u.username, size: 40)
                    VStack(alignment: .leading) {
                        Text(u.username)
                        Text("Nivel \(u.level)" + (u.relation == "friends" ? " · Ya son amigos" : "")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    switch u.relation {
                    case "friends": Text("Amigos").foregroundStyle(.secondary)
                    case "sent": Text("Enviada").foregroundStyle(.secondary)
                    case "received":
                        Button("Aceptar") { act { try await API.respondFriendRequest(u.userId, accept: true) } }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    default:
                        Button("Agregar") { act { try await API.sendFriendRequest(u.userId) } }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            Section {
                FriendLinkCard()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .overlay {
            if results.isEmpty && query.count >= 2 { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nombre de usuario")
        .textInputAutocapitalization(.never)
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = query.count >= 2 ? ((try? await API.searchUsers(query.lowercased())) ?? []) : []
        }
        .gameTitle("Agregar amigo")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($error)
    }

    private func act(_ op: @escaping () async throws -> Void) {
        Task {
            do { try await op(); results = (try? await API.searchUsers(query.lowercased())) ?? results }
            catch { self.error = friendlyError(error) }
        }
    }
}

struct FriendProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var userId: UUID
    @State private var profile: Profile?
    @State private var h2h: HeadToHead?
    @State private var relation = "none"
    @State private var confirmRemove = false
    @State private var showReport = false
    @State private var error: String?

    var body: some View {
        GameList {
            if let p = profile, let me = app.profile {
                Section {
                    VStack(spacing: 8) {
                        AvatarView(avatar: p.avatar, name: p.username, size: 88)
                        Text(p.username).font(.title2.bold())
                        Text("Nivel \(p.level)").foregroundStyle(.secondary)
                        if p.isOnline { StatusBadge(status: "valid", label: "En línea") }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                GameSection("Tú vs \(p.username)") {
                    compare("Partidas jugadas", "\(me.gamesPlayed)", "\(p.gamesPlayed)")
                    compare("% victorias", me.winRate.formatted(.percent.precision(.fractionLength(0))), p.winRate.formatted(.percent.precision(.fractionLength(0))))
                    compare("Mejor puntaje", "\(me.bestScore)", "\(p.bestScore)")
                    compare("Duelos entre ustedes", "\(h2h?.duelsMe ?? 0)", "\(h2h?.duelsThem ?? 0)")
                }
                Section {
                    switch relation {
                    case "friends":
                        PrimaryButton(title: "Invitar a una partida", systemImage: "gamecontroller") {
                            do {
                                let room = try await API.createRoom(API.RoomSettings())
                                try await API.invite(room.id, users: [userId])
                                app.enterRoom(room.id)
                            } catch { self.error = friendlyError(error) }
                        }
                    case "received":
                        PrimaryButton(title: "Aceptar solicitud", systemImage: "checkmark", color: Game.lime) {
                            do { try await API.respondFriendRequest(userId, accept: true); await load() } catch { self.error = friendlyError(error) }
                        }
                    case "sent":
                        Text("Solicitud enviada").frame(maxWidth: .infinity).foregroundStyle(.secondary)
                    default:
                        PrimaryButton(title: "Agregar amigo", systemImage: "person.badge.plus") {
                            do { try await API.sendFriendRequest(userId); await load() } catch { self.error = friendlyError(error) }
                        }
                    }
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                if relation == "friends" {
                    Section { Button("Eliminar amigo", role: .destructive) { confirmRemove = true } }
                }
            }
        }
        .gameTitle(profile?.username ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Reportar jugador", systemImage: "exclamationmark.bubble") { showReport = true }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .navigationDestination(isPresented: $showReport) {
            ReportPlayerView(userId: userId, name: profile?.username ?? "", roomId: nil, code: nil)
        }
        .confirmationDialog("¿Eliminar a \(profile?.username ?? "") de tus amigos?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                Task { try? await API.removeFriend(userId); dismiss() }
            }
        }
        .task { await load() }
        .errorAlert($error)
    }

    private func compare(_ label: String, _ mine: String, _ theirs: String) -> some View {
        HStack {
            Text(mine).bold().monospacedDigit().frame(width: 60, alignment: .leading)
            Spacer()
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(theirs).bold().monospacedDigit().frame(width: 60, alignment: .trailing)
        }
    }

    private func load() async {
        profile = try? await API.profile(userId)
        h2h = try? await API.headToHead(userId)
        if let p = profile {
            relation = (try? await API.searchUsers(p.username))?.first { $0.userId == userId }?.relation ?? "none"
        }
    }
}

// MARK: Enlace de amistad

/// Tarjeta para compartir mi enlace de amistad (quien lo abre queda como amigo).
struct FriendLinkCard: View {
    @State private var token: String?
    @State private var loading = false
    @State private var error: String?
    @State private var confirmRenew = false

    var body: some View {
        CreamCard(padding: 14) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image("icon_invite").resizable().scaledToFit().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tu enlace de amistad").font(.system(.headline, design: .rounded).weight(.black))
                        Text("Quien lo abra quedará como tu amigo al instante.").font(.caption.weight(.semibold)).opacity(0.7)
                    }
                    Spacer(minLength: 0)
                }
                if let token {
                    ShareLink(item: Config.friendURL(token: token),
                              subject: Text("¡Seamos amigos en Tutifruti AI!"),
                              message: Text("¡Agrégame como amigo en Tutifruti AI! Toca el enlace:"),
                              preview: SharePreview("Amistad en Tutifruti AI", image: Image("app_logo"))) {
                        Text("Compartir enlace")
                    }
                    .buttonStyle(CandyButtonStyle(color: Game.lime, icon: "square.and.arrow.up.fill", height: 50))
                    Button("Generar un enlace nuevo") { confirmRenew = true }
                        .font(.caption.weight(.heavy)).foregroundStyle(Game.ink.opacity(0.6))
                } else if loading {
                    ProgressView().tint(Game.ink)
                } else {
                    Button("Reintentar") { Task { await load() } }
                        .buttonStyle(CandyButtonStyle(color: Game.sky, icon: "arrow.clockwise", height: 46))
                }
            }
        }
        .task { await load() }
        .confirmationDialog("¿Generar un enlace nuevo?", isPresented: $confirmRenew, titleVisibility: .visible) {
            Button("Generar nuevo") { Task { await load(renew: true) } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El enlace anterior dejará de funcionar.")
        }
        .errorAlert($error)
    }

    private func load(renew: Bool = false) async {
        loading = true
        defer { loading = false }
        do { token = try await API.myFriendInvite(renew: renew) } catch { self.error = friendlyError(error) }
    }
}

/// Se muestra al abrir un enlace de amistad.
struct FriendAddedSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var result: FriendLinkResult
    @State private var pop = false
    @State private var inviting = false
    @State private var error: String?

    private var already: Bool { result.status == "already" }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            HStack(spacing: -14) {
                AvatarView(avatar: app.profile?.avatar ?? "", name: app.profile?.username ?? "", size: 96)
                    .overlay(Circle().strokeBorder(Game.ink, lineWidth: 3))
                    .rotationEffect(.degrees(pop ? -8 : 0))
                Image(systemName: "heart.fill").font(.system(size: 30, weight: .black)).foregroundStyle(Game.cherry)
                    .padding(8).background(Circle().fill(.white)).overlay(Circle().strokeBorder(Game.ink, lineWidth: 2.5))
                    .zIndex(1).scaleEffect(pop ? 1 : 0.2)
                AvatarView(avatar: result.avatar, name: result.username, size: 96)
                    .overlay(Circle().strokeBorder(Game.ink, lineWidth: 3))
                    .rotationEffect(.degrees(pop ? 8 : 0))
            }
            OutlinedTitle(text: already ? "Ya son amigos" : "¡Ahora son amigos!", size: 28)
            Text(already ? "Tú y \(result.username) ya estaban conectados."
                         : "\(result.username) · Nivel \(result.level) ya está en tu lista de amigos.")
                .font(.callout.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 10)
            Button(inviting ? "Creando sala…" : "Invitar a jugar") { Task { await inviteToPlay() } }
                .buttonStyle(CandyButtonStyle(color: Game.lemon, icon: "gamecontroller.fill"))
                .disabled(inviting)
            Button("Listo") { dismiss() }
                .buttonStyle(CandyButtonStyle(color: Game.sky, icon: "checkmark", height: 50))
        }
        .padding(24)
        .overlay { ConfettiView(trigger: pop && !already ? 1 : 0, count: 100) }
        .presentationDetents([.medium, .large])
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.55).delay(0.1)) { pop = true } }
        .errorAlert($error)
    }

    private func inviteToPlay() async {
        inviting = true
        defer { inviting = false }
        do {
            let room = try await API.createRoom(API.RoomSettings())
            try await API.invite(room.id, users: [result.userId])
            dismiss()
            try? await Task.sleep(for: .milliseconds(350))
            app.enterRoom(room.id)
        } catch { self.error = friendlyError(error) }
    }
}
