import SpriteKit

enum PowerUpType: CaseIterable {
    case bananaPeel
    case couponBoost
    case spilledMilk
    case canPyramid

    var displayName: String {
        switch self {
        case .bananaPeel: return "Banana Peel"
        case .couponBoost: return "Coupon Boost"
        case .spilledMilk: return "Spilled Milk"
        case .canPyramid: return "Can Pyramid"
        }
    }

    var color: SKColor {
        switch self {
        case .bananaPeel: return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        case .couponBoost: return SKColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1)
        case .spilledMilk: return SKColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1)
        case .canPyramid: return SKColor(red: 0.85, green: 0.35, blue: 0.2, alpha: 1)
        }
    }

    var icon: String {
        switch self {
        case .bananaPeel: return "🍌"
        case .couponBoost: return "🏷️"
        case .spilledMilk: return "🥛"
        case .canPyramid: return "🥫"
        }
    }

    static func random() -> PowerUpType {
        allCases.randomElement() ?? .couponBoost
    }
}
