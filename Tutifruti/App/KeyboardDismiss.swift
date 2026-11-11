import UIKit

/// Oculta el teclado al tocar fuera de un campo de texto, en toda la app.
/// El gesto no cancela el toque: botones, listas y otros controles siguen recibiéndolo.
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private var installed = Set<ObjectIdentifier>()

    /// Instala el gesto en todas las ventanas de la app (llamar al aparecer la escena; es idempotente).
    @MainActor func install() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where !installed.contains(ObjectIdentifier(window)) {
                let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing(_:)))
                tap.cancelsTouchesInView = false
                tap.requiresExclusiveTouchType = false
                tap.delegate = self
                window.addGestureRecognizer(tap)
                installed.insert(ObjectIdentifier(window))
            }
        }
    }

    // No interfiere con otros gestos (scroll, botones, menús).
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // Tocar otro campo de texto no debe cerrar el teclado (solo cambia de campo).
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let v = view {
            if v is UITextField || v is UITextView || v is UISearchBar { return false }
            view = v.superview
        }
        return true
    }
}
