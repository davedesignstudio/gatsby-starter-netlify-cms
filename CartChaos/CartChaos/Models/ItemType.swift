import SpriteKit

enum ItemType: CaseIterable {
    case bananaPeel
    case canMissile
    case squeakyBoost
    case couponShield
    case spilledMilk

    var displayName: String {
        switch self {
        case .bananaPeel: return "Banana Peel"
        case .canMissile: return "Can Missile"
        case .squeakyBoost: return "Squeaky Boost"
        case .couponShield: return "Coupon Shield"
        case .spilledMilk: return "Spilled Milk"
        }
    }

    var emoji: String {
        switch self {
        case .bananaPeel: return "🍌"
        case .canMissile: return "🥫"
        case .squeakyBoost: return "⚡"
        case .couponShield: return "🛡️"
        case .spilledMilk: return "🥛"
        }
    }

    var color: SKColor {
        switch self {
        case .bananaPeel: return .yellow
        case .canMissile: return .orange
        case .squeakyBoost: return .cyan
        case .couponShield: return .green
        case .spilledMilk: return .white
        }
    }

    static func random() -> ItemType {
        allCases.randomElement() ?? .bananaPeel
    }
}
