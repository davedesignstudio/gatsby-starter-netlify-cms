import Foundation

/// Everything you can pull out of a crate. Grocery equivalents of the usual
/// kart-racer arsenal.
public enum ItemKind: String, Sendable, CaseIterable {
    /// Tinned soup, thrown forward or back. Ricochets off shelving.
    case soupCan
    /// Three cans orbiting the cart until thrown or knocked off.
    case tripleCans
    /// Seedless, homing, and extremely committed to the racer ahead of you.
    case rogueMelon
    /// A dropped puddle. Whoever touches it loses the plot.
    case milkSpill
    /// Instant boost.
    case energyDrink
    /// Dropped upright. Not solid, but it will spin you.
    case wetFloorSign
    /// "Cleanup on aisle five." Everyone ahead of you slows down.
    case cleanupCall
    /// Store VIP card: briefly untouchable and faster.
    case vipCard
    /// A runaway cart drags you along the racing line at speed.
    case runawayCart

    public var displayName: String {
        switch self {
        case .soupCan: return "Soup Can"
        case .tripleCans: return "Triple Cans"
        case .rogueMelon: return "Rogue Melon"
        case .milkSpill: return "Milk Spill"
        case .energyDrink: return "Energy Drink"
        case .wetFloorSign: return "Wet Floor Sign"
        case .cleanupCall: return "Cleanup Call"
        case .vipCard: return "VIP Card"
        case .runawayCart: return "Runaway Cart"
        }
    }

    public var blurb: String {
        switch self {
        case .soupCan: return "Bounces off shelves. Condensed."
        case .tripleCans: return "Three chances to be unpleasant."
        case .rogueMelon: return "Locks on to the cart ahead."
        case .milkSpill: return "Drop it. Watch the chaos."
        case .energyDrink: return "Tastes blue. Goes fast."
        case .wetFloorSign: return "A warning, weaponised."
        case .cleanupCall: return "Slows everyone ahead of you."
        case .vipCard: return "Untouchable, briefly."
        case .runawayCart: return "Hold on. Steering is optional."
        }
    }

    /// How many uses one pickup grants.
    public var charges: Int {
        switch self {
        case .tripleCans: return 3
        default: return 1
        }
    }

    /// Items held behind the cart as a shield rather than fired immediately.
    public var isTrailable: Bool {
        switch self {
        case .soupCan, .tripleCans, .milkSpill, .wetFloorSign: return true
        default: return false
        }
    }

    /// Used the instant it is triggered, no aiming involved.
    public var isInstant: Bool {
        switch self {
        case .energyDrink, .vipCard, .cleanupCall, .runawayCart: return true
        default: return false
        }
    }
}

/// Position-weighted item distribution: the front of the field gets junk, the
/// back gets rescue items.
public enum ItemRoulette {
    /// Weight anchors at the front, middle and back of the field.
    private static let table: [(kind: ItemKind, front: Double, mid: Double, back: Double)] = [
        (.milkSpill, 34, 16, 4),
        (.soupCan, 30, 20, 6),
        (.wetFloorSign, 20, 12, 3),
        (.tripleCans, 8, 14, 8),
        (.energyDrink, 6, 18, 24),
        (.rogueMelon, 2, 14, 20),
        (.cleanupCall, 0, 4, 10),
        (.vipCard, 0, 2, 12),
        (.runawayCart, 0, 0, 7)
    ]

    /// - Parameters:
    ///   - position: 1-based finishing order at the moment of pickup.
    ///   - fieldSize: number of racers.
    ///   - luck: 0...1 from the character; nudges the roll towards better items.
    public static func roll(
        position: Int,
        fieldSize: Int,
        luck: Double,
        using generator: inout SeededRandom
    ) -> ItemKind {
        let denominator = Double(max(fieldSize - 1, 1))
        let rank = clamp(Double(position - 1) / denominator, 0, 1)
        let biased = clamp(rank + (luck - 0.5) * 0.22, 0, 1)

        let weights = table.map { entry -> Double in
            if biased < 0.5 {
                let t = biased / 0.5
                return entry.front + (entry.mid - entry.front) * t
            } else {
                let t = (biased - 0.5) / 0.5
                return entry.mid + (entry.back - entry.mid) * t
            }
        }
        return table[generator.weightedIndex(weights)].kind
    }

    /// Expected distribution for a given slot, exposed for tuning and tests.
    public static func weights(position: Int, fieldSize: Int, luck: Double = 0.5) -> [ItemKind: Double] {
        let denominator = Double(max(fieldSize - 1, 1))
        let rank = clamp(Double(position - 1) / denominator, 0, 1)
        let biased = clamp(rank + (luck - 0.5) * 0.22, 0, 1)
        var result: [ItemKind: Double] = [:]
        for entry in table {
            let weight: Double
            if biased < 0.5 {
                weight = entry.front + (entry.mid - entry.front) * (biased / 0.5)
            } else {
                weight = entry.mid + (entry.back - entry.mid) * ((biased - 0.5) / 0.5)
            }
            result[entry.kind] = weight
        }
        return result
    }
}
