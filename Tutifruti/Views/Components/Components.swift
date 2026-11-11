import SwiftUI

/// Avatar: ilustración (clave), foto (URL) o inicial.
struct AvatarView: View {
    var avatar: String
    var name: String = ""
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(.fill.tertiary)
            if let image = Avatars.imageName(for: avatar) {
                Image(image).resizable().scaledToFit()
            } else if avatar.hasPrefix("http"), let url = URL(string: avatar) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .clipShape(Circle())
            } else {
                Text(name.prefix(1).uppercased()).font(.system(size: size * 0.45, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(size >= 40 ? 0.12 : 0), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

struct StatTile: View {
    var value: String
    var label: String
    var systemImage: String? = nil
    var tint: Color = Game.lemon

    var body: some View {
        VStack(spacing: 3) {
            if let systemImage {
                // Un solo acento (amarillo) para todas las estadísticas: menos ruido de colores.
                Image(systemName: systemImage).font(.system(size: 16, weight: .black)).foregroundStyle(Game.lemon)
                    .frame(height: 22)
            }
            Text(value).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Game.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Game.panelStroke, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    var status: String
    var label: String? = nil

    var color: Color {
        switch status {
        case "valid", "accepted": .green
        case "invalid", "rejected": .red
        case "doubtful", "pending": .orange
        default: .secondary
        }
    }
    var text: String {
        if let label { return label }
        switch status {
        case "valid": return "Válida"
        case "invalid": return "Inválida"
        case "doubtful": return "Dudosa"
        case "empty": return "Vacía"
        case "accepted": return "Aceptada"
        case "rejected": return "Rechazada"
        default: return "Pendiente"
        }
    }

    var icon: String? {
        switch status {
        case "valid", "accepted": "checkmark"
        case "invalid", "rejected": "xmark"
        case "doubtful": "questionmark"
        case "pending": "hourglass"
        default: nil
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.black)) }
            Text(text)
        }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct ToastView: View {
    @Binding var text: String?

    var body: some View {
        if let text {
            Label(text, systemImage: "bell.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 6, y: 2)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { self.text = nil }
                }
                .onTapGesture { withAnimation { self.text = nil } }
        }
    }
}

/// Botón principal a lo ancho con estado de carga.
struct PrimaryButton: View {
    var title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var loading = false
    /// Color del botón caramelo (por defecto amarillo limón; rojo cereza si es destructivo).
    var color: Color? = nil
    var action: () async -> Void

    var body: some View {
        Button(role: role) {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(Game.onFill(resolvedColor)) }
                Text(title)
            }
        }
        .buttonStyle(CandyButtonStyle(color: resolvedColor, icon: loading ? nil : systemImage, height: 54))
        .disabled(loading)
        .padding(.horizontal, 2)
    }

    private var resolvedColor: Color { color ?? (role == .destructive ? Game.cherry : Game.lemon) }
}

extension View {
    /// Muestra un error como alerta nativa.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Algo salió mal", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

struct LetterBadge: View {
    var letter: String
    var size: CGFloat = 44
    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.55, weight: .black, design: .rounded))
            .frame(width: size, height: size)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: size * 0.02, y: size * 0.02)
            .background(Brand.gradient, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).stroke(.white.opacity(0.35), lineWidth: max(1, size * 0.025)).padding(size * 0.04))
            .shadow(color: Brand.pink.opacity(0.35), radius: size * 0.08, y: size * 0.05)
            .accessibilityLabel("Letra \(letter)")
    }
}

/// Etiqueta de interruptor con ícono en círculo de color.
struct GameToggleLabel: View {
    var icon: String
    var title: String
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .black)).foregroundStyle(Game.onFill(tint))
                .frame(width: 40, height: 40).background(Circle().fill(tint)).overlay(Circle().strokeBorder(Game.ink, lineWidth: 2))
            Text(title).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
        }
    }
}
