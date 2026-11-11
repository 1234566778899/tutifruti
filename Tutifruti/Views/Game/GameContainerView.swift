import SwiftUI

/// Pantalla completa de una sala: cambia de vista según la fase que dicta el servidor.
struct GameContainerView: View {
    @Environment(AppState.self) private var app
    @State private var game: GameStore
    @State private var confirmLeave = false
    @State private var showChat = false
    @Environment(\.scenePhase) private var scenePhase

    init(roomId: UUID) {
        _game = State(initialValue: GameStore(roomId: roomId))
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // el fondo cubre toda la pantalla en cualquier fase
                .gameScreen()
                .toolbar { toolbar }
                .overlay { if game.isOffline { ReconnectingOverlay(game: game) { leave() } } }
                .overlay(alignment: .top) {
                    if game.reconnecting && !game.isOffline {
                        Label("Reconectando…", systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: game.reconnecting)
                .overlay(alignment: .top) {
                    if let notice = game.notice, !game.reconnecting, !game.isOffline {
                        Label(notice, systemImage: "wifi.exclamationmark")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: game.notice)
                .overlay(alignment: .top) {
                    if let m = game.incomingMessage, !showChat {
                        ChatBanner(message: m, author: m.userId.flatMap { game.player($0) }) {
                            game.incomingMessage = nil
                            showChat = true
                        } onDismiss: {
                            game.incomingMessage = nil
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(m.id)
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.3), value: game.incomingMessage?.id)
                .sensoryFeedback(.impact(weight: .heavy), trigger: game.currentRound?.stopBy)
                .sensoryFeedback(.success, trigger: game.phase == .results)
                .onChange(of: game.phase) { old, new in phaseSound(from: old, to: new) }
                .onChange(of: game.currentRound?.stopBy) { _, by in if by != nil { Sfx.play(.stop) } }
                .onChange(of: game.secondsLeft) { _, s in
                    if game.phase == .answering, s > 0, s <= 10 { Sfx.play(.hurry, volume: s <= 5 ? 0.9 : 0.5) }
                }
                .onChange(of: game.activePlayers.count) { old, new in
                    if new > old, game.phase == .lobby || game.phase == .matchmaking { Sfx.play(.join) }
                }
                .onChange(of: game.unreadChat) { old, new in if new > old { Sfx.play(.message, volume: 0.6) } }
                .animation(.spring(duration: 0.45), value: game.phase)
        }
        .interactiveDismissDisabled()
        .task { await game.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await game.appBecameActive() }
            case .background, .inactive: Task { await game.appWillResignActive() }
            @unknown default: break
            }
        }
        .onDisappear { Task { await game.stop() } }
        .sheet(isPresented: $showChat) { ChatSheet(game: game).gameScreen() }
        .onChange(of: showChat) { _, open in if open { game.incomingMessage = nil } }
        .overlay {
            if confirmLeave {
                GameDialog(title: "Salir",
                           message: game.phase == .finished ? "¿Volver al inicio?"
                               : (game.room?.isPublic == true ? "¿Seguro que quieres abandonar? En salas públicas cuenta como derrota."
                                                               : "¿Seguro que quieres abandonar la partida?"),
                           mascot: .bye,
                           onConfirm: { confirmLeave = false; leave() },
                           onCancel: { confirmLeave = false })
            }
        }
        .errorAlert($game.errorMessage)
    }

    @ViewBuilder private var content: some View {
        switch game.phase {
        case .loading:
            VStack(spacing: 14) {
                MascotView(pose: .hello, size: 170)
                OutlinedTitle(text: "Conectando", size: 26)
                ThinkingDots()
            }
        case .lobby:
            LobbyView(game: game)
        case .matchmaking:
            MatchmakingView(game: game) { leave() }
        case .letterDraw:
            LetterDrawView(game: game)
        case .answering:
            AnsweringView(game: game)
        case .validating:
            ValidatingView(game: game)
        case .results:
            RoundResultsView(game: game)
        case .finished:
            FinalStandingsView(game: game)
        case .cancelled:
            VStack(spacing: 18) {
                MascotView(pose: .sad, size: 170)
                OutlinedTitle(text: "La sala se cerró", size: 28)
                Button("Ir al inicio") { app.activeRoom = nil }
                    .buttonStyle(CandyButtonStyle(color: Game.tangerine, icon: "house.fill"))
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if game.phase != .finished && game.phase != .matchmaking {
            ToolbarItem(placement: .cancellationAction) {
                Button("Salir", systemImage: "chevron.backward") {
                    if game.phase == .lobby || game.phase == .cancelled || game.phase == .loading { leave() } else { confirmLeave = true }
                }
                .labelStyle(.titleAndIcon)
            }
        }
        if game.phase != .matchmaking && game.phase != .loading {
            ToolbarItem(placement: .primaryAction) {
                Button { showChat = true } label: {
                    // El globo va dentro del propio marco del botón: el vidrio de la barra recorta lo que sobresale.
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: game.unreadChat > 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                            .symbolEffect(.bounce, value: game.unreadChat)
                            .frame(width: 34, height: 28)
                        if game.unreadChat > 0 {
                            Text(game.unreadChat > 9 ? "9+" : "\(game.unreadChat)")
                                .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 17, minHeight: 17)
                                .background(Game.cherry, in: Capsule())
                                .overlay(Capsule().stroke(.background, lineWidth: 1.5))
                                .offset(x: 6, y: -5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 44, height: 34)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: game.unreadChat)
                }
                .accessibilityLabel(game.unreadChat > 0 ? "Chat de la sala, \(game.unreadChat) mensajes nuevos" : "Chat de la sala")
            }
        }
    }

    private func phaseSound(from old: GameStore.Phase, to new: GameStore.Phase) {
        switch new {
        case .answering where old == .letterDraw: Sfx.play(.go)
        case .validating: Sfx.play(.tap)
        default: break
        }
    }

    private func leave() {
        Task {
            if game.phase != .finished { await game.leave() }
            await game.stop()
            app.activeRoom = nil
            await app.refreshProfile()
        }
    }
}

struct ReconnectingOverlay: View {
    @Bindable var game: GameStore
    var onLeave: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.35)).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Conexión perdida").font(.headline)
                Text("Intentando reconectar… Tus respuestas guardadas se restaurarán y la ronda sigue para los demás.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Reintentar") { Task { await game.resync() } }.buttonStyle(.borderedProminent)
                Button("Abandonar partida", role: .destructive, action: onLeave)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}

/// Aviso flotante de mensaje nuevo en el chat de la sala (se oculta solo; tócalo para abrir el chat).
struct ChatBanner: View {
    var message: ChatMessage
    var author: RoomPlayer?
    var onOpen: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                AvatarView(avatar: author?.avatar ?? "", name: author?.name ?? "", size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(author?.name ?? "Jugador").font(.subheadline.weight(.bold))
                    Text(message.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "bubble.left.fill").foregroundStyle(Game.lemon)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .gesture(DragGesture(minimumDistance: 10).onEnded { if $0.translation.height < 0 { onDismiss() } })
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            onDismiss()
        }
        .accessibilityLabel("Mensaje de \(author?.name ?? "jugador"): \(message.body). Toca para abrir el chat")
    }
}
