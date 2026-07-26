import Foundation

/// The contents of a smashed item box.
public enum ItemKind: String, Sendable, CaseIterable, Codable {
    /// Dropped behind you. Whoever rolls over it takes a spin.
    case grapeSpill
    /// Forward-firing tin that nudges itself toward the cart in front.
    case soupCan
    /// Three tins, fired one at a time.
    case tripleSoup
    /// Instant boost.
    case energyDrink
    /// Leaves a mopped patch: no grip, no steering.
    case mopBucket
    /// Puff of self-raising flour that blinds and slows whoever drives through.
    case flourBomb
    /// Temporary invincibility and extra speed. Everything you touch goes flying.
    case bulkBuy
    /// Rolls along the aisle until it finds the race leader.
    case runawayMelon

    public var displayName: String {
        switch self {
        case .grapeSpill: return "Grape Spill"
        case .soupCan: return "Soup Can"
        case .tripleSoup: return "Triple Soup"
        case .energyDrink: return "Energy Drink"
        case .mopBucket: return "Mop Bucket"
        case .flourBomb: return "Flour Bomb"
        case .bulkBuy: return "Bulk Buy"
        case .runawayMelon: return "Runaway Melon"
        }
    }

    public var emoji: String {
        switch self {
        case .grapeSpill: return "🍇"
        case .soupCan, .tripleSoup: return "🥫"
        case .energyDrink: return "🥤"
        case .mopBucket: return "🪣"
        case .flourBomb: return "🌾"
        case .bulkBuy: return "🛍️"
        case .runawayMelon: return "🍉"
        }
    }

    /// How many times the item can be used before the slot empties.
    public var charges: Int {
        switch self {
        case .tripleSoup: return 3
        default: return 1
        }
    }

    /// Items that sit behind the cart as a shield until fired or dropped.
    public var isTrailed: Bool {
        switch self {
        case .grapeSpill, .soupCan, .tripleSoup: return true
        default: return false
        }
    }
}

/// A hazard resting on the floor.
public struct DroppedHazard: Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case grapeSpill
        case moppedFloor
        case flourCloud
    }

    public let id: Int
    public var kind: Kind
    public var position: Vec2
    public var radius: Double
    public var ownerID: Int?
    /// Seconds until it is cleaned up by staff.
    public var remainingLife: Double
    /// Brief window after spawning during which the owner cannot trip on it.
    public var ownerGrace: Double
}

/// Something flying (or rolling) through the store.
public struct Projectile: Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case soupCan
        case runawayMelon
    }

    public let id: Int
    public var kind: Kind
    public var position: Vec2
    public var velocity: Vec2
    public var ownerID: Int
    public var remainingLife: Double
    /// Melons navigate by arc length instead of chasing a point in space.
    public var trackArcLength: Double
    public var targetID: Int?
    public var radius: Double
}

/// Item box on the floor, temporarily empty after being smashed.
public struct ItemBoxState: Sendable, Identifiable {
    public let id: Int
    public var position: Vec2
    public var radius: Double
    public var respawnTimer: Double
    /// Cached from the track so the AI can plan detours cheaply.
    public var arcLength: Double
    public var lane: Double
    public var isAvailable: Bool { respawnTimer <= 0 }
}

/// Position-aware item distribution, so last place gets the fun stuff.
public enum ItemRoulette {
    /// - Parameter positionFraction: 0 for the leader, 1 for last place.
    public static func weights(positionFraction: Double, racerCount: Int) -> [(ItemKind, Double)] {
        let t = clamp(positionFraction, 0, 1)
        // Front of the pack: defensive junk. Back of the pack: comeback tools.
        let melonWeight = racerCount > 2 ? max(0, (t - 0.45) * 2.4) : 0
        return [
            (.grapeSpill, lerp(3.4, 0.6, t)),
            (.soupCan, lerp(3.0, 1.1, t)),
            (.tripleSoup, lerp(0.7, 1.9, t)),
            (.energyDrink, lerp(1.0, 2.6, t)),
            (.mopBucket, lerp(1.6, 1.2, t)),
            (.flourBomb, lerp(1.2, 1.6, t)),
            (.bulkBuy, lerp(0.0, 1.5, max(0, t - 0.3) / 0.7)),
            (.runawayMelon, melonWeight)
        ]
    }

    public static func roll(
        positionFraction: Double,
        racerCount: Int,
        random: inout SeededRandom
    ) -> ItemKind {
        let table = weights(positionFraction: positionFraction, racerCount: racerCount)
        let index = random.weightedIndex(table.map(\.1))
        return table[index].0
    }
}
