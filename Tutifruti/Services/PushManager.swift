import UIKit
import UserNotifications

/// Notificaciones push (APNs): pide permiso, registra el device token en el servidor y abre la pantalla
/// correspondiente al tocar un aviso. El servidor envía cada fila nueva de `notifications` (Edge Function send-push).
@MainActor
final class PushManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushManager()
    private(set) var token: String?
    weak var app: AppState?

    #if DEBUG
    private let sandbox = true
    #else
    private let sandbox = false
    #endif

    /// Pide permiso (solo la primera vez muestra el diálogo) y registra el dispositivo.
    func enable() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        case .denied:
            return
        default:
            break
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegister(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        Task { await API.registerPushToken(hex, sandbox: sandbox) }
    }

    /// Al cerrar sesión el dispositivo deja de recibir avisos de esa cuenta.
    func disable() async {
        if let token { await API.unregisterPushToken(token) }
        token = nil
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    func setBadge(_ n: Int) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(n) }
    }

    // En primer plano ya se muestra el aviso flotante de la app: no se duplica con el banner del sistema.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let kind = info["kind"] as? String
        let code = info["code"] as? String
        await MainActor.run { open(kind: kind, code: code) }
    }

    private func open(kind: String?, code: String?) {
        guard let app else { return }
        switch kind {
        case "room_invite":
            if let code { app.handleDeepLink(URL(string: "\(Config.deepLinkScheme)://join/\(code)")!) }
        case "friend_request", "friend_online":
            app.selectedTab = .friends
        case "results":
            app.selectedTab = .profile
        default:
            app.selectedTab = .home
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs:", error.localizedDescription)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // El delegado debe asignarse antes de terminar el arranque para recibir el toque que abrió la app.
        UNUserNotificationCenter.current().delegate = PushManager.shared
        return true
    }
}
