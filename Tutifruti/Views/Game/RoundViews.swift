import SwiftUI

// MARK: Sorteo de letra
struct LetterDrawView: View {
    @Bindable var game: GameStore
    @State private var spinning = "A"
    private let alphabet = Array("ABCDEFGHIJLMNOPRSTUV").map(String.init)

    var body: some View {
        let r = game.currentRound
        let remaining = max(0, Int(ceil((r?.startsAt ?? game.now).timeIntervalSince(game.now))))
        let revealed = remaining <= 3
        VStack(spacing: 20) {
            Text("Ronda \(r?.number ?? 1) de \(game.room?.roundsTotal ?? 1)").font(.headline).foregroundStyle(.secondary)
            Spacer()
            ZStack {
                if revealed {
                    // rayos de sol girando detrás de la letra
                    SunburstView().frame(width: 360, height: 360).transition(.scale.combined(with: .opacity))
                }
                LetterBadge(letter: revealed ? (r?.letter ?? "?") : spinning, size: 180)
                    .scaleEffect(revealed ? 1.08 : 0.9)
                    .rotationEffect(.degrees(revealed ? 0 : -4))
                    .animation(.spring(duration: 0.5, bounce: 0.6), value: revealed)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.08), value: spinning)
            }
            OutlinedTitle(text: revealed ? "¡La letra es \(r?.letter ?? "")!" : "Sorteando letra…", size: 30,
                          fill: revealed ? Game.lemon : .white)
                .contentTransition(.opacity)
            if revealed {
                Text("\(remaining)")
                    .font(.system(size: 54, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Game.lemon)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: remaining)
            }
            if let used = game.room?.usedLetters.dropLast(), !used.isEmpty {
                Text("Letras ya usadas: \(used.joined(separator: ", "))").foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: -8) {
                ForEach(game.activePlayers) { AvatarView(avatar: $0.avatar, name: $0.name, size: 40) }
            }
            Text("\(game.activePlayers.filter(\.isConnected).count) jugadores sincronizados")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .gameTitle("Ronda \(r?.number ?? 1)")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: revealed) {
            while !revealed && !Task.isCancelled {
                spinning = alphabet.filter { $0 != spinning }.randomElement()!
                Sfx.play(.tick, volume: 0.5)
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
        .onChange(of: revealed) { _, r in if r { Sfx.play(.reveal) } }
        .onChange(of: remaining) { _, s in if revealed, s > 0, s <= 3 { Sfx.play(.count) } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: revealed)
        .sensoryFeedback(.impact(weight: .light), trigger: spinning)
    }
}

// MARK: Completando categorías
struct AnsweringView: View {
    @Bindable var game: GameStore
    @FocusState private var focused: String?
    @State private var stopping = false
    /// Teclado en pantalla visible (con teclado físico no aparece la barra del teclado).
    @State private var keyboardShown = false

    var body: some View {
        let r = game.currentRound
        let stopped = r?.stopBy != nil
        let letter = r?.letter ?? ""
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(game.categories.enumerated()), id: \.element) { i, cat in
                        AnswerField(category: cat, letter: letter, index: i + 1,
                                    text: Binding(get: { game.drafts[cat] ?? "" },
                                                  set: { game.setDraft(cat, String($0.prefix(40))) }),
                                    focused: $focused,
                                    onSubmit: { focusNext(after: cat) })
                            .id(cat)
                    }
                    Text("Se guarda solo. Puedes editar hasta que cierre la ronda.")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .onChange(of: focused) { _, f in
                guard let f else { return }
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(f, anchor: .center) }
            }
        }
        .gameTitle("Ronda \(r?.number ?? 1) de \(game.room?.roundsTotal ?? 1)")
        .navigationBarTitleDisplayMode(.inline)
        // Barra superior fija: letra, progreso hacia el STOP y reloj (o el aviso de STOP).
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                if let caller = game.stopCaller {
                    HStack(spacing: 12) {
                        MascotView(pose: .stop, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(caller.userId == game.me ? "¡Dijiste STOP!" : "¡\(caller.name) dijo STOP!")
                                .font(.system(.headline, design: .rounded).weight(.black))
                            Text("Cierra tus respuestas").font(.subheadline.weight(.semibold)).opacity(0.85)
                        }
                        Spacer()
                        Text("\(game.secondsLeft)")
                            .font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: game.secondsLeft)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Game.cherry))
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    AnswerHUD(letter: letter, filled: game.filledCount, total: game.categories.count,
                              threshold: game.stopThreshold, seconds: game.secondsLeft,
                              totalSeconds: game.room?.roundSeconds ?? 60)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Game.deep))
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
        }
        .animation(.spring(duration: 0.4), value: stopped)
        // Abajo: STOP grande sin teclado; con teclado en pantalla, una barra compacta encima del teclado.
        .safeAreaInset(edge: .bottom) {
            if keyboardShown {
                HStack(spacing: 10) {
                    Button { move(-1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(RoundIconButtonStyle(color: Game.panel, iconColor: .white, size: 38))
                        .accessibilityLabel("Categoría anterior")
                    Button { move(1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(RoundIconButtonStyle(color: Game.panel, iconColor: .white, size: 38))
                        .accessibilityLabel("Categoría siguiente")
                    Spacer()
                    if game.canStop && !stopped {
                        Button {
                            Task { stopping = true; await game.callStop(); stopping = false }
                        } label: {
                            Label("¡STOP!", systemImage: "hand.raised.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16).frame(height: 38)
                                .background(Capsule().fill(Game.cherry))
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(stopping)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button("Listo") { focused = nil }
                            .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Game.lemon)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Game.night.opacity(0.92))
            } else if game.canStop && !stopped {
                stopButton(height: 58)
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                    .background(LinearGradient(colors: [Game.night.opacity(0), Game.night], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.4), value: game.canStop)
        .onChange(of: game.canStop) { _, can in if can && !stopped { Sfx.play(.reveal, volume: 0.5) } }
        .sensoryFeedback(.success, trigger: game.canStop) { _, new in new }
        .onAppear { focused = game.categories.first { (game.drafts[$0] ?? "").isEmpty } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
            // Con teclado físico solo aparece una barra mínima (altura pequeña): se trata como "sin teclado".
            let h = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            keyboardShown = h > 120
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardShown = false
        }
    }

    private func stopButton(height: CGFloat) -> some View {
        Button("¡STOP!") {
            Task { stopping = true; await game.callStop(); stopping = false }
        }
        .buttonStyle(CandyButtonStyle(color: Game.cherry, icon: "hand.raised.fill", height: height))
        .disabled(stopping)
        .accessibilityHint("Cierra la ronda para todos")
    }

    private func move(_ delta: Int) {
        guard let f = focused, let i = game.categories.firstIndex(of: f) else { return }
        let n = i + delta
        if game.categories.indices.contains(n) { focused = game.categories[n] }
    }

    private func focusNext(after cat: String) {
        guard let i = game.categories.firstIndex(of: cat) else { return }
        let rest = game.categories[(i + 1)...]
        focused = rest.first { (game.drafts[$0] ?? "").isEmpty } ?? rest.first
    }
}

/// Barra superior de la ronda: letra, progreso (con marca del 75 % para el STOP) y reloj.
struct AnswerHUD: View {
    var letter: String
    var filled: Int
    var total: Int
    var threshold: Int
    var seconds: Int
    var totalSeconds: Int

    var body: some View {
        let can = filled >= threshold
        GamePanel(padding: 10) {
            HStack(spacing: 12) {
                LetterBadge(letter: letter, size: 50)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(filled)/\(total)").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: filled)
                        Text(can ? "¡ya puedes decir STOP!" : "STOP con \(threshold)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(can ? Game.lime : .white.opacity(0.6))
                    }
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(can ? Game.lime : Game.lemon)
                                .frame(width: max(8, w * CGFloat(filled) / CGFloat(max(1, total))))
                                .animation(.spring(duration: 0.4), value: filled)
                            // marca del mínimo para STOP
                            Rectangle().fill(.white.opacity(0.8)).frame(width: 2, height: 14)
                                .offset(x: w * CGFloat(threshold) / CGFloat(max(1, total)) - 1)
                        }
                    }
                    .frame(height: 8)
                }
                TimerRing(seconds: seconds, total: totalSeconds)
                    .colorScheme(.dark)
                    .scaleEffect(0.85)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Letra \(letter). \(filled) de \(total) respuestas. \(seconds) segundos")
    }
}

/// Campo de una categoría a todo lo ancho, con aviso si no empieza con la letra.
struct AnswerField: View {
    var category: String
    var letter: String
    var index: Int
    @Binding var text: String
    var focused: FocusState<String?>.Binding
    var onSubmit: () -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    private var valid: Bool {
        guard trimmed.count >= 2, !letter.isEmpty else { return false }
        return trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).uppercased()
            .hasPrefix(letter == "Ñ" ? "N" : letter)
    }
    private var wrongLetter: Bool {
        guard let first = trimmed.first, !letter.isEmpty else { return false }
        let f = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).uppercased()
        return f != (letter == "Ñ" ? "N" : letter)
    }

    var body: some View {
        let isFocused = focused.wrappedValue == category
        let border: Color = isFocused ? Game.lemon : (wrongLetter ? Game.cherry : (valid ? Game.lime.opacity(0.6) : Game.panelStroke))
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(isFocused ? Game.lemon : .white.opacity(0.6))
                        .lineLimit(1)
                    TextField("", text: $text, prompt: Text("\(letter)…").foregroundStyle(.white.opacity(0.3)))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .tint(Game.lemon)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused(focused, equals: category)
                        .onSubmit(onSubmit)
                }
                if valid {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .black))
                        .foregroundStyle(Game.ink).frame(width: 26, height: 26).background(Circle().fill(Game.lime))
                        .transition(.scale.combined(with: .opacity))
                } else if wrongLetter {
                    Image(systemName: "exclamationmark").font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white).frame(width: 26, height: 26).background(Circle().fill(Game.cherry))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            if wrongLetter {
                Text("Debe empezar con la \(letter)").font(.caption.weight(.heavy)).foregroundStyle(Game.cherry)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isFocused ? Color.white.opacity(0.14) : Game.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(border, lineWidth: isFocused ? 2.5 : 1.5))
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = category }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: valid)
        .animation(.spring(duration: 0.3), value: wrongLetter)
        .animation(.spring(duration: 0.25), value: isFocused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(category)
    }
}

/// Barra de tiempo horizontal con reloj (se pone roja y rayada al final).
struct TimeBar: View {
    var seconds: Int
    var total: Int

    var body: some View {
        let p = CGFloat(seconds) / CGFloat(max(1, total))
        let urgent = seconds <= 10
        HStack(spacing: 8) {
            Image(systemName: "clock.fill").font(.headline).foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: urgent)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Game.deeper)
                    Capsule()
                        .fill(urgent ? AnyShapeStyle(Game.cherry) : AnyShapeStyle(LinearGradient(colors: [Game.lime, Game.lemon], startPoint: .leading, endPoint: .trailing)))
                        .frame(width: max(10, geo.size.width * p))
                        .animation(.linear(duration: 1), value: seconds)
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 2))
            }
            .frame(height: 14)
        }
        .accessibilityElement()
        .accessibilityLabel("\(seconds) segundos restantes")
    }
}

// MARK: Validando con IA
struct ValidatingView: View {
    @Bindable var game: GameStore
    @State private var start = Date()

    private var letter: String { game.currentRound?.letter ?? "" }
    private var messages: [String] {
        ["Revisando que empiecen con la \(letter)…", "Consultando el diccionario…", "¿Pertenece a la categoría?…",
         "Buscando respuestas repetidas…", "Contando los puntos…"]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            let msg = messages[Int(t / 2.2) % messages.count]
            // Progreso suave que se acerca al 95 % (no promete un tiempo exacto).
            let progress = min(0.95, 1 - exp(-t / 6))
            let scanning = Int(t / 0.7) % max(1, game.categories.count)
            ScrollView {
                VStack(spacing: 16) {
                    // Árbitro protagonista
                    ZStack(alignment: .topTrailing) {
                        MascotView(pose: .judge, size: 170)
                        LetterBadge(letter: letter, size: 52)
                            .rotationEffect(.degrees(10))
                            .offset(x: 40, y: 10)
                    }
                    .padding(.top, 4)
                    OutlinedTitle(text: "El árbitro está revisando", size: 22)
                    Text(msg)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Game.lemon)
                        .id(msg)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.35), value: msg)
                    // Barra de progreso
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(LinearGradient(colors: [Game.lemon, Game.tangerine], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(12, geo.size.width * progress))
                        }
                    }
                    .frame(height: 10)
                    .padding(.horizontal, 30)
                    // Jugadores esperando
                    HStack(spacing: -8) {
                        ForEach(game.activePlayers) { p in AvatarView(avatar: p.avatar, name: p.name, size: 32) }
                    }
                    Text("\(game.activePlayers.count * game.categories.count) respuestas de \(game.activePlayers.count) jugadores")
                        .font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.6))

                    // Mis respuestas, recorridas por el "escáner"
                    HStack {
                        SectionTitle(text: "Tus respuestas")
                        Image(systemName: "lock.fill").font(.caption.weight(.black)).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 6)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Array(game.categories.enumerated()), id: \.element) { i, cat in
                            PendingAnswerCard(category: cat, value: game.drafts[cat] ?? "", scanning: i == scanning)
                        }
                    }
                    // El árbitro falló: aviso en línea (no una alerta), porque se reintenta solo.
                    if game.aiFailed && game.aiAttempt < 3 {
                        GamePanel(padding: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.headline.weight(.black)).foregroundStyle(Game.lemon)
                                    .symbolEffect(.pulse)
                                Text("El árbitro tarda más de lo normal. Reintentando (intento \(game.aiAttempt + 1) de 3)…")
                                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                                Spacer(minLength: 4)
                                Button("Ahora") { game.retryAI() }
                                    .font(.footnote.weight(.heavy)).foregroundStyle(Game.lemon)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.35), value: game.aiFailed)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .gameTitle("Ronda \(game.currentRound?.number ?? 1) de \(game.room?.roundsTotal ?? 1)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Respuesta en revisión: sin veredicto todavía; un brillo la recorre cuando le "toca".
struct PendingAnswerCard: View {
    var category: String
    var value: String
    var scanning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.uppercased()).font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            Text(value.isEmpty ? "—" : value)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(value.isEmpty ? .white.opacity(0.4) : .white)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Image(systemName: scanning ? "magnifyingglass" : "hourglass")
                    .font(.caption2.weight(.black))
                    .symbolEffect(.pulse, isActive: scanning)
                Text(scanning ? "Revisando…" : "En espera").font(.caption.weight(.heavy))
            }
            .foregroundStyle(scanning ? Game.lemon : .white.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(scanning ? Game.lemon.opacity(0.12) : Game.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(scanning ? Game.lemon.opacity(0.7) : Game.panelStroke, lineWidth: 1.5))
        .scaleEffect(scanning ? 1.03 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: scanning)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category): \(value.isEmpty ? "vacía" : value), en revisión")
    }
}

// MARK: Piezas animadas del juego

/// Anillo de cuenta regresiva que cambia a rojo y late en los últimos segundos.
struct TimerRing: View {
    var seconds: Int
    var total: Int

    var body: some View {
        let urgent = seconds <= 10
        ZStack {
            Circle().stroke(.fill.tertiary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(seconds) / CGFloat(max(1, total)))
                .stroke(urgent ? AnyShapeStyle(Game.cherry) : AnyShapeStyle(Game.lemon), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: seconds)
            Text("\(seconds)")
                .font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                .foregroundStyle(urgent ? .red : .primary)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: seconds)
        }
        .frame(width: 58, height: 58)
        .scaleEffect(urgent && seconds % 2 == 0 ? 1.08 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.6), value: seconds)
        .accessibilityElement()
        .accessibilityLabel("\(seconds) segundos")
    }
}

/// Rayos girando detrás de la letra revelada.
struct SunburstView: View {
    @State private var spin = false
    var body: some View {
        Canvas { g, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            for i in 0..<16 {
                let a0 = Double(i) / 16 * 2 * .pi
                let a1 = a0 + .pi / 16
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                p.closeSubpath()
                g.fill(p, with: .radialGradient(Gradient(colors: [Brand.yellow.opacity(0.55), .clear]), center: c, startRadius: 0, endRadius: r))
            }
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear { withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true } }
        .accessibilityHidden(true)
    }
}

/// Tres puntos que saltan ("pensando…").
struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle().fill(Game.lemon).frame(width: 9, height: 9)
                        .offset(y: -6 * max(0, sin(t * 6 - Double(i) * 0.7)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
