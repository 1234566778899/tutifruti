import SwiftUI

// MARK: Estilo "arcade frutal" de Tutifruti
// Fondo verde azulado profundo con patrón de frutas y letras, tarjetas crema con relieve,
// botones "caramelo" con borde inferior 3D y títulos gruesos con contorno. Original de Tutifruti.

enum Game {
    // Fondo
    static let deep = Color(red: 0.05, green: 0.27, blue: 0.33)       // verde azulado profundo
    static let deeper = Color(red: 0.03, green: 0.17, blue: 0.22)
    static let header = Color(red: 0.07, green: 0.36, blue: 0.42)
    static let night = Color(red: 0.04, green: 0.09, blue: 0.20)       // azul noche (parte baja del fondo)
    // Superficies
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)
    static let creamEdge = Color(red: 0.93, green: 0.82, blue: 0.64)
    static let ink = Color(red: 0.18, green: 0.11, blue: 0.08)        // contorno café oscuro
    static let panel = Color.white.opacity(0.10)
    static let panelStroke = Color.white.opacity(0.18)
    // Colores de acción
    static let tangerine = Color(red: 1.0, green: 0.58, blue: 0.12)
    static let lime = Color(red: 0.55, green: 0.85, blue: 0.20)
    static let cherry = Color(red: 0.93, green: 0.22, blue: 0.36)
    static let sky = Color(red: 0.25, green: 0.72, blue: 0.95)
    /// Color principal (acento): amarillo limón #FFD23F, contraste ≥ 5:1 sobre todas las superficies oscuras.
    static let lemon = Color(red: 1.0, green: 0.824, blue: 0.247)
    static let grape = Color(red: 0.62, green: 0.38, blue: 0.95)

    static func edge(_ c: Color) -> Color { c.mix(with: .black, by: 0.32) }

    /// Texto legible sobre un relleno: café oscuro sobre colores claros, blanco sobre oscuros.
    static func onFill(_ c: Color) -> Color { c.isLight ? ink : .white }
}

extension Color {
    /// Luminancia relativa > 0,4 (amarillo, lima, naranja, celeste…).
    var isLight: Bool {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func f(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b) > 0.4
    }

    /// Mezcla simple (iOS 17 no tiene `mix`): interpola en RGB.
    func mix(with other: Color, by amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(amount)
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, opacity: a1 + (a2 - a1) * t)
    }
}

// MARK: Fondo

/// Fondo de juego: degradado profundo + patrón de frutas/letras (imagen `game_pattern`) que se desliza lento.
struct GameBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [Game.header, Game.deep, Game.night], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let tile: CGFloat = 320
                let off = CGFloat((t * 6).truncatingRemainder(dividingBy: Double(tile)))
                Canvas { g, size in
                    guard let img = g.resolveSymbol(id: 0) else { return }
                    var y = -tile + off
                    while y < size.height {
                        var x = -tile + off * 0.5
                        while x < size.width {
                            g.draw(img, in: CGRect(x: x, y: y, width: tile, height: tile))
                            x += tile
                        }
                        y += tile
                    }
                } symbols: {
                    Image("game_pattern").resizable().frame(width: 320, height: 320).tag(0)
                }
                .opacity(0.045)
            }
            RadialGradient(colors: [Game.tangerine.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.08), startRadius: 0, endRadius: 380)
            // viñeta: oscurece los bordes para centrar la atención
            RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 220, endRadius: 650)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Aplica el fondo de juego a una pantalla con List/Form/ScrollView y estiliza la barra de navegación.
    func gameScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { GameBackground() }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .environment(\.colorScheme, .dark)
    }

    /// Fila de lista con tarjeta translúcida del tema.
    func gameRow() -> some View {
        listRowBackground(Game.panel)
    }
}

// MARK: Tipografía

/// Título grueso con contorno oscuro (estilo cartel de juego).
struct OutlinedTitle: View {
    var text: String
    var size: CGFloat = 28
    var fill: Color = Game.lemon
    var stroke: Color = Game.ink

    var body: some View {
        let t = Text(text.uppercased()).font(.system(size: size, weight: .black, design: .rounded))
            .lineLimit(1).minimumScaleFactor(0.55)
        ZStack {
            // contorno: copias desplazadas
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                t.foregroundStyle(stroke).offset(x: cos(a) * size * 0.07, y: sin(a) * size * 0.07)
            }
            t.foregroundStyle(stroke).offset(y: size * 0.11)       // sombra inferior
            t.foregroundStyle(fill)
        }
        .accessibilityElement()
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: Botones

/// Botón "caramelo": cápsula con borde inferior 3D, ícono en medallón y texto en mayúsculas.
struct CandyButtonStyle: ButtonStyle {
    var color: Color = Game.tangerine
    var textColor: Color? = nil
    var icon: String? = nil
    var height: CGFloat = 58
    @Environment(\.isEnabled) private var isEnabled

    /// Relieve sutil: borde inferior corto y suave, contorno fino y brillo leve.
    private let lift: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let depth: CGFloat = pressed ? 1 : lift
        let fg = textColor ?? Game.onFill(color)
        let stroke: CGFloat = 1.5
        ZStack(alignment: .top) {
            // Silueta completa (cara + relieve) con un único contorno continuo.
            Capsule().fill(color.mix(with: .black, by: 0.22))
                .overlay { Capsule().strokeBorder(Game.ink.opacity(0.5), lineWidth: stroke) }
            // Cara del botón: dentro del contorno, sin borde propio (no hay línea entre cara y relieve).
            Capsule()
                .fill(LinearGradient(colors: [color.mix(with: .white, by: 0.10), color], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.14)).frame(height: height * 0.22).padding(.horizontal, 22).padding(.top, 4)
                }
                .padding([.top, .horizontal], stroke)
                .frame(height: height)
                .offset(y: lift - depth)
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: height * 0.30, weight: .heavy))
                        .foregroundStyle(color)
                        .frame(width: height * 0.62, height: height * 0.62)
                        .background(Circle().fill(.white))
                }
                configuration.label
                    .font(.system(size: height * 0.30, weight: .heavy, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(fg)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if icon != nil { Spacer(minLength: height * 0.62) }
            }
            .padding(.horizontal, 8)
            .frame(height: height)
            .offset(y: lift - depth)
        }
        .frame(height: height + lift)
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.5)
        .saturation(isEnabled ? 1 : 0.4)
        .animation(.spring(duration: 0.18, bounce: 0.4), value: pressed)
        .onChange(of: pressed) { _, p in if p { Sfx.play(.tap, volume: 0.6) } }
    }
}

/// Botón redondo de icono (barra superior, acciones rápidas).
struct RoundIconButtonStyle: ButtonStyle {
    var color: Color = Game.cream
    var iconColor: Color = Game.ink
    var size: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        ZStack {
            Circle().fill(Game.edge(color)).offset(y: 4)
            Circle().fill(color)
                .overlay { Circle().strokeBorder(Game.ink.opacity(0.85), lineWidth: 2.5) }
                .offset(y: pressed ? 3 : 0)
            configuration.label
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundStyle(iconColor)
                .offset(y: pressed ? 3 : 0)
        }
        .frame(width: size, height: size + 4)
        .animation(.spring(duration: 0.15), value: pressed)
        .onChange(of: pressed) { _, p in if p { Sfx.play(.tap, volume: 0.5) } }
    }
}

// MARK: Tarjetas

/// Tarjeta crema con borde y relieve inferior.
struct CreamCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Game.ink)
            .environment(\.colorScheme, .light)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Game.creamEdge).offset(y: 5)
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Game.cream)
                    .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Game.ink.opacity(0.85), lineWidth: 2.5) }
            }
            .padding(.bottom, 5)
    }
}

/// Panel translúcido sobre el fondo oscuro (secciones, listas).
struct GamePanel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Game.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Game.panelStroke, lineWidth: 1.5) }
    }
}

/// Encabezado de sección en mayúsculas con contorno.
struct SectionTitle: View {
    var text: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            OutlinedTitle(text: text, size: 18, fill: Game.lemon)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

// MARK: Diálogo de juego

/// Diálogo modal ilustrado (p. ej. "¿Salir de la sala?") con botones NO / SÍ.
struct GameDialog: View {
    var title: String
    var message: String
    var mascot: MascotPose = .bye
    var confirmTitle: String = "Sí"
    var cancelTitle: String = "No"
    var destructive = true
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.55 : 0).ignoresSafeArea().onTapGesture(perform: close)
            if shown {
                CreamCard(padding: 22) {
                    VStack(spacing: 14) {
                        OutlinedTitle(text: title, size: 30, fill: .white, stroke: Game.ink)
                        MascotView(pose: mascot, size: 170)
                        Text(message)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Game.ink)
                        HStack(spacing: 12) {
                            Button(cancelTitle, action: close)
                                .buttonStyle(CandyButtonStyle(color: Game.sky, icon: "xmark", height: 52))
                            Button(confirmTitle) {
                                withAnimation(.spring(duration: 0.25)) { shown = false }
                                onConfirm()
                            }
                            .buttonStyle(CandyButtonStyle(color: destructive ? Game.cherry : Game.lime, icon: "checkmark", height: 52))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 22)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.45)) { shown = true } }
    }

    private func close() {
        withAnimation(.spring(duration: 0.25)) { shown = false }
        Task { try? await Task.sleep(for: .milliseconds(200)); onCancel() }
    }
}

// MARK: Insignia de estado (estilo juego)

struct GamePill: View {
    var text: String
    var icon: String? = nil
    var color: Color = Game.lime

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption.weight(.black)) }
            Text(text).font(.system(.caption, design: .rounded).weight(.black)).textCase(.uppercase)
                .lineLimit(1).fixedSize()
        }
        .foregroundStyle(Game.onFill(color))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(color))
        .overlay(Capsule().strokeBorder(Game.ink.opacity(0.8), lineWidth: 1.5))
    }
}

// MARK: Listas con el estilo del juego

/// `List` cuyas filas usan el panel translúcido del tema (las filas que fijan su propio fondo lo conservan).
struct GameList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        List {
            Group { content }
                .listRowBackground(Game.panel)
                .listRowSeparatorTint(.white.opacity(0.15))
        }
        .gameScreen()
    }
}

/// `Form` con el mismo estilo.
struct GameForm<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        Form {
            Group { content }
                .listRowBackground(Game.panel)
                .listRowSeparatorTint(.white.opacity(0.15))
        }
        .gameScreen()
    }
}

// MARK: Título de pantalla

extension View {
    /// Título de juego centrado (con contorno) en la barra de navegación.
    func gameTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { OutlinedTitle(text: title, size: 22) }
            }
    }
}

// MARK: Selector segmentado

/// Selector de pestañas con estilo de juego (reemplaza al `.segmented` del sistema).
struct GameSegmented<T: Hashable>: View {
    @Binding var selection: T
    var options: [(T, String)]
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let selected = value == selection
                Button {
                    guard !selected else { return }
                    withAnimation(.spring(duration: 0.3, bounce: 0.3)) { selection = value }
                    Sfx.play(.tap, volume: 0.5)
                } label: {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(selected ? Game.ink : .white.opacity(0.75))
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background {
                            if selected {
                                Capsule().fill(Game.lemon)
                                    .overlay(Capsule().strokeBorder(Game.ink.opacity(0.6), lineWidth: 1.5))
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                        // Todo el segmento es tocable (no solo las letras).
                        .contentShape(Capsule())
                }
                .buttonStyle(SegmentPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Game.deeper.opacity(0.7)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1.5))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Respuesta visual al presionar un segmento.
private struct SegmentPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: Fila de menú con ícono ilustrado

/// Fila de menú: ícono ilustrado (`icon_*`), título y detalle, sobre panel con relieve.
struct GameMenuRow: View {
    var icon: String
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(icon).resizable().scaledToFit().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                if let detail { Text(detail).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.65)).lineLimit(1) }
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Estado vacío con Tuti.
struct GameEmptyState: View {
    var pose: MascotPose = .think
    var title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            MascotView(pose: pose, size: 130)
            OutlinedTitle(text: title, size: 20)
                .multilineTextAlignment(.center)
            if let message {
                Text(message).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// Sección de lista con título de juego (mismo cierre de llave que `Section("…") { }`).
struct GameSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        Section {
            content
        } header: {
            SectionTitle(text: title)
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
        }
    }
}
