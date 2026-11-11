import SwiftUI
import PhotosUI
import Supabase

// MARK: Mi perfil
struct ProfileView: View {
    @AppStorage(SoundManager.enabledKey) private var soundOn = true
    @AppStorage(SoundManager.hapticsKey) private var hapticsOn = true
    @Environment(AppState.self) private var app
    @State private var achievements: [Achievement] = []
    @State private var mine: [UserAchievement] = []
    @State private var customCount = 0
    @State private var setCount = 0

    var body: some View {
        GameList {
            if let p = app.profile {
                Section {
                    GamePanel(padding: 16) {
                        VStack(spacing: 8) {
                            AvatarView(avatar: p.avatar, name: p.username, size: 96)
                            Text(p.username).font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(.white)
                            HStack(spacing: 6) {
                                GamePill(text: "Nivel \(p.level)", icon: "star.fill", color: Game.lemon)
                            }
                            XPBar(progress: Double(p.xp) / Double(max(1, p.xpForNext)))
                                .padding(.horizontal, 20).padding(.top, 2)
                            Text("\(p.xp) / \(p.xpForNext) XP").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                Section {
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            StatTile(value: p.totalPoints.formatted(), label: "Puntos", systemImage: "star.fill", tint: Game.lemon)
                            StatTile(value: "\(p.gamesPlayed)", label: "Jugadas", systemImage: "gamecontroller.fill", tint: Game.sky)
                            StatTile(value: "\(p.gamesWon)", label: "Ganadas", systemImage: "trophy.fill", tint: Game.tangerine)
                        }
                        GridRow {
                            StatTile(value: p.winRate.formatted(.percent.precision(.fractionLength(0))), label: "Victorias", systemImage: "percent", tint: Game.lime)
                            StatTile(value: "\(p.bestScore)", label: "Récord", systemImage: "bolt.fill", tint: Game.grape)
                            StatTile(value: "\(p.winStreak)", label: "Racha", systemImage: "flame.fill", tint: Game.cherry)
                        }
                    }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
            }

            Section {
                let recent = mine.prefix(3).compactMap { u in achievements.first { $0.id == u.achievementId } }
                if recent.isEmpty {
                    HStack(spacing: 12) {
                        Image("icon_trophy").resizable().scaledToFit().frame(width: 40, height: 40).saturation(0.2).opacity(0.7)
                        Text("Juega partidas para desbloquear logros.").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    HStack {
                        ForEach(recent) { a in
                            VStack(spacing: 6) {
                                Image(systemName: a.icon).font(.title2).foregroundStyle(Game.lemon)
                                Text(a.title).font(.caption.weight(.bold)).multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } header: {
                HStack {
                    SectionTitle(text: "Logros recientes")
                    NavigationLink("Ver todos") { AchievementsView() }
                        .font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(Game.lemon).textCase(nil)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
            }

            Section {
                NavigationLink { HistoryView() } label: {
                    GameMenuRow(icon: "icon_history", title: "Historial", detail: "\(app.profile?.gamesPlayed ?? 0) partidas")
                }
                NavigationLink { AchievementsView() } label: {
                    GameMenuRow(icon: "icon_trophy", title: "Logros", detail: "\(mine.count) de \(achievements.count) desbloqueados")
                }
                NavigationLink { MyCategoriesView() } label: {
                    GameMenuRow(icon: "icon_categories", title: "Mis categorías", detail: "\(customCount) personalizadas · \(setCount) favoritos")
                }
                NavigationLink { StoreView() } label: { GameMenuRow(icon: "icon_shop", title: "Recompensas", detail: "Avatares y temas") }
            } header: {
                SectionTitle(text: "Tu juego").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
            }

            Section {
                Toggle(isOn: $soundOn) {
                    GameToggleLabel(icon: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", title: "Sonidos", tint: Game.sky)
                }
                .onChange(of: soundOn) { _, on in if on { Sfx.play(.coin) } }
                Toggle(isOn: $hapticsOn) {
                    GameToggleLabel(icon: "iphone.radiowaves.left.and.right", title: "Vibración", tint: Game.grape)
                }
                NavigationLink { NotificationPrefsView() } label: { GameMenuRow(icon: "icon_bell", title: "Notificaciones", detail: "Qué avisos recibir") }
                NavigationLink { RulesView() } label: { GameMenuRow(icon: "icon_rules", title: "Reglas del juego") }
                NavigationLink { AccountView() } label: { GameMenuRow(icon: "icon_gear", title: "Cuenta", detail: "Correo, privacidad, sesión") }
            } header: {
                SectionTitle(text: "Ajustes").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
            }
        }
        .tint(Game.lime)
        .gameTitle("Perfil")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { EditProfileView() } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Editar perfil")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await app.refreshProfile()
        guard let me = API.myId else { return }
        async let a = try? API.achievements()
        async let m = try? API.userAchievements(me)
        async let c = try? API.categories()
        async let s = try? API.categorySets()
        achievements = await a ?? []
        mine = await m ?? []
        customCount = (await c ?? []).filter { $0.kind == "custom" }.count
        setCount = (await s ?? []).count
    }
}

// MARK: Editar perfil
struct EditProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var avatar = ""
    @State private var language = "es"
    @State private var photo: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        GameForm {
            Section {
                VStack(spacing: 10) {
                    AvatarView(avatar: avatar, name: username, size: 88)
                    PhotosPicker(selection: $photo, matching: .images) { Text("Cambiar foto") }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            GameSection("Avatar") { AvatarGrid(selection: $avatar, owned: StoreManager.ownedAvatars(level: app.profile?.level ?? 1)) }
            Section {
                TextField("Nombre de usuario", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                LabeledContent("Correo electrónico", value: supabase.auth.currentUser?.email ?? "—")
                Picker("Idioma de juego", selection: $language) {
                    ForEach(GameLanguage.all, id: \.key) { Text($0.name).tag($0.key) }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Puedes cambiar tu nombre de usuario una vez cada 30 días.", systemImage: "info.circle")
                    Label("Las salas que crees se juegan en tu idioma de juego: la IA valida las respuestas en ese idioma.",
                          systemImage: "globe")
                }
            }
        }
        .gameTitle("Editar perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if loading { ProgressView() } else { Button("Guardar") { Task { await save() } } }
            }
        }
        .onAppear {
            username = app.profile?.username ?? ""
            avatar = app.profile?.avatar ?? ""
            language = app.profile?.language ?? "es"
        }
        .onChange(of: photo) {
            Task {
                guard let photo, let data = try? await photo.loadTransferable(type: Data.self),
                      let img = UIImage(data: data), let jpg = img.resizedSquare(256).jpegData(compressionQuality: 0.8) else { return }
                do { avatar = try await API.uploadAvatar(jpg) } catch { self.error = friendlyError(error) }
            }
        }
        .errorAlert($error)
    }

    private func save() async {
        loading = true
        defer { loading = false }
        do {
            let name = username.lowercased().trimmingCharacters(in: .whitespaces)
            if name != app.profile?.username { _ = try await API.changeUsername(name) }
            try await API.updateProfile(avatar: avatar, language: language)
            await app.refreshProfile()
            dismiss()
        } catch { self.error = friendlyError(error) }
    }
}

// MARK: Cuenta
struct AccountView: View {
    @Environment(AppState.self) private var app
    @State private var confirmDelete = false
    @State private var changePassword = false
    @State private var newPassword = ""
    @State private var error: String?
    @State private var info: String?

    private var provider: String {
        let p = supabase.auth.currentUser?.appMetadata["provider"]?.stringValue ?? "email"
        switch p { case "apple": return "Apple ID"; case "email": return "Correo"; default: return supabase.auth.currentUser?.isAnonymous == true ? "Invitado" : p }
    }

    var body: some View {
        GameForm {
            Section {
                LabeledContent("Método de acceso", value: provider)
                LabeledContent("Correo", value: supabase.auth.currentUser?.email ?? "—")
                if provider == "Correo" { Button("Cambiar contraseña") { changePassword = true } }
                Link("Privacidad y datos", destination: URL(string: "https://tutifruti.site/privacidad")!)
                Link("Términos y condiciones", destination: URL(string: "https://tutifruti.site/terminos")!)
            }
            Section {
                Button("Cerrar sesión") { Task { await app.signOut() } }
                Button("Eliminar cuenta", role: .destructive) { confirmDelete = true }
            }
        }
        .gameTitle("Cuenta")
        .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar cuenta definitivamente", role: .destructive) {
                Task {
                    do { try await API.deleteAccount(); await app.signOut() } catch { self.error = friendlyError(error) }
                }
            }
        } message: {
            Text("Se borrarán tu perfil, historial, amigos y logros. Esta acción no se puede deshacer.")
        }
        .alert("Nueva contraseña", isPresented: $changePassword) {
            SecureField("Mínimo 8 caracteres", text: $newPassword)
            Button("Guardar") {
                let p = newPassword
                newPassword = ""
                Task {
                    guard p.count >= 8 else { error = "La contraseña debe tener al menos 8 caracteres."; return }
                    do { _ = try await supabase.auth.update(user: UserAttributes(password: p)); info = "Contraseña actualizada." }
                    catch { self.error = friendlyError(error) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert(info ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) { Button("OK") {} }
        .errorAlert($error)
    }
}

// MARK: Historial
struct HistoryView: View {
    @State private var filter = "all"
    @State private var rows: [HistoryRow] = []

    var body: some View {
        GameList {
            GameSegmented(selection: $filter, options: [("all", "Todas"), ("public", "Públicas"), ("private", "Privadas")])
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            let groups = Dictionary(grouping: rows) { ($0.finishedAt ?? .distantPast).formatted(.dateTime.month(.wide).year()) }
            ForEach(groups.keys.sorted { (groups[$0]?.first?.finishedAt ?? .distantPast) > (groups[$1]?.first?.finishedAt ?? .distantPast) }, id: \.self) { key in
                Section(key.capitalized) {
                    ForEach(groups[key] ?? []) { h in
                        NavigationLink { GameDetailView(roomId: h.roomId) } label: {
                            HStack(spacing: 12) {
                                Text("\(h.finalRank ?? 0)º").font(.title3.bold()).frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(h.code) · \(h.isPublic ? "Pública" : h.name)").font(.subheadline.weight(.semibold))
                                    Text("\((h.finishedAt ?? .now).formatted(.relative(presentation: .named))) · \(h.players) jugadores · \(h.rounds) rondas")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(h.score) pts").monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .overlay { if rows.isEmpty { ContentUnavailableView("Sin partidas", systemImage: "clock", description: Text("Tus partidas terminadas aparecerán aquí.")) } }
        .gameTitle("Historial")
        .task(id: filter) { rows = (try? await API.history(filter: filter)) ?? [] }
    }
}

struct GameDetailView: View {
    @Environment(AppState.self) private var app
    var roomId: UUID
    @State private var room: Room?
    @State private var players: [RoomPlayer] = []
    @State private var rounds: [Round] = []
    @State private var answers: [Answer] = []
    @State private var error: String?

    var body: some View {
        GameList {
            if let room {
                Section(room.name) {
                    Text("\((room.finishedAt ?? room.createdAt).formatted(date: .abbreviated, time: .shortened)) · \(room.isPublic ? "Pública" : "Sala privada") · \(room.roundsTotal) rondas · \(room.roundSeconds) s")
                        .font(.subheadline)
                    FlowChips(items: room.categories)
                }
                GameSection("Resultado final") {
                    ForEach(players.sorted { ($0.finalRank ?? 99) < ($1.finalRank ?? 99) }) { p in
                        HStack {
                            Text("\(p.finalRank ?? 0)").bold().frame(width: 24)
                            AvatarView(avatar: p.avatar, name: p.name, size: 28)
                            Text(p.name + (p.userId == API.myId ? " (tú)" : ""))
                            Spacer()
                            Text("\(p.score) pts").monospacedDigit()
                        }
                    }
                }
                GameSection("Rondas") {
                    ForEach(rounds) { r in
                        DisclosureGroup {
                            ForEach(answers.filter { $0.roundId == r.id && $0.userId == API.myId }) { a in
                                LabeledContent("\(a.category): \(a.value.isEmpty ? "—" : a.value)") {
                                    HStack { StatusBadge(status: a.status); Text("\(a.points)").monospacedDigit() }
                                }
                            }
                        } label: {
                            LabeledContent("R\(r.number) · Letra \(r.letter)") {
                                Text("\(answers.filter { $0.roundId == r.id && $0.userId == API.myId }.reduce(0) { $0 + $1.points }) pts")
                            }
                        }
                    }
                }
                Section {
                    PrimaryButton(title: "Volver a jugar con esta configuración", systemImage: "arrow.clockwise") {
                        do { app.enterRoom(try await API.rematch(room.id).id) } catch { self.error = friendlyError(error) }
                    }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
            }
        }
        .gameTitle(room?.code ?? "Partida")
        .task {
            room = try? await API.room(roomId)
            players = (try? await API.players(roomId)) ?? []
            rounds = (try? await API.rounds(roomId)) ?? []
            answers = (try? await API.answers(rounds: rounds.map(\.id))) ?? []
        }
        .errorAlert($error)
    }
}

// MARK: Logros
struct AchievementsView: View {
    @Environment(AppState.self) private var app
    var initialTab = 0
    @State private var tab = 0
    @State private var achievements: [Achievement] = []
    @State private var mine: [UserAchievement] = []
    @State private var error: String?

    var body: some View {
        GameList {
            if let p = app.profile {
                Section {
                    HStack(spacing: 14) {
                        Text("\(p.level)").font(.title.bold()).frame(width: 56, height: 56)
                            .background(Color.accentColor.opacity(0.2), in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nivel \(p.level)").font(.headline)
                            ProgressView(value: Double(p.xp), total: Double(p.xpForNext))
                            Text("\(p.xpForNext - p.xp) XP para nivel \(p.level + 1)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            GameSegmented(selection: $tab, options: [(0, "Logros"), (1, "Insignias")])
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            switch tab {
            case 0:
                GameSection("\(mine.count) de \(achievements.count) desbloqueados") {
                    ForEach(achievements) { a in
                        let unlocked = mine.first { $0.achievementId == a.id }
                        HStack(spacing: 12) {
                            Image(systemName: a.icon).font(.title3).frame(width: 32)
                                .foregroundStyle(unlocked != nil ? Color.accentColor : .secondary)
                            VStack(alignment: .leading) {
                                Text(a.title).fontWeight(.medium)
                                Text(a.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: unlocked != nil ? "checkmark.seal.fill" : "lock.fill")
                                .foregroundStyle(unlocked != nil ? .green : .secondary)
                        }
                        .opacity(unlocked != nil ? 1 : 0.6)
                    }
                }
            default:
                GameSection("Insignias de nivel") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(Array(stride(from: 5, through: 50, by: 5)), id: \.self) { lv in
                            let ok = (app.profile?.level ?? 1) >= lv
                            VStack {
                                Image(systemName: ok ? "shield.lefthalf.filled" : "shield")
                                    .font(.largeTitle).foregroundStyle(ok ? Color.accentColor : .secondary)
                                Text("Nivel \(lv)").font(.caption)
                            }
                            .opacity(ok ? 1 : 0.5)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .gameTitle("Logros")
        .onAppear { tab = initialTab }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        guard let me = API.myId else { return }
        achievements = (try? await API.achievements()) ?? []
        mine = (try? await API.userAchievements(me)) ?? []
    }

}

// MARK: Mis categorías
struct MyCategoriesView: View {
    @State private var cats: [Category] = []
    @State private var sets: [CategorySet] = []
    @State private var showNew = false

    var body: some View {
        GameList {
            GameSection("Personalizadas") {
                if cats.isEmpty { Text("Aún no tienes categorías personalizadas.").foregroundStyle(.secondary) }
                ForEach(cats) { c in
                    VStack(alignment: .leading) {
                        Text(c.name)
                        if let d = c.description, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .onDelete { idx in
                    let ids = idx.map { cats[$0].id }
                    Task { for id in ids { try? await API.deleteCategory(id) }; await load() }
                }
            }
            GameSection("Conjuntos favoritos") {
                if sets.isEmpty { Text("Guarda conjuntos desde la pantalla de categorías.").foregroundStyle(.secondary) }
                ForEach(sets) { s in
                    VStack(alignment: .leading) {
                        Text(s.name)
                        Text(s.categories.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { idx in
                    let ids = idx.map { sets[$0].id }
                    Task { for id in ids { try? await API.deleteCategorySet(id) }; await load() }
                }
            }
        }
        .gameTitle("Mis categorías")
        .toolbar { Button("Nueva", systemImage: "plus") { showNew = true } }
        .sheet(isPresented: $showNew) { NewCategorySheet { _ in Task { await load() } } }
        .task { await load() }
    }

    private func load() async {
        cats = ((try? await API.categories()) ?? []).filter { $0.kind == "custom" }
        sets = (try? await API.categorySets()) ?? []
    }
}
