import Foundation

public enum SteeringStyle: String, Codable, CaseIterable, Sendable {
    /// Thumb pad in the bottom-left corner.
    case touchPad
    /// Drag anywhere on the left half of the screen.
    case dragAnywhere
    /// Tilt the device.
    case tilt

    public var displayName: String {
        switch self {
        case .touchPad: return "Thumb Pad"
        case .dragAnywhere: return "Drag Anywhere"
        case .tilt: return "Tilt"
        }
    }
}

public struct ControlSettings: Codable, Equatable, Sendable {
    public var steeringStyle: SteeringStyle
    /// 0.5 (gentle) ... 1.5 (twitchy).
    public var sensitivity: Double
    /// Hold the throttle automatically so the player only steers and drifts.
    public var autoAccelerate: Bool
    public var hapticsEnabled: Bool
    public var soundEnabled: Bool
    /// Where "level" is for tilt steering, in radians.
    public var tiltNeutral: Double

    public init(
        steeringStyle: SteeringStyle = .touchPad,
        sensitivity: Double = 1.0,
        autoAccelerate: Bool = true,
        hapticsEnabled: Bool = true,
        soundEnabled: Bool = true,
        tiltNeutral: Double = 0
    ) {
        self.steeringStyle = steeringStyle
        self.sensitivity = sensitivity
        self.autoAccelerate = autoAccelerate
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
        self.tiltNeutral = tiltNeutral
    }

    public static let `default` = ControlSettings()
}

/// Shapes raw control input into something drivable: a dead zone so a resting
/// thumb does not weave, an expo curve for fine control near the centre, and a
/// rate limit so the cart never snaps to full lock in one frame.
public struct SteeringFilter: Sendable {
    public private(set) var value: Double = 0

    /// Inputs below this are treated as centred.
    public var deadZone: Double = 0.06
    /// 0 is linear; higher values give finer control around the centre.
    public var expo: Double = 0.45
    /// Maximum change in steering per second.
    public var slewRate: Double = 7.0

    public init() {}

    public mutating func reset() {
        value = 0
    }

    /// - Parameter raw: -1...1 from the thumb pad, drag or tilt.
    public mutating func update(raw: Double, settings: ControlSettings, delta: Double) -> Double {
        let clamped = Scalar.clamp(raw, -1, 1)
        let magnitude = abs(clamped)

        var shaped = 0.0
        if magnitude > deadZone {
            // Rescale so the input still reaches full lock after the dead zone.
            let normalized = (magnitude - deadZone) / (1 - deadZone)
            let curved = Scalar.lerp(normalized, normalized * normalized * normalized, expo)
            shaped = Scalar.signum(clamped) * curved * settings.sensitivity
        }
        shaped = Scalar.clamp(shaped, -1, 1)

        let maxChange = slewRate * max(delta, 0)
        let difference = Scalar.clamp(shaped - value, -maxChange, maxChange)
        value = Scalar.clamp(value + difference, -1, 1)
        return value
    }
}

/// The raw state of the on-screen controls for one frame, before shaping.
public struct RawControlState: Equatable, Sendable {
    /// -1 (right) ... 1 (left).
    public var steer: Double
    public var accelerating: Bool
    public var braking: Bool
    public var drifting: Bool
    public var firingItem: Bool
    /// True while the countdown is running and the player is revving.
    public var lookingBehind: Bool

    public init(
        steer: Double = 0,
        accelerating: Bool = false,
        braking: Bool = false,
        drifting: Bool = false,
        firingItem: Bool = false,
        lookingBehind: Bool = false
    ) {
        self.steer = steer
        self.accelerating = accelerating
        self.braking = braking
        self.drifting = drifting
        self.firingItem = firingItem
        self.lookingBehind = lookingBehind
    }
}

/// Turns on-screen controls into simulation input.
public struct ControlMapper: Sendable {
    public var filter = SteeringFilter()

    public init() {}

    public mutating func input(
        from raw: RawControlState,
        settings: ControlSettings,
        delta: Double
    ) -> DriverInput {
        let steer = filter.update(raw: raw.steer, settings: settings, delta: delta)

        var throttle = 0.0
        if raw.braking {
            throttle = -1
        } else if raw.accelerating || settings.autoAccelerate {
            throttle = 1
        }

        return DriverInput(throttle: throttle, steer: steer, drift: raw.drifting, useItem: raw.firingItem)
    }

    /// Converts a device roll angle into a steering value.
    ///
    /// - Parameters:
    ///   - roll: radians, positive when the right edge of the device is raised.
    ///   - range: the tilt angle that corresponds to full lock.
    public static func tiltSteer(roll: Double, settings: ControlSettings, range: Double = 0.55) -> Double {
        let corrected = roll - settings.tiltNeutral
        // Tilting right should turn right, which is a negative steer value.
        return Scalar.clamp(-corrected / max(range, 0.05), -1, 1)
    }
}
