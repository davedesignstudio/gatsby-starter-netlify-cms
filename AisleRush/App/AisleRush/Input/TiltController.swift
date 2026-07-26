import CoreMotion
import Foundation
import UIKit

/// Tilt steering. Reads device motion, takes a neutral reference the first
/// time it sees the device, and reports a -1...1 steering value.
final class TiltController {
    private let motion = CMMotionManager()
    private var neutralRoll: Double?
    /// Tilt beyond this many radians counts as full lock.
    private let fullLock: Double = 0.42
    /// Which way round the device is. Resolved once at start rather than on
    /// every one of sixty callbacks a second.
    private var gravitySign: Double = 1

    func start(onUpdate: @escaping (Double) -> Void) {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        // Landscape: the axis that tips left and right is gravity.y, and its
        // sign flips with which way up the device is being held.
        gravitySign = UIApplication.shared.landscapeOrientation == .landscapeLeft ? 1 : -1
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }

            let raw = data.gravity.y * self.gravitySign
            let angle = asin(max(-1, min(1, raw)))

            if self.neutralRoll == nil { self.neutralRoll = angle }
            let offset = angle - (self.neutralRoll ?? 0)
            var steer = offset / self.fullLock
            steer = max(-1, min(1, steer))
            // A small dead zone stops the cart weaving while you hold still.
            if abs(steer) < 0.08 { steer = 0 }
            onUpdate(-steer)
        }
    }

    func recentre() {
        neutralRoll = nil
    }

    func stop() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        neutralRoll = nil
    }
}

extension UIApplication {
    var landscapeOrientation: UIInterfaceOrientation {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let orientation = scene?.interfaceOrientation ?? .landscapeRight
        return orientation == .landscapeLeft ? .landscapeLeft : .landscapeRight
    }
}
