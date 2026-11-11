import SwiftUI

/// Recompensas cosméticas: todo es gratis y se desbloquea subiendo de nivel (no hay compras dentro de la app).
enum StoreManager {
    static let items: [StoreItem] = [
        .init(id: "level.fire_fox", name: "Zorro astuto", art: "fire_fox", kind: .avatar, level: 3),
        .init(id: "level.robot", name: "Robot letrado", art: "robot", kind: .avatar, level: 6),
        .init(id: "level.stop_cat", name: "Gato STOP", art: "stop_cat", kind: .avatar, level: 10),
        .init(id: "level.llama", name: "Llama rapera", art: "llama", kind: .avatar, level: 15),
        .init(id: "level.owl", name: "Búho sabio", art: "wise_owl", kind: .avatar, level: 20),
        .init(id: "level.dragon", name: "Dragón", art: "dragon", kind: .avatar, level: 30),
        .init(id: "theme.clasico", name: "Clásico", art: "leaf.fill", kind: .theme, level: 1),
        .init(id: "theme.pizarra", name: "Pizarra", art: "rectangle.inset.filled", kind: .theme, level: 5),
        .init(id: "theme.neon", name: "Neón", art: "sparkles", kind: .theme, level: 10),
    ]

    /// Avatares de recompensa ya desbloqueados para ese nivel.
    static func ownedAvatars(level: Int) -> [String] {
        items.filter { $0.kind == .avatar && level >= $0.level }.map(\.art)
    }

    /// Nivel necesario para usar un tema (`profiles.theme`).
    static func themeLevel(_ key: String) -> Int {
        items.first { $0.themeKey == key }?.level ?? 1
    }
}

struct StoreItem: Identifiable, Hashable {
    enum Kind { case avatar, theme }
    var id: String
    var name: String
    /// Avatar: clave de la ilustración. Tema: símbolo SF.
    var art: String
    var kind: Kind
    /// Nivel en el que se desbloquea.
    var level: Int

    /// Clave en `profiles.theme` para los temas ("theme.neon" → "neon").
    var themeKey: String? { kind == .theme ? String(id.dropFirst("theme.".count)) : nil }
}

struct StoreView: View {
    @Environment(AppState.self) private var app
    @State private var tab = StoreItem.Kind.avatar
    @State private var error: String?

    private var level: Int { app.profile?.level ?? 1 }

    var body: some View {
        GameList {
            GameSegmented(selection: $tab, options: [(StoreItem.Kind.avatar, "Avatares"), (.theme, "Temas")])
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())

            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(StoreManager.items.filter { $0.kind == tab }) { item in
                        Button { Task { await tap(item) } } label: {
                            VStack(spacing: 6) {
                                if item.kind == .avatar {
                                    AvatarView(avatar: item.art, size: 64)
                                } else {
                                    Image(systemName: item.art).font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Brand.gradient, in: Circle())
                                }
                                Text(item.name).font(.caption.weight(.medium)).lineLimit(1)
                                Text(label(item)).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
                            .opacity(level >= item.level ? 1 : 0.55)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            } footer: {
                Label("Todo es gratis: se desbloquea al subir de nivel. Son solo cosméticos, no dan ventajas en la partida.",
                      systemImage: "info.circle")
            }
        }
        .gameTitle("Recompensas")
        .errorAlert($error)
    }

    private func label(_ item: StoreItem) -> String {
        guard level >= item.level else { return "Nivel \(item.level)" }
        if let key = item.themeKey { return AppState.usableTheme(app.profile) == key ? "En uso" : "Usar" }
        return app.profile?.avatar == item.art ? "En uso" : "Usar"
    }

    private func tap(_ item: StoreItem) async {
        guard level >= item.level else { return }
        Sfx.play(.tap)
        do {
            if let key = item.themeKey { try await API.updateProfile(theme: key) }
            else { try await API.updateProfile(avatar: item.art) }
            await app.refreshProfile()
        } catch { self.error = friendlyError(error) }
    }
}
