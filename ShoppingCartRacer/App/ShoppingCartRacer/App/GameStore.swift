import Combine
import SwiftUI

/// Keeps the record book in `UserDefaults`.
final class UserDefaultsRecordStorage: RecordStorage {
    private let defaults: UserDefaults
    private let key = "cart-racer.records.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRecordBookData() -> Data? {
        defaults.data(forKey: key)
    }

    func save(recordBookData: Data) {
        defaults.set(recordBookData, forKey: key)
    }
}

/// The app's single source of truth: wraps the framework-free `GameSession` state
/// machine in something SwiftUI can observe, and owns the shared device systems.
///
/// Only ever touched from the main thread — SwiftUI and the SpriteKit render loop
/// both run there — so it deliberately carries no actor annotation.
final class GameStore: ObservableObject {
    @Published private(set) var session: GameSession

    let keeper: RecordKeeper
    let audio = AudioDirector()
    let haptics = HapticsDirector()
    let gamepad = GamepadBridge()
    let motion = MotionSteering()

    private let defaults: UserDefaults
    private let settingsKey = "cart-racer.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keeper = RecordKeeper(storage: UserDefaultsRecordStorage(defaults: defaults))

        var settings = ControlSettings.default
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(ControlSettings.self, from: data) {
            settings = decoded
        }
        session = GameSession(book: keeper.book, settings: settings)

        audio.setEnabled(settings.soundEnabled)
        haptics.setEnabled(settings.hapticsEnabled)
        haptics.prepare()
    }

    var settings: ControlSettings { session.settings }

    // MARK: - Navigation

    func go(to route: GameRoute) {
        haptics.tapSelection()
        audio.play(.menuTap, volume: 0.4)
        session.go(to: route)
    }

    func beginSingleRace() {
        haptics.tapSelection()
        session.beginSingleRace()
    }

    func beginGrandPrix() {
        haptics.tapSelection()
        session.beginGrandPrix()
    }

    func selectRacer(_ id: String) {
        haptics.tapSelection()
        audio.play(.menuTap, volume: 0.35)
        session.selectedRacerID = id
    }

    func selectTrack(_ id: String) {
        guard session.isUnlocked(trackID: id) else { return }
        haptics.tapSelection()
        audio.play(.menuTap, volume: 0.35)
        session.selectedTrackID = id
    }

    func setDifficulty(_ difficulty: Difficulty) {
        haptics.tapSelection()
        session.difficulty = difficulty
    }

    func confirmRacer() {
        haptics.tapSelection()
        session.confirmRacer()
    }

    func startRace() {
        haptics.tapSelection()
        session.startRace()
    }

    func makeRaceConfiguration() -> RaceConfiguration? {
        session.makeRaceConfiguration()
    }

    func finishRace(result: RaceResult) {
        session.finishRace(result: result, keeper: keeper)
    }

    func continueFromResults() {
        haptics.tapSelection()
        session.continueFromResults()
    }

    func continueFromStandings() {
        haptics.tapSelection()
        session.continueFromStandings()
    }

    func restartRace() {
        haptics.tapSelection()
        session.restartRace()
    }

    func abandonRace() {
        haptics.tapSelection()
        session.abandonRace()
    }

    // MARK: - Settings

    func update(settings newValue: ControlSettings) {
        session.settings = newValue
        audio.setEnabled(newValue.soundEnabled)
        haptics.setEnabled(newValue.hapticsEnabled)
        if let data = try? JSONEncoder().encode(newValue) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    /// Takes however the player is holding the device right now as centred.
    func calibrateTilt() {
        var updated = session.settings
        updated.tiltNeutral = motion.steeringAngle()
        update(settings: updated)
        haptics.tapSelection()
    }

    func resetRecords() {
        keeper.reset()
        session = GameSession(book: keeper.book, settings: session.settings)
    }

    // MARK: - Lifecycle

    func startSystems() {
        audio.start()
        if session.settings.steeringStyle == .tilt {
            motion.start()
        }
    }

    func stopSystems() {
        audio.stop()
        motion.stop()
    }

    /// Tilt is only worth powering up while it is the chosen control scheme.
    func syncMotionUpdates(forRacing racing: Bool) {
        if racing, session.settings.steeringStyle == .tilt {
            motion.start()
        } else if !racing {
            motion.stop()
        }
    }
}
