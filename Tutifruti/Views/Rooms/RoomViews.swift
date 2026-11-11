import SwiftUI

// MARK: Configurar sala
struct RoomConfigView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    /// Si se pasa una sala, edita su configuración en lugar de crear una nueva.
    var editing: Room? = nil
    var onSaved: (() -> Void)? = nil
    /// Tipo inicial al crear (p. ej. "Crear sala pública" desde la lista de salas públicas).
    var startPublic = false

    @State private var s = API.RoomSettings()
    @State private var loading = false
    @State private var error: String?
    @State private var didLoad = false
    @State private var showMore = false
    @State private var pickCategories = false

    private var isPlus: Bool { app.profile?.isPlus ?? false }

    /// Estilos de partida de un toque.
    private struct Preset: Identifiable { let id: String; let icon: String; let rounds: Int; let seconds: Int }
    private let presets = [Preset(id: "Rápida", icon: "bolt.fill", rounds: 3, seconds: 60),
                           Preset(id: "Clásica", icon: "star.fill", rounds: 5, seconds: 90),
                           Preset(id: "Larga", icon: "hourglass", rounds: 8, seconds: 120)]
    private static let randomNames = ["Viernes de Stop", "Basta con amigos", "La letra misteriosa", "Tutifruti épico",
                                      "Noche de Stop", "Mente rápida", "Duelo de palabras", "Stop sin piedad",
                                      "Los veloces", "Club de la A a la Z"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoomTypePicker(isPublic: $s.isPublic)
                Text(s.isPublic ? "Aparece en Salas públicas: cualquiera puede unirse mientras esperas."
                                : "Solo entran quienes tengan el código o tu invitación.")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                    .padding(.top, -10).padding(.horizontal, 4)

                // Nombre con dado
                HStack(spacing: 10) {
                    TextField("Nombre de la sala", text: $s.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Game.panel))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Game.panelStroke, lineWidth: 1.5))
                    Button {
                        s.name = (Self.randomNames.filter { $0 != s.name }).randomElement() ?? s.name
                    } label: { Image(systemName: "dice.fill") }
                        .buttonStyle(RoundIconButtonStyle(color: Game.lemon, size: 50))
                        .accessibilityLabel("Nombre al azar")
                }

                // Estilo de partida
                SectionTitle(text: "Estilo de partida")
                HStack(spacing: 10) {
                    ForEach(presets) { p in
                        let on = s.rounds == p.rounds && s.roundSeconds == p.seconds
                        Button {
                            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { s.rounds = p.rounds; s.roundSeconds = p.seconds }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: p.icon).font(.system(size: 18, weight: .black))
                                Text(p.id).font(.system(.subheadline, design: .rounded).weight(.black))
                                Text("\(p.rounds) · \(p.seconds)s").font(.caption2.weight(.heavy)).opacity(0.75)
                            }
                            .foregroundStyle(on ? Game.ink : .white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? AnyShapeStyle(Game.lemon) : AnyShapeStyle(Game.panel)))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Game.ink.opacity(0.5) : Game.panelStroke, lineWidth: 1.5))
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                GamePanel(padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        ValueChips(title: "Rondas", value: $s.rounds, options: [3, 5, 8, 10]) { "\($0)" }
                        ValueChips(title: "Tiempo por ronda", value: $s.roundSeconds, options: [60, 90, 120, 180]) {
                            $0 % 60 == 0 ? "\($0 / 60) min" : "\($0) s"
                        }
                        ValueChips(title: "Jugadores máximos", value: $s.maxPlayers, options: [4, 6, 8, 12],
                                   locked: isPlus ? [] : [12]) { "\($0)" }
                        if !isPlus {
                            Label("12 jugadores con Tutifruti Plus", systemImage: "crown.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }

                // Categorías
                HStack {
                    SectionTitle(text: "Categorías", trailing: "\(s.categories.count)")
                }
                GamePanel(padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        RemovableChips(items: $s.categories, minimum: 3)
                        Button { pickCategories = true } label: {
                            SmallActionLabel(icon: "plus", title: "Agregar o cambiar", tint: Game.lime)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        if s.categories.count <= 3 {
                            Text("Mínimo 3 categorías.").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }

                // Más opciones (plegado)
                GamePanel(padding: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            withAnimation(.spring(duration: 0.35)) { showMore.toggle() }
                        } label: {
                            HStack {
                                Text("Más opciones").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.down").font(.subheadline.weight(.black)).foregroundStyle(Game.lemon)
                                    .rotationEffect(.degrees(showMore ? 180 : 0))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showMore {
                            Toggle(isOn: $s.excludeHard) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sin letras difíciles").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                    Text("K, Ñ, Q, W, X, Y, Z").font(.caption).foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            ValueChips(title: "Tiempo para cerrar tras STOP", value: $s.stopSeconds, options: [5, 10, 15, 20]) { "\($0) s" }
                            Toggle(isOn: $s.allowCustom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Categorías personalizadas").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                    Text("Permite usar categorías creadas por jugadores").font(.caption).foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                    }
                }
                .tint(Game.lime)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text("\(s.rounds) rondas · \(s.roundSeconds) s · \(s.categories.count) categorías · hasta \(s.maxPlayers)")
                    .font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
                PrimaryButton(title: editing == nil ? "Crear sala" : "Guardar cambios", systemImage: editing == nil ? "plus" : "checkmark",
                              loading: loading, color: Game.lime) { await save() }
                    .disabled(s.categories.count < 3 || s.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
            .background(LinearGradient(colors: [Game.night.opacity(0), Game.night.opacity(0.92), Game.night], startPoint: .top, endPoint: .bottom))
        }
        .navigationDestination(isPresented: $pickCategories) { CategoryPickerView(selection: $s.categories) }
        .gameTitle(editing == nil ? "Nueva sala" : "Editar sala")
        .gameScreen()
        .onAppear {
            // Solo la primera vez: al volver del selector de categorías no se pierden los cambios.
            guard !didLoad else { return }
            didLoad = true
            if let editing { s = API.RoomSettings(room: editing) }
            else if startPublic { s.isPublic = true; s.name = "Stop para todos" }
        }
        .errorAlert($error)
    }

    private func save() async {
        loading = true
        defer { loading = false }
        do {
            if let editing {
                _ = try await API.updateRoom(editing.id, s)
                onSaved?()
                dismiss()
            } else {
                let room = try await API.createRoom(s)
                dismiss()
                app.enterRoom(room.id)
            }
        } catch { self.error = friendlyError(error) }
    }
}

/// Fila de valores en fichas grandes (reemplaza a los − / +). Incluye el valor actual si no está en las opciones.
struct ValueChips: View {
    var title: String
    @Binding var value: Int
    var options: [Int]
    var locked: Set<Int> = []
    var label: (Int) -> String

    var body: some View {
        let all = Array(Set(options + [value])).sorted()
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.white.opacity(0.65))
            HStack(spacing: 8) {
                ForEach(all, id: \.self) { v in
                    let on = v == value
                    let isLocked = locked.contains(v)
                    Button {
                        guard !isLocked else { return }
                        withAnimation(.spring(duration: 0.25, bounce: 0.4)) { value = v }
                        Sfx.play(.tap, volume: 0.5)
                    } label: {
                        HStack(spacing: 3) {
                            if isLocked { Image(systemName: "lock.fill").font(.caption2.weight(.black)) }
                            Text(label(v)).font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(on ? Game.ink : .white.opacity(isLocked ? 0.35 : 0.9))
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(Capsule().fill(on ? AnyShapeStyle(Game.lemon) : AnyShapeStyle(Color.white.opacity(0.07))))
                        .overlay(Capsule().strokeBorder(on ? Game.ink.opacity(0.4) : Game.panelStroke, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    .accessibilityLabel("\(title): \(label(v))\(isLocked ? ", requiere Plus" : "")")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// Fichas de categorías que se quitan tocando la ✕ (respetando un mínimo).
struct RemovableChips: View {
    @Binding var items: [String]
    var minimum: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let canRemove = items.count > minimum
                HStack(spacing: 4) {
                    Text(item).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if canRemove {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { items.removeAll { $0 == item } }
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar \(item)")
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Game.header))
                .overlay(Capsule().strokeBorder(Game.lemon.opacity(0.5), lineWidth: 1.5))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// Botón compacto de una sola línea para las acciones del código de sala.
struct CodeActionLabel: View {
    var title: String
    var icon: String
    var filled: Bool

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .lineLimit(1)
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(filled ? .white : Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                Capsule().fill(filled ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.accentColor.opacity(0.14)))
            }
            .overlay { if !filled { Capsule().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5) } }
    }
}

/// Selector grande Pública / Privada.
struct RoomTypePicker: View {
    @Binding var isPublic: Bool

    var body: some View {
        HStack(spacing: 10) {
            option(false, title: "Privada", subtitle: "Con código", icon: "lock.fill")
            option(true, title: "Pública", subtitle: "Abierta a todos", icon: "globe.americas.fill")
        }
    }

    private func option(_ value: Bool, title: String, subtitle: String, icon: String) -> some View {
        let selected = isPublic == value
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) { isPublic = value }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                    .symbolEffect(.bounce, value: selected)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).opacity(0.85)
            }
            .foregroundStyle(selected ? Game.ink : .primary)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Game.lemon) : AnyShapeStyle(.fill.tertiary))
            }
            .scaleEffect(selected ? 1.0 : 0.97)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FlowChips: View {
    var items: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Game.header))
                    .overlay(Capsule().strokeBorder(Game.lemon.opacity(0.6), lineWidth: 1.5))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: Elegir categorías
struct CategoryPickerView: View {
    @Environment(AppState.self) private var app
    @Binding var selection: [String]
    @State private var all: [Category] = []
    @State private var sets: [CategorySet] = []
    @State private var tab = 0
    @State private var query = ""
    @State private var showNew = false
    @State private var saveSetName = ""
    @State private var askSetName = false
    @State private var theme = ""
    @State private var generating = false
    @State private var generated: [String] = []
    @State private var error: String?

    private func matches(_ c: Category) -> Bool { query.isEmpty || c.name.localizedCaseInsensitiveContains(query) }
    private var defaults: [Category] { all.filter { $0.kind == "default" && matches($0) } }
    private var mine: [Category] { all.filter { $0.kind == "custom" && matches($0) } }
    private var themes: [(String, [Category])] {
        Dictionary(grouping: all.filter { $0.kind == "thematic" }, by: { $0.theme ?? "" })
            .map { ($0.key, $0.value.sorted { $0.sort < $1.sort }) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        GameList {
            GameSegmented(selection: $tab, options: [(0, "Clásicas"), (1, "Temáticas"), (2, "Mías")])
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            switch tab {
            case 0:
                GameSection("Predeterminadas · \(selection.filter { n in defaults.contains { $0.name == n } }.count) de \(defaults.count)") {
                    ForEach(defaults) { toggleRow($0.name) }
                }
                if !sets.isEmpty {
                    GameSection("Conjuntos favoritos") {
                        ForEach(sets) { set in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(set.name)
                                    Text(set.categories.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Button("Usar") { selection = set.categories }.buttonStyle(.bordered).controlSize(.small)
                            }
                            .swipeActions {
                                Button("Borrar", role: .destructive) {
                                    Task { try? await API.deleteCategorySet(set.id); await load() }
                                }
                            }
                        }
                    }
                }
            case 1:
                ForEach(themes, id: \.0) { name, cats in
                    let locked = cats.first?.isPremium == true && !(app.profile?.isPlus ?? false)
                    Section {
                        if locked {
                            Label("Disponible con Tutifruti Plus", systemImage: "lock.fill").foregroundStyle(.secondary)
                        } else {
                            ForEach(cats) { toggleRow($0.name) }
                        }
                    } header: {
                        SectionTitle(text: name, trailing: cats.first?.isPremium == true ? "Premium" : nil).listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
                    }
                }
                GameSection("Generar con IA") {
                    TextField("Ej. \"Mitología griega\"", text: $theme)
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack { Label("Generar categorías", systemImage: "sparkles"); if generating { Spacer(); ProgressView() } }
                    }
                    .disabled(theme.count < 3 || generating)
                    ForEach(generated, id: \.self) { toggleRow($0) }
                }
            default:
                Section {
                    if mine.isEmpty {
                        Text("Aún no tienes categorías personalizadas.").foregroundStyle(.secondary)
                    }
                    ForEach(mine) { c in
                        toggleRow(c.name, subtitle: c.description)
                            .swipeActions {
                                Button("Borrar", role: .destructive) {
                                    Task { try? await API.deleteCategory(c.id); await load() }
                                }
                            }
                    }
                }
            }

            Section {
                Button("Guardar como favorito", systemImage: "star") { askSetName = true }
                    .disabled(selection.count < 3)
            } footer: {
                Text("\(selection.count) seleccionadas · mínimo 3, máximo 12")
            }
        }
        .searchable(text: $query, prompt: "Buscar categoría")
        .gameTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Personalizada", systemImage: "plus") { showNew = true }
            }
        }
        .sheet(isPresented: $showNew) {
            NewCategorySheet { name in
                if !selection.contains(name) && selection.count < 12 { selection.append(name) }
                Task { await load() }
            }
        }
        .alert("Guardar conjunto", isPresented: $askSetName) {
            TextField("Nombre", text: $saveSetName)
            Button("Guardar") {
                let name = saveSetName
                Task {
                    do { try await API.saveCategorySet(name: name, categories: selection); await load() }
                    catch { self.error = friendlyError(error) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .task { await load() }
        .errorAlert($error)
    }

    private func load() async {
        all = (try? await API.categories()) ?? all
        sets = (try? await API.categorySets()) ?? sets
    }

    private func generate() async {
        generating = true
        defer { generating = false }
        do { generated = try await API.generateCategories(theme: theme) }
        catch { self.error = "No se pudieron generar categorías ahora. ¿Está desplegado el árbitro IA?" }
    }

    @ViewBuilder
    private func toggleRow(_ name: String, subtitle: String? = nil) -> some View {
        let on = selection.contains(name)
        Button {
            if on { selection.removeAll { $0 == name } }
            else if selection.count < 12 { selection.append(name) }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(name).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.accentColor : .secondary)
                    .font(.title3)
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (String) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            GameForm {
                GameSection("Nombre de la categoría") {
                    TextField("Instrumentos musicales", text: $name)
                }
                Section {
                    TextField("Instrumentos que se pueden tocar, de cualquier cultura.", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                } header: { SectionTitle(text: "Descripción para la IA").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) } footer: {
                    Label("La IA revisará que la categoría sea clara y apropiada antes de usarla.", systemImage: "info.circle")
                }
                Section {
                    PrimaryButton(title: "Crear categoría", systemImage: "plus", loading: loading, color: Game.lime) { await create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).count < 3)
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
            }
            .gameTitle("Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .errorAlert($error)
        }
    }

    private func create() async {
        loading = true
        defer { loading = false }
        let n = name.trimmingCharacters(in: .whitespaces)
        // La revisión IA es opcional: si la función no está disponible, se permite la categoría.
        if let check = try? await API.checkCategory(name: n, description: description), !check.ok {
            error = check.reason
            return
        }
        do {
            _ = try await API.createCategory(name: n, description: description)
            onCreated(n)
            dismiss()
        } catch { self.error = friendlyError(error) }
    }
}

// MARK: Sala de espera
struct LobbyView: View {
    @Environment(AppState.self) private var app
    @Bindable var game: GameStore
    @State private var showInvite = false
    @State private var showEdit = false
    @State private var copied = false
    @State private var starting = false

    var body: some View {
        if let room = game.room {
            ScrollView {
                VStack(spacing: 18) {
                    // Código de la sala (panel translúcido; las acciones son secundarias)
                    GamePanel(padding: 16) {
                        VStack(spacing: 12) {
                            GamePill(text: room.isPublic ? "Sala pública" : "Sala privada",
                                     icon: room.isPublic ? "globe.americas.fill" : "lock.fill",
                                     color: room.isPublic ? Game.lime : Game.grape)
                            Text(room.code)
                                .font(.system(size: 40, weight: .black, design: .rounded)).monospaced()
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                                .accessibilityLabel("Código de la sala \(room.code)")
                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = room.code
                                    Sfx.play(.coin, volume: 0.5)
                                    withAnimation(.spring(duration: 0.3, bounce: 0.5)) { copied = true }
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        withAnimation { copied = false }
                                    }
                                } label: {
                                    SmallActionLabel(icon: copied ? "checkmark" : "doc.on.doc.fill",
                                                     title: copied ? "¡Copiado!" : "Copiar", tint: copied ? Game.lime : Game.lemon)
                                }
                                .buttonStyle(BouncyButtonStyle(sound: nil))
                                .sensoryFeedback(.success, trigger: copied) { _, new in new }
                                ShareLink(item: Config.inviteURL(code: room.code),
                                          subject: Text("Únete a mi partida de Tutifruti AI"),
                                          message: Text("¡Juega Tutifruti conmigo! Toca el enlace para entrar a la sala \(room.code):"),
                                          preview: SharePreview("Sala \(room.code) · Tutifruti AI", image: Image("app_logo"))) {
                                    SmallActionLabel(icon: "square.and.arrow.up.fill", title: "Invitar", tint: Game.lemon)
                                }
                                .buttonStyle(BouncyButtonStyle())
                            }
                            if room.isPublic {
                                Text("Visible en Salas públicas: cualquiera puede unirse hasta que inicies.")
                                    .font(.caption.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.65))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Jugadores
                    SectionTitle(text: "Jugadores", trailing: "\(game.activePlayers.count)/\(room.maxPlayers)")
                    VStack(spacing: 10) {
                        ForEach(Array(game.activePlayers.enumerated()), id: \.element.id) { i, p in
                            PlayerRow(player: p, room: room, me: game.me).popIn(i)
                        }
                        let free = max(0, min(2, room.maxPlayers - game.activePlayers.count))
                        ForEach(0..<free, id: \.self) { _ in
                            if app.isGuest {
                                EmptySlotRow(label: "Libre")
                            } else {
                                Button { showInvite = true } label: { EmptySlotRow() }.buttonStyle(BouncyButtonStyle())
                            }
                        }
                    }

                    // Configuración
                    HStack {
                        SectionTitle(text: "Reglas")
                        if game.isHost {
                            Button { showEdit = true } label: { Image(systemName: "pencil") }
                                .buttonStyle(RoundIconButtonStyle(size: 38))
                        }
                    }
                    GamePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 14) {
                                ruleStat("arrow.triangle.2.circlepath", "\(room.roundsTotal)", "rondas")
                                ruleStat("timer", "\(room.roundSeconds)s", "por ronda")
                                ruleStat("hand.raised.fill", "\(room.stopSeconds)s", "tras STOP")
                            }
                            if let lang = room.language, lang != "es" {
                                Label("Se juega en \(GameLanguage.name(lang)): la IA valida respuestas en ese idioma.", systemImage: "globe")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Game.lemon)
                            }
                            FlowChips(items: room.categories)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    if game.isHost {
                        Button(starting ? "Iniciando…" : "Iniciar partida") {
                            Task {
                                starting = true
                                await game.startGame()
                                starting = false
                            }
                        }
                        .buttonStyle(CandyButtonStyle(color: Game.lime, icon: "play.fill"))
                        .disabled(starting || game.activePlayers.filter(\.ready).count < 2)
                        Text(game.activePlayers.filter(\.ready).count < 2 ? "Necesitas al menos 2 jugadores listos" : "¡Todo listo para empezar!")
                            .font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
                    } else if let mine = game.myPlayer {
                        Button(mine.ready ? "¡Estoy listo!" : "Marcar como listo") {
                            Task { await game.setReady(!mine.ready) }
                        }
                        .buttonStyle(CandyButtonStyle(color: mine.ready ? Game.lime : Game.tangerine,
                                                      icon: mine.ready ? "checkmark" : "hand.raised.fill"))
                        Text("Espera a que el anfitrión inicie la partida").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
                .background(LinearGradient(colors: [Game.night.opacity(0), Game.night.opacity(0.92), Game.night], startPoint: .top, endPoint: .bottom))
            }
            .gameTitle(room.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInvite) { InviteFriendsSheet(roomId: room.id, already: Set(game.players.map(\.userId))).gameScreen() }
            .sheet(isPresented: $showEdit) {
                NavigationStack { RoomConfigView(editing: room) { Task { await game.refresh() } } }.gameScreen()
            }
        }
    }

    private func ruleStat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.headline).foregroundStyle(Game.lemon)
            Text(value).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Lugar libre en la sala ("Invitar").
struct EmptySlotRow: View {
    var label = "Libre · invitar"
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill.badge.plus")
                .font(.title3.weight(.bold)).foregroundStyle(.white.opacity(0.6))
                .frame(width: 46, height: 46)
                .background(Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
            Text(label).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
    }
}

struct PlayerRow: View {
    var player: RoomPlayer
    var room: Room
    var me: UUID?

    var body: some View {
        GamePanel(padding: 10) {
            HStack(spacing: 12) {
                AvatarView(avatar: player.avatar, name: player.name, size: 46)
                    .overlay(alignment: .bottomTrailing) {
                        if room.hostId == player.userId {
                            Image(systemName: "crown.fill").font(.system(size: 11, weight: .black)).foregroundStyle(Game.ink)
                                .padding(4).background(Circle().fill(Game.lemon)).overlay(Circle().strokeBorder(Game.ink, lineWidth: 1.5))
                                .offset(x: 4, y: 4)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name + (player.userId == me ? " (tú)" : ""))
                        .font(.system(.headline, design: .rounded).weight(.heavy)).lineLimit(1).foregroundStyle(.white)
                    Text(subtitle).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 6)
                if !player.isConnected {
                    GamePill(text: "Sin conexión", icon: "wifi.slash", color: Game.cherry)
                } else if player.ready {
                    GamePill(text: "Listo", icon: "checkmark", color: Game.lime)
                } else {
                    GamePill(text: "Esperando", icon: "hourglass", color: Game.tangerine)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = ["Nivel \(player.profile?.level ?? 1)"]
        if room.hostId == player.userId { parts.append("Anfitrión") }
        if !player.isConnected { parts.append("Reconectando…") }
        return parts.joined(separator: " · ")
    }
}

// MARK: Invitar amigos
struct InviteFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var roomId: UUID
    var already: Set<UUID>
    @State private var friends: [FriendRow] = []
    @State private var selected: Set<UUID> = []
    @State private var query = ""
    @State private var loading = false
    @State private var error: String?

    private var list: [FriendRow] {
        friends.filter { $0.status == "accepted" && !already.contains($0.userId) && (query.isEmpty || $0.username.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        NavigationStack {
            List(list, selection: $selected) { f in
                HStack(spacing: 12) {
                    AvatarView(avatar: f.avatar, name: f.username, size: 36)
                    VStack(alignment: .leading) {
                        Text(f.username)
                        Text(f.statusText).font(.caption).foregroundStyle(f.isOnline ? .green : .secondary)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .overlay {
                if list.isEmpty {
                    ContentUnavailableView("Sin amigos para invitar", systemImage: "person.2.slash",
                                           description: Text("Comparte el código de la sala o agrega amigos."))
                }
            }
            .searchable(text: $query, prompt: "Buscar amigos")
            .gameTitle("Invitar amigos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: selected.count == 1 ? "Enviar 1 invitación" : "Enviar \(selected.count) invitaciones", systemImage: "paperplane.fill", loading: loading) {
                    loading = true
                    defer { loading = false }
                    do { try await API.invite(roomId, users: Array(selected)); dismiss() }
                    catch { self.error = friendlyError(error) }
                }
                .disabled(selected.isEmpty)
                .padding()
                .background(.bar)
            }
            .task { friends = (try? await API.friends()) ?? [] }
            .errorAlert($error)
        }
    }
}

// MARK: Chat
struct ChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: GameStore
    @State private var text = ""
    private let quick = ["¡Suerte!", "GG", "¡Qué rápido!", "¡Bien jugado!"]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                GameList {
                    ForEach(game.chat.filter { !($0.userId.map(game.muted.contains) ?? false) }) { m in
                        ChatBubble(message: m, author: m.userId.flatMap { game.player($0) }, mine: m.userId == game.me)
                            .listRowSeparator(.hidden)
                            .id(m.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: game.chat.count) { if let last = game.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
                .onAppear { if let last = game.chat.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(quick, id: \.self) { q in
                                Button(q) { Task { await game.sendChat(q) } }.buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack {
                        TextField("Escribe un mensaje…", text: $text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...3)
                            .onSubmit(send)
                        Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title) }
                            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel("Enviar mensaje")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(.bar)
            }
            .gameTitle("Chat · \(game.activePlayers.filter(\.isConnected).count) conectados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .onAppear { game.chatOpen = true }
            .onDisappear { game.chatOpen = false }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() {
        let t = text
        text = ""
        Task { await game.sendChat(t) }
    }
}

struct ChatBubble: View {
    var message: ChatMessage
    var author: RoomPlayer?
    var mine: Bool

    var body: some View {
        if message.kind == "system" {
            Text(message.body).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if mine { Spacer(minLength: 40) }
                if !mine { AvatarView(avatar: author?.avatar ?? "", name: author?.name ?? "", size: 28) }
                VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                    if !mine { Text(author?.name ?? "jugador").font(.caption2).foregroundStyle(.secondary) }
                    Text(message.body)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(mine ? Game.ink : .primary)
                        .background(mine ? Game.lemon : Game.panel, in: RoundedRectangle(cornerRadius: 16))
                }
                if !mine { Spacer(minLength: 40) }
            }
        }
    }
}

// MARK: Partida pública
struct MatchmakingView: View {
    @Bindable var game: GameStore
    var onCancel: () -> Void
    @State private var queuedAt = Date()
    @State private var showNoMatch = false
    @State private var widened = false

    var body: some View {
        let room = game.room
        let count = game.activePlayers.count
        VStack(spacing: 24) {
            if let starts = room?.startsAt {
                VStack(spacing: 6) {
                    Text("La partida empieza en").foregroundStyle(.secondary)
                    Text(Duration.seconds(max(0, starts.timeIntervalSince(game.now))).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 56, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Game.lemon)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: Int(starts.timeIntervalSince(game.now)))
                    Text("Mínimo alcanzado · \(count) / \(room?.maxPlayers ?? 8) jugadores").font(.subheadline)
                }
                .padding(.top, 24)
                GameList {
                    GameSection("Jugadores · \(count) / \(room?.maxPlayers ?? 8)") {
                        ForEach(game.activePlayers) { p in
                            HStack {
                                AvatarView(avatar: p.avatar, name: p.name, size: 32)
                                Text(p.name + (p.userId == game.me ? " (tú)" : ""))
                                Spacer()
                                Text("Nivel \(p.profile?.level ?? 1)").foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let room {
                        GameSection("Reglas de la partida") {
                            Text("\(room.roundsTotal) rondas · \(room.roundSeconds) s por ronda · \(room.categories.count) categorías clásicas · Competitiva (suma al ranking)")
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Spacer()
                MascotView(pose: .sleep, size: 170)
                ThinkingDots()
                Text("Buscando jugadores…").font(.title2.bold())
                Text(widened ? "Buscando jugadores de cualquier nivel." :
                        "Te emparejamos con jugadores de nivel similar (\(room?.levelMin ?? 1)–\(room?.levelMax ?? 1)).")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(Array(game.activePlayers.enumerated()), id: \.element.id) { i, p in
                        AvatarView(avatar: p.avatar, name: p.name, size: 44).popIn(i)
                    }
                }
                Text("\(count) de \(room?.minPlayers ?? 2) mínimos encontrados").font(.subheadline)
                Text(Duration.seconds(game.now.timeIntervalSince(queuedAt)).formatted(.time(pattern: .minuteSecond)) + " en cola")
                    .monospacedDigit().foregroundStyle(.secondary)
                Spacer()
            }
            Button(room?.startsAt == nil ? "Cancelar búsqueda" : "Salir de la cola", role: .destructive, action: onCancel)
                .buttonStyle(.bordered).controlSize(.large)
                .padding(.bottom)
        }
        .padding(.horizontal)
        .gameTitle("Partida pública")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: Int(game.now.timeIntervalSince(queuedAt))) { _, s in
            if s == 120 && room?.startsAt == nil { showNoMatch = true }
        }
        .alert("Aún no hay suficientes jugadores", isPresented: $showNoMatch) {
            Button("Ampliar rango de nivel") {
                widened = true
                Task { try? await API.widenMatch(game.roomId); await game.refresh() }
            }
            Button("Seguir esperando") { queuedAt = Date() }
            Button("Cancelar", role: .cancel, action: onCancel)
        } message: {
            Text("Llevas 2 minutos en cola. Puedes seguir esperando, ampliar el rango de nivel o crear una sala privada.")
        }
    }
}

/// Acción secundaria compacta (panel translúcido, color solo en el ícono).
struct SmallActionLabel: View {
    var icon: String
    var title: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .black))
                .foregroundStyle(Game.onFill(tint))
                .frame(width: 30, height: 30).background(Circle().fill(tint))
            Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                .lineLimit(1).contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Game.panelStroke, lineWidth: 1.5))
    }
}
