import SwiftUI

struct RacerDef: Identifiable {
    let id: String
    let name: String
    let color: Color
    let accent: Color
    let speed: CGFloat
    let accel: CGFloat
    let handling: CGFloat
    let blurb: String
}

enum RacerRoster {
    static let all: [RacerDef] = [
        RacerDef(id: "rusty", name: "Rusty Rick", color: Color(red: 0.77, green: 0.36, blue: 0.15), accent: Color(red: 0.94, green: 0.76, blue: 0.48), speed: 1.0, accel: 1.05, handling: 0.95, blurb: "Beater cart, sticky wheels"),
        RacerDef(id: "dana", name: "Dumpster Dana", color: Color(red: 0.18, green: 0.42, blue: 0.31), accent: Color(red: 0.58, green: 0.84, blue: 0.70), speed: 0.95, accel: 1.10, handling: 1.10, blurb: "Tight turns, alley-trained"),
        RacerDef(id: "ace", name: "Alley Ace", color: Color(red: 0.11, green: 0.21, blue: 0.34), accent: Color(red: 0.66, green: 0.85, blue: 0.86), speed: 1.10, accel: 0.95, handling: 0.90, blurb: "Built for straightaways"),
        RacerDef(id: "king", name: "Cart King", color: Color(red: 0.42, green: 0.02, blue: 0.45), accent: Color(red: 0.88, green: 0.67, blue: 1.0), speed: 1.02, accel: 1.0, handling: 1.0, blurb: "Balanced aisle legend")
    ]
}

enum RacePhase {
    case title
    case select
    case howTo
    case countdown
    case racing
    case results
}

enum PowerUp: String, CaseIterable {
    case boost, banana, soup, gum

    var icon: String {
        switch self {
        case .boost: return "⚡"
        case .banana: return "🍌"
        case .soup: return "🥫"
        case .gum: return "🫧"
        }
    }
}
