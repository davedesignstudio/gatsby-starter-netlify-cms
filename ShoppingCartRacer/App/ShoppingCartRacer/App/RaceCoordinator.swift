import Combine
import SwiftUI

/// Owns one race: the SpriteKit scene, the HUD snapshot the overlay renders from,
/// and the wiring between simulation events and sound and haptics.
///
/// The scene callbacks all arrive on SpriteKit's render loop, which is the main
/// thread, so publishing from them is safe without any actor hop.
final class RaceCoordinator: ObservableObject {
    @Published private(set) var hud: HUDModel?
    @Published private(set) var standings: [StandingsRow] = []
    @Published var isPaused = false
    @Published private(set) var isFinished = false

    let scene: RaceScene
    let minimap: MinimapModel
    let trackName: String
    let laps: Int

    /// Live control state, deliberately not `@Published`: it changes every frame
    /// and must not drive SwiftUI updates.
    private var touchControls = RawControlState()
    private var frameCounter = 0
    private let audio: AudioDirector
    private let haptics: HapticsDirector
    private let gamepad: GamepadBridge
    private let motion: MotionSteering
    private var settings: ControlSettings
    private let onComplete: (RaceResult) -> Void

    init(
        configuration: RaceConfiguration,
        settings: ControlSettings,
        size: CGSize,
        audio: AudioDirector,
        haptics: HapticsDirector,
        gamepad: GamepadBridge,
        motion: MotionSteering,
        onComplete: @escaping (RaceResult) -> Void
    ) {
        self.audio = audio
        self.haptics = haptics
        self.gamepad = gamepad
        self.motion = motion
        self.settings = settings
        self.onComplete = onComplete

        scene = RaceScene(configuration: configuration, settings: settings, size: size)
        minimap = MinimapModel(track: configuration.track)
        trackName = configuration.track.name
        laps = configuration.laps

        scene.inputSource = { [weak self] in
            self?.currentInput() ?? RawControlState()
        }
        scene.onFrame = { [weak self] simulation in
            self?.publish(from: simulation)
        }
        scene.onEvents = { [weak self] events in
            guard let self else { return }
            let playerID = self.scene.simulation.playerCartID
            self.audio.handle(events: events, playerID: playerID)
            self.haptics.handle(events: events, playerID: playerID)
        }
        scene.onComplete = { [weak self] result in
            guard let self else { return }
            self.isFinished = true
            self.onComplete(result)
        }
    }

    // MARK: - Input

    /// Combines the touch controls with a game pad and tilt, whichever are live.
    private func currentInput() -> RawControlState {
        var controls = touchControls

        if settings.steeringStyle == .tilt {
            controls.steer = ControlMapper.tiltSteer(angle: motion.steeringAngle(), settings: settings)
        }
        if gamepad.isConnected {
            gamepad.apply(to: &controls)
        }
        return controls
    }

    func setSteer(_ value: Double) {
        touchControls.steer = value
    }

    func setAccelerating(_ value: Bool) {
        touchControls.accelerating = value
    }

    func setBraking(_ value: Bool) {
        touchControls.braking = value
    }

    func setDrifting(_ value: Bool) {
        touchControls.drifting = value
    }

    func setFiringItem(_ value: Bool) {
        touchControls.firingItem = value
    }

    func update(settings newValue: ControlSettings) {
        settings = newValue
        scene.settings = newValue
    }

    /// Which button earns a rocket start, given the current assists.
    var rocketStartHint: String {
        ControlMapper.rocketStartHint(settings: settings)
    }

    // MARK: - Presentation

    /// Republishes the HUD at 30 Hz. Every frame would re-render the overlay
    /// needlessly; much slower and the speed dial looks steppy.
    private func publish(from simulation: RaceSimulation) {
        frameCounter += 1
        guard frameCounter % 2 == 0 else { return }

        let model = HUDModel(simulation: simulation)
        hud = model

        if frameCounter % 10 == 0 {
            standings = StandingsRow.rows(simulation: simulation)
        }

        if let player = simulation.playerCart {
            audio.updateEngine(
                speedFraction: player.forwardSpeed / player.tuning.topSpeed,
                onRoughGround: player.isOffRoad,
                boosting: player.isBoosting
            )
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        scene.isPaused = paused
        if paused {
            audio.silenceEngine()
        }
    }

    /// Called when the race view goes away, so the trolley does not carry on
    /// rattling over the results screen.
    func stopEngineSound() {
        audio.silenceEngine()
    }
}
