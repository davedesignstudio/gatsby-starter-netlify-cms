import CoreMotion

/// Tilt steering. Reads device motion on a background queue and exposes the
/// latest steering angle for the render loop to sample, so no work happens per
/// frame.
final class MotionSteering {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    /// Latest steering angle in radians, guarded by the lock.
    private var latestAngle: Double = 0
    private let lock = NSLock()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    init() {
        queue.name = "cart-racer.motion"
        queue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Turning the device like a steering wheel rotates it about the axis
            // coming out of the screen, which swings gravity around within the
            // device's own x-y plane. Measuring that angle works the same in both
            // landscape orientations and at whatever angle the player is holding
            // the phone, as long as they calibrate a neutral — unlike attitude
            // roll, whose sign flips with the orientation.
            let gravity = motion.gravity
            let angle = atan2(gravity.y, gravity.x)
            self.lock.lock()
            self.latestAngle = angle
            self.lock.unlock()
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Current steering angle in radians, to be compared against the calibrated
    /// neutral in `ControlSettings`.
    func steeringAngle() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return latestAngle
    }
}
