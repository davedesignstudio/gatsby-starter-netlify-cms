import Foundation

/// One frame of control input, whether it came from a thumb, a tilt sensor, a
/// game controller or the AI.
public struct DriverInput: Equatable, Sendable {
    /// -1 (full brake / reverse) ... 1 (full throttle).
    public var throttle: Double
    /// -1 (right) ... 1 (left). Positive matches the maths convention: turning
    /// left increases the heading angle.
    public var steer: Double
    /// Hold to slide; release with charge for a mini-turbo.
    public var drift: Bool
    /// Rising edge fires whatever is in the item slot.
    public var useItem: Bool

    public init(throttle: Double = 0, steer: Double = 0, drift: Bool = false, useItem: Bool = false) {
        self.throttle = Scalar.clamp(throttle, -1, 1)
        self.steer = Scalar.clamp(steer, -1, 1)
        self.drift = drift
        self.useItem = useItem
    }

    public static let idle = DriverInput()
    public static let flatOut = DriverInput(throttle: 1)
}
