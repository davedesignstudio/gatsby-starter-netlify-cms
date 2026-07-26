import SpriteKit

enum PowerUpType: String, CaseIterable {
    case couponBoost
    case wetFloorSign
    case paperBagShield
    case spilledSoda

    var displayName: String {
        switch self {
        case .couponBoost: return "COUPON BOOST"
        case .wetFloorSign: return "WET FLOOR"
        case .paperBagShield: return "PAPER SHIELD"
        case .spilledSoda: return "SPILLED SODA"
        }
    }

    var color: SKColor {
        switch self {
        case .couponBoost: return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        case .wetFloorSign: return SKColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
        case .paperBagShield: return SKColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1)
        case .spilledSoda: return SKColor(red: 0.55, green: 0.2, blue: 0.75, alpha: 1)
        }
    }

    var iconLetter: String {
        switch self {
        case .couponBoost: return "$"
        case .wetFloorSign: return "!"
        case .paperBagShield: return "B"
        case .spilledSoda: return "~"
        }
    }
}
