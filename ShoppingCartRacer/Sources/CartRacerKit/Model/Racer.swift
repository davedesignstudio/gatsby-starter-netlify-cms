import Foundation

/// A colour in linear-ish sRGB components, so the kit can describe its own art
/// direction without importing any graphics framework.
public struct RacerColor: Equatable, Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Convenience for authoring from hex literals like `0xFF7A1F`.
    public init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    public func mixed(with other: RacerColor, amount: Double) -> RacerColor {
        RacerColor(
            Scalar.lerp(red, other.red, amount),
            Scalar.lerp(green, other.green, amount),
            Scalar.lerp(blue, other.blue, amount)
        )
    }
}

/// Star ratings (0...1) that the character select screen shows and the physics
/// converts into real numbers.
public struct RacerStats: Equatable, Codable, Sendable {
    /// Straight-line speed.
    public var speed: Double
    /// How quickly the cart gets going again after a spinout.
    public var acceleration: Double
    /// Cornering bite.
    public var handling: Double
    /// Bump authority — heavy carts shove light ones aside.
    public var weight: Double
    /// How well the cart copes with wet floors and spilled stock.
    public var traction: Double

    public init(speed: Double, acceleration: Double, handling: Double, weight: Double, traction: Double) {
        self.speed = speed
        self.acceleration = acceleration
        self.handling = handling
        self.weight = weight
        self.traction = traction
    }
}

/// Silhouette used by the renderer to build the cart art procedurally.
public enum CartSilhouette: String, Codable, CaseIterable, Sendable {
    /// Standard supermarket trolley.
    case standardTrolley
    /// Small hand basket on castors.
    case handBasket
    /// Deep-sided warehouse cart piled with cardboard.
    case stockCart
    /// Two trolleys nested together.
    case nestedPair
    /// Cleaning rig with a mop bucket bolted on.
    case janitorRig
    /// Flat-bed trolley loaded with crates.
    case flatbed
}

/// A driver plus their cart. Stats are authored as 0...1 ratings and mapped to
/// physical values by `CartTuning`, which keeps balance edits in one place.
public struct Racer: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let blurb: String
    public let stats: RacerStats
    public let silhouette: CartSilhouette
    public let primaryColor: RacerColor
    public let secondaryColor: RacerColor
    /// Small per-racer perk, applied on top of the stat curve.
    public let perk: RacerPerk

    public init(
        id: String,
        name: String,
        title: String,
        blurb: String,
        stats: RacerStats,
        silhouette: CartSilhouette,
        primaryColor: RacerColor,
        secondaryColor: RacerColor,
        perk: RacerPerk
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.blurb = blurb
        self.stats = stats
        self.silhouette = silhouette
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.perk = perk
    }
}

public enum RacerPerk: String, Codable, CaseIterable, Sendable {
    /// Nothing special, just balanced.
    case none
    /// Keeps grip on wet floors and frost.
    case wetFloorSpecialist
    /// Mini-turbos charge faster.
    case driftCharger
    /// Shrugs off spinouts sooner.
    case quickRecovery
    /// Wins bumps against anyone.
    case bulldozer
    /// Boost pads and mini-turbos last longer.
    case boostHoarder

    public var displayName: String {
        switch self {
        case .none: return "All Rounder"
        case .wetFloorSpecialist: return "Wet Floor Specialist"
        case .driftCharger: return "Drift Charger"
        case .quickRecovery: return "Quick Recovery"
        case .bulldozer: return "Bulldozer"
        case .boostHoarder: return "Boost Hoarder"
        }
    }

    public var detail: String {
        switch self {
        case .none: return "No weaknesses, no gimmicks."
        case .wetFloorSpecialist: return "Half the grip penalty on wet floors and freezer frost."
        case .driftCharger: return "Mini-turbos charge 35% faster."
        case .quickRecovery: return "Spinouts end 30% sooner."
        case .bulldozer: return "Counts as much heavier when trading paint."
        case .boostHoarder: return "Every boost lasts 30% longer."
        }
    }
}

/// Converts a racer's 0...1 ratings into the numbers the physics loop uses.
public struct CartTuning: Sendable {
    public let topSpeed: Double
    public let enginePower: Double
    public let brakePower: Double
    public let reverseSpeed: Double
    public let baseTurnRate: Double
    public let driftTurnRate: Double
    public let mass: Double
    public let gripMultiplier: Double
    public let radius: Double

    public init(racer: Racer) {
        let stats = racer.stats
        // Metres per second. ~16 m/s reads as a comically fast trolley.
        topSpeed = Scalar.lerp(13.5, 17.5, stats.speed)
        enginePower = Scalar.lerp(9.0, 15.5, stats.acceleration)
        brakePower = Scalar.lerp(14.0, 20.0, stats.handling)
        reverseSpeed = 4.0
        // Radians per second at speed. These are the numbers that decide the
        // tightest corner a cart can take: at ~15 m/s, 1.1 rad/s is a 14 m
        // radius, and drifting brings that down to about 8 m. The courses are
        // authored around those two figures.
        baseTurnRate = Scalar.lerp(0.85, 1.25, stats.handling)
        driftTurnRate = baseTurnRate * Scalar.lerp(1.5, 1.75, stats.handling)
        mass = Scalar.lerp(70, 165, stats.weight)
        gripMultiplier = Scalar.lerp(0.82, 1.25, stats.traction)
        radius = Scalar.lerp(0.62, 0.86, stats.weight)
    }
}

/// The starting grid of playable characters.
public enum RacerRoster {
    public static let all: [Racer] = [
        Racer(
            id: "squeak",
            name: "Squeak",
            title: "Stockroom Rat",
            blurb: "Lives behind the cereal. Steers a hand basket at unreasonable speed.",
            stats: RacerStats(speed: 0.35, acceleration: 0.95, handling: 0.9, weight: 0.1, traction: 0.65),
            silhouette: .handBasket,
            primaryColor: RacerColor(hex: 0x9B8CFF),
            secondaryColor: RacerColor(hex: 0xFFE066),
            perk: .quickRecovery
        ),
        Racer(
            id: "marge",
            name: "Marge",
            title: "Coupon Queen",
            blurb: "Forty years of trolley experience and a folder of expired vouchers.",
            stats: RacerStats(speed: 0.55, acceleration: 0.6, handling: 0.95, weight: 0.35, traction: 0.8),
            silhouette: .standardTrolley,
            primaryColor: RacerColor(hex: 0xFF6FA5),
            secondaryColor: RacerColor(hex: 0xFFF3D6),
            perk: .driftCharger
        ),
        Racer(
            id: "kev",
            name: "Kev",
            title: "Bag Boy",
            blurb: "Off shift, technically. Pushes a flatbed like it owes him money.",
            stats: RacerStats(speed: 0.9, acceleration: 0.4, handling: 0.45, weight: 0.6, traction: 0.5),
            silhouette: .flatbed,
            primaryColor: RacerColor(hex: 0x3FC1C9),
            secondaryColor: RacerColor(hex: 0x22333B),
            perk: .boostHoarder
        ),
        Racer(
            id: "rusty",
            name: "Rusty",
            title: "Loading Bay Raccoon",
            blurb: "Cart is 60% cardboard by volume. Somehow that makes it faster.",
            stats: RacerStats(speed: 0.6, acceleration: 0.5, handling: 0.55, weight: 0.85, traction: 0.6),
            silhouette: .stockCart,
            primaryColor: RacerColor(hex: 0x8D6E5B),
            secondaryColor: RacerColor(hex: 0xC9A227),
            perk: .bulldozer
        ),
        Racer(
            id: "todd",
            name: "Trolley Todd",
            title: "Cart Wrangler",
            blurb: "Never pushes fewer than two trolleys. Corners like a freight train.",
            stats: RacerStats(speed: 0.95, acceleration: 0.35, handling: 0.3, weight: 1.0, traction: 0.45),
            silhouette: .nestedPair,
            primaryColor: RacerColor(hex: 0xF4A259),
            secondaryColor: RacerColor(hex: 0x5B5F97),
            perk: .bulldozer
        ),
        Racer(
            id: "mopbot",
            name: "Mopbot 9",
            title: "Floor Care Unit",
            blurb: "Was built to clean up spills. Has decided to race through them instead.",
            stats: RacerStats(speed: 0.6, acceleration: 0.7, handling: 0.7, weight: 0.5, traction: 1.0),
            silhouette: .janitorRig,
            primaryColor: RacerColor(hex: 0x7ED957),
            secondaryColor: RacerColor(hex: 0x2E3A59),
            perk: .wetFloorSpecialist
        )
    ]

    public static func racer(id: String) -> Racer? {
        all.first { $0.id == id }
    }

    /// Deterministic opponent grid: everyone except the player's pick.
    public static func opponents(excluding playerID: String, count: Int) -> [Racer] {
        let pool = all.filter { $0.id != playerID }
        guard count <= pool.count else { return pool }
        return Array(pool.prefix(count))
    }
}
