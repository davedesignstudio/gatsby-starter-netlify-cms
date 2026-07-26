import SpriteKit
import UIKit

enum RaceConfig {
    static let lapCount = 3
    static let racerCount = 4
    static let maxSpeed: CGFloat = 420
    static let acceleration: CGFloat = 520
    static let brakeForce: CGFloat = 680
    static let turnSpeed: CGFloat = 2.8
    static let driftBoostWindow: TimeInterval = 0.45
    static let itemCooldown: TimeInterval = 0.8
}

struct RacerProfile: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let cartColor: UIColor
    let accentColor: UIColor
    let speed: CGFloat
    let handling: CGFloat
    let cargo: String

    static let roster: [RacerProfile] = [
        RacerProfile(
            id: "terry",
            name: "Tin Can Terry",
            tagline: "Aluminum rocket. Zero brakes.",
            cartColor: UIColor(red: 0.72, green: 0.78, blue: 0.84, alpha: 1),
            accentColor: UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1),
            speed: 1.08,
            handling: 0.92,
            cargo: "🥫"
        ),
        RacerProfile(
            id: "betty",
            name: "Blanket Betty",
            tagline: "Cozy corners. Killer drifts.",
            cartColor: UIColor(red: 0.45, green: 0.62, blue: 0.95, alpha: 1),
            accentColor: UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1),
            speed: 0.95,
            handling: 1.15,
            cargo: "🧣"
        ),
        RacerProfile(
            id: "bill",
            name: "Bottle Cap Bill",
            tagline: "Clinks when he wins.",
            cartColor: UIColor(red: 0.35, green: 0.75, blue: 0.48, alpha: 1),
            accentColor: UIColor(red: 0.98, green: 0.82, blue: 0.18, alpha: 1),
            speed: 1.0,
            handling: 1.0,
            cargo: "🍾"
        ),
        RacerProfile(
            id: "daisy",
            name: "Dumpster Daisy",
            tagline: "Finds boosts in the trash.",
            cartColor: UIColor(red: 0.85, green: 0.42, blue: 0.28, alpha: 1),
            accentColor: UIColor(red: 0.55, green: 0.85, blue: 0.35, alpha: 1),
            speed: 1.05,
            handling: 0.98,
            cargo: "🗑️"
        ),
        RacerProfile(
            id: "carl",
            name: "Can Collector Carl",
            tagline: "Stack height equals horsepower.",
            cartColor: UIColor(red: 0.55, green: 0.40, blue: 0.75, alpha: 1),
            accentColor: UIColor(red: 0.25, green: 0.85, blue: 0.90, alpha: 1),
            speed: 1.12,
            handling: 0.88,
            cargo: "📦"
        ),
        RacerProfile(
            id: "sam",
            name: "Shopping Bag Sam",
            tagline: "Plastic wings, paper dreams.",
            cartColor: UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1),
            accentColor: UIColor(red: 0.20, green: 0.35, blue: 0.55, alpha: 1),
            speed: 0.98,
            handling: 1.08,
            cargo: "🛍️"
        )
    ]
}

enum PowerUpType: CaseIterable {
    case banana
    case sodaSplash
    case beanTurbo
    case shoppingBag
    case shoppingList

    var label: String {
        switch self {
        case .banana: return "🍌"
        case .sodaSplash: return "🥤"
        case .beanTurbo: return "🫘"
        case .shoppingBag: return "🛡️"
        case .shoppingList: return "📋"
        }
    }

    var name: String {
        switch self {
        case .banana: return "Banana Peel"
        case .sodaSplash: return "Soda Splash"
        case .beanTurbo: return "Bean Turbo"
        case .shoppingBag: return "Bag Shield"
        case .shoppingList: return "Homing List"
        }
    }
}

struct RaceResult {
    let place: Int
    let profile: RacerProfile
    let isPlayer: Bool
    let finishTime: TimeInterval
}
