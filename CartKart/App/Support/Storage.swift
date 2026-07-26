import CartKartCore
import Combine
import Foundation

/// Player preferences and records, persisted in `UserDefaults`.
///
/// Everything here is small and flat, so a document store would be overkill.
final class Storage: ObservableObject {
    private enum Key {
        static let bestLap = "cartkart.bestLap."
        static let bestRace = "cartkart.bestRace."
        static let selectedCart = "cartkart.selectedCart"
        static let difficulty = "cartkart.difficulty"
        static let controlScheme = "cartkart.controlScheme"
        static let soundEnabled = "cartkart.sound"
        static let hapticsEnabled = "cartkart.haptics"
        static let cupWins = "cartkart.cupWins"
    }

    enum ControlScheme: String, CaseIterable, Identifiable {
        /// Drag anywhere on the left of the screen to steer.
        case slide
        /// Discrete left and right buttons.
        case buttons
        /// Tilt the device.
        case tilt

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .slide: return "Slide"
            case .buttons: return "Buttons"
            case .tilt: return "Tilt"
            }
        }

        var explanation: String {
            switch self {
            case .slide: return "Drag your left thumb to steer."
            case .buttons: return "Tap left and right to steer."
            case .tilt: return "Tilt the device to steer."
            }
        }
    }

    private let defaults: UserDefaults

    @Published var selectedCartID: String {
        didSet { defaults.set(selectedCartID, forKey: Key.selectedCart) }
    }

    @Published var difficulty: RaceConfiguration.Difficulty {
        didSet { defaults.set(difficulty.rawValue, forKey: Key.difficulty) }
    }

    @Published var controlScheme: ControlScheme {
        didSet { defaults.set(controlScheme.rawValue, forKey: Key.controlScheme) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    @Published private(set) var cupWins: Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCartID = defaults.string(forKey: Key.selectedCart) ?? Roster.all[0].id
        self.difficulty = defaults.string(forKey: Key.difficulty)
            .flatMap(RaceConfiguration.Difficulty.init(rawValue:)) ?? .weeklyShop
        self.controlScheme = defaults.string(forKey: Key.controlScheme)
            .flatMap(ControlScheme.init(rawValue:)) ?? .slide
        self.soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        self.cupWins = defaults.integer(forKey: Key.cupWins)
    }

    var selectedCart: RacerProfile { Roster.profile(id: selectedCartID) }

    // MARK: - Records

    func bestLap(for trackID: String) -> Double? {
        let value = defaults.double(forKey: Key.bestLap + trackID)
        return value > 0 ? value : nil
    }

    func bestRace(for trackID: String) -> Double? {
        let value = defaults.double(forKey: Key.bestRace + trackID)
        return value > 0 ? value : nil
    }

    /// Stores a result if it beats what is already there.
    /// - Returns: true when a record was broken, so the UI can celebrate.
    @discardableResult
    func recordRace(trackID: String, lapTimes: [Double], totalTime: Double?) -> Bool {
        var improved = false
        if let fastestLap = lapTimes.min(), fastestLap > 0 {
            if bestLap(for: trackID).map({ fastestLap < $0 }) ?? true {
                defaults.set(fastestLap, forKey: Key.bestLap + trackID)
                improved = true
            }
        }
        if let totalTime, totalTime > 0, bestRace(for: trackID).map({ totalTime < $0 }) ?? true {
            defaults.set(totalTime, forKey: Key.bestRace + trackID)
            improved = true
        }
        return improved
    }

    func recordCupWin() {
        cupWins += 1
        defaults.set(cupWins, forKey: Key.cupWins)
    }
}
