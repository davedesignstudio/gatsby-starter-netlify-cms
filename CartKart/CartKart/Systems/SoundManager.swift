import AVFoundation

enum SoundEffect {
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
}

final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isConfigured = false

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup can fail on simulator; game still runs silently.
        }
    }

    private func ensureEngine() {
        guard !isConfigured else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
            isConfigured = true
        } catch {
            isConfigured = false
        }
    }

    func play(_ effect: SoundEffect) {
        guard GameSettings.shared.soundEnabled else { return }
        ensureEngine()
        guard isConfigured else { return }

        let (frequency, duration, volume): (Double, Double, Float) = {
            switch effect {
            case .countdown: return (440, 0.12, 0.35)
            case .go: return (880, 0.25, 0.45)
            case .boost: return (660, 0.18, 0.4)
            case .itemPickup: return (523, 0.15, 0.35)
            case .collision: return (180, 0.2, 0.5)
            case .drift: return (300, 0.08, 0.2)
            case .spin: return (250, 0.3, 0.35)
            case .lapComplete: return (740, 0.22, 0.4)
            case .raceFinish: return (988, 0.5, 0.5)
            case .menuTap: return (392, 0.08, 0.25)
            }
        }()

        playTone(frequency: frequency, duration: duration, volume: volume)
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
            let sample = sin(2 * .pi * frequency * time) * envelope
            samples?[frame] = Float(sample) * volume
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }
}
