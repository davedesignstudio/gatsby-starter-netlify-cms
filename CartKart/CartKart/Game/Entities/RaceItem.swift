import Foundation

enum RaceItem: CaseIterable {
    case coffeeBoost
    case bananaPeel
    case cardboardBox
    case couponShield

    var displayName: String {
        switch self {
        case .coffeeBoost: return "Coffee Boost"
        case .bananaPeel: return "Banana Peel"
        case .cardboardBox: return "Cardboard Box"
        case .couponShield: return "Coupon Shield"
        }
    }

    var iconName: String {
        switch self {
        case .coffeeBoost: return "cup.and.saucer.fill"
        case .bananaPeel: return "leaf.fill"
        case .cardboardBox: return "shippingbox.fill"
        case .couponShield: return "shield.fill"
        }
    }

    static func random() -> RaceItem {
        allCases.randomElement() ?? .coffeeBoost
    }
}
