import Foundation

/// One frame of control, whether it came from a thumb or from `AIDriver`.
public struct ControlInput: Sendable {
    /// -1...1. Positive steers left (counter-clockwise).
    public var steer: Double = 0
    /// -1...1. Negative brakes, then reverses.
    public var throttle: Double = 0
    public var drift: Bool = false
    public var useItem: Bool = false
    /// Fire the held item backwards instead of forwards.
    public var aimBackward: Bool = false

    public init(steer: Double = 0, throttle: Double = 0, drift: Bool = false, useItem: Bool = false, aimBackward: Bool = false) {
        self.steer = steer
        self.throttle = throttle
        self.drift = drift
        self.useItem = useItem
        self.aimBackward = aimBackward
    }

    public static let idle = ControlInput()
    public static let coasting = ControlInput(throttle: 1)
}

public struct DriftState: Sendable {
    public var isActive = false
    /// +1 drifting left, -1 drifting right.
    public var direction: Double = 0
    public var charge: Double = 0

    /// 0 = none, 1 = blue, 2 = orange, 3 = purple.
    public var tier: Int {
        if charge >= DriftTuning.tierThresholds[2] { return 3 }
        if charge >= DriftTuning.tierThresholds[1] { return 2 }
        if charge >= DriftTuning.tierThresholds[0] { return 1 }
        return 0
    }
}

public enum DriftTuning {
    public static let tierThresholds: [Double] = [0.75, 1.7, 2.9]
    public static let boostDurations: [Double] = [0.75, 1.25, 1.9]
    public static let boostStrengths: [Double] = [1.18, 1.3, 1.45]
    public static let minimumSpeed: Double = 7.0
    public static let minimumSteer: Double = 0.22
}

/// Why a cart is currently having a bad time. Purely for presentation.
public enum CartMishap: String, Sendable {
    case none
    case spinning
    case slowed
    case crashed
}

public struct Cart: Sendable, Identifiable {
    public let id: Int
    public var setup: CartSetup
    /// Stats as configured. `stats` is the live copy the physics reads, which
    /// the simulation may scale for catch-up assistance.
    public let baseStats: CartStats
    public var stats: CartStats
    public var isPlayer: Bool
    /// 0...1. Scales AI aggression, reaction time and cornering commitment.
    public var aiSkill: Double

    public var position: Vector2
    public var heading: Double
    public var velocity: Vector2 = .zero

    public var drift = DriftState()
    public var boostTimer: Double = 0
    public var boostStrength: Double = 1
    /// Set for one tick when a mini-turbo fires, so the view can spark.
    public var boostJustStarted: Int = 0

    public var spinTimer: Double = 0
    public var spinDirection: Double = 1
    public var slowTimer: Double = 0
    public var invincibleTimer: Double = 0
    public var autopilotTimer: Double = 0
    public var bumpCooldown: Double = 0

    public var heldItem: ItemKind?
    public var heldCharges: Int = 0
    public var rouletteTimer: Double = 0
    public var pendingItem: ItemKind?
    /// Cans currently orbiting the cart.
    public var orbitingCans: Int = 0
    public var orbitAngle: Double = 0
    /// True while the fire button is held on a trailable item, which drags it
    /// behind the cart as a shield.
    public var isTrailingItem = false
    /// Previous frame's fire button, for edge detection.
    public var wasFirePressed = false

    /// Laps started. 0 until the cart first crosses the line.
    public var lap: Int = 0
    /// Index of the next gate that must be passed for progress to count.
    public var checkpoint: Int = 0
    public var lapDistance: Double = 0
    public var lateral: Double = 0
    public var totalDistance: Double = 0
    public var lapStartTime: Double = 0
    public var lapTimes: [Double] = []
    public var finishTime: Double?
    public var placement: Int = 0
    public var surface: Surface = .linoleum
    public var isWrongWay = false
    public var projectionHint: Int = 0
    /// Rolling count of item boxes taken; used by the UI for flair.
    public var boxesCollected: Int = 0

    public init(id: Int, setup: CartSetup, isPlayer: Bool, aiSkill: Double, position: Vector2, heading: Double) {
        self.id = id
        self.setup = setup
        let resolved = setup.stats
        baseStats = resolved
        stats = resolved
        self.isPlayer = isPlayer
        self.aiSkill = aiSkill
        self.position = position
        self.heading = heading
    }

    public var speed: Double { velocity.length }

    /// Speed along the direction the cart is pointing; negative when reversing.
    public var forwardSpeed: Double { velocity.dot(Vector2.angled(heading)) }

    /// Angle between where the cart points and where it is actually going.
    public var slipAngle: Double {
        guard speed > 0.5 else { return 0 }
        return Angle.delta(from: heading, to: velocity.angle)
    }

    public var isControllable: Bool {
        spinTimer <= 0 && autopilotTimer <= 0
    }

    public var isInvincible: Bool { invincibleTimer > 0 }

    public var mishap: CartMishap {
        if spinTimer > 0 { return .spinning }
        if slowTimer > 0 { return .slowed }
        return .none
    }

    public var hasFinished: Bool { finishTime != nil }

    public var bestLapTime: Double? { lapTimes.min() }

    public var lastLapTime: Double? { lapTimes.last }

    /// Radius used for cart-to-cart contact.
    public var collisionRadius: Double { max(setup.frame.size.x, setup.frame.size.y) * 0.72 }

    public mutating func spinOut(direction: Double, duration: Double = 1.15) {
        guard !isInvincible else { return }
        spinTimer = max(spinTimer, duration)
        spinDirection = direction >= 0 ? 1 : -1
        drift = DriftState()
        boostTimer = 0
        boostStrength = 1
        orbitingCans = 0
        // Getting hit costs you whatever you were carrying.
        heldItem = nil
        heldCharges = 0
        isTrailingItem = false
    }

    public mutating func applySlow(duration: Double) {
        guard !isInvincible else { return }
        slowTimer = max(slowTimer, duration)
        drift = DriftState()
        boostTimer = 0
        boostStrength = 1
    }

    public mutating func grantBoost(duration: Double, strength: Double) {
        if strength >= boostStrength || boostTimer < duration * 0.4 {
            boostStrength = max(boostStrength, strength)
            boostTimer = max(boostTimer, duration)
            boostJustStarted = 2
        }
    }
}
