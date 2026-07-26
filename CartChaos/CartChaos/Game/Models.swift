import SpriteKit
import UIKit

enum PowerUpKind: String, CaseIterable {
    case banana
    case soda
    case soup
    case coupon

    var displayName: String {
        switch self {
        case .banana: return "BANANA"
        case .soda: return "SODA"
        case .soup: return "SOUP"
        case .coupon: return "COUPON"
        }
    }

    var color: UIColor {
        switch self {
        case .banana: return UIColor(red: 0.95, green: 0.82, blue: 0.20, alpha: 1)
        case .soda: return UIColor(red: 0.15, green: 0.72, blue: 0.45, alpha: 1)
        case .soup: return UIColor(red: 0.85, green: 0.35, blue: 0.20, alpha: 1)
        case .coupon: return UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1)
        }
    }

    var tip: String {
        switch self {
        case .banana: return "Drop a peel behind you"
        case .soda: return "Speed boost!"
        case .soup: return "Fire a can ahead"
        case .coupon: return "Brief shield"
        }
    }
}

struct CartProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let motto: String
    let bodyColor: UIColor
    let accentColor: UIColor
    let speed: CGFloat
    let handling: CGFloat
    let weight: CGFloat

    static let roster: [CartProfile] = [
        CartProfile(
            id: "rusty",
            name: "Rusty Rex",
            motto: "Squeaky but speedy",
            bodyColor: UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1),
            accentColor: UIColor(red: 0.85, green: 0.45, blue: 0.20, alpha: 1),
            speed: 1.05, handling: 0.95, weight: 1.0
        ),
        CartProfile(
            id: "coupon",
            name: "Coupon Queen",
            motto: "Cuts every corner",
            bodyColor: UIColor(red: 0.90, green: 0.35, blue: 0.55, alpha: 1),
            accentColor: UIColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1),
            speed: 0.95, handling: 1.15, weight: 0.9
        ),
        CartProfile(
            id: "dumpster",
            name: "Dumpster Dan",
            motto: "Built like a brick",
            bodyColor: UIColor(red: 0.35, green: 0.55, blue: 0.40, alpha: 1),
            accentColor: UIColor(red: 0.70, green: 0.55, blue: 0.30, alpha: 1),
            speed: 0.90, handling: 0.85, weight: 1.25
        ),
        CartProfile(
            id: "aisle",
            name: "Aisle Ace",
            motto: "Knows every shortcut",
            bodyColor: UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1),
            accentColor: UIColor(red: 0.40, green: 0.90, blue: 0.95, alpha: 1),
            speed: 1.0, handling: 1.05, weight: 1.0
        ),
        CartProfile(
            id: "midnight",
            name: "Midnight Mick",
            motto: "Races after closing",
            bodyColor: UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
            accentColor: UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1),
            speed: 1.10, handling: 0.90, weight: 0.95
        ),
        CartProfile(
            id: "bag",
            name: "Bag Lady",
            motto: "Plastic and proud",
            bodyColor: UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1),
            accentColor: UIColor(red: 0.20, green: 0.65, blue: 0.55, alpha: 1),
            speed: 1.0, handling: 1.10, weight: 0.85
        )
    ]
}

enum RaceConfig {
    static let totalLaps = 3
    static let racerCount = 4
    static let baseMaxSpeed: CGFloat = 420
    static let boostMultiplier: CGFloat = 1.45
    static let spinDuration: TimeInterval = 1.2
    static let shieldDuration: TimeInterval = 2.5
    static let boostDuration: TimeInterval = 1.6
}

final class RaceSession {
    static var shared = RaceSession()
    var selectedCart: CartProfile = CartProfile.roster[0]
    var finishingOrder: [String] = []
    var playerFinishPosition: Int = 0
}
