import CoreMotion

/// Tilt steering. Reads device motion on a background queue and exposes the
/// latest roll for the render loop to sample, so no work happens per frame.
final class MotionSteering {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    /// Latest device roll in radians, guarded by the lock.
    private var latestRoll: Double = 0
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
            // The device is held in landscape, so the roll axis is the one that
            // corresponds to turning an imaginary steering wheel.
            let roll = motion.attitude.roll
            self.lock.lock()
            self.latestRoll = roll
            self.lock.unlock()
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Current roll in radians.
    func roll() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return latestRoll
    }
}
