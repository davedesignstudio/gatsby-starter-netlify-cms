import Foundation

/// Player or AI intent for a single simulation step.
public struct RaceInput: Sendable, Equatable {
    /// -1 (brake / reverse) ... 1 (full push).
    public var throttle: Double
    /// -1 (right) ... 1 (left). Positive is counter-clockwise, matching world angles.
    public var steer: Double
    /// Held to lean into a drift.
    public var isDrifting: Bool
    /// Edge-triggered by the engine: only a false -> true transition fires an item.
    public var useItem: Bool
    /// Fires trailed items backwards instead of forwards.
    public var aimBackwards: Bool

    public init(
        throttle: Double = 0,
        steer: Double = 0,
        isDrifting: Bool = false,
        useItem: Bool = false,
        aimBackwards: Bool = false
    ) {
        self.throttle = throttle
        self.steer = steer
        self.isDrifting = isDrifting
        self.useItem = useItem
        self.aimBackwards = aimBackwards
    }

    public static let idle = RaceInput()
    public static let fullThrottle = RaceInput(throttle: 1)
}

/// Something unpleasant that just happened to a cart.
public enum Disruption: String, Sendable {
    /// Hit a spill or a tin: the cart pirouettes.
    case spin
    /// On a mopped patch: steering does nothing until it ends.
    case slip
    /// Melon direct hit: flattened, very slow to recover.
    case squash
    /// Drove through flour: slowed and half blind.
    case cloud

    /// Higher severity overrides lower when effects overlap.
    public var severity: Int {
        switch self {
        case .cloud: return 0
        case .slip: return 1
        case .spin: return 2
        case .squash: return 3
        }
    }

    /// Whether the driver keeps control of steering.
    public var allowsControl: Bool {
        self == .cloud
    }
}

/// Held item plus remaining charges.
public struct HeldItem: Sendable, Equatable {
    public var kind: ItemKind
    public var charges: Int

    public init(kind: ItemKind, charges: Int? = nil) {
        self.kind = kind
        self.charges = charges ?? kind.charges
    }
}

/// Mini-turbo charge level.
public enum DriftTier: Int, Sendable, Comparable {
    case none = 0
    case squeak = 1
    case rattle = 2
    case rumble = 3

    public static func < (lhs: DriftTier, rhs: DriftTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .none: return ""
        case .squeak: return "SQUEAK"
        case .rattle: return "RATTLE"
        case .rumble: return "RUMBLE!"
        }
    }
}

/// Full mutable state of one cart in a race.
public struct KartState: Sendable, Identifiable {
    public let id: Int
    public let profile: RacerProfile
    public let physics: PhysicsProfile
    public let isPlayerControlled: Bool

    // Motion
    public var position: Vec2
    public var heading: Double
    public var velocity: Vec2 = .zero
    /// Visual-only body yaw offset while drifting, in radians.
    public var driftLean: Double = 0
    /// Smoothed cosmetic wheel angle for the renderer.
    public var steerVisual: Double = 0

    // Drift and boost
    public var isDrifting: Bool = false
    public var driftDirection: Double = 0
    public var driftCharge: Double = 0
    public var driftTier: DriftTier = .none
    public var boostTimer: Double = 0
    public var boostStrength: Double = 1
    public var bulkBuyTimer: Double = 0

    // Damage
    public var disruption: Disruption?
    public var disruptionTimer: Double = 0
    public var invulnerabilityTimer: Double = 0
    /// Spin animation angle, kept separate from `heading` so recovery is clean.
    public var spinVisual: Double = 0

    // Items
    public var item: HeldItem?
    /// Counts down while the item roulette spins before settling.
    public var itemRouletteTimer: Double = 0
    public var pendingItem: ItemKind?

    // Progress
    public var lapsCompleted: Int = 0
    public var arcLength: Double = 0
    public var lateralOffset: Double = 0
    public var sampleHint: Int = 0
    /// Laps plus fractional lap distance; the single source of truth for ranking.
    public var totalProgress: Double = 0
    public var isWrongWay: Bool = false
    public var lapTimes: [Double] = []
    public var currentLapStart: Double = 0
    public var finishTime: Double?
    public var finishPlace: Int?
    public var surface: SurfaceKind = .tile
    /// 1 = leader.
    public var racePosition: Int = 1

    // AI
    public var aiSkill: Double = 1
    /// Per-cart lane preference so the field does not drive in single file.
    public var aiLaneBias: Double = 0
    public var aiItemTimer: Double = 0
    /// While positive the AI backs up to free itself from whatever it is against.
    public var aiReverseTimer: Double = 0

    /// Seconds spent going nowhere while nominally in control. Feeds both the
    /// AI's reversing recovery and the staff rescue.
    public var stuckTimer: Double = 0

    public init(
        id: Int,
        profile: RacerProfile,
        tuning: RaceTuning,
        isPlayerControlled: Bool,
        position: Vec2,
        heading: Double
    ) {
        self.id = id
        self.profile = profile
        self.physics = PhysicsProfile(profile: profile, tuning: tuning)
        self.isPlayerControlled = isPlayerControlled
        self.position = position
        self.heading = heading
    }

    public var isFinished: Bool { finishTime != nil }
    public var isBoosting: Bool { boostTimer > 0 }
    public var isInvincible: Bool { bulkBuyTimer > 0 }
    public var canBeHit: Bool { invulnerabilityTimer <= 0 && bulkBuyTimer <= 0 && !isFinished }
    public var speed: Double { velocity.length }
    /// Component of velocity along the cart's facing direction.
    public var forwardSpeed: Double { velocity.dot(Vec2.direction(heading)) }
    /// Body angle for rendering, including drift lean and spin animation.
    public var visualHeading: Double { heading + driftLean + spinVisual }
}
