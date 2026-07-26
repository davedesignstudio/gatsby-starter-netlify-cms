import SpriteKit

enum CharacterType: String, CaseIterable, Identifiable {
    case rustyRon = "Rusty Ron"
    case bagLadyBetty = "Bag Lady Betty"
    case couponCarl = "Coupon Carl"
    case canCollectorClyde = "Can Collector Clyde"

    var id: String { rawValue }

    var tagline: String {
        switch self {
        case .rustyRon: return "Fastest wheels in the parking lot"
        case .bagLadyBetty: return "Never drops a bag"
        case .couponCarl: return "Discount drift master"
        case .canCollectorClyde: return "Recycles the competition"
        }
    }

    var cartColor: SKColor {
        switch self {
        case .rustyRon: return SKColor(red: 0.55, green: 0.35, blue: 0.20, alpha: 1)
        case .bagLadyBetty: return SKColor(red: 0.75, green: 0.20, blue: 0.45, alpha: 1)
        case .couponCarl: return SKColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1)
        case .canCollectorClyde: return SKColor(red: 0.30, green: 0.70, blue: 0.35, alpha: 1)
        }
    }

    var shirtColor: SKColor {
        switch self {
        case .rustyRon: return SKColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 1)
        case .bagLadyBetty: return SKColor(red: 0.55, green: 0.25, blue: 0.55, alpha: 1)
        case .couponCarl: return SKColor(red: 0.90, green: 0.85, blue: 0.20, alpha: 1)
        case .canCollectorClyde: return SKColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1)
        }
    }

    var speed: CGFloat { 220 }
    var acceleration: CGFloat { 480 }
    var handling: CGFloat { 3.2 }
    var weight: CGFloat { 1.0 }
}
