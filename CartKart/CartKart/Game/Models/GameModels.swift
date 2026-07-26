import UIKit
import SpriteKit

enum PowerUpKind: String, CaseIterable {
    case banana
    case sodaBoost
    case cannedGoods
    case shoppingBag
    case wetFloor

    var displayName: String {
        switch self {
        case .banana: return "Banana Peel"
        case .sodaBoost: return "Soda Boost"
        case .cannedGoods: return "Canned Goods"
        case .shoppingBag: return "Shopping Bag"
        case .wetFloor: return "Wet Floor"
        }
    }

    var emoji: String {
        switch self {
        case .banana: return "🍌"
        case .sodaBoost: return "🥤"
        case .cannedGoods: return "🥫"
        case .shoppingBag: return "🛍️"
        case .wetFloor: return "⚠️"
        }
    }

    var tint: UIColor {
        switch self {
        case .banana: return UIColor(red: 0.95, green: 0.82, blue: 0.20, alpha: 1)
        case .sodaBoost: return UIColor(red: 0.20, green: 0.75, blue: 0.95, alpha: 1)
        case .cannedGoods: return UIColor(red: 0.85, green: 0.35, blue: 0.25, alpha: 1)
        case .shoppingBag: return UIColor(red: 0.45, green: 0.75, blue: 0.40, alpha: 1)
        case .wetFloor: return UIColor(red: 0.95, green: 0.70, blue: 0.15, alpha: 1)
        }
    }
}

struct RacerProfile {
    let id: String
    let name: String
    let cartColor: UIColor
    let accentColor: UIColor
    let topSpeed: CGFloat
    let handling: CGFloat
    let acceleration: CGFloat
    let isPlayer: Bool

    static let roster: [RacerProfile] = [
        RacerProfile(
            id: "rusty",
            name: "Rusty",
            cartColor: UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1),
            accentColor: UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1),
            topSpeed: 420,
            handling: 3.2,
            acceleration: 280,
            isPlayer: true
        ),
        RacerProfile(
            id: "tinny",
            name: "Tinny",
            cartColor: UIColor(red: 0.72, green: 0.45, blue: 0.28, alpha: 1),
            accentColor: UIColor(red: 0.30, green: 0.70, blue: 0.95, alpha: 1),
            topSpeed: 400,
            handling: 3.6,
            acceleration: 300,
            isPlayer: false
        ),
        RacerProfile(
            id: "squeaky",
            name: "Squeaky",
            cartColor: UIColor(red: 0.35, green: 0.55, blue: 0.45, alpha: 1),
            accentColor: UIColor(red: 0.95, green: 0.85, blue: 0.25, alpha: 1),
            topSpeed: 390,
            handling: 3.8,
            acceleration: 320,
            isPlayer: false
        ),
        RacerProfile(
            id: "dumpster",
            name: "Dumpster",
            cartColor: UIColor(red: 0.40, green: 0.35, blue: 0.50, alpha: 1),
            accentColor: UIColor(red: 0.90, green: 0.30, blue: 0.45, alpha: 1),
            topSpeed: 440,
            handling: 2.8,
            acceleration: 250,
            isPlayer: false
        )
    ]
}

enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let itemBox: UInt32 = 1 << 2
    static let hazard: UInt32 = 1 << 3
    static let projectile: UInt32 = 1 << 4
    static let checkpoint: UInt32 = 1 << 5
}

enum RaceState {
    case countdown
    case racing
    case finished
}
