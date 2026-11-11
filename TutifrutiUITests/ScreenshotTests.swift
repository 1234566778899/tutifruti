import XCTest

/// Capturas para App Store: juega una partida real en el simulador y guarda las pantallas.
/// No forma parte del esquema normal de pruebas (toca producción): se lanza con el esquema "Screenshots" junto con
/// `tools/screenshot_bots.mjs`, que mete jugadores simulados en la sala. Ver CLAUDE.md → "Capturas".
final class ScreenshotTests: XCTestCase {
    private let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory()
    private let app = XCUIApplication()

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    private func allowSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Permitir", "Allow"] {
            let b = springboard.buttons[label]
            if b.waitForExistence(timeout: 3) { b.tap(); return }
        }
    }

    private func waitFile(_ name: String, timeout: TimeInterval) -> Data? {
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if let d = try? Data(contentsOf: url), !d.isEmpty { return d }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    func testScreenshots() throws {
        continueAfterFailure = false
        app.launch()

        let play = app.buttons["Jugar ahora"]
        XCTAssertTrue(play.waitForExistence(timeout: 30))
        play.tap()

        let nick = app.textFields["Tu apodo"]
        XCTAssertTrue(nick.waitForExistence(timeout: 30))
        nick.tap()
        nick.typeText("Carlos\n")
        let begin = app.buttons["Empezar a jugar"]
        if !begin.isHittable { app.swipeUp() }
        begin.tap()
        allowSystemAlert()

        let create = app.buttons["Crear sala"]
        XCTAssertTrue(create.waitForExistence(timeout: 30))
        allowSystemAlert()
        shot("01_inicio")
        create.tap()

        let confirm = app.buttons["Crear sala"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        shot("02_crear")
        app.swipeUp()
        confirm.tap()

        // Sala de espera: los jugadores simulados entran y se marcan listos.
        let start = app.buttons["Iniciar partida"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        wait(for: [ready], timeout: 90)
        shot("03_sala")
        start.tap()

        // Ronda: el script fija la letra y deja las respuestas del anfitrión en answers.json.
        let data = try XCTUnwrap(waitFile("answers.json", timeout: 60))
        let answers = try JSONDecoder().decode([String].self, from: data)
        let first = app.textFields.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 40))
        Thread.sleep(forTimeInterval: 1.5)
        for (i, answer) in answers.enumerated() {
            let field = app.textFields.element(boundBy: i)
            guard field.waitForExistence(timeout: 5) else { break }
            if i > 0 { field.tap() }
            field.typeText(answer)
            if i == 3 { shot("04_ronda") }
        }
        let stop = app.buttons["¡STOP!"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        shot("04b_ronda_stop")
        stop.tap()

        // Resultados (la IA tarda unos segundos).
        _ = waitFile("results.flag", timeout: 90)
        Thread.sleep(forTimeInterval: 6)
        shot("05_resultados")
        app.swipeUp()
        shot("06_resultados_detalle")
    }
}
