import SwiftUI
import AuthenticationServices

// MARK: Inicio
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var openRooms = 0
    @State private var friends: [FriendRow] = []
    @State private var showJoin = false
    @State private var error: String?
    @State private var goPublic = false
    @State private var goCreate = false
    @State private var goEditProfile = false
    @State private var showGuest = false

    var body: some View {
        GameList {
            Section {
                VStack(spacing: 18) {
                    LogoView(height: 78)
                        .padding(.top, 2)
                    if let p = app.profile {
                        PlayerHeroCard(profile: p) { goEditProfile = true }
                    }
                    // Protagonista: Jugar (salas públicas), con Tuti asomándose.
                    Button { goPublic = true } label: {
                        HStack(spacing: 8) {
                            Text("Jugar")
                            if openRooms > 0 {
                                Text("\(openRooms) \(openRooms == 1 ? "sala" : "salas")")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .textCase(nil)
                                    .foregroundStyle(Game.ink)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(Game.lemon))
                            }
                        }
                    }
                    .buttonStyle(CandyButtonStyle(color: Game.tangerine, icon: "play.fill", height: 70))
                    .overlay(alignment: .topTrailing) {
                        MascotView(pose: .hello, size: 104)
                            .offset(x: -6, y: -78)
                            .allowsHitTesting(false)
                    }
                    .padding(.top, 54)
                    .accessibilityHint("Ver salas públicas abiertas")
                    // Acciones secundarias: fichas calladas, color solo en el ícono.
                    HStack(spacing: 12) {
                        HomeTile(icon: "plus", title: "Crear sala", tint: Game.lime) { goCreate = true }
                        HomeTile(icon: "number", title: "Con código", tint: Game.lemon) { showJoin = true }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                .listRowBackground(Color.clear)
            }

            if app.isGuest {
                Section {
                    Button { showGuest = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.and.arrow.up.fill").font(.title2).foregroundStyle(Game.lemon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estás jugando como invitado").font(.headline)
                                Text("Guarda tu progreso y desbloquea amigos y perfil.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }

            let onlineFriends = friends.filter { $0.status == "accepted" && $0.isOnline }
            if !app.isGuest {
            Section {
                if onlineFriends.isEmpty {
                    Text("Ninguno de tus amigos está conectado ahora.").foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(onlineFriends) { f in
                                NavigationLink { FriendProfileView(userId: f.userId) } label: {
                                    VStack {
                                        AvatarView(avatar: f.avatar, name: f.username, size: 52)
                                            .overlay(alignment: .bottomTrailing) {
                                                Circle().fill(.green).frame(width: 12, height: 12)
                                                    .overlay(Circle().stroke(.background, lineWidth: 2))
                                            }
                                        Text(f.username).font(.caption).lineLimit(1)
                                    }
                                    .frame(width: 64)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } header: { SectionTitle(text: "Amigos conectados · \(onlineFriends.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
            }
        }
        .gameTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goPublic) { PublicRoomsView() }
        .navigationDestination(isPresented: $goCreate) { RoomConfigView() }
        .navigationDestination(isPresented: $goEditProfile) { EditProfileView() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if app.isGuest {
                    Button { showGuest = true } label: {
                        Label("Invitado", systemImage: "person.crop.circle.badge.questionmark").labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.bold))
                    }
                } else {
                    AvatarView(avatar: app.profile?.avatar ?? "", name: app.profile?.username ?? "", size: 32)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !app.isGuest {
                NavigationLink { NotificationsView() } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if app.unreadNotifications > 0 {
                                Text("\(app.unreadNotifications)")
                                    .font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(4).background(.red, in: Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                }
                .accessibilityLabel("Notificaciones, \(app.unreadNotifications) sin leer")
                }
            }
        }
        .sheet(isPresented: $showGuest) { GuestAccountSheet().gameScreen() }
        .sheet(isPresented: $showJoin) { JoinCodeSheet().gameScreen() }
        .refreshable { await load() }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        async let pr = try? API.publicRooms()
        async let f = app.isGuest ? nil : try? API.friends()
        openRooms = (await pr)?.count ?? openRooms
        friends = await f ?? friends
        await app.refreshProfile()
    }


}

struct MenuRow: View {
    var title: String
    var subtitle: String
    var icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}



// MARK: Unirse con código
struct JoinCodeSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var loading = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var normalized: String {
        let raw = code.uppercased().filter { $0.isLetter || $0.isNumber }
        let body = raw.hasPrefix("TUTI") ? String(raw.dropFirst(4)) : raw
        return "TUTI-" + body.prefix(4)
    }
    private var complete: Bool { normalized.count == 9 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Pide el código al anfitrión o abre el enlace que te compartió.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)

                ZStack {
                    TextField("", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .focused($focused).opacity(0.02)
                    HStack(spacing: 6) {
                        ForEach(Array(normalized.enumerated()), id: \.offset) { _, ch in
                            Text(String(ch))
                                .font(.title2.monospaced().bold())
                                .frame(width: ch == "-" ? 14 : 30, height: 44)
                                .background(ch == "-" ? Color.clear : Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        }
                        ForEach(0..<max(0, 9 - normalized.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)).frame(width: 30, height: 44)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .onTapGesture { focused = true }
                .accessibilityLabel("Código de sala")

                Button {
                    if let s = UIPasteboard.general.string { code = s }
                } label: { Label("Pegar desde portapapeles", systemImage: "doc.on.clipboard") }
                .buttonStyle(.bordered)

                Spacer()
                PrimaryButton(title: "Entrar a la sala", systemImage: "number", loading: loading, color: Game.sky) {
                    loading = true
                    defer { loading = false }
                    do {
                        try await app.join(code: normalized)
                        dismiss()
                    } catch { self.error = friendlyError(error) }
                }
                .disabled(!complete)
            }
            .padding(24)
            .gameTitle("Unirse con código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .onAppear { focused = true }
            .errorAlert($error)
        }
        .presentationDetents([.medium])
    }
}

// MARK: Notificaciones
struct NotificationsView: View {
    @Environment(AppState.self) private var app
    @State private var items: [AppNotification] = []
    @State private var filter = 0
    @State private var error: String?

    private var filtered: [AppNotification] {
        switch filter {
        case 1: items.filter { $0.kind == "room_invite" || $0.kind == "friend_request" }
        case 2: items.filter { $0.kind == "achievement" || $0.kind == "level_up" }
        default: items
        }
    }

    var body: some View {
        GameList {
            GameSegmented(selection: $filter, options: [(0, "Todas"), (1, "Invitaciones"), (2, "Logros")])
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            let today = filtered.filter { Calendar.current.isDateInToday($0.createdAt) }
            let older = filtered.filter { !Calendar.current.isDateInToday($0.createdAt) }
            if !today.isEmpty { GameSection("Hoy") { ForEach(today) { row($0) } } }
            if !older.isEmpty { GameSection("Anteriores") { ForEach(older) { row($0) } } }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("Sin notificaciones", systemImage: "bell.slash", description: Text("Aquí verás invitaciones, solicitudes y logros."))
            }
        }
        .gameTitle("Notificaciones")
        .toolbar {
            NavigationLink("Ajustes") { NotificationPrefsView() }
        }
        .task {
            items = (try? await API.notifications()) ?? []
            try? await API.markAllRead()
            await app.refreshUnread()
        }
        .refreshable { items = (try? await API.notifications()) ?? items }
        .errorAlert($error)
    }

    @ViewBuilder
    private func row(_ n: AppNotification) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(n.kind))
                .frame(width: 36, height: 36)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(n.title).font(.subheadline.weight(n.read ? .regular : .semibold))
                Text([n.body, n.createdAt.formatted(.relative(presentation: .named))].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch n.kind {
            case "room_invite":
                if let code = n.payload?.code {
                    Button("Unirse") {
                        Task { do { try await app.join(code: code) } catch { self.error = friendlyError(error) } }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
            case "friend_request":
                if let uid = n.payload?.userId {
                    NavigationLink("Ver") { FriendProfileView(userId: uid) }.fixedSize()
                }
            default: EmptyView()
            }
        }
        .swipeActions {
            Button("Borrar", role: .destructive) {
                Task { try? await API.deleteNotification(n.id); items.removeAll { $0.id == n.id } }
            }
        }
    }

    private func icon(_ kind: String) -> String {
        switch kind {
        case "room_invite": "envelope.fill"
        case "friend_request": "person.badge.plus"
        case "achievement": "trophy.fill"
        case "level_up": "arrow.up.circle.fill"
        case "results": "flag.checkered"
        case "season": "calendar"
        default: "bell.fill"
        }
    }
}

struct NotificationPrefsView: View {
    @Environment(AppState.self) private var app
    @State private var prefs: [String: Bool] = [:]

    private let items: [(String, String)] = [
        ("invites", "Invitaciones a partidas"), ("friend_requests", "Solicitudes de amistad"),
        ("friends_online", "Amigos que se conectan"), ("results", "Resultados de partidas"),
        ("achievements", "Logros desbloqueados"),
    ]

    var body: some View {
        GameForm {
            Section {
                ForEach(items, id: \.0) { key, label in
                    Toggle(label, isOn: Binding(get: { prefs[key] ?? true }, set: { prefs[key] = $0; save() }))
                }
            } header: { SectionTitle(text: "Notificaciones").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) } footer: {
                Text("Llegan dentro de la app y como notificación push. Si las desactivas en Ajustes de iOS, solo verás los avisos dentro de la app.")
            }
        }
        .gameTitle("Notificaciones")
        .onAppear { prefs = app.profile?.notifPrefs ?? [:] }
    }

    private func save() {
        let p = prefs
        Task {
            try? await API.updateProfile(notifPrefs: p)
            await app.refreshProfile()
        }
    }
}

/// Barra de experiencia con degradado que se llena animada.
struct XPBar: View {
    var progress: Double
    @State private var shown = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.fill.tertiary)
                Capsule().fill(LinearGradient(colors: [Game.lemon, Game.lime], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * shown))
            }
        }
        .frame(height: 10)
        .onAppear { withAnimation(.spring(duration: 1.0, bounce: 0.3).delay(0.2)) { shown = min(1, max(0, progress)) } }
        .onChange(of: progress) { _, p in withAnimation(.spring(duration: 0.8)) { shown = min(1, max(0, p)) } }
        .accessibilityElement()
        .accessibilityValue("\(Int(progress * 100)) por ciento")
    }
}

// MARK: Logo y tarjeta del jugador
/// Logotipo (imagen `logo_wordmark` si existe; si no, texto con contorno).
struct LogoView: View {
    var height: CGFloat = 90
    @State private var pop = false

    var body: some View {
        Group {
            if UIImage(named: "logo_wordmark") != nil {
                Image("logo_wordmark").resizable().scaledToFit().frame(height: height)
                    .overlay(alignment: .bottomTrailing) {
                        Image("logo_badge").resizable().scaledToFit().frame(height: height * 0.36)
                            .rotationEffect(.degrees(-8))
                            .offset(x: height * 0.05, y: height * 0.18)
                    }
            } else {
                OutlinedTitle(text: "Tutifruti", size: height * 0.5, fill: Game.lemon)
            }
        }
        .scaleEffect(pop ? 1 : 0.85)
        .rotationEffect(.degrees(pop ? 0 : -4))
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.6)) { pop = true } }
        .accessibilityLabel("Tutifruti AI")
    }
}

/// Avatar grande con nivel y barra de experiencia.
struct PlayerHeroCard: View {
    var profile: Profile
    var onEdit: () -> Void

    var body: some View {
        GamePanel(padding: 12) {
            HStack(spacing: 14) {
                Button(action: onEdit) {
                    AvatarView(avatar: profile.avatar, name: profile.username, size: 62)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil").font(.system(size: 11, weight: .black))
                                .foregroundStyle(Game.ink).frame(width: 22, height: 22)
                                .background(Circle().fill(Game.lemon))
                                .offset(x: 3, y: 3)
                        }
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityLabel("Editar perfil")
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("¡Hola, \(profile.username)!")
                            .font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 4)
                        Text("Nv \(profile.level)")
                            .font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Game.lemon)
                    }
                    XPBar(progress: Double(profile.xp) / Double(max(1, profile.xpForNext)))
                    Text("\(profile.xp) / \(profile.xpForNext) XP").font(.caption2.weight(.heavy)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}

/// Ficha secundaria del inicio: panel translúcido con el color solo en el ícono.
struct HomeTile: View {
    var icon: String
    var title: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Game.onFill(tint))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(tint))
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Game.panel))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Game.panelStroke, lineWidth: 1.5))
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: Cuenta de invitado
/// Explica el modo invitado: guardar el progreso (vinculando Apple) o salir y borrar la cuenta temporal.
struct GuestAccountSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var confirmLeave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MascotView(pose: .think, size: 150)
                    OutlinedTitle(text: "Modo invitado", size: 26)
                    Text("Puedes jugar sin cuenta, pero tu partida vive solo en este dispositivo: si sales o borras la app, se pierde. Sin cuenta tampoco hay amigos ni perfil.")
                        .font(.callout.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                    GamePanel {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(["Guarda tu nombre, avatar, nivel y logros", "Agrega amigos e invítalos a tus salas",
                                     "Entra desde cualquier iPhone"], id: \.self) { t in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Game.lime)
                                    Text(t).foregroundStyle(.white)
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    SignInWithAppleButton(.continue) { app.prepareAppleRequest($0) } onCompletion: { result in
                        Task {
                            do { try await app.upgradeGuestWithApple(result); if !app.isGuest { dismiss() } }
                            catch { self.error = friendlyError(error) }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Game.ink, lineWidth: 2.5))
                    Text("Guardar con Apple conserva todo lo que jugaste como invitado.")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Button("Salir del modo invitado") { confirmLeave = true }
                        .buttonStyle(CandyButtonStyle(color: Game.cherry, icon: "rectangle.portrait.and.arrow.right", height: 50))
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
        }
        .overlay {
            if confirmLeave {
                GameDialog(title: "Salir", message: "Se borrará tu partida de invitado (nombre, nivel y logros). ¿Continuar?",
                           mascot: .bye,
                           onConfirm: { confirmLeave = false; Task { await app.leaveGuestMode(); dismiss() } },
                           onCancel: { confirmLeave = false })
            }
        }
        .errorAlert($error)
    }
}
