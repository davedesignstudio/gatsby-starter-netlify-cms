import AVFoundation

enum SoundEffect: String {
    case countdown
    case go
    case boost
    case itemPickup
    case collision
    case drift
    case spin
    case lapComplete
    case raceFinish
    case menuTap
    case cartSqueak

    var fileName: String {
        switch self {
        case .countdown: return "countdown"
        case .go: return "go"
        case .boost: return "boost"
        case .itemPickup: return "item_pickup"
        case .collision: return "collision"
        case .drift: return "cart_squeak"
        case .spin: return "spin"
        case .lapComplete: return "lap_complete"
        case .raceFinish: return "race_finish"
        case .menuTap: return "menu_tap"
        case .cartSqueak: return "cart_squeak"
        }
    }
}

enum MusicTrack: String {
    case aisleAmbience = "aisle_ambience"
    case raceTheme = "race_theme"
}

final class SoundManager {
    static let shared = SoundManager()

    private var sfxPlayers: [SoundEffect: AVAudioPlayer] = [:]
    private var musicPlayers: [MusicTrack: AVAudioPlayer] = [:]
    private var engine = AVAudioEngine()
    private var fallbackPlayer = AVAudioPlayerNode()
    private var fallbackConfigured = false

    private init() {
        configureAudioSession()
        preloadSounds()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }

    private func preloadSounds() {
        for effect in [SoundEffect.countdown, .go, .boost, .itemPickup, .collision, .drift, .spin, .lapComplete, .raceFinish, .menuTap, .cartSqueak] {
            if let player = makePlayer(named: effect.fileName, loops: false) {
                player.prepareToPlay()
                sfxPlayers[effect] = player
            }
        }

        if let ambience = makePlayer(named: MusicTrack.aisleAmbience.rawValue, loops: true) {
            ambience.volume = 0.35
            ambience.prepareToPlay()
            musicPlayers[.aisleAmbience] = ambience
        }

        if let theme = makePlayer(named: MusicTrack.raceTheme.rawValue, loops: true) {
            theme.volume = 0.45
            theme.prepareToPlay()
            musicPlayers[.raceTheme] = theme
        }
    }

    private func makePlayer(named name: String, loops: Bool) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = loops ? -1 : 0
            return player
        } catch {
            return nil
        }
    }

    func play(_ effect: SoundEffect) {
        guard GameSettings.shared.soundEnabled else { return }

        if let player = sfxPlayers[effect] {
            player.currentTime = 0
            player.play()
            return
        }

        playFallback(effect)
    }

    func startAmbience() {
        guard GameSettings.shared.soundEnabled else { return }
        musicPlayers[.aisleAmbience]?.play()
    }

    func stopAmbience() {
        musicPlayers[.aisleAmbience]?.stop()
    }

    func startRaceMusic() {
        guard GameSettings.shared.soundEnabled else { return }
        musicPlayers[.aisleAmbience]?.stop()
        musicPlayers[.raceTheme]?.currentTime = 0
        musicPlayers[.raceTheme]?.play()
    }

    func stopRaceMusic() {
        musicPlayers[.raceTheme]?.stop()
    }

    func stopAll() {
        stopAmbience()
        stopRaceMusic()
    }

    private func playFallback(_ effect: SoundEffect) {
        ensureFallbackEngine()
        guard fallbackConfigured else { return }

        let tones: (Double, Double, Float) = {
            switch effect {
            case .countdown: return (440, 0.12, 0.35)
            case .go: return (880, 0.25, 0.45)
            case .boost: return (660, 0.18, 0.4)
            case .itemPickup: return (523, 0.15, 0.35)
            case .collision: return (180, 0.2, 0.5)
            case .drift, .cartSqueak: return (600, 0.1, 0.25)
            case .spin: return (250, 0.3, 0.35)
            case .lapComplete: return (740, 0.22, 0.4)
            case .raceFinish: return (988, 0.5, 0.5)
            case .menuTap: return (392, 0.08, 0.25)
            }
        }()

        playTone(frequency: tones.0, duration: tones.1, volume: tones.2)
    }

    private func ensureFallbackEngine() {
        guard !fallbackConfigured else { return }
        engine.attach(fallbackPlayer)
        engine.connect(fallbackPlayer, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
            fallbackConfigured = true
        } catch {
            fallbackConfigured = false
        }
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData?[0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = exp(-time * 6)
            samples?[frame] = Float(sin(2 * .pi * frequency * time) * envelope) * volume
        }

        fallbackPlayer.scheduleBuffer(buffer, completionHandler: nil)
        if !fallbackPlayer.isPlaying { fallbackPlayer.play() }
    }
}
