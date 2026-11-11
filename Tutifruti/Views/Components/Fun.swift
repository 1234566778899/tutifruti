import SwiftUI

// MARK: Marca

/// Paleta de la marca (naranja de Tuti → rosa). El resto de la UI sigue usando colores del sistema.
enum Brand {
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.10)
    static let pink = Color(red: 0.98, green: 0.25, blue: 0.52)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.20)
    static let gradient = LinearGradient(colors: [orange, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let confetti: [Color] = [orange, pink, yellow, .green, .cyan, .purple, .blue]
}

/// Fondo suave con manchas de color que se mueven lentamente.
struct BrandBackground: View {
    var intensity: Double = 1
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let blobs: [(Color, Double, Double, Double)] = [
                    (Brand.orange, 0.15, 0.10, 0.0), (Brand.pink, 0.85, 0.30, 1.7),
                    (Brand.yellow, 0.25, 0.85, 3.1), (.purple, 0.90, 0.95, 4.4),
                ]
                for (color, x, y, phase) in blobs {
                    let r = max(size.width, size.height) * 0.55
                    let cx = size.width * (x + 0.06 * sin(t * 0.25 + phase))
                    let cy = size.height * (y + 0.05 * cos(t * 0.2 + phase))
                    let rect = CGRect(x: cx - r / 2, y: cy - r / 2, width: r, height: r)
                    g.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [color.opacity((scheme == .dark ? 0.28 : 0.22) * intensity), .clear]),
                        center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: r / 2))
                }
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: Mascota

enum MascotPose: String {
    case hello = "tuti_hello", judge = "tuti_judge", party = "tuti_party", sad = "tuti_sad", stop = "tuti_stop", sleep = "tuti_sleep"
    case bye = "tuti_bye", think = "tuti_think"
}

/// Tuti, la mascota, con una animación sutil según la pose.
struct MascotView: View {
    var pose: MascotPose
    var size: CGFloat = 160
    var animated = true
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(scale, anchor: .bottom)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .offset(y: offset)
            .onAppear {
                guard animated, !reduceMotion else { return }
                withAnimation(animation) { phase = true }
            }
            .accessibilityHidden(true)
    }

    private var animation: Animation {
        switch pose {
        case .party: .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
        case .stop: .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
        case .sleep: .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        default: .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        }
    }
    private var offset: CGFloat {
        switch pose {
        case .party: phase ? -size * 0.08 : 0
        case .hello, .judge: phase ? -size * 0.03 : 0
        default: 0
        }
    }
    private var rotation: Double {
        switch pose {
        case .hello: phase ? 3 : -3
        case .judge: phase ? -4 : 4
        case .stop: phase ? 2.5 : -2.5
        case .sad: phase ? 1.5 : -1.5
        default: 0
        }
    }
    private var scale: CGFloat {
        switch pose {
        case .sleep: phase ? 1.03 : 0.98
        case .party: phase ? 1.04 : 0.97
        default: 1
        }
    }
}

// MARK: Confeti

/// Lluvia de confeti. Cambia `trigger` para lanzar una nueva ráfaga.
struct ConfettiView: View {
    var trigger: Int
    var count = 90
    @State private var pieces: [Piece] = []
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Piece {
        var x: Double, vx: Double, vy: Double, spin: Double, size: Double, color: Color, shape: Int, delay: Double
    }

    var body: some View {
        TimelineView(.animation(paused: pieces.isEmpty)) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            Canvas { g, size in
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0, tt < 4 else { continue }
                    let x = p.x * size.width + p.vx * tt * 60
                    let y = -20 + p.vy * tt * 60 + 0.5 * 420 * tt * tt * 0.35
                    guard y < size.height + 30 else { continue }
                    var ctx = g
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.spin * tt))
                    ctx.scaleBy(x: cos(tt * p.spin * 0.7), y: 1)
                    ctx.opacity = min(1, max(0, (4 - tt) / 1.0))
                    let r = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / (p.shape == 0 ? 2 : 1))
                    ctx.fill(p.shape == 1 ? Path(ellipseIn: r) : Path(roundedRect: r, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { fire() }
        .onAppear { if trigger > 0 { fire() } }
        .accessibilityHidden(true)
    }

    private func fire() {
        guard !reduceMotion else { return }
        start = Date()
        pieces = (0..<count).map { _ in
            Piece(x: .random(in: 0...1), vx: .random(in: -1.2...1.2), vy: .random(in: 0.5...3),
                  spin: .random(in: 2...9), size: .random(in: 7...13), color: Brand.confetti.randomElement()!,
                  shape: .random(in: 0...2), delay: .random(in: 0...0.6))
        }
        Task {
            try? await Task.sleep(for: .seconds(5))
            if Date().timeIntervalSince(start) >= 4.9 { pieces = [] }
        }
    }
}

// MARK: Estilos y efectos

/// Botón que se encoge al presionar y hace "pop".
struct BouncyButtonStyle: ButtonStyle {
    var sound: Sound? = .tap
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, let sound { Sfx.play(sound, volume: 0.6) }
            }
    }
}

/// Botón grande con degradado de la marca.
struct GradientButtonStyle: ButtonStyle {
    var colors: [Color] = [Brand.orange, Brand.pink]
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: colors.last!.opacity(isEnabled ? 0.35 : 0), radius: 10, y: 5)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { Sfx.play(.tap, volume: 0.6) } }
    }
}

/// Sacudida horizontal (respuestas inválidas, errores).
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Número que cuenta hasta su valor al aparecer.
struct CountingText: View {
    var value: Int
    var font: Font = .title3.bold()
    var sound = false
    @State private var shown = 0

    var body: some View {
        Text("\(shown)")
            .font(font).monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .task(id: value) {
                let from = shown
                let steps = min(20, max(1, abs(value - from)))
                for i in 1...steps {
                    try? await Task.sleep(for: .milliseconds(35))
                    withAnimation(.snappy) { shown = from + (value - from) * i / steps }
                }
                if sound && value > from { Sfx.play(.coin, volume: 0.5) }
            }
    }
}

/// Entrada escalonada: aparece desde abajo con resorte, con retraso según su índice.
struct PopIn: ViewModifier {
    var index: Int = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.7)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.45).delay(Double(index) * 0.06)) { shown = true }
            }
    }
}

extension View {
    func popIn(_ index: Int = 0) -> some View { modifier(PopIn(index: index)) }
}

/// Insignia de puntos que flota hacia arriba ("+10").
struct FloatingPoints: View {
    var points: Int
    @State private var go = false
    var body: some View {
        Text(points > 0 ? "+\(points)" : "\(points)")
            .font(.headline.weight(.heavy))
            .foregroundStyle(points > 0 ? .green : .secondary)
            .offset(y: go ? -26 : 0)
            .opacity(go ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
            .allowsHitTesting(false)
    }
}
