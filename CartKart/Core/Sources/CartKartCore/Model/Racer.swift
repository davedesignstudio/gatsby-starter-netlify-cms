import Foundation

/// A selectable cart. Stats are on a 1...5 scale in the classic kart-racer
/// tradition and get converted into physics multipliers by `PhysicsProfile`.
public struct RacerProfile: Sendable, Identifiable, Hashable {
    public enum Weight: String, Sendable, CaseIterable {
        case feather
        case light
        case medium
        case heavy

        /// Mass used when two carts collide.
        public var mass: Double {
            switch self {
            case .feather: return 0.7
            case .light: return 0.85
            case .medium: return 1.0
            case .heavy: return 1.3
            }
        }
    }

    public let id: String
    public let name: String
    /// One-line character flavour shown on the select screen.
    public let tagline: String
    public let weight: Weight
    /// 1...5
    public let speed: Int
    /// 1...5
    public let acceleration: Int
    /// 1...5, resistance to sliding
    public let handling: Int
    /// 1...5, how quickly mini-turbos charge
    public let drift: Int
    /// 1...5, how little off-road ground hurts
    public let allTerrain: Int
    public let bodyColor: TrackTheme.RGB
    public let trimColor: TrackTheme.RGB
    /// Emoji used as a quick stand-in marker on the minimap and results table.
    public let emblem: String

    public init(
        id: String,
        name: String,
        tagline: String,
        weight: Weight,
        speed: Int,
        acceleration: Int,
        handling: Int,
        drift: Int,
        allTerrain: Int,
        bodyColor: TrackTheme.RGB,
        trimColor: TrackTheme.RGB,
        emblem: String
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.weight = weight
        self.speed = speed
        self.acceleration = acceleration
        self.handling = handling
        self.drift = drift
        self.allTerrain = allTerrain
        self.bodyColor = bodyColor
        self.trimColor = trimColor
        self.emblem = emblem
    }
}

/// Physics multipliers derived from a `RacerProfile`.
public struct PhysicsProfile: Sendable {
    public var topSpeed: Double
    public var acceleration: Double
    public var grip: Double
    public var driftCharge: Double
    public var roughPenalty: Double
    public var mass: Double

    public init(profile: RacerProfile, tuning: RaceTuning = .default) {
        func scale(_ stat: Int, _ spread: Double) -> Double {
            // stat 3 is neutral; each point moves the multiplier by `spread`.
            1 + (Double(clamp(stat, 1, 5)) - 3) * spread
        }
        // The spreads are deliberately narrow: a big top-speed advantage swamps
        // every other stat over a three lap race.
        self.topSpeed = tuning.baseTopSpeed * scale(profile.speed, 0.055)
        self.acceleration = tuning.baseAcceleration * scale(profile.acceleration, 0.13)
        self.grip = tuning.baseGrip * scale(profile.handling, 0.10)
        self.driftCharge = scale(profile.drift, 0.13)
        // allTerrain 5 keeps almost all your speed in the cereal aisle.
        self.roughPenalty = lerp(0.52, 0.86, (Double(clamp(profile.allTerrain, 1, 5)) - 1) / 4)
        self.mass = profile.weight.mass
    }
}

public enum Roster {
    public static let all: [RacerProfile] = [
        RacerProfile(
            id: "rusty",
            name: "Rusty",
            tagline: "Been doing loops of aisle four since 1994.",
            weight: .heavy,
            speed: 5, acceleration: 2, handling: 2, drift: 3, allTerrain: 4,
            bodyColor: .init(0.62, 0.30, 0.16),
            trimColor: .init(0.85, 0.72, 0.55),
            emblem: "🛒"
        ),
        RacerProfile(
            id: "squeaks",
            name: "Squeaks",
            tagline: "One wheel, zero fear, all noise.",
            weight: .feather,
            speed: 2, acceleration: 5, handling: 4, drift: 4, allTerrain: 2,
            bodyColor: .init(0.98, 0.80, 0.22),
            trimColor: .init(0.35, 0.28, 0.12),
            emblem: "🧺"
        ),
        RacerProfile(
            id: "chrome",
            name: "Chrome",
            tagline: "Showroom model. Never been near a carpark.",
            weight: .medium,
            speed: 4, acceleration: 3, handling: 4, drift: 3, allTerrain: 3,
            bodyColor: .init(0.78, 0.82, 0.88),
            trimColor: .init(0.20, 0.26, 0.34),
            emblem: "✨"
        ),
        RacerProfile(
            id: "wobble",
            name: "Wobble",
            tagline: "The bad wheel is a feature, not a defect.",
            weight: .light,
            speed: 3, acceleration: 4, handling: 2, drift: 5, allTerrain: 3,
            bodyColor: .init(0.42, 0.72, 0.45),
            trimColor: .init(0.14, 0.30, 0.18),
            emblem: "🌀"
        ),
        RacerProfile(
            id: "bertha",
            name: "Big Bertha",
            tagline: "Bulk buy champion. Yields to nobody.",
            weight: .heavy,
            speed: 4, acceleration: 2, handling: 3, drift: 2, allTerrain: 5,
            bodyColor: .init(0.85, 0.34, 0.30),
            trimColor: .init(0.32, 0.10, 0.10),
            emblem: "📦"
        ),
        RacerProfile(
            id: "sprout",
            name: "Sprout",
            tagline: "Kiddie cart with a plastic steering wheel and big dreams.",
            weight: .feather,
            speed: 2, acceleration: 5, handling: 5, drift: 4, allTerrain: 1,
            bodyColor: .init(0.36, 0.68, 0.92),
            trimColor: .init(0.98, 0.86, 0.32),
            emblem: "🚸"
        ),
        RacerProfile(
            id: "mopsy",
            name: "Mopsy",
            tagline: "Janitor's rig. Makes the mess, then races through it.",
            weight: .medium,
            speed: 3, acceleration: 3, handling: 5, drift: 3, allTerrain: 4,
            bodyColor: .init(0.30, 0.62, 0.60),
            trimColor: .init(0.95, 0.95, 0.90),
            emblem: "🧽"
        ),
        RacerProfile(
            id: "flatpack",
            name: "Flatpack",
            tagline: "Warehouse flatbed. Straight lines only, thanks.",
            weight: .heavy,
            speed: 5, acceleration: 3, handling: 1, drift: 2, allTerrain: 4,
            bodyColor: .init(0.55, 0.45, 0.72),
            trimColor: .init(0.22, 0.18, 0.30),
            emblem: "🪑"
        )
    ]

    public static func profile(id: String) -> RacerProfile {
        all.first { $0.id == id } ?? all[0]
    }
}
