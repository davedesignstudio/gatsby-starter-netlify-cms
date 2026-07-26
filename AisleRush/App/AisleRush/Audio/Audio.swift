import AVFoundation
import Foundation

/// Every sound is synthesised at launch, so the app ships no audio files.
/// Squeaky casters, tinned clangs and a PA chime are all just maths.
final class Audio {
    static let shared = Audio()

    enum Effect: String, CaseIterable {
        case beep
        case go
        case pickup
        case powerUp
        case throwItem
        case boost
        case crash
        case bump
        case splat
        case clatter
        case lap
        case finalLap
        case finish
        case fanfare
        case announce
        case uiTap
    }

    var isEnabled = true {
        didSet { if !isEnabled { stopEngineLoop() } }
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let rattlePlayer = AVAudioPlayerNode()
    /// `AVAudioPlayerNode` has no usable playback rate on a stereo mixer, so
    /// the rattle runs through a varispeed unit to pitch with road speed.
    private let rattleSpeed = AVAudioUnitVarispeed()
    private var rattleBuffer: AVAudioPCMBuffer?
    private var isRunning = false
    private var rattleActive = false
    private var observers: [NSObjectProtocol] = []

    private init() {}

    // MARK: - Lifecycle

    func prepare() {
        guard !isRunning else { return }
        configureSession()

        // A small pool of voices, so overlapping effects do not cut each other.
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.attach(rattlePlayer)
        engine.attach(rattleSpeed)
        engine.connect(rattlePlayer, to: rattleSpeed, format: format)
        engine.connect(rattleSpeed, to: engine.mainMixerNode, format: format)

        for effect in Effect.allCases {
            buffers[effect] = render(effect)
        }
        rattleBuffer = renderRattle()

        do {
            try engine.start()
            isRunning = true
            for player in players { player.play() }
        } catch {
            isRunning = false
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // Ambient already mixes with other audio, and a racing game should
        // never stop somebody's podcast. Passing .mixWithOthers here would
        // throw: that option is only valid for playback categories.
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)

        // A phone call, Siri or a route change stops the engine. Without this
        // the game would be silent for the rest of the launch.
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        })
        observers.append(centre.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            rattleActive = false
            engine.pause()
        case .ended:
            restart()
        @unknown default:
            break
        }
    }

    private func restart() {
        guard isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        rattleActive = false
        do {
            try engine.start()
            for player in players { player.play() }
        } catch {
            // Nothing sensible to do; the next interruption may recover it.
        }
    }

    func play(_ effect: Effect, muffled: Bool = false) {
        guard isEnabled, isRunning, engine.isRunning, let buffer = buffers[effect], !players.isEmpty else { return }
        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        player.volume = muffled ? 0.22 : 0.85
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// The rolling rattle of casters, pitched by how fast the cart is going.
    func updateEngineLoop(speed: Double, topSpeed: Double, boosting: Bool) {
        guard isEnabled, isRunning, engine.isRunning, let rattleBuffer else { return }
        guard speed > 0.6 else { return stopEngineLoop() }

        if !rattleActive {
            rattleActive = true
            rattlePlayer.scheduleBuffer(rattleBuffer, at: nil, options: .loops, completionHandler: nil)
            rattlePlayer.play()
        }
        let normalised = min(speed / max(topSpeed, 1), 1.6)
        rattleSpeed.rate = Float(0.72 + normalised * 0.85)
        rattlePlayer.volume = Float(min(0.06 + normalised * 0.2, 0.28)) * (boosting ? 1.35 : 1)
    }

    func stopEngineLoop() {
        guard rattleActive else { return }
        rattleActive = false
        rattlePlayer.stop()
    }

    // MARK: - Synthesis

    private func buffer(seconds: Double, _ fill: (_ index: Int, _ time: Double, _ sampleRate: Double) -> Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for index in 0..<Int(frames) {
            channel[index] = fill(index, Double(index) / sampleRate, sampleRate)
        }
        return buffer
    }

    private func render(_ effect: Effect) -> AVAudioPCMBuffer? {
        switch effect {
        case .beep:
            return tone(frequency: 660, seconds: 0.16, decay: 14)
        case .go:
            return buffer(seconds: 0.5) { _, time, _ in
                let sweep = 520 + 400 * min(time / 0.25, 1)
                let envelope = exp(-4 * time)
                return Float(sin(2 * .pi * sweep * time) * envelope * 0.6)
            }
        case .pickup:
            return buffer(seconds: 0.3) { _, time, _ in
                // A two-note pickup chime.
                let first = sin(2 * .pi * 880 * time) * exp(-12 * time)
                let second = time > 0.1 ? sin(2 * .pi * 1320 * (time - 0.1)) * exp(-12 * (time - 0.1)) : 0
                return Float((first + second) * 0.4)
            }
        case .powerUp:
            return buffer(seconds: 0.55) { _, time, _ in
                let sweep = 300 + 1200 * time
                return Float(sin(2 * .pi * sweep * time) * exp(-3.2 * time) * 0.45)
            }
        case .throwItem:
            return buffer(seconds: 0.25) { index, time, rate in
                let noise = Audio.noise(index)
                let sweep = sin(2 * .pi * (900 - 1800 * time) * time)
                _ = rate
                return Float((noise * 0.4 + sweep * 0.6) * exp(-11 * time) * 0.45)
            }
        case .boost:
            return buffer(seconds: 0.7) { index, time, _ in
                let noise = Audio.noise(index)
                let body = sin(2 * .pi * (240 + 700 * time) * time)
                return Float((noise * 0.55 + body * 0.45) * exp(-3.6 * time) * 0.55)
            }
        case .crash:
            return buffer(seconds: 0.45) { index, time, _ in
                let noise = Audio.noise(index)
                let clang = sin(2 * .pi * 210 * time) + 0.6 * sin(2 * .pi * 470 * time)
                return Float((noise * 0.7 + clang * 0.5) * exp(-9 * time) * 0.6)
            }
        case .bump:
            return buffer(seconds: 0.2) { index, time, _ in
                let noise = Audio.noise(index)
                return Float((noise * 0.5 + sin(2 * .pi * 150 * time) * 0.7) * exp(-16 * time) * 0.5)
            }
        case .splat:
            return buffer(seconds: 0.35) { index, time, _ in
                let noise = Audio.noise(index)
                let wobble = sin(2 * .pi * (120 - 90 * time) * time)
                return Float((noise * 0.6 + wobble * 0.4) * exp(-8 * time) * 0.5)
            }
        case .clatter:
            return buffer(seconds: 0.5) { index, time, _ in
                // Several tins hitting the floor at slightly different times.
                var sample = 0.0
                for hit in 0..<4 {
                    let start = Double(hit) * 0.055
                    guard time > start else { continue }
                    let local = time - start
                    sample += sin(2 * .pi * (380 + Double(hit) * 90) * local) * exp(-18 * local)
                }
                return Float((sample * 0.3 + Audio.noise(index) * 0.15 * exp(-6 * time)) * 0.5)
            }
        case .lap:
            return buffer(seconds: 0.3) { _, time, _ in
                Float(sin(2 * .pi * 990 * time) * exp(-9 * time) * 0.4)
            }
        case .finalLap:
            return buffer(seconds: 0.8) { _, time, _ in
                let wobble = sin(2 * .pi * 6 * time) * 30
                return Float(sin(2 * .pi * (760 + wobble) * time) * exp(-2.6 * time) * 0.45)
            }
        case .finish:
            return chord([392, 523], seconds: 0.9)
        case .fanfare:
            return buffer(seconds: 1.3) { _, time, _ in
                // Do-mi-so-do, the universal sound of having done well.
                let notes: [Double] = [523.25, 659.25, 783.99, 1046.5]
                let step = min(Int(time / 0.22), notes.count - 1)
                let local = time - Double(step) * 0.22
                return Float(sin(2 * .pi * notes[step] * time) * exp(-5 * local) * 0.42)
            }
        case .announce:
            return buffer(seconds: 0.6) { _, time, _ in
                // The two-tone chime before a store announcement.
                let frequency = time < 0.25 ? 784.0 : 587.0
                let local = time < 0.25 ? time : time - 0.25
                return Float(sin(2 * .pi * frequency * time) * exp(-5 * local) * 0.4)
            }
        case .uiTap:
            return tone(frequency: 520, seconds: 0.08, decay: 26)
        }
    }

    private func tone(frequency: Double, seconds: Double, decay: Double) -> AVAudioPCMBuffer? {
        buffer(seconds: seconds) { _, time, _ in
            Float(sin(2 * .pi * frequency * time) * exp(-decay * time) * 0.45)
        }
    }

    private func chord(_ frequencies: [Double], seconds: Double) -> AVAudioPCMBuffer? {
        buffer(seconds: seconds) { _, time, _ in
            var sample = 0.0
            for frequency in frequencies {
                sample += sin(2 * .pi * frequency * time)
            }
            return Float(sample / Double(frequencies.count) * exp(-3 * time) * 0.45)
        }
    }

    /// One second of caster rattle: filtered noise plus a squeaky harmonic.
    private func renderRattle() -> AVAudioPCMBuffer? {
        var previous = 0.0
        return buffer(seconds: 1.0) { index, time, _ in
            let raw = Audio.noise(index)
            // One-pole low pass, so it rumbles rather than hisses.
            previous += (raw - previous) * 0.12
            let squeak = sin(2 * .pi * 1180 * time) * 0.05 * (0.6 + 0.4 * sin(2 * .pi * 3 * time))
            // Wheel thump, four times a second at the reference rate.
            let thump = sin(2 * .pi * 74 * time) * 0.25 * abs(sin(2 * .pi * 4 * time))
            return Float((previous * 0.55 + squeak + thump) * 0.6)
        }
    }

    /// Deterministic white noise, so the buffers are identical every launch.
    private static func noise(_ index: Int) -> Double {
        var state = UInt64(bitPattern: Int64(index &* 6_364_136_223_846_793_005))
        state ^= state >> 33
        state = state &* 0xFF51_AFD7_ED55_8CCD
        state ^= state >> 33
        return Double(state % 20_001) / 10_000.0 - 1.0
    }
}
