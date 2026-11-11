import SwiftUI
import StoreKit

/// Compras con StoreKit 2. Los IDs deben existir en App Store Connect (en local usa Products.storekit).
@MainActor @Observable
final class StoreManager {
    static let plusIDs = ["com.carlosordaz.tutifruti.plus.monthly", "com.carlosordaz.tutifruti.plus.yearly"]
    static let items: [StoreItem] = [
        .init(id: "com.carlosordaz.tutifruti.avatar.fox", name: "Zorro astuto", art: "fire_fox", kind: .avatar, requirement: .purchase),
        .init(id: "com.carlosordaz.tutifruti.avatar.robot", name: "Robot letrado", art: "robot", kind: .avatar, requirement: .purchase),
        .init(id: "plus.llama", name: "Llama rapera", art: "llama", kind: .avatar, requirement: .plus),
        .init(id: "level.owl", name: "Búho sabio", art: "wise_owl", kind: .avatar, requirement: .level(20)),
        .init(id: "com.carlosordaz.tutifruti.avatar.cat", name: "Gato STOP", art: "stop_cat", kind: .avatar, requirement: .purchase),
        .init(id: "level.dragon", name: "Dragón", art: "dragon", kind: .avatar, requirement: .level(30)),
        .init(id: "theme.clasico", name: "Clásico", art: "leaf.fill", kind: .theme, requirement: .level(1)),
        .init(id: "theme.pizarra", name: "Pizarra", art: "rectangle.inset.filled", kind: .theme, requirement: .level(5)),
        .init(id: "theme.neon", name: "Neón", art: "sparkles", kind: .theme, requirement: .plus),
        .init(id: "cats.tecnologia", name: "Tecnología", art: "desktopcomputer", kind: .category, requirement: .plus),
    ]

    var products: [String: Product] = [:]
    var owned: Set<String> = []
    var purchasing: String?
    var hasPlus = false

    var ownedAvatars: [String] {
        Self.items.filter { $0.kind == .avatar && (owned.contains($0.id) || ($0.requirement == .plus && hasPlus)) }.map(\.art)
    }

    init() {
        Task { await load() }
        Task { await listen() }
    }

    func load() async {
        let ids = Self.plusIDs + Self.items.filter { $0.requirement == .purchase }.map(\.id)
        if let list = try? await Product.products(for: ids) {
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var set = await API.ownedItems()
        var plus = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result {
                set.insert(t.productID)
                if Self.plusIDs.contains(t.productID) { plus = true }
                try? await sync(t, jws: result.jwsRepresentation)
            }
        }
        owned = set
        hasPlus = plus
    }

    /// El servidor verifica la firma de Apple y otorga el artículo (Plus o compra). Las transacciones ya vistas
    /// en esta instalación no se reenvían.
    private func sync(_ t: StoreKit.Transaction, jws: String) async throws {
        let key = "verified.\(t.id)"
        if UserDefaults.standard.bool(forKey: key) { return }
        try await API.verifyPurchase(jws: jws)
        UserDefaults.standard.set(true, forKey: key)
    }

    private func listen() async {
        for await result in Transaction.updates {
            if case .verified(let t) = result {
                try? await sync(t, jws: result.jwsRepresentation)
                await t.finish()
                await refreshEntitlements()
            }
        }
    }

    func buy(_ id: String) async throws -> Bool {
        guard let product = products[id] else { throw APIError.message("Producto no disponible todavía en App Store Connect.") }
        purchasing = id
        defer { purchasing = nil }
        // appAccountToken = id del jugador: el servidor comprueba que la compra sea de esta cuenta.
        var options: Set<Product.PurchaseOption> = []
        if let me = API.myId { options.insert(.appAccountToken(me)) }
        let result = try await product.purchase(options: options)
        guard case .success(let verification) = result, case .verified(let t) = verification else { return false }
        try await sync(t, jws: verification.jwsRepresentation)
        await t.finish()
        await refreshEntitlements()
        return true
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}

struct StoreItem: Identifiable, Hashable {
    enum Kind { case avatar, theme, category }
    enum Requirement: Hashable { case purchase, plus, level(Int) }
    var id: String
    var name: String
    /// Avatar: clave de la ilustración. Tema/categoría: símbolo SF.
    var art: String
    var kind: Kind
    var requirement: Requirement

    /// Clave en `profiles.theme` para los temas ("theme.neon" → "neon").
    var themeKey: String? { kind == .theme ? String(id.dropFirst("theme.".count)) : nil }
}

struct StoreView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppState.self) private var app
    @State private var tab = StoreItem.Kind.avatar
    @State private var error: String?

    var body: some View {
        GameList {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tutifruti Plus", systemImage: "sparkles").font(.title3.bold())
                    Text("Salas avanzadas, estadísticas ampliadas y categorías especiales.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink { PlusView() } label: { Label(store.hasPlus ? "Ya eres Plus" : "Ver planes", systemImage: store.hasPlus ? "checkmark.seal.fill" : "crown.fill").fontWeight(.semibold) }
                }
                .padding(.vertical, 4)
            }
            GameSegmented(selection: $tab, options: [(StoreItem.Kind.avatar, "Avatares"), (.theme, "Temas"), (.category, "Categorías")])
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
                            .overlay { if store.purchasing == item.id { ProgressView() } }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            } footer: {
                Label("Los artículos son solo cosméticos: no dan ventajas en la partida.", systemImage: "info.circle")
            }
            Section {
                Button("Restaurar compras") { Task { await store.restore() } }
            }
        }
        .gameTitle("Tienda")
        .errorAlert($error)
    }

    private func label(_ item: StoreItem) -> String {
        if item.kind == .theme, let key = item.themeKey {
            if AppState.usableTheme(app.profile) == key { return "En uso" }
            if unlocked(item) { return "Equipar" }
        }
        if store.owned.contains(item.id) { return "Tuyo" }
        switch item.requirement {
        case .purchase: return store.products[item.id]?.displayPrice ?? "—"
        case .plus: return store.hasPlus ? "Tuyo" : "Plus"
        case .level(let l): return (app.profile?.level ?? 0) >= l ? "Tuyo" : "Nivel \(l)"
        }
    }

    private func unlocked(_ item: StoreItem) -> Bool {
        switch item.requirement {
        case .purchase: store.owned.contains(item.id)
        case .plus: store.hasPlus || app.profile?.isPlus == true
        case .level(let l): (app.profile?.level ?? 0) >= l
        }
    }

    private func tap(_ item: StoreItem) async {
        if item.kind == .theme, let key = item.themeKey {
            guard unlocked(item) else { return }
            Sfx.play(.tap)
            do { try await API.updateProfile(theme: key); await app.refreshProfile() } catch { self.error = friendlyError(error) }
            return
        }
        guard item.requirement == .purchase, !store.owned.contains(item.id) else { return }
        do { _ = try await store.buy(item.id) } catch { self.error = friendlyError(error) }
    }
}

struct PlusView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppState.self) private var app
    @State private var selected = StoreManager.plusIDs[1]
    @State private var error: String?

    private let perks = [
        "Salas personalizadas avanzadas (hasta 12 jugadores, reglas extra)",
        "Categorías especiales y temáticas premium",
        "Estadísticas ampliadas",
        "Avatares y temas exclusivos",
    ]

    var body: some View {
        GameList {
            Section {
                ForEach(perks, id: \.self) { Label($0, systemImage: "checkmark.circle.fill").symbolRenderingMode(.multicolor) }
            }
            Section {
                planRow(StoreManager.plusIDs[0], "Mensual", fallback: "$2,99 / mes")
                planRow(StoreManager.plusIDs[1], "Anual", fallback: "$19,99 / año · ahorra 44 %")
            }
            Section {
                PrimaryButton(title: store.hasPlus ? "Ya tienes Plus" : "Suscribirme con Apple", systemImage: "apple.logo",
                              loading: store.purchasing != nil) {
                    do { if try await store.buy(selected) { await app.refreshProfile() } } catch { self.error = friendlyError(error) }
                }
                .disabled(store.hasPlus)
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            } footer: {
                Text("Se cobra a tu Apple ID. Renovación automática, cancela en Ajustes de iOS.")
            }
        }
        .gameTitle("Tutifruti Plus")
        .errorAlert($error)
    }

    private func planRow(_ id: String, _ title: String, fallback: String) -> some View {
        Button { selected = id } label: {
            HStack {
                Image(systemName: selected == id ? "largecircle.fill.circle" : "circle").foregroundStyle(Color.accentColor)
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(store.products[id].map { "\($0.displayPrice) / \(title == "Mensual" ? "mes" : "año")" } ?? fallback)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }
}
