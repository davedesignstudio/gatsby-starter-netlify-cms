import SpriteKit

enum PowerUp: String, CaseIterable {
    case banana, soda, soap, can

    var emoji: String {
        switch self {
        case .banana: return "🍌"
        case .soda: return "🥤"
        case .soap: return "🧼"
        case .can: return "🥫"
        }
    }
}

struct CartBuild: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let color: SKColor
    let accent: SKColor
    let topSpeed: CGFloat
    let accel: CGFloat
    let turn: CGFloat
    let grip: CGFloat

    static let all: [CartBuild] = [
        CartBuild(
            id: "rusty",
            name: "Rusty",
            blurb: "Abandoned by produce. Slow start, tough frame.",
            color: SKColor(red: 0.77, green: 0.36, blue: 0.15, alpha: 1),
            accent: SKColor(red: 0.42, green: 0.23, blue: 0.12, alpha: 1),
            topSpeed: 280, accel: 210, turn: 2.55, grip: 0.9
        ),
        CartBuild(
            id: "squeaky",
            name: "Squeaky",
            blurb: "Wheels scream. Turns like a shopping list on fire.",
            color: SKColor(red: 0.24, green: 0.49, blue: 0.65, alpha: 1),
            accent: SKColor(red: 0.12, green: 0.25, blue: 0.33, alpha: 1),
            topSpeed: 265, accel: 230, turn: 3.2, grip: 1.05
        ),
        CartBuild(
            id: "bent",
            name: "Bent Frame",
            blurb: "Survived the parking lot. Tanky bumper.",
            color: SKColor(red: 0.35, green: 0.42, blue: 0.36, alpha: 1),
            accent: SKColor(red: 0.18, green: 0.22, blue: 0.19, alpha: 1),
            topSpeed: 255, accel: 200, turn: 2.35, grip: 1.15
        ),
        CartBuild(
            id: "express",
            name: "Express Lane",
            blurb: "Stolen from checkout. Pure aisle velocity.",
            color: SKColor(red: 0.91, green: 0.36, blue: 0.02, alpha: 1),
            accent: SKColor(red: 0.48, green: 0.18, blue: 0.02, alpha: 1),
            topSpeed: 310, accel: 250, turn: 2.4, grip: 0.82
        ),
    ]
}

struct RaceResult: Identifiable {
    let id = UUID()
    let place: Int
    let name: String
    let isPlayer: Bool
}
