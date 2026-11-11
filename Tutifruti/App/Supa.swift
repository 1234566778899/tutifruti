import Foundation
import Supabase

enum Config {
    static let supabaseURL = URL(string: "https://liejnmzxlpctqybecrbu.supabase.co")!
    /// Clave publicable: es la única que puede ir dentro de la app.
    static let supabaseKey = "sb_publishable_kcbf362MFjHNT0ozSuXmOA_zfX9koBw"
    static let deepLinkScheme = "tutifruti"
    /// Dominio de la página de invitaciones (Vercel, carpeta web/). Debe coincidir con applinks en el entitlement.
    static let inviteHost = "tutifruti-ai.vercel.app"

    /// A dónde vuelven los enlaces de correo (debe estar en Auth → URL Configuration → Redirect URLs).
    static let authCallbackURL = URL(string: "tutifruti://auth/callback")!

    /// Enlace https para compartir (WhatsApp lo hace clicable; abre la app por Universal Link o la página de respaldo).
    static func inviteURL(code: String) -> URL {
        URL(string: "https://\(inviteHost)/j/\(code)")!
    }

    /// Enlace de amistad: quien lo abre queda como amigo automáticamente.
    static func friendURL(token: String) -> URL {
        URL(string: "https://\(inviteHost)/a/\(token)")!
    }
}

enum Coders {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = parseDate(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha inválida: \(s)")
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseDate(_ raw: String) -> Date? {
        var s = raw.replacingOccurrences(of: " ", with: "T")
        if !s.contains("+") && !s.hasSuffix("Z") && s.count <= 26 { s += "Z" }
        // ISO8601DateFormatter solo acepta hasta 3 decimales: recortamos microsegundos.
        if let dot = s.firstIndex(of: ".") {
            let afterDot = s[s.index(after: dot)...]
            let digits = afterDot.prefix { $0.isNumber }
            if digits.count > 3 {
                let tz = afterDot.dropFirst(digits.count)
                s = String(s[..<dot]) + "." + digits.prefix(3) + tz
            }
        }
        return isoFrac.date(from: s) ?? iso.date(from: s)
    }
}

let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseKey,
    options: SupabaseClientOptions(
        db: .init(encoder: Coders.encoder, decoder: Coders.decoder)
    )
)
