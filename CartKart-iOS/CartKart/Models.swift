// Models.swift — carts, items, shared types
import SwiftUI

struct CartDef: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let color: Color
    let accent: Color
    let basket: Color
    let maxSpeed: CGFloat
    let accel: CGFloat
    let turn: CGFloat
    let grip: CGFloat
}

enum CartCatalog {
    static let all: [CartDef] = [
        CartDef(id: "rusty", name: "Rusty", blurb: "Veteran cart. Sticky wheels, big heart.",
                color: Color(red: 0.77, green: 0.36, blue: 0.15), accent: Color(red: 0.55, green: 0.23, blue: 0.07),
                basket: Color(red: 0.60, green: 0.65, blue: 0.69), maxSpeed: 220, accel: 140, turn: 2.6, grip: 0.92),
        CartDef(id: "squeaky", name: "Squeaky", blurb: "Loudest wheels in aisle 7.",
                color: Color(red: 0.17, green: 0.70, blue: 1.0), accent: Color(red: 0.09, green: 0.47, blue: 0.66),
                basket: Color(red: 0.86, green: 0.91, blue: 0.94), maxSpeed: 210, accel: 160, turn: 3.0, grip: 0.88),
        CartDef(id: "neon", name: "Neon", blurb: "Escaped the electronics wing.",
                color: Color(red: 0.71, green: 0.30, blue: 1.0), accent: Color(red: 0.43, green: 0.12, blue: 0.66),
                basket: Color(red: 0.91, green: 0.84, blue: 1.0), maxSpeed: 235, accel: 130, turn: 2.7, grip: 0.90),
        CartDef(id: "basket", name: "Basket Case", blurb: "Handheld energy. Tiny, snappy.",
                color: Color(red: 0.43, green: 0.75, blue: 0.29), accent: Color(red: 0.24, green: 0.48, blue: 0.16),
                basket: Color(red: 0.83, green: 0.94, blue: 0.78), maxSpeed: 200, accel: 175, turn: 3.3, grip: 0.94),
        CartDef(id: "graffiti", name: "Rolling Stone", blurb: "Tagged up. Drifts like gossip.",
                color: Color(red: 0.91, green: 0.27, blue: 0.18), accent: Color(red: 0.60, green: 0.14, blue: 0.09),
                basket: Color(red: 0.96, green: 0.77, blue: 0.74), maxSpeed: 225, accel: 145, turn: 2.8, grip: 0.84),
        CartDef(id: "coupon", name: "Coupon Queen", blurb: "Clipped deals. Clips corners.",
                color: Color(red: 0.94, green: 0.77, blue: 0.10), accent: Color(red: 0.72, green: 0.57, blue: 0.04),
                basket: Color(red: 1.0, green: 0.96, blue: 0.82), maxSpeed: 215, accel: 150, turn: 3.1, grip: 0.91),
    ]
}

enum ItemKind: String, CaseIterable {
    case banana, soda, can, milk, bag

    var icon: String {
        switch self {
        case .banana: return "🍌"
        case .soda: return "🥤"
        case .can: return "🥫"
        case .milk: return "🥛"
        case .bag: return "🛍️"
        }
    }
}
