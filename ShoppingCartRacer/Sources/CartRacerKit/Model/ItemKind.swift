import Foundation

/// Everything you can pull out of a smashed promo crate.
public enum ItemKind: String, CaseIterable, Codable, Sendable {
    /// Instant burst of speed.
    case energyDrink
    /// Shaken fizzy can thrown forwards; lightly homes on the cart ahead.
    case sodaCan
    /// Cooking oil dropped behind you. Anyone who touches it loses the back end.
    case greaseSlick
    /// Stack of milk crates that orbits the cart and eats one hit.
    case crateShield
    /// Tannoy announcement that stalls everybody ahead of you.
    case clearanceAnnouncement
    /// Auto-piloted sprint up the racing line, for the back of the pack only.
    case expressLane

    public var displayName: String {
        switch self {
        case .energyDrink: return "Energy Drink"
        case .sodaCan: return "Shaken Can"
        case .greaseSlick: return "Grease Slick"
        case .crateShield: return "Crate Shield"
        case .clearanceAnnouncement: return "Clearance Announcement"
        case .expressLane: return "Express Lane"
        }
    }

    public var detail: String {
        switch self {
        case .energyDrink: return "Chug it for an instant burst."
        case .sodaCan: return "Fires forwards and spins out whoever it finds."
        case .greaseSlick: return "Drops behind you. Very slippery."
        case .crateShield: return "Blocks the next hit, then shatters."
        case .clearanceAnnouncement: return "Stalls every cart ahead of you."
        case .expressLane: return "Rockets you up the racing line."
        }
    }

    /// Items that fire the moment you press the button rather than being aimed.
    public var isInstant: Bool {
        switch self {
        case .energyDrink, .clearanceAnnouncement, .expressLane: return true
        case .sodaCan, .greaseSlick, .crateShield: return false
        }
    }
}

/// Position-weighted item distribution. Leaders get defensive junk, the back of
/// the field gets the comeback tools — the usual kart-racer bargain.
public struct ItemRoulette: Sendable {
    public init() {}

    /// - Parameters:
    ///   - racePosition: 1-based finishing position right now.
    ///   - fieldSize: how many carts are in the race.
    public func weights(racePosition: Int, fieldSize: Int) -> [ItemKind: Double] {
        let clampedField = max(fieldSize, 1)
        let position = Scalar.clamp(racePosition, 1, clampedField)
        // 0 for the leader, 1 for last place.
        let backness = clampedField == 1 ? 0 : Double(position - 1) / Double(clampedField - 1)

        var table: [ItemKind: Double] = [:]
        table[.sodaCan] = Scalar.lerp(1.0, 2.6, backness)
        table[.greaseSlick] = Scalar.lerp(3.0, 0.9, backness)
        table[.crateShield] = Scalar.lerp(2.6, 1.2, backness)
        table[.energyDrink] = Scalar.lerp(1.6, 2.4, backness)
        // Comeback items are gated behind actually being behind.
        table[.clearanceAnnouncement] = backness > 0.34 ? Scalar.lerp(0, 1.5, backness) : 0
        table[.expressLane] = backness > 0.66 ? Scalar.lerp(0, 1.8, backness) : 0
        return table
    }

    public func draw(racePosition: Int, fieldSize: Int, random: inout DeterministicRandom) -> ItemKind {
        let table = weights(racePosition: racePosition, fieldSize: fieldSize)
        // Sorted for determinism: dictionary order is not stable across runs.
        let entries = table
            .filter { $0.value > 0 }
            .sorted { $0.key.rawValue < $1.key.rawValue }
        guard !entries.isEmpty else { return .energyDrink }
        let index = random.weightedIndex(entries.map(\.value))
        return entries[index].key
    }
}
