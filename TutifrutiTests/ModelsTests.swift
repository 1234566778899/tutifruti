import XCTest
@testable import Tutifruti

final class ModelsTests: XCTestCase {
    func testParseDateAcceptsPostgresFormats() {
        XCTAssertNotNil(Coders.parseDate("2026-11-11T12:00:00Z"))
        XCTAssertNotNil(Coders.parseDate("2026-11-11T12:00:00.123456+00:00"))   // microsegundos
        XCTAssertNotNil(Coders.parseDate("2026-11-11 12:00:00.5"))              // sin zona → UTC
        XCTAssertNil(Coders.parseDate("ayer"))
    }

    func testAvatarImageNames() {
        XCTAssertEqual(Avatars.imageName(for: "fox"), "avatar_fox")
        XCTAssertEqual(Avatars.imageName(for: "\u{1F98A}"), "avatar_fox")      // emoji antiguo
        XCTAssertNil(Avatars.imageName(for: "https://example.com/a.jpg"))       // foto
        XCTAssertEqual(Avatars.free.count, 12)
    }

    func testLanguageNames() {
        XCTAssertEqual(GameLanguage.name("en"), "English")
        XCTAssertEqual(GameLanguage.name(nil), "Español")
        XCTAssertEqual(GameLanguage.name("xx"), "Español")
    }

    func testStoreThemeKeys() {
        let themes = StoreManager.items.filter { $0.kind == .theme }
        XCTAssertEqual(Set(themes.compactMap(\.themeKey)), ["clasico", "pizarra", "neon"])
        XCTAssertNil(StoreManager.items.first { $0.kind == .avatar }?.themeKey)
    }

    @MainActor
    func testUsableThemeRequiresUnlock() throws {
        var p = try profile(theme: "neon", level: 1, plus: false)
        XCTAssertEqual(AppState.usableTheme(p), "clasico")
        p.isPlus = true
        XCTAssertEqual(AppState.usableTheme(p), "neon")
        p.theme = "pizarra"
        XCTAssertEqual(AppState.usableTheme(p), "clasico")
        p.level = 5
        XCTAssertEqual(AppState.usableTheme(p), "pizarra")
        XCTAssertEqual(AppState.usableTheme(nil), "clasico")
    }

    @MainActor
    func testThemePalettesExist() {
        for key in ["clasico", "pizarra", "neon"] { XCTAssertNotNil(ThemePalette.all[key]) }
        ThemeStore.shared.key = "inexistente"
        XCTAssertNotNil(ThemeStore.shared.palette)   // vuelve al clásico
        ThemeStore.shared.key = "clasico"
    }

    private func profile(theme: String, level: Int, plus: Bool) throws -> Profile {
        let json = """
        {"id":"8f0e2d1c-1111-4c2b-9a3e-000000000001","username":"prueba","avatar":"fox","level":\(level),"xp":0,
         "total_points":0,"games_played":0,"games_won":0,"best_score":0,"win_streak":0,"valid_answers":0,
         "is_plus":\(plus),"theme":"\(theme)","language":"es","notif_prefs":{},"last_seen":"2026-11-11T12:00:00Z",
         "created_at":"2026-11-11T12:00:00Z","is_admin":false}
        """
        return try Coders.decoder.decode(Profile.self, from: Data(json.utf8))
    }
}
