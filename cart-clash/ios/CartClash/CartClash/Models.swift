import SwiftUI

struct CartDef: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let color: Color
    let accent: Color
    let speed: CGFloat
    let accel: CGFloat
    let handling: CGFloat

    static let roster: [CartDef] = [
        CartDef(id: "rustbucket", name: "Rustbucket", blurb: "Wonky wheel. Pure spite.",
                color: Color(red: 0.72, green: 0.36, blue: 0.22),
                accent: Color(red: 0.35, green: 0.16, blue: 0.09),
                speed: 0.96, accel: 1.08, handling: 1.12),
        CartDef(id: "couponqueen", name: "Coupon Queen", blurb: "Clipped every deal. Still broke.",
                color: Color(red: 0.85, green: 0.64, blue: 0.25),
                accent: Color(red: 0.48, green: 0.33, blue: 0.08),
                speed: 1.0, accel: 1.0, handling: 1.05),
        CartDef(id: "freezerburn", name: "Freezer Burn", blurb: "Cold chrome. Hot temper.",
                color: Color(red: 0.43, green: 0.77, blue: 0.78),
                accent: Color(red: 0.14, green: 0.34, blue: 0.35),
                speed: 1.08, accel: 0.92, handling: 0.90),
        CartDef(id: "aisleghost", name: "Aisle Ghost", blurb: "Never paid. Never caught.",
                color: Color(red: 0.60, green: 0.65, blue: 0.69),
                accent: Color(red: 0.24, green: 0.27, blue: 0.30),
                speed: 1.02, accel: 1.02, handling: 1.0),
    ]
}

struct RaceResult: Identifiable {
    var id: String { "\(place)-\(name)" }
    let place: Int
    let name: String
    let isPlayer: Bool
    let finished: Bool
    let time: TimeInterval

    var placeSuffix: String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }
}

enum ItemType: String, CaseIterable {
    case banana, soda, pricegun, coupon

    var label: String {
        switch self {
        case .banana: return "BANANA"
        case .soda: return "SODA"
        case .pricegun: return "ZAP"
        case .coupon: return "SHIELD"
        }
    }
}
