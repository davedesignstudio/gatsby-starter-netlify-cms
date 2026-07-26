import SpriteKit
import UIKit

enum CartArchetype: String, CaseIterable {
    case rusty = "Rusty"
    case speedy = "Speedy"
    case jumbo = "Jumbo"
    case zigzag = "Zigzag"
    case glitter = "Glitter"

    var displayName: String { rawValue }

    var tagline: String {
        switch self {
        case .rusty: return "Squeaky wheels, big heart"
        case .speedy: return "Stolen from express lane"
        case .jumbo: return "Built for bulk hauls"
        case .zigzag: return "Never walks a straight aisle"
        case .glitter: return "Cart with main-character energy"
        }
    }

    var accent: UIColor {
        switch self {
        case .rusty: return UIColor(red: 0.72, green: 0.38, blue: 0.18, alpha: 1)
        case .speedy: return UIColor(red: 0.15, green: 0.55, blue: 0.85, alpha: 1)
        case .jumbo: return UIColor(red: 0.25, green: 0.62, blue: 0.28, alpha: 1)
        case .zigzag: return UIColor(red: 0.85, green: 0.55, blue: 0.12, alpha: 1)
        case .glitter: return UIColor(red: 0.78, green: 0.22, blue: 0.42, alpha: 1)
        }
    }

    var topSpeed: CGFloat {
        switch self {
        case .rusty: return 4.6
        case .speedy: return 5.4
        case .jumbo: return 4.2
        case .zigzag: return 4.9
        case .glitter: return 5.0
        }
    }

    var acceleration: CGFloat {
        switch self {
        case .rusty: return 0.055
        case .speedy: return 0.08
        case .jumbo: return 0.04
        case .zigzag: return 0.065
        case .glitter: return 0.07
        }
    }

    var handling: CGFloat {
        switch self {
        case .rusty: return 0.065
        case .speedy: return 0.05
        case .jumbo: return 0.045
        case .zigzag: return 0.09
        case .glitter: return 0.06
        }
    }
}

enum PowerUpKind: CaseIterable {
    case banana
    case sodaBoost
    case soupCan
    case couponShield
    case spill

    var label: String {
        switch self {
        case .banana: return "BANANA"
        case .sodaBoost: return "SODA"
        case .soupCan: return "SOUP"
        case .couponShield: return "COUPON"
        case .spill: return "SPILL"
        }
    }

    var color: UIColor {
        switch self {
        case .banana: return .systemYellow
        case .sodaBoost: return .systemRed
        case .soupCan: return .systemOrange
        case .couponShield: return .systemTeal
        case .spill: return .systemPurple
        }
    }
}

final class CartRacer {
    let id: Int
    let archetype: CartArchetype
    let isPlayer: Bool
    var progress: CGFloat = 0
    var lateral: CGFloat = 0
    var speed: CGFloat = 0
    var lap: Int = 1
    var finished: Bool = false
    var finishPlace: Int?
    var stunTimer: TimeInterval = 0
    var boostTimer: TimeInterval = 0
    var shieldTimer: TimeInterval = 0
    var heldPowerUp: PowerUpKind?
    var aiSteerBias: CGFloat = 0
    var aiDecisionTimer: TimeInterval = 0

    init(id: Int, archetype: CartArchetype, isPlayer: Bool, startProgress: CGFloat) {
        self.id = id
        self.archetype = archetype
        self.isPlayer = isPlayer
        self.progress = startProgress
        self.lateral = CGFloat.random(in: -0.25...0.25)
        if !isPlayer {
            aiSteerBias = CGFloat.random(in: -0.3...0.3)
        }
    }

    var effectiveTopSpeed: CGFloat {
        let boost = boostTimer > 0 ? 1.45 : 1.0
        return archetype.topSpeed * boost
    }

    var effectiveAccel: CGFloat {
        let boost = boostTimer > 0 ? 1.6 : 1.0
        return archetype.acceleration * boost
    }
}
