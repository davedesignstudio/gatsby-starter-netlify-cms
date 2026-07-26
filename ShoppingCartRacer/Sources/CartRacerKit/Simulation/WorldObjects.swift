import Foundation

/// A thrown can (or a launched crate) in flight.
public struct Projectile: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case sodaCan
        case launchedCrate

        public var radius: Double {
            switch self {
            case .sodaCan: return 0.42
            case .launchedCrate: return 0.55
            }
        }

        /// Cans chase the cart ahead; launched crates fly dead straight.
        public var homingStrength: Double {
            switch self {
            case .sodaCan: return 1.0
            case .launchedCrate: return 0
            }
        }
    }

    public let id: Int
    public let ownerID: Int
    public let kind: Kind
    public var position: Vector2
    public var velocity: Vector2
    public var lifetime: Double
    /// Grace period so a projectile cannot immediately hit its thrower.
    public var ownerImmunity: Double
    public var spin: Double

    public init(
        id: Int,
        ownerID: Int,
        kind: Kind,
        position: Vector2,
        velocity: Vector2,
        lifetime: Double,
        ownerImmunity: Double = 0.35,
        spin: Double = 0
    ) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.position = position
        self.velocity = velocity
        self.lifetime = lifetime
        self.ownerImmunity = ownerImmunity
        self.spin = spin
    }
}

/// Something left on the floor for the people behind you.
public struct Hazard: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case greaseSlick
        case spilledStock

        public var radius: Double {
            switch self {
            case .greaseSlick: return 1.5
            case .spilledStock: return 1.2
            }
        }
    }

    public let id: Int
    public let ownerID: Int
    public let kind: Kind
    public var position: Vector2
    public var lifetime: Double
    /// Grows to 1 as the puddle spreads, so it can pop into view.
    public var maturity: Double
    /// Where this sits relative to the centreline, resolved once at spawn so the
    /// AI can plan around it without re-projecting every frame.
    public let trackDistance: Double
    public let trackLateral: Double

    public init(
        id: Int,
        ownerID: Int,
        kind: Kind,
        position: Vector2,
        lifetime: Double,
        maturity: Double = 0,
        trackDistance: Double = 0,
        trackLateral: Double = 0
    ) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.position = position
        self.lifetime = lifetime
        self.maturity = maturity
        self.trackDistance = trackDistance
        self.trackLateral = trackLateral
    }
}

/// A promo crate with a respawn timer.
public struct ItemBoxRuntime: Identifiable, Sendable {
    public let id: Int
    public let spawn: ItemBoxSpawn
    public var cooldown: Double
    public let trackDistance: Double
    public let trackLateral: Double

    public var isAvailable: Bool { cooldown <= 0 }
    public var position: Vector2 { spawn.position }

    public init(id: Int, spawn: ItemBoxSpawn, trackDistance: Double, trackLateral: Double) {
        self.id = id
        self.spawn = spawn
        self.cooldown = 0
        self.trackDistance = trackDistance
        self.trackLateral = trackLateral
    }
}

/// Loose change on the floor.
public struct TokenRuntime: Identifiable, Sendable {
    public let id: Int
    public let spawn: TokenSpawn
    public var cooldown: Double

    public var isAvailable: Bool { cooldown <= 0 }
    public var position: Vector2 { spawn.position }

    public init(id: Int, spawn: TokenSpawn) {
        self.id = id
        self.spawn = spawn
        self.cooldown = 0
    }
}
