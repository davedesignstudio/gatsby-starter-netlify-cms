import CartKartCore
import Combine
import CoreMotion
import Foundation

/// Bridge between the on-screen controls and the simulation's `RaceInput`.
///
/// The scene reads this once per frame. Steering is published so the HUD can
/// show the wheel moving; the rest is plain state to avoid needless redraws.
final class ControlState: ObservableObject {
    /// -1 (right) ... 1 (left), matching `RaceInput.steer`.
    @Published var steer: Double = 0
    @Published var isDrifting: Bool = false
    @Published var isBraking: Bool = false
    /// Carts accelerate on their own; the player only steers, drifts and brakes.
    var autoAccelerate = true
    /// Set by the throttle pad when auto acceleration is switched off.
    var manualThrottle: Double = 0
    /// True for exactly one frame after the item button is tapped.
    private var itemRequested = false
    private var fireBackwards = false

    private let tilt = TiltSteering()

    func requestItem(backwards: Bool = false) {
        itemRequested = true
        fireBackwards = backwards
    }

    func beginTiltIfNeeded(_ scheme: Storage.ControlScheme) {
        if scheme == .tilt { tilt.start() } else { tilt.stop() }
    }

    func stopTilt() {
        tilt.stop()
    }

    /// Builds this frame's input and clears the one-shot item request.
    func makeInput(scheme: Storage.ControlScheme) -> RaceInput {
        let steering = scheme == .tilt ? tilt.steer : steer
        let throttle: Double
        if isBraking {
            throttle = -1
        } else if autoAccelerate {
            throttle = 1
        } else {
            throttle = manualThrottle
        }
        defer { itemRequested = false }
        return RaceInput(
            throttle: throttle,
            steer: clamp(steering, -1, 1),
            isDrifting: isDrifting,
            useItem: itemRequested,
            aimBackwards: fireBackwards
        )
    }

    func reset() {
        steer = 0
        isDrifting = false
        isBraking = false
        itemRequested = false
    }
}

/// Reads device roll and turns it into a steering value.
private final class TiltSteering {
    private let motion = CMMotionManager()
    /// Roll offset captured when tilt steering starts, so any comfortable
    /// holding angle counts as straight ahead.
    private var neutralRoll: Double?

    var steer: Double {
        guard let gravity = motion.deviceMotion?.gravity else { return 0 }
        // Landscape: rolling the device tips gravity along the y axis.
        let roll = atan2(gravity.y, -gravity.x)
        if neutralRoll == nil { neutralRoll = roll }
        let delta = Angle.delta(from: neutralRoll ?? roll, to: roll)
        // Full lock at about 30 degrees of tilt, with a small dead zone.
        let normalized = clamp(delta / (Double.pi / 6), -1, 1)
        return abs(normalized) < 0.06 ? 0 : normalized
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates()
        neutralRoll = nil
    }

    func stop() {
        guard motion.isDeviceMotionActive else { return }
        motion.stopDeviceMotionUpdates()
        neutralRoll = nil
    }
}
