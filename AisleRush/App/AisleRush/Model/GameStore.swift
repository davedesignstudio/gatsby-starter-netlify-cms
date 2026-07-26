import Combine
import Foundation
import AisleRushCore

/// Player preferences. Observable so the settings screen can bind straight to
/// it; every change writes through to `UserDefaults`.
final class GameSettings: ObservableObject {
    enum SteeringMode: String, CaseIterable, Identifiable {
        case touch
        case tilt

        var id: String { rawValue }
        var title: String { self == .touch ? "Thumb" : "Tilt" }
        var blurb: String {
            self == .touch
                ? "Slide your left thumb to steer."
                : "Tip the device. Braver, and worse."
        }
    }

    @Published var steering: SteeringMode { didSet { store.set(steering.rawValue, forKey: Keys.steering) } }
    @Published var autoAccelerate: Bool { didSet { store.set(autoAccelerate, forKey: Keys.autoAccelerate) } }
    @Published var rotatingCamera: Bool { didSet { store.set(rotatingCamera, forKey: Keys.rotatingCamera) } }
    @Published var soundEnabled: Bool {
        didSet {
            store.set(soundEnabled, forKey: Keys.sound)
            Audio.shared.isEnabled = soundEnabled
        }
    }
    @Published var hapticsEnabled: Bool {
        didSet {
            store.set(hapticsEnabled, forKey: Keys.haptics)
            Haptics.isEnabled = hapticsEnabled
        }
    }
    @Published var difficulty: Int { didSet { store.set(difficulty, forKey: Keys.difficulty) } }
    @Published var tiltSensitivity: Double { didSet { store.set(tiltSensitivity, forKey: Keys.tiltSensitivity) } }

    private let store: UserDefaults

    private enum Keys {
        static let steering = "settings.steering"
        static let autoAccelerate = "settings.autoAccelerate"
        static let rotatingCamera = "settings.rotatingCamera"
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let difficulty = "settings.difficulty"
        static let tiltSensitivity = "settings.tiltSensitivity"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        steering = SteeringMode(rawValue: store.string(forKey: Keys.steering) ?? "") ?? .touch
        autoAccelerate = store.object(forKey: Keys.autoAccelerate) as? Bool ?? true
        rotatingCamera = store.object(forKey: Keys.rotatingCamera) as? Bool ?? true
        soundEnabled = store.object(forKey: Keys.sound) as? Bool ?? true
        hapticsEnabled = store.object(forKey: Keys.haptics) as? Bool ?? true
        // Clamped: this indexes a fixed-size names table.
        difficulty = min(max(store.object(forKey: Keys.difficulty) as? Int ?? 1, 0), 2)
        tiltSensitivity = store.object(forKey: Keys.tiltSensitivity) as? Double ?? 1.0

        Audio.shared.isEnabled = soundEnabled
        Haptics.isEnabled = hapticsEnabled
    }
}

/// Saved progress: garage choices, records and which cups have been won.
final class GameStore: ObservableObject {
    @Published var characterID: String { didSet { store.set(characterID, forKey: Keys.character) } }
    @Published var frameID: String { didSet { store.set(frameID, forKey: Keys.frame) } }
    @Published var wheelsID: String { didSet { store.set(wheelsID, forKey: Keys.wheels) } }
    @Published private(set) var bestLaps: [String: Double]
    @Published private(set) var bestRaces: [String: Double]
    /// Cup id to the best (lowest) finishing position achieved in it.
    @Published private(set) var cupTrophies: [String: Int]

    private let store: UserDefaults

    private enum Keys {
        static let character = "garage.character"
        static let frame = "garage.frame"
        static let wheels = "garage.wheels"
        static let bestLaps = "records.bestLaps"
        static let bestRaces = "records.bestRaces"
        static let trophies = "records.trophies"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        characterID = store.string(forKey: Keys.character) ?? Roster.characters[0].id
        frameID = store.string(forKey: Keys.frame) ?? Roster.frames[0].id
        wheelsID = store.string(forKey: Keys.wheels) ?? Roster.wheels[0].id
        bestLaps = store.dictionary(forKey: Keys.bestLaps) as? [String: Double] ?? [:]
        bestRaces = store.dictionary(forKey: Keys.bestRaces) as? [String: Double] ?? [:]
        cupTrophies = store.dictionary(forKey: Keys.trophies) as? [String: Int] ?? [:]
    }

    var setup: CartSetup {
        CartSetup(
            character: Roster.character(id: characterID),
            frame: Roster.frame(id: frameID),
            wheels: Roster.wheels(id: wheelsID)
        )
    }

    func bestLap(for trackID: String) -> Double? { bestLaps[trackID] }
    func bestRace(for trackID: String) -> Double? { bestRaces[trackID] }
    func trophy(for cupID: String) -> Int? { cupTrophies[cupID] }

    /// Returns true when the lap is a new personal best.
    @discardableResult
    func recordLap(_ seconds: Double, trackID: String) -> Bool {
        guard seconds > 0 else { return false }
        if let existing = bestLaps[trackID], existing <= seconds { return false }
        bestLaps[trackID] = seconds
        store.set(bestLaps, forKey: Keys.bestLaps)
        return true
    }

    @discardableResult
    func recordRace(_ seconds: Double, trackID: String) -> Bool {
        guard seconds > 0 else { return false }
        if let existing = bestRaces[trackID], existing <= seconds { return false }
        bestRaces[trackID] = seconds
        store.set(bestRaces, forKey: Keys.bestRaces)
        return true
    }

    func recordCup(_ cupID: String, place: Int) {
        guard place > 0 else { return }
        if let existing = cupTrophies[cupID], existing <= place { return }
        cupTrophies[cupID] = place
        store.set(cupTrophies, forKey: Keys.trophies)
    }

    func resetRecords() {
        bestLaps = [:]
        bestRaces = [:]
        cupTrophies = [:]
        store.removeObject(forKey: Keys.bestLaps)
        store.removeObject(forKey: Keys.bestRaces)
        store.removeObject(forKey: Keys.trophies)
    }
}
