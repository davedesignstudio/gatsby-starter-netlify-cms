import Combine
import Foundation
import SpriteKit
import AisleRushCore

/// Owns one race: the simulation, the SpriteKit scene rendering it, and the
/// published state the HUD reads.
final class RaceSession: ObservableObject {
    let trackDefinition: TrackDefinition
    let config: RaceConfig
    let entrants: [Entrant]
    let track: Track
    let simulation: RaceSimulation
    let input = RaceInput()

    @Published var hud = HUDSnapshot()
    @Published var isPaused = false {
        didSet {
            scene.isPaused = isPaused
            if isPaused { Audio.shared.stopEngineLoop() }
        }
    }

    var onComplete: (([RaceResult]) -> Void)?
    var mode: RaceMode { config.mode }

    private(set) lazy var scene: RaceScene = {
        RaceScene(simulation: simulation, input: input, settings: settings, session: self)
    }()

    private let settings: GameSettings
    private var hasCompleted = false
    private let tilt = TiltController()

    init(definition: TrackDefinition, config: RaceConfig, entrants: [Entrant], settings: GameSettings) {
        trackDefinition = definition
        self.config = config
        self.entrants = entrants
        self.settings = settings
        track = Track(definition: definition)
        simulation = RaceSimulation(track: track, config: config, entrants: entrants)
        if settings.steering == .tilt {
            tilt.start { [weak self] value in
                guard let self, !self.isPaused else { return }
                self.input.steer = value * self.settings.tiltSensitivity
            }
        }
    }

    deinit {
        tilt.stop()
        Audio.shared.stopEngineLoop()
    }

    func raceDidComplete(results: [RaceResult]) {
        guard !hasCompleted else { return }
        hasCompleted = true
        tilt.stop()
        Audio.shared.stopEngineLoop()
        onComplete?(results)
    }

    /// The player's own cart, for garage-style readouts on the pause screen.
    var playerSetup: CartSetup? {
        entrants.first(where: \.isPlayer)?.setup
    }
}
