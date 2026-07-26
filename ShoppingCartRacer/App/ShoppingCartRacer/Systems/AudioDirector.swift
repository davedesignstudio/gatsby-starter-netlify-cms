import AVFoundation

/// All the game's sound, synthesised at runtime. There are no audio files in the
/// bundle: the trolley rattle is filtered noise whose playback rate tracks speed,
/// and the one-shots are short envelopes over sine and noise.
final class AudioDirector {
    private let engine = AVAudioEngine()
    private let rattlePlayer = AVAudioPlayerNode()
    private let rattleSpeed = AVAudioUnitVarispeed()
    private let rattleMixer = AVAudioMixerNode()
    private var oneShotPlayers: [AVAudioPlayerNode] = []
    private var nextOneShot = 0

    private let format: AVAudioFormat
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var rattleBuffer: AVAudioPCMBuffer?
    private var isRunning = false
    private(set) var isEnabled = true

    enum Cue: String, CaseIterable {
        case countdownBeep
        case countdownGo
        case boost
        case crash
        case scrape
        case pickup
        case coin
        case itemFire
        case lap
        case spinOut
        case menuTap
        case fanfare
    }

    init(sampleRate: Double = 44_100) {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        buildGraph()
        buildBuffers()
    }

    private func buildGraph() {
        engine.attach(rattlePlayer)
        engine.attach(rattleSpeed)
        engine.attach(rattleMixer)
        engine.connect(rattlePlayer, to: rattleSpeed, format: format)
        engine.connect(rattleSpeed, to: rattleMixer, format: format)
        engine.connect(rattleMixer, to: engine.mainMixerNode, format: format)
        rattleMixer.outputVolume = 0

        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            oneShotPlayers.append(player)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        configureSession()
        do {
            try engine.start()
            isRunning = true
        } catch {
            // Sound is a nicety; a failure here must never take the race down.
            isRunning = false
            return
        }
        startRattleLoop()
    }

    func stop() {
        guard isRunning else { return }
        rattlePlayer.stop()
        oneShotPlayers.forEach { $0.stop() }
        engine.stop()
        isRunning = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            rattleMixer.outputVolume = 0
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // Ambient so the player's own music keeps playing if they want it to.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func startRattleLoop() {
        guard let rattleBuffer else { return }
        rattlePlayer.scheduleBuffer(rattleBuffer, at: nil, options: [.loops])
        rattlePlayer.play()
    }

    // MARK: - Driving

    /// Feeds the engine loop from the cart's state each frame.
    ///
    /// - Parameters:
    ///   - speedFraction: 0...1 of the cart's top speed.
    ///   - onRoughGround: true off the aisle, where the trolley clatters.
    func updateEngine(speedFraction: Double, onRoughGround: Bool, boosting: Bool) {
        guard isRunning, isEnabled else { return }
        let fraction = Float(Scalar.clamp(speedFraction, 0, 1.4))
        // Pitch rises with speed; the rattle gets louder on rough ground.
        rattleSpeed.rate = 0.75 + fraction * 0.85
        var volume = 0.05 + fraction * 0.22
        if onRoughGround { volume += 0.16 }
        if boosting { volume += 0.08 }
        rattleMixer.outputVolume = min(volume, 0.5)
    }

    /// Cuts the engine loop dead, for pauses and for leaving the race.
    func silenceEngine() {
        rattleMixer.outputVolume = 0
    }

    func play(_ cue: Cue, volume: Float = 1) {
        guard isRunning, isEnabled, let buffer = buffers[cue] else { return }
        let player = oneShotPlayers[nextOneShot % oneShotPlayers.count]
        nextOneShot += 1
        player.volume = volume
        // Restarting an in-flight player is what allows rapid-fire effects.
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    /// Maps simulation events onto sound. Only the player's own events are loud.
    func handle(events: [RaceEvent], playerID: Int?) {
        for event in events {
            switch event {
            case .countdownBeep:
                play(.countdownBeep, volume: 0.7)
            case .raceStarted:
                play(.countdownGo, volume: 0.85)
            case .boostStarted(let cartID, _), .miniTurbo(let cartID, _):
                play(.boost, volume: cartID == playerID ? 0.8 : 0.25)
            case .rocketStart(let cartID):
                play(.boost, volume: cartID == playerID ? 0.9 : 0.2)
            case .wallScrape(let cartID, let intensity, _):
                play(.scrape, volume: Float(intensity) * (cartID == playerID ? 0.6 : 0.15))
            case .cartBump(let cartID, _, let intensity, _):
                play(.crash, volume: Float(intensity) * (cartID == playerID ? 0.55 : 0.15))
            case .obstacleHit(let cartID, _, _):
                play(.crash, volume: cartID == playerID ? 0.7 : 0.15)
            case .projectileHit(let cartID, _), .spunOut(let cartID):
                play(.spinOut, volume: cartID == playerID ? 0.8 : 0.2)
            case .slipped(let cartID, _):
                play(.scrape, volume: cartID == playerID ? 0.5 : 0.12)
            case .itemCollected(let cartID, _):
                play(.pickup, volume: cartID == playerID ? 0.7 : 0.1)
            case .itemUsed(let cartID, _):
                play(.itemFire, volume: cartID == playerID ? 0.7 : 0.12)
            case .tokenCollected(let cartID, _):
                play(.coin, volume: cartID == playerID ? 0.5 : 0.08)
            case .lapCompleted(let cartID, _, _):
                play(.lap, volume: cartID == playerID ? 0.7 : 0)
            case .finished(let cartID, let racePosition, _):
                if cartID == playerID {
                    play(racePosition <= 3 ? .fanfare : .lap, volume: 0.9)
                }
            default:
                break
            }
        }
    }

    // MARK: - Synthesis

    private func buildBuffers() {
        rattleBuffer = makeBuffer(seconds: 1.4) { time, _ in
            // Bandpassed-ish noise plus a low thrum: a trolley with one bad wheel.
            var value = 0.0
            var random = DeterministicRandom(seed: UInt64(time * 44_100) &+ 1)
            let noise = random.nextDouble(in: -1...1)
            value += noise * 0.25
            value += sin(2 * .pi * 42 * time) * 0.28
            value += sin(2 * .pi * 63 * time) * 0.12
            // The squeak: a quiet high tone that wobbles.
            let wobble = 1 + 0.06 * sin(2 * .pi * 3.1 * time)
            value += sin(2 * .pi * 1180 * time * wobble) * 0.05
            return value * 0.5
        }

        buffers[.countdownBeep] = makeBuffer(seconds: 0.18) { time, duration in
            AudioDirector.tone(880, time: time, duration: duration, attack: 0.005, release: 0.09) * 0.5
        }
        buffers[.countdownGo] = makeBuffer(seconds: 0.5) { time, duration in
            let sweep = 660 + 520 * min(time / 0.2, 1)
            return AudioDirector.tone(sweep, time: time, duration: duration, attack: 0.005, release: 0.3) * 0.55
        }
        buffers[.boost] = makeBuffer(seconds: 0.55) { time, duration in
            var random = DeterministicRandom(seed: UInt64(time * 44_100) &+ 7)
            let noise = random.nextDouble(in: -1...1)
            let envelope = AudioDirector.envelope(time: time, duration: duration, attack: 0.02, release: 0.4)
            let rise = sin(2 * .pi * (320 + 900 * time / duration) * time)
            return (noise * 0.35 + rise * 0.5) * envelope * 0.6
        }
        buffers[.crash] = makeBuffer(seconds: 0.4) { time, duration in
            var random = DeterministicRandom(seed: UInt64(time * 44_100) &+ 13)
            let noise = random.nextDouble(in: -1...1)
            let envelope = AudioDirector.envelope(time: time, duration: duration, attack: 0.002, release: 0.32)
            let clang = sin(2 * .pi * 190 * time) + sin(2 * .pi * 287 * time) * 0.6
            return (noise * 0.55 + clang * 0.4) * envelope * 0.7
        }
        buffers[.scrape] = makeBuffer(seconds: 0.3) { time, duration in
            var random = DeterministicRandom(seed: UInt64(time * 44_100) &+ 29)
            let noise = random.nextDouble(in: -1...1)
            let envelope = AudioDirector.envelope(time: time, duration: duration, attack: 0.01, release: 0.24)
            return noise * envelope * 0.5
        }
        buffers[.pickup] = makeBuffer(seconds: 0.3) { time, duration in
            let steps = [523.25, 659.25, 783.99]
            let index = min(Int(time / 0.08), steps.count - 1)
            return AudioDirector.tone(steps[index], time: time, duration: duration, attack: 0.004, release: 0.2) * 0.42
        }
        buffers[.coin] = makeBuffer(seconds: 0.16) { time, duration in
            AudioDirector.tone(1318.5, time: time, duration: duration, attack: 0.002, release: 0.1) * 0.3
        }
        buffers[.itemFire] = makeBuffer(seconds: 0.28) { time, duration in
            let sweep = 900 - 500 * (time / duration)
            return AudioDirector.tone(sweep, time: time, duration: duration, attack: 0.003, release: 0.2) * 0.4
        }
        buffers[.lap] = makeBuffer(seconds: 0.42) { time, duration in
            let steps = [659.25, 987.77]
            let index = min(Int(time / 0.14), steps.count - 1)
            return AudioDirector.tone(steps[index], time: time, duration: duration, attack: 0.004, release: 0.26) * 0.42
        }
        buffers[.spinOut] = makeBuffer(seconds: 0.6) { time, duration in
            let sweep = 620 - 420 * (time / duration)
            var random = DeterministicRandom(seed: UInt64(time * 44_100) &+ 41)
            let noise = random.nextDouble(in: -1...1) * 0.2
            return (AudioDirector.tone(sweep, time: time, duration: duration, attack: 0.01, release: 0.45) + noise) * 0.45
        }
        buffers[.menuTap] = makeBuffer(seconds: 0.1) { time, duration in
            AudioDirector.tone(440, time: time, duration: duration, attack: 0.002, release: 0.06) * 0.25
        }
        buffers[.fanfare] = makeBuffer(seconds: 1.1) { time, duration in
            let steps = [523.25, 659.25, 783.99, 1046.5]
            let index = min(Int(time / 0.22), steps.count - 1)
            let envelope = AudioDirector.envelope(time: time, duration: duration, attack: 0.01, release: 0.6)
            return sin(2 * .pi * steps[index] * time) * envelope * 0.4
        }
    }

    /// - Parameter generator: called per sample with the time in seconds and the
    ///   total duration, returning a sample in -1...1.
    private func makeBuffer(seconds: Double, generator: (Double, Double) -> Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }

        for frame in 0..<Int(frames) {
            let time = Double(frame) / sampleRate
            channel[frame] = Float(max(-1, min(1, generator(time, seconds))))
        }
        buffer.frameLength = frames
        return buffer
    }

    private static func tone(
        _ frequency: Double,
        time: Double,
        duration: Double,
        attack: Double,
        release: Double
    ) -> Double {
        sin(2 * .pi * frequency * time) * envelope(time: time, duration: duration, attack: attack, release: release)
    }

    private static func envelope(time: Double, duration: Double, attack: Double, release: Double) -> Double {
        let rise = attack > 0 ? min(time / attack, 1) : 1
        let fall = release > 0 ? max(0, 1 - max(0, time - attack) / release) : 1
        return max(0, rise * fall)
    }
}
