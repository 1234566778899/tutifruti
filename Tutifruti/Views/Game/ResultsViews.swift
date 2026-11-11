import SwiftUI
import Charts

// MARK: Resultados de la ronda
struct RoundResultsView: View {
    @Bindable var game: GameStore
    @State private var mode = 0
    @State private var playerIndex = 0
    @State private var detail: Answer?
    @State private var resolvedDispute: Dispute?
    @State private var seenDisputes: Set<UUID> = []
    private let reactionKeys = Reactions.all

    var body: some View {
        let r = game.currentRound
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MyRoundHero(game: game)
                RoundStandings(game: game)
                GameSegmented(selection: $mode, options: [(0, "Mis respuestas"), (1, "Todas")])
                if mode == 0 {
                    let mine = game.roundAnswers.filter { $0.userId == game.me }
                        .sorted { (game.categories.firstIndex(of: $0.category) ?? 0) < (game.categories.firstIndex(of: $1.category) ?? 0) }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Array(mine.enumerated()), id: \.element.id) { i, a in
                            Button { detail = a } label: { MyAnswerCard(answer: a) }
                                .buttonStyle(BouncyButtonStyle())
                                .popIn(i)
                        }
                    }
                    Text("Toca una respuesta para ver la explicación del árbitro o impugnarla.")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.55))
                } else {
                    ForEach(game.categories, id: \.self) { cat in
                        GamePanel(padding: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(cat.uppercased()).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(Game.lemon)
                                    Spacer()
                                    reactionBar(cat)
                                }
                                ForEach(game.answers(for: cat)) { a in
                                    Button { detail = a } label: { CompactAnswerRow(answer: a, player: game.player(a.userId), me: game.me) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                if r?.validatedByAi == false {
                    Label("Árbitro IA no disponible: se aplicó la validación básica (letra correcta).", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .gameTitle("Ronda \(r?.number ?? 1)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ReadyBar(game: game, isLast: (r?.number ?? 0) >= (game.room?.roundsTotal ?? 0))
        }
        .sheet(item: $detail) { a in
            AnswerDetailSheet(game: game, answer: a).gameScreen()
        }
        .alert(resolvedDispute?.status == "accepted" ? "Impugnación aceptada" : "Impugnación rechazada",
               isPresented: Binding(get: { resolvedDispute != nil }, set: { if !$0 { resolvedDispute = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            if let d = resolvedDispute {
                Text((d.resolution ?? "") + (d.pointsDelta != 0 ? "\n\(d.pointsDelta > 0 ? "+" : "")\(d.pointsDelta) pts" : ""))
            }
        }
        .onChange(of: game.disputes) { _, list in
            if let d = list.first(where: { $0.userId == game.me && $0.status != "pending" && !seenDisputes.contains($0.id) }) {
                seenDisputes.insert(d.id)
                resolvedDispute = d
            }
        }
        .onAppear {
            seenDisputes = Set(game.disputes.filter { $0.status != "pending" }.map(\.id))
        }
        .task(id: game.loadedResultsFor) { await playMyResult() }
        .onChange(of: resolvedDispute) { _, d in
            guard let d else { return }
            Sfx.play(d.status == "accepted" ? .valid : .invalid)
        }
    }

    /// Suena cada una de mis respuestas (válida/inválida) y luego las monedas de los puntos.
    private func playMyResult() async {
        guard game.loadedResultsFor != nil, let me = game.me else { return }
        try? await Task.sleep(for: .milliseconds(450))
        let mine = game.roundAnswers.filter { $0.userId == me }
        for a in mine.prefix(8) {
            switch a.status {
            case "valid": Sfx.play(.valid, volume: 0.7)
            case "doubtful": Sfx.play(.doubtful, volume: 0.7)
            default: Sfx.play(.invalid, volume: 0.5)
            }
            try? await Task.sleep(for: .milliseconds(170))
        }
        if game.points(of: me) > 0 { Sfx.play(.coin) }
    }

    @ViewBuilder
    private func reactionBar(_ cat: String) -> some View {
        let rs = game.reactions.filter { $0.category == cat }
        HStack(spacing: 2) {
            ForEach(reactionKeys, id: \.self) { e in
                let count = rs.filter { Reactions.key(for: $0.emoji) == e }.count
                let mine = rs.contains { Reactions.key(for: $0.emoji) == e && $0.userId == game.me }
                Button {
                    Sfx.play(.tap, volume: 0.6)
                    Task { await game.react(category: cat, emoji: e) }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: Reactions.symbol(e))
                            .symbolEffect(.bounce, value: count)
                            .foregroundStyle(mine ? Reactions.color(e) : .white.opacity(0.45))
                        if count > 0 { Text("\(count)").font(.caption2.bold()).monospacedDigit().foregroundStyle(.white) }
                    }
                    .font(.caption)
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .background(mine ? Reactions.color(e).opacity(0.2) : Color.clear, in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Reaccionar \(Reactions.name(e))")
            }
        }
    }
}

struct AnswerRow: View {
    var answer: Answer
    var player: RoomPlayer?
    var me: UUID?

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(avatar: player?.avatar ?? "", name: player?.name ?? "", size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(answer.displayValue).font(.body.weight(.medium))
                    .foregroundStyle(answer.value.isEmpty ? .secondary : .primary)
                Text((player?.name ?? "jugador") + (answer.userId == me ? " (tú)" : "")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if answer.disputed { Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange) }
            StatusBadge(status: answer.status)
            Text(answer.status == "doubtful" ? "—" : "\(answer.points)")
                .font(.body.weight(.semibold)).monospacedDigit().frame(width: 28, alignment: .trailing)
                .overlay(alignment: .top) { if answer.points > 0 && answer.userId == me { FloatingPoints(points: answer.points) } }
        }
        .accessibilityElement(children: .combine)
    }
}

struct Podium: View {
    var entries: [(RoomPlayer, Int)]
    var me: UUID?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(order, id: \.self) { i in
                if i < entries.count {
                    let (p, pts) = entries[i]
                    VStack(spacing: 6) {
                        AvatarView(avatar: p.avatar, name: p.name, size: i == 0 ? 60 : 46)
                            .overlay(alignment: .top) {
                                if i == 0 {
                                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                        .shadow(color: .orange, radius: 2).offset(y: -16)
                                        .symbolEffect(.bounce, value: risen)
                                }
                            }
                            .popIn(3 - i)
                        CountingText(value: risen ? pts : 0, font: .title3.bold())
                        Text(p.userId == me ? "\(p.name) (tú)" : p.name).font(.caption).lineLimit(1)
                        Text("\(i + 1)º")
                            .font(.headline.weight(.heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: risen ? [86, 60, 42][i] : 8)
                            .background(LinearGradient(colors: [[Brand.yellow, Brand.orange], [Color(white: 0.8), Color(white: 0.6)], [Brand.orange.opacity(0.8), .brown]][i],
                                                       startPoint: .top, endPoint: .bottom),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.top, 18)
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.35).delay(0.15)) { risen = true } }
    }

    @State private var risen = false
    private var order: [Int] { [1, 0, 2] }
}

// MARK: Detalle de respuesta
struct AnswerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: GameStore
    var answer: Answer
    @State private var showDispute = false
    @State private var showReport = false

    private var current: Answer { game.roundAnswers.first { $0.id == answer.id } ?? answer }
    private var dispute: Dispute? { game.dispute(for: current) }
    private var isMine: Bool { current.userId == game.me }

    var body: some View {
        NavigationStack {
            GameList {
                Section {
                    HStack {
                        StatusBadge(status: current.status)
                        if let l = game.currentRound?.letter {
                            Label("Letra \(l)", systemImage: current.checks?.letter == false ? "xmark" : "checkmark").font(.subheadline)
                        }
                        Spacer()
                        if let dispute { StatusBadge(status: dispute.status, label: dispute.status == "pending" ? "En revisión" : nil) }
                    }
                }
                GameSection("Explicación del árbitro IA") {
                    Text(current.reason ?? "Sin explicación.")
                }
                if let c = current.checks {
                    Section {
                        check("Empieza con la letra \(game.currentRound?.letter ?? "")", c.letter)
                        check("Pertenece a la categoría", c.category)
                        check("Palabra real en español", c.realWord)
                        check("Sin errores ortográficos", c.spelling)
                    }
                }
                if let dispute, dispute.status != "pending" {
                    GameSection("Segunda evaluación") {
                        Text(dispute.resolution ?? "")
                        if dispute.pointsDelta != 0 {
                            Text("\(dispute.pointsDelta > 0 ? "+" : "")\(dispute.pointsDelta) pts").bold()
                        }
                    }
                }
                Section {
                    if !current.disputed {
                        Button("Impugnar evaluación", systemImage: "flag") { showDispute = true }
                            .disabled((game.myPlayer?.disputesLeft ?? 0) <= 0)
                    }
                    if !isMine {
                        Button("Reportar jugador", systemImage: "exclamationmark.bubble", role: .destructive) { showReport = true }
                    }
                } footer: {
                    Text("Te quedan \(game.myPlayer?.disputesLeft ?? 0) impugnaciones en esta partida.")
                }
            }
            .gameTitle("\(current.category) · \"\(current.value.isEmpty ? "—" : current.value)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .navigationDestination(isPresented: $showDispute) { DisputeView(game: game, answer: current) }
            .navigationDestination(isPresented: $showReport) {
                ReportPlayerView(userId: current.userId, name: game.player(current.userId)?.name ?? "", roomId: game.roomId, code: game.room?.code)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func check(_ label: String, _ value: Bool?) -> some View {
        LabeledContent(label) {
            Image(systemName: value == nil ? "minus.circle" : (value! ? "checkmark.circle.fill" : "xmark.circle.fill"))
                .foregroundStyle(value == nil ? Color.orange : (value! ? Color.green : Color.red))
        }
    }
}

// MARK: Impugnar respuesta
struct DisputeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: GameStore
    var answer: Answer
    @State private var kind = "my_valid"
    @State private var justification = ""
    @State private var loading = false
    @State private var error: String?

    private var isMine: Bool { answer.userId == game.me }

    var body: some View {
        GameForm {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("\(answer.category) · \"\(answer.value)\"").font(.headline); Spacer(); StatusBadge(status: answer.status) }
                    Text("Jugador: \(game.player(answer.userId)?.name ?? "") · Letra \(game.currentRound?.letter ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            GameSection("¿Qué quieres impugnar?") {
                Picker("Motivo", selection: $kind) {
                    if isMine {
                        Text("Mi respuesta debió ser válida").tag("my_valid")
                        Text("No debió contarse como duplicada").tag("not_duplicate")
                    } else {
                        Text("La respuesta de otro jugador es inválida").tag("other_invalid")
                    }
                }
                .pickerStyle(.inline).labelsHidden()
            }
            Section {
                TextField("Mago es una profesión reconocida: ilusionista de espectáculos.", text: $justification, axis: .vertical)
                    .lineLimit(3...6)
            } header: { SectionTitle(text: "Justificación").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) } footer: {
                Label("Una segunda IA evaluará de forma independiente. Solo puedes impugnar una vez cada respuesta.", systemImage: "info.circle")
            }
            Section {
                PrimaryButton(title: "Enviar impugnación", systemImage: "flag.fill", loading: loading) { await send() }
                    .disabled(justification.trimmingCharacters(in: .whitespaces).count < 5)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
        }
        .gameTitle("Impugnar")
        .onAppear { kind = isMine ? "my_valid" : "other_invalid" }
        .errorAlert($error)
    }

    private func send() async {
        loading = true
        defer { loading = false }
        do {
            let id = try await API.submitDispute(round: answer.roundId, target: answer.userId, category: answer.category,
                                                 kind: kind, justification: justification)
            _ = try await API.resolveDispute(id)
            await game.refresh()
            await game.loadResults(answer.roundId, force: true)
            dismiss()
        } catch { self.error = friendlyError(error) }
    }
}

// MARK: Reportar jugador
struct ReportPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    var userId: UUID
    var name: String
    var roomId: UUID?
    var code: String?
    @State private var reason = "Lenguaje ofensivo en el chat"
    @State private var details = ""
    @State private var mute = true
    @State private var loading = false
    @State private var sent = false
    @State private var error: String?
    private let reasons = ["Lenguaje ofensivo en el chat", "Nombre de usuario inapropiado", "Abandona partidas a propósito", "Sospecha de trampa", "Otro"]

    var body: some View {
        GameForm {
            Section {
                LabeledContent(name) { if let code { Text("Partida \(code)") } }
            }
            GameSection("Motivo") {
                Picker("Motivo", selection: $reason) { ForEach(reasons, id: \.self) { Text($0) } }
                    .pickerStyle(.inline).labelsHidden()
            }
            GameSection("Detalles (opcional)") {
                TextField("Describe lo ocurrido", text: $details, axis: .vertical).lineLimit(3...6)
            }
            Section { Toggle("Silenciar a este jugador", isOn: $mute) }
            Section {
                PrimaryButton(title: "Enviar reporte", systemImage: "exclamationmark.bubble.fill", role: .destructive, loading: loading) {
                    loading = true
                    defer { loading = false }
                    do { try await API.report(user: userId, room: roomId, reason: reason, details: details, mute: mute); sent = true }
                    catch { self.error = friendlyError(error) }
                }
                .tint(.red)
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
        }
        .gameTitle("Reportar")
        .alert("Reporte enviado", isPresented: $sent) { Button("OK") { dismiss() } } message: {
            Text("Gracias. Nuestro equipo lo revisará.")
        }
        .errorAlert($error)
    }
}

// MARK: Clasificación final
struct FinalStandingsView: View {
    @Environment(AppState.self) private var app
    @Bindable var game: GameStore
    @State private var unlocked: [Achievement] = []
    @State private var showLevelUp = false
    @State private var loading = false
    @State private var error: String?

    private var ranking: [RoomPlayer] { game.players.sorted { ($0.finalRank ?? 99, -$0.score) < ($1.finalRank ?? 99, -$1.score) } }
    private var winners: [RoomPlayer] { ranking.filter { $0.finalRank == 1 } }
    private var iWon: Bool { winners.contains { $0.userId == game.me } }
    @State private var confetti = 0

    var body: some View {
        GameList {
            Section {
                VStack(spacing: 10) {
                    if let w = winners.first {
                        MascotView(pose: iWon ? .party : .hello, size: 130)
                        AvatarView(avatar: w.avatar, name: w.name, size: 80)
                            .overlay(alignment: .top) {
                                Image(systemName: "crown.fill").font(.title2).foregroundStyle(.yellow)
                                    .shadow(color: .orange, radius: 3).offset(y: -22)
                                    .symbolEffect(.bounce.up, value: confetti)
                            }
                            .popIn(1)
                        Text(winners.count > 1 ? (iWon ? "¡Empate!" : "Empate") : (iWon ? "¡Ganaste!" : "\(w.name) gana"))
                            .font(.system(.largeTitle, design: .rounded).weight(.black))
                            .foregroundStyle(Game.lemon)
                            .popIn(2)
                        Text(winners.count > 1 ? "\(winners.map(\.name).joined(separator: " y ")) · \(w.score) pts"
                                                : "\(w.score) pts · \(game.room?.roundsTotal ?? 0) \(game.room?.roundsTotal == 1 ? "ronda" : "rondas")")
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            GameSection("Clasificación") {
                ForEach(ranking) { p in
                    HStack {
                        Text("\(p.finalRank ?? 0)").font(.headline).monospacedDigit().frame(width: 24)
                        AvatarView(avatar: p.avatar, name: p.name, size: 32)
                        Text(p.name + (p.userId == game.me ? " (tú)" : ""))
                        if p.leftAt != nil { Text("abandonó").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("\(p.score) pts").monospacedDigit().fontWeight(.semibold)
                    }
                }
            }
            GameSection("Recompensas") {
                HStack {
                    Image(systemName: "star.circle.fill").foregroundStyle(.yellow).symbolEffect(.bounce, value: confetti)
                    Text("+")
                    CountingText(value: game.myPlayer?.xpGained ?? 0, font: .body.bold(), sound: true)
                    Text("XP")
                }
                ForEach(Array(unlocked.enumerated()), id: \.element.id) { i, a in
                    Label("Logro: \(a.title)", systemImage: a.icon).symbolRenderingMode(.multicolor).popIn(i)
                }
            }
            Section {
                NavigationLink { GameStatsView(game: game) } label: { Label("Ver estadísticas", systemImage: "chart.bar.fill") }
            }
            Section {
                PrimaryButton(title: "Volver a jugar", systemImage: "arrow.clockwise", loading: loading) { await playAgain() }
                Button("Ir al inicio") {
                    Task { await game.stop(); app.activeRoom = nil; await app.refreshProfile() }
                }
                .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
        }
        .gameTitle("Fin de la partida")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { ConfettiView(trigger: confetti, count: 140) }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            if iWon { Sfx.play(.win); confetti += 1 } else if (game.myPlayer?.finalRank ?? 9) <= 3 { Sfx.play(.win, volume: 0.6) } else { Sfx.play(.lose) }
        }
        .task {
            await app.refreshProfile()
            if let start = app.levelAtGameStart, let now = app.profile?.level, now > start {
                showLevelUp = true
                app.levelAtGameStart = now
            }
            guard let me = game.me, let created = game.room?.createdAt else { return }
            async let all = try? API.achievements()
            async let mine = try? API.userAchievements(me)
            let ids = Set((await mine ?? []).filter { $0.unlockedAt >= created }.map(\.achievementId))
            unlocked = (await all ?? []).filter { ids.contains($0.id) }
        }
        .sheet(isPresented: $showLevelUp) { LevelUpSheet(level: app.profile?.level ?? 1).gameScreen() }
        .errorAlert($error)
    }

    private func playAgain() async {
        loading = true
        defer { loading = false }
        do {
            let id: UUID
            id = try await API.rematch(game.roomId).id
            await game.stop()
            app.activeRoom = nil
            try? await Task.sleep(for: .milliseconds(450))
            app.enterRoom(id)
        } catch { self.error = friendlyError(error) }
    }
}

// MARK: Estadísticas de la partida
struct GameStatsView: View {
    @Bindable var game: GameStore
    @State private var answers: [Answer] = []

    private var mine: [Answer] { answers.filter { $0.userId == game.me } }
    private var valid: Int { mine.filter { $0.status == "valid" }.count }
    private var unique: Int { mine.filter { $0.points == 10 }.count }
    private var perRound: [(String, Int)] {
        game.rounds.map { r in ("R\(r.number)", mine.filter { $0.roundId == r.id }.reduce(0) { $0 + $1.points }) }
    }
    private var original: [Answer] {
        Array(answers.filter { $0.points == 10 }.shuffled().prefix(3))
    }

    var body: some View {
        GameList {
            Section {
                HStack {
                    StatTile(value: "\(valid)/\(mine.count)", label: "Válidas")
                    StatTile(value: mine.isEmpty ? "0 %" : "\(Int(Double(valid) / Double(mine.count) * 100)) %", label: "Aciertos")
                    StatTile(value: "\(unique)", label: "Únicas")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            GameSection("Puntos por ronda") {
                Chart(perRound, id: \.0) { item in
                    BarMark(x: .value("Ronda", item.0), y: .value("Puntos", item.1))
                        .foregroundStyle(Color.accentColor)
                        .annotation(position: .top) { Text("\(item.1)").font(.caption2) }
                }
                .frame(height: 180)
                .padding(.vertical, 8)
            }
            GameSection("Respuestas más originales") {
                ForEach(original) { a in
                    let r = game.rounds.first { $0.id == a.roundId }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(a.value).font(.headline)
                            Text("\(a.userId == game.me ? "tú" : game.player(a.userId)?.name ?? "") · \(a.category) · \(r?.letter ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: "valid", label: "Única")
                    }
                }
            }
        }
        .gameTitle("Estadísticas")
        .task { answers = (try? await API.answers(rounds: game.rounds.map(\.id))) ?? [] }
    }
}

// MARK: Subiste de nivel
struct LevelUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    var level: Int
    @State private var popped = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                SunburstView().frame(width: 260, height: 260)
                Text("\(level)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 140)
                    .background(Brand.gradient, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4).padding(6))
                    .shadow(color: Brand.pink.opacity(0.5), radius: 14, y: 6)
                    .scaleEffect(popped ? 1 : 0.3)
                    .rotationEffect(.degrees(popped ? 0 : -30))
            }
            .frame(height: 170)
            Text("¡Subiste a nivel \(level)!").font(.title.bold())
            Text("Desbloqueaste la insignia Nivel \(level)\(level % 5 == 0 ? " y un tema nuevo" : "").")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            PrimaryButton(title: "¡Genial!", systemImage: "star.fill") { dismiss() }
            if level % 5 == 0 {
                Button("Equipar tema") {
                    Task { try? await API.updateProfile(theme: "pizarra"); await app.refreshProfile(); dismiss() }
                }
            }
        }
        .padding(28)
        .overlay { ConfettiView(trigger: popped ? 1 : 0, count: 110) }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: popped)
        .onAppear {
            Sfx.play(.levelup)
            withAnimation(.spring(duration: 0.7, bounce: 0.55)) { popped = true }
        }
    }
}

// MARK: Barra "Listo para continuar"
/// Cada jugador marca "Listo"; la partida sigue cuando todos los conectados lo están.
struct ReadyBar: View {
    @Bindable var game: GameStore
    var isLast: Bool
    @State private var busy = false

    var body: some View {
        let waiting = game.playersToWait
        let readyCount = waiting.filter { game.readyIds.contains($0.userId) }.count
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(waiting) { p in
                        let ok = game.readyIds.contains(p.userId)
                        AvatarView(avatar: p.avatar, name: p.name, size: 30)
                            .overlay(alignment: .bottomTrailing) {
                                if ok {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption).foregroundStyle(.white, .green)
                                        .background(Circle().fill(.background))
                                        .offset(x: 3, y: 3)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .opacity(ok ? 1 : 0.45)
                            .animation(.spring(duration: 0.35, bounce: 0.5), value: ok)
                    }
                }
                Text(game.everyoneReady ? "¡Todos listos!" : "\(readyCount) de \(waiting.count) listos")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy)).monospacedDigit().foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
            }
            .accessibilityElement(children: .combine)

            Button {
                Task {
                    busy = true
                    await game.toggleReady()
                    busy = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: game.iAmReady ? "checkmark.circle.fill" : (isLast ? "trophy.fill" : "play.fill"))
                        .symbolEffect(.bounce, value: game.iAmReady)
                    Text(title)
                }
            }
            .buttonStyle(CandyButtonStyle(color: game.iAmReady ? Game.lime : Game.lemon))
            .disabled(busy)
            .accessibilityHint(game.iAmReady ? "Toca para dejar de estar listo" : "La partida sigue cuando todos estén listos")
        }
        .padding(.horizontal).padding(.top, 22).padding(.bottom, 8)
        .background(LinearGradient(colors: [Game.night.opacity(0), Game.night], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.22)))
        .onChange(of: readyCount) { old, new in if new > old { Sfx.play(.join, volume: 0.6) } }
    }

    private var title: String {
        if game.iAmReady { return "Listo · esperando a los demás" }
        return isLast ? "Listo para ver la clasificación" : "Listo para la siguiente ronda"
    }
}

// MARK: Piezas de resultados

/// Color y texto por estado de respuesta.
enum AnswerStyle {
    static func color(_ status: String) -> Color {
        switch status {
        case "valid": Game.lime
        case "doubtful": Game.tangerine
        case "invalid": Game.cherry
        default: .gray
        }
    }
    static func icon(_ status: String) -> String {
        switch status {
        case "valid": "checkmark"
        case "doubtful": "questionmark"
        case "invalid": "xmark"
        default: "minus"
        }
    }
    static func points(_ a: Answer) -> String {
        if a.status == "doubtful" { return "—" }
        return a.points > 0 ? "+\(a.points)" : "0"
    }
    static func detail(_ a: Answer) -> String {
        switch a.status {
        case "valid": a.points >= 10 ? "Única" : "Repetida"
        case "doubtful": "Dudosa"
        case "invalid": "Inválida"
        default: "Vacía"
        }
    }
}

/// Encabezado: tus puntos de la ronda, tu puesto y Tuti reaccionando.
struct MyRoundHero: View {
    @Bindable var game: GameStore

    var body: some View {
        let ranking = game.roundRanking
        let myPts = game.me.map { game.points(of: $0) } ?? 0
        // Puesto con empates: 1 + cuántos hicieron más puntos que yo.
        let pos = 1 + ranking.filter { $0.points > myPts }.count
        let top = ranking.first?.points ?? 0
        let mine = game.roundAnswers.filter { $0.userId == game.me }
        let valid = mine.filter { $0.status == "valid" }.count
        let unique = mine.filter { $0.points >= 10 }.count
        let pose: MascotPose = myPts == 0 ? .sad : (myPts >= top ? .party : .hello)
        GamePanel(padding: 14) {
            HStack(spacing: 12) {
                MascotView(pose: pose, size: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTA RONDA").font(.caption.weight(.black)).foregroundStyle(.white.opacity(0.6))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("+").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(Game.lemon)
                        CountingText(value: myPts, font: .system(size: 44, weight: .black, design: .rounded), sound: false)
                            .foregroundStyle(Game.lemon)
                        Text("pts").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Game.lemon.opacity(0.8))
                    }
                    let tied = ranking.filter { $0.points == myPts }.count > 1
                    Text("\(pos)º\(tied ? " (empate)" : "") de \(ranking.count) · \(valid) válidas · \(unique) únicas")
                        .font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Clasificación compacta: puesto, avatar, puntos de la ronda y total.
struct RoundStandings: View {
    @Bindable var game: GameStore

    var body: some View {
        let ranking = game.roundRanking
        GamePanel(padding: 10) {
            VStack(spacing: 6) {
                ForEach(Array(ranking.enumerated()), id: \.element.player.id) { i, e in
                    let isMe = e.player.userId == game.me
                    let place = 1 + ranking.filter { $0.points > e.points }.count
                    HStack(spacing: 10) {
                        Text("\(place)").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(place == 1 ? Game.ink : .white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(place == 1 ? Game.lemon : Color.white.opacity(0.1)))
                        AvatarView(avatar: e.player.avatar, name: e.player.name, size: 34)
                        Text(e.player.name + (isMe ? " (tú)" : ""))
                            .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(.white).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("+\(e.points)").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Game.lemon)
                            .monospacedDigit()
                        Text("\(e.player.score)").font(.caption.weight(.heavy)).monospacedDigit().foregroundStyle(.white.opacity(0.55))
                            .frame(minWidth: 30, alignment: .trailing)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isMe ? Game.lemon.opacity(0.12) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isMe ? Game.lemon.opacity(0.5) : .clear, lineWidth: 1.5))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(place)º \(e.player.name), \(e.points) puntos en la ronda, \(e.player.score) en total")
                }
                HStack {
                    Spacer()
                    Text("ronda · total").font(.caption2.weight(.heavy)).foregroundStyle(.white.opacity(0.4))
                }
                .padding(.trailing, 8)
            }
        }
    }
}

/// Tarjeta de una respuesta mía: color según el veredicto y puntos.
struct MyAnswerCard: View {
    var answer: Answer

    var body: some View {
        let c = AnswerStyle.color(answer.status)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(answer.category.uppercased()).font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                Spacer(minLength: 2)
                if answer.disputed { Image(systemName: "flag.fill").font(.caption2).foregroundStyle(Game.tangerine) }
            }
            Text(answer.value.isEmpty ? "—" : answer.value)
                .font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                Image(systemName: AnswerStyle.icon(answer.status)).font(.caption2.weight(.black))
                    .foregroundStyle(Game.onFill(c)).frame(width: 18, height: 18).background(Circle().fill(c))
                Text(AnswerStyle.detail(answer)).font(.caption.weight(.heavy)).foregroundStyle(c)
                Spacer(minLength: 2)
                Text(AnswerStyle.points(answer)).font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(answer.points > 0 ? Game.lemon : .white.opacity(0.4))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(c.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(c.opacity(0.55), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(answer.category): \(answer.value.isEmpty ? "vacía" : answer.value), \(AnswerStyle.detail(answer)), \(answer.points) puntos")
    }
}

/// Fila compacta en la vista "Todas".
struct CompactAnswerRow: View {
    var answer: Answer
    var player: RoomPlayer?
    var me: UUID?

    var body: some View {
        let c = AnswerStyle.color(answer.status)
        HStack(spacing: 10) {
            AvatarView(avatar: player?.avatar ?? "", name: player?.name ?? "", size: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(answer.value.isEmpty ? "—" : answer.value)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(answer.value.isEmpty ? .white.opacity(0.4) : .white).lineLimit(1)
                Text((player?.name ?? "jugador") + (answer.userId == me ? " (tú)" : ""))
                    .font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if answer.disputed { Image(systemName: "flag.fill").font(.caption2).foregroundStyle(Game.tangerine) }
            Image(systemName: AnswerStyle.icon(answer.status)).font(.caption2.weight(.black))
                .foregroundStyle(Game.onFill(c)).frame(width: 20, height: 20).background(Circle().fill(c))
            Text(AnswerStyle.points(answer)).font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(answer.points > 0 ? Game.lemon : .white.opacity(0.4))
                .lineLimit(1).fixedSize()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
