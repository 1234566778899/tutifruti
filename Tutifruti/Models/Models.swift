import Foundation
import SwiftUI

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var avatar: String
    var level: Int
    var xp: Int
    var totalPoints: Int
    var gamesPlayed: Int
    var gamesWon: Int
    var bestScore: Int
    var winStreak: Int
    var validAnswers: Int
    var isPlus: Bool
    var theme: String
    var language: String
    var notifPrefs: [String: Bool]
    var usernameChangedAt: Date?
    var lastSeen: Date
    var currentRoom: UUID?
    var createdAt: Date

    var xpForNext: Int { 250 * level }
    var winRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed) }
    var isOnline: Bool { lastSeen > Date().addingTimeInterval(-90) }
}

struct Room: Codable, Identifiable, Hashable {
    let id: UUID
    var code: String
    var name: String
    var hostId: UUID?
    var isPublic: Bool
    var ranked: Bool
    var status: String          // waiting | playing | finished | cancelled
    var maxPlayers: Int
    var minPlayers: Int
    var roundsTotal: Int
    var roundSeconds: Int
    var stopSeconds: Int
    var excludeHard: Bool
    var categories: [String]
    var allowCustom: Bool
    var currentRound: Int
    var usedLetters: [String]
    var startsAt: Date?
    var levelMin: Int
    var levelMax: Int
    var createdAt: Date
    var finishedAt: Date?
    /// Idioma de juego (el del anfitrión): es | en | pt. Opcional para tolerar filas antiguas.
    var language: String?

    var summary: String {
        "\(roundsTotal) rondas · \(roundSeconds) s por ronda · STOP \(stopSeconds) s · \(categories.count) categorías"
            + (excludeHard ? " · sin letras difíciles" : "")
    }
}

struct RoomPlayer: Codable, Identifiable, Hashable {
    var roomId: UUID
    var userId: UUID
    var joinedAt: Date
    var ready: Bool
    var score: Int
    var leftAt: Date?
    var lastSeen: Date
    var disputesLeft: Int
    var finalRank: Int?
    var xpGained: Int?
    var profile: Profile?

    var id: UUID { userId }
    var name: String { profile?.username ?? "jugador" }
    var avatar: String { profile?.avatar ?? Avatars.defaultKey }
    var isConnected: Bool { lastSeen > Date().addingTimeInterval(-45) }
}

struct Round: Codable, Identifiable, Hashable {
    let id: UUID
    var roomId: UUID
    var number: Int
    var letter: String
    var status: String          // playing | validating | results
    var startsAt: Date
    var endsAt: Date
    var closeAt: Date
    var stopBy: UUID?
    var stopAt: Date?
    var validationStartedAt: Date?
    var validationAttempts: Int
    var validatedByAi: Bool
    var nextAt: Date?
    /// Jugadores que marcaron "Listo" en los resultados de esta ronda.
    var readyUsers: [UUID]?
}

struct AnswerChecks: Codable, Hashable {
    var letter: Bool?
    var category: Bool?
    var realWord: Bool?
    var spelling: Bool?
}

struct Answer: Codable, Hashable, Identifiable {
    var roundId: UUID
    var userId: UUID
    var category: String
    var value: String
    var status: String          // pending | valid | invalid | doubtful | empty
    var reason: String?
    var checks: AnswerChecks?
    var points: Int
    var disputed: Bool

    var id: String { "\(roundId)-\(userId)-\(category)" }
    var statusLabel: String {
        switch status {
        case "valid": "Válida"
        case "invalid": "Inválida"
        case "doubtful": "Dudosa"
        case "empty": "Vacía"
        default: "Pendiente"
        }
    }
    var displayValue: String { value.trimmingCharacters(in: .whitespaces).isEmpty ? "— vacía —" : value }
}

struct Dispute: Codable, Identifiable, Hashable {
    let id: UUID
    var roundId: UUID
    var userId: UUID
    var targetUser: UUID
    var category: String
    var kind: String
    var justification: String
    var status: String          // pending | accepted | rejected
    var resolution: String?
    var oldStatus: String?
    var newStatus: String?
    var pointsDelta: Int
}

struct Reaction: Codable, Hashable {
    var roundId: UUID
    var userId: UUID
    var category: String
    var emoji: String
}

/// Resultado de abrir un enlace de amistad.
struct FriendLinkResult: Codable, Hashable, Identifiable {
    var status: String          // added | already | accepted_request
    var userId: UUID
    var username: String
    var avatar: String
    var level: Int
    var id: UUID { userId }
}

/// Sala pública abierta (lista de "Salas públicas").
struct PublicRoom: Codable, Identifiable, Hashable {
    var roomId: UUID
    var code: String
    var name: String
    var hostId: UUID
    var hostName: String
    var hostAvatar: String
    var hostLevel: Int
    var players: Int
    var maxPlayers: Int
    var roundsTotal: Int
    var roundSeconds: Int
    var categories: [String]
    var excludeHard: Bool
    var createdAt: Date
    var isMember: Bool
    var language: String?

    var id: UUID { roomId }
    var isFull: Bool { players >= maxPlayers }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    var roomId: UUID
    var userId: UUID?
    var body: String
    var kind: String
    var createdAt: Date
}

struct NotificationPayload: Codable, Hashable {
    var roomId: UUID?
    var code: String?
    var userId: UUID?
    var level: Int?
    var achievement: String?
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: Int
    var kind: String
    var title: String
    var body: String?
    var payload: NotificationPayload?
    var read: Bool
    var createdAt: Date
}

struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var kind: String
    var theme: String?
    var isPremium: Bool
    var ownerId: UUID?
    var sort: Int
}

struct CategorySet: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var categories: [String]
}

struct Achievement: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var icon: String
    var sort: Int
}

struct UserAchievement: Codable, Hashable {
    var userId: UUID
    var achievementId: String
    var unlockedAt: Date
}



struct HistoryRow: Codable, Identifiable, Hashable {
    var roomId: UUID
    var code: String
    var name: String
    var isPublic: Bool
    var finishedAt: Date?
    var players: Int
    var rounds: Int
    var score: Int
    var finalRank: Int?
    var xpGained: Int?
    var id: UUID { roomId }
}

struct FriendRow: Codable, Identifiable, Hashable {
    var userId: UUID
    var username: String
    var avatar: String
    var level: Int
    var lastSeen: Date
    var currentRoom: UUID?
    var playing: Bool
    var status: String          // pending | accepted
    var incoming: Bool
    var gamesTogether: Int
    var id: UUID { userId }
    var isOnline: Bool { lastSeen > Date().addingTimeInterval(-90) }
    var statusText: String {
        if playing { return "Jugando una partida" }
        if isOnline { return "En línea" }
        return lastSeen.formatted(.relative(presentation: .named))
    }
}

struct SearchUser: Codable, Identifiable, Hashable {
    var userId: UUID
    var username: String
    var avatar: String
    var level: Int
    var relation: String        // none | sent | received | friends
    var id: UUID { userId }
}

struct ActivityItem: Codable, Identifiable, Hashable {
    let id: Int
    var userId: UUID
    var text: String
    var detail: String?
    var createdAt: Date
    var profile: Profile?
}


struct HeadToHead: Codable, Hashable {
    var duelsMe: Int
    var duelsThem: Int
}

/// Avatares ilustrados (Assets.xcassets/Avatars, imagen `avatar_<clave>`). En la base se guarda la clave.
enum Avatars {
    static let defaultKey = "fox"
    static let free = ["fox", "owl", "panda", "frog", "octopus", "lion", "koala", "tiger", "monkey", "penguin", "unicorn", "turtle"]
    static let premium = ["fire_fox", "robot", "llama", "wise_owl", "stop_cat", "dragon"]
    static let names: [String: String] = [
        "fox": "Zorro", "owl": "Búho", "panda": "Panda", "frog": "Rana", "octopus": "Pulpo", "lion": "León",
        "koala": "Koala", "tiger": "Tigre", "monkey": "Mono", "penguin": "Pingüino", "unicorn": "Unicornio", "turtle": "Tortuga",
        "fire_fox": "Zorro astuto", "robot": "Robot letrado", "llama": "Llama rapera", "wise_owl": "Búho sabio",
        "stop_cat": "Gato STOP", "dragon": "Dragón",
    ]
    /// Avatares guardados antes como emoji → clave nueva.
    static let legacy: [String: String] = [
        "\u{1F98A}": "fox", "\u{1F989}": "owl", "\u{1F43C}": "panda", "\u{1F438}": "frog", "\u{1F419}": "octopus",
        "\u{1F981}": "lion", "\u{1F428}": "koala", "\u{1F42F}": "tiger", "\u{1F435}": "monkey", "\u{1F427}": "penguin",
        "\u{1F984}": "unicorn", "\u{1F422}": "turtle", "\u{1F916}": "robot", "\u{1F999}": "llama", "\u{1F63C}": "stop_cat",
        "\u{1F409}": "dragon",
    ]

    /// Nombre de la imagen para un valor de avatar (clave o emoji antiguo); nil si es foto o vacío.
    static func imageName(for value: String) -> String? {
        if names[value] != nil { return "avatar_" + value }
        let base = String(value.unicodeScalars.prefix(1).map(Character.init))
        if let key = legacy[base] ?? legacy[value] { return "avatar_" + key }
        if value.unicodeScalars.first.map({ $0.properties.isEmojiPresentation }) == true { return "avatar_" + defaultKey }
        return nil
    }
}

/// Reacciones a respuestas (se guardan como clave en `reactions.emoji`; se muestran con símbolos SF).
enum Reactions {
    static let all = ["haha", "fire", "wow", "clap", "hmm", "ouch"]

    static func symbol(_ key: String) -> String {
        switch key {
        case "haha": "face.smiling.inverse"
        case "fire": "flame.fill"
        case "wow": "exclamationmark.2"
        case "clap": "hands.clap.fill"
        case "hmm": "questionmark"
        default: "bolt.heart.fill"
        }
    }

    static func color(_ key: String) -> Color {
        switch key {
        case "haha": .yellow
        case "fire": .orange
        case "wow": .purple
        case "clap": .pink
        case "hmm": .teal
        default: .red
        }
    }

    static func name(_ key: String) -> String {
        ["haha": "risa", "fire": "fuego", "wow": "sorpresa", "clap": "aplauso", "hmm": "duda", "ouch": "auch"][key] ?? key
    }

    /// Convierte reacciones antiguas guardadas como emoji a su clave.
    static func key(for stored: String) -> String {
        if all.contains(stored) { return stored }
        let legacy: [String: String] = ["\u{1F602}": "haha", "\u{1F525}": "fire", "\u{1F62E}": "wow",
                                        "\u{1F44F}": "clap", "\u{1F914}": "hmm", "\u{1F480}": "ouch"]
        return legacy[stored] ?? "wow"
    }
}

/// Idiomas de juego (`profiles.language`, `rooms.language`).
enum GameLanguage {
    static let all: [(key: String, name: String)] = [("es", "Español"), ("en", "English"), ("pt", "Português")]
    static func name(_ key: String?) -> String { all.first { $0.key == (key ?? "es") }?.name ?? "Español" }
}
