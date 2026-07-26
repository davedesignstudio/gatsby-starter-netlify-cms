import AVFoundation
import CartKartCore
import UIKit

/// Sound and haptics for race events.
///
/// The sound effects are synthesised at launch rather than shipped as files,
/// which keeps the project asset free. They are deliberately short, simple
/// waveforms: a blip for items, a thud for contact, a whoosh for boosts.
final class Feedback {
    static let shared = Feedback()

    var isSoundEnabled = true
    var isHapticsEnabled = true

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var players: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var isRunning = false

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    // MARK: - Setup

    func start() {
        guard !isRunning else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }

        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        for (name, recipe) in Recipe.all {
            guard let buffer = Feedback.render(recipe, format: format) else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            players[name] = player
            buffers[name] = buffer
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            for player in players.values { player.play() }
            isRunning = true
        } catch {
            // Audio is a nicety; a failure here should never stop the race.
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Playback

    func play(_ sound: Sound, volume: Float = 1) {
        guard isSoundEnabled, isRunning else { return }
        guard let player = players[sound.rawValue], let buffer = buffers[sound.rawValue] else { return }
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    func impact(_ strength: Strength) {
        guard isHapticsEnabled else { return }
        switch strength {
        case .light: lightImpact.impactOccurred()
        case .heavy: heavyImpact.impactOccurred()
        case .success: notification.notificationOccurred(.success)
        case .failure: notification.notificationOccurred(.error)
        }
    }

    /// Maps a race event onto the right noise and buzz.
    func react(to event: RaceEvent, playerKartID: Int?) {
        func isPlayer(_ id: Int) -> Bool { id == playerKartID }

        switch event {
        case .countdownTick:
            play(.beep, volume: 0.6)
            impact(.light)
        case .go:
            play(.startBeep)
            impact(.success)
        case .rocketStart(let id) where isPlayer(id):
            play(.boost)
            impact(.heavy)
        case .miniTurbo(let id, _) where isPlayer(id):
            play(.boost, volume: 0.85)
            impact(.light)
        case .boostPad(let id) where isPlayer(id):
            play(.boost, volume: 0.7)
        case .itemBoxCollected(let id, _) where isPlayer(id):
            play(.pickup)
            impact(.light)
        case .itemUsed(let id, _) where isPlayer(id):
            play(.whoosh, volume: 0.8)
        case .kartHit(let id, _, _) where isPlayer(id):
            play(.crash)
            impact(.failure)
        case .kartBumped(let id, _, let impactStrength) where isPlayer(id):
            play(.thud, volume: Float(min(1, impactStrength / 400)))
            impact(.light)
        case .wallScrape(let id, _) where isPlayer(id):
            play(.thud, volume: 0.5)
        case .lapCompleted(let id, _, _) where isPlayer(id):
            play(.lap)
            impact(.light)
        case .finished(let id, let place, _) where isPlayer(id):
            play(place <= 3 ? .fanfare : .lap)
            impact(place <= 3 ? .success : .light)
        default:
            break
        }
    }

    enum Strength {
        case light
        case heavy
        case success
        case failure
    }

    enum Sound: String {
        case beep
        case startBeep
        case pickup
        case boost
        case whoosh
        case thud
        case crash
        case lap
        case fanfare
    }

    // MARK: - Synthesis

    /// A tiny description of a sound: a pitch sweep, a shape and a duration.
    private struct Recipe {
        enum Wave {
            case square
            case sine
            case noise
        }

        var wave: Wave
        var startFrequency: Double
        var endFrequency: Double
        var duration: Double
        var amplitude: Double
        /// Extra notes played in sequence, for the finish fanfare.
        var followUps: [(frequency: Double, duration: Double)] = []

        static let all: [(String, Recipe)] = [
            (Sound.beep.rawValue, Recipe(wave: .square, startFrequency: 440, endFrequency: 440, duration: 0.12, amplitude: 0.25)),
            (Sound.startBeep.rawValue, Recipe(wave: .square, startFrequency: 880, endFrequency: 880, duration: 0.32, amplitude: 0.3)),
            (Sound.pickup.rawValue, Recipe(wave: .square, startFrequency: 620, endFrequency: 1180, duration: 0.18, amplitude: 0.22)),
            (Sound.boost.rawValue, Recipe(wave: .sine, startFrequency: 320, endFrequency: 1400, duration: 0.36, amplitude: 0.28)),
            (Sound.whoosh.rawValue, Recipe(wave: .noise, startFrequency: 1200, endFrequency: 300, duration: 0.24, amplitude: 0.18)),
            (Sound.thud.rawValue, Recipe(wave: .sine, startFrequency: 170, endFrequency: 70, duration: 0.16, amplitude: 0.35)),
            (Sound.crash.rawValue, Recipe(wave: .noise, startFrequency: 800, endFrequency: 120, duration: 0.4, amplitude: 0.3)),
            (Sound.lap.rawValue, Recipe(wave: .square, startFrequency: 700, endFrequency: 980, duration: 0.22, amplitude: 0.22)),
            (
                Sound.fanfare.rawValue,
                Recipe(
                    wave: .square,
                    startFrequency: 523,
                    endFrequency: 523,
                    duration: 0.16,
                    amplitude: 0.25,
                    followUps: [(659, 0.16), (784, 0.16), (1046, 0.36)]
                )
            )
        ]
    }

    private static func render(_ recipe: Recipe, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let segments: [(start: Double, end: Double, duration: Double)] =
            [(recipe.startFrequency, recipe.endFrequency, recipe.duration)]
                + recipe.followUps.map { ($0.frequency, $0.frequency, $0.duration) }
        let totalDuration = segments.reduce(0) { $0 + $1.duration }
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var frame = 0
        var phase = 0.0
        var noise = SeededRandom(seed: 0x5EED)
        for segment in segments {
            let segmentFrames = Int(segment.duration * sampleRate)
            for index in 0..<segmentFrames where frame < Int(frameCount) {
                let progress = Double(index) / Double(max(segmentFrames - 1, 1))
                let frequency = segment.start + (segment.end - segment.start) * progress
                phase += 2 * Double.pi * frequency / sampleRate
                if phase > 2 * Double.pi { phase -= 2 * Double.pi }

                let raw: Double
                switch recipe.wave {
                case .sine: raw = sin(phase)
                case .square: raw = sin(phase) >= 0 ? 1 : -1
                case .noise: raw = noise.double(in: -1...1) * (0.4 + 0.6 * sin(phase) * sin(phase))
                }

                // Quick attack, smooth decay, so nothing clicks.
                let attack = min(1, progress / 0.05)
                let decay = pow(1 - progress, 1.6)
                channel[frame] = Float(raw * recipe.amplitude * attack * decay)
                frame += 1
            }
        }
        return buffer
    }
}
