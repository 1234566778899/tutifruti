import AVFoundation
import UIKit

/// Efectos de sonido del juego (WAV en Resources/Sounds, generados con tools/make_sounds.py).
/// Usa la sesión `.ambient`: respeta el interruptor de silencio y se mezcla con la música del usuario.
enum Sound: String, CaseIterable {
    case tap, tick, reveal, count, go, stop, hurry, valid, invalid, doubtful, coin, win, levelup, notify, message, join, lose
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    static let enabledKey = "soundEnabled"
    static let hapticsKey = "hapticsEnabled"

    private var players: [Sound: [AVAudioPlayer]] = [:]
    private var lastPlayed: [Sound: Date] = [:]

    var enabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
    var hapticsEnabled: Bool { UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool ?? true }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
            // dos instancias por sonido para que puedan solaparse (p. ej. tics rápidos)
            players[s] = (0..<2).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    /// Reproduce un efecto. `minGap` evita que el mismo sonido se dispare en ráfaga.
    func play(_ sound: Sound, volume: Float = 1, minGap: TimeInterval = 0.04) {
        guard enabled else { return }
        if let last = lastPlayed[sound], Date().timeIntervalSince(last) < minGap { return }
        lastPlayed[sound] = Date()
        guard let list = players[sound], let p = list.first(where: { !$0.isPlaying }) ?? list.first else { return }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notifyHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// Atajo: `Sfx.play(.tap)`.
@MainActor enum Sfx {
    static func play(_ s: Sound, volume: Float = 1) { SoundManager.shared.play(s, volume: volume) }
}
