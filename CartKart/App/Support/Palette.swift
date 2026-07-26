import CartKartCore
import SpriteKit
import SwiftUI

/// Bridges the renderer-agnostic colours in `CartKartCore` to UIKit/SwiftUI.
extension TrackTheme.RGB {
    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    var color: Color { Color(uiColor) }

    /// Same hue, scaled brightness. Values above 1 lighten towards white.
    func shaded(_ factor: Double) -> UIColor {
        if factor <= 1 {
            return UIColor(
                red: CGFloat(red * factor),
                green: CGFloat(green * factor),
                blue: CGFloat(blue * factor),
                alpha: 1
            )
        }
        let t = min(factor - 1, 1)
        return UIColor(
            red: CGFloat(red + (1 - red) * t),
            green: CGFloat(green + (1 - green) * t),
            blue: CGFloat(blue + (1 - blue) * t),
            alpha: 1
        )
    }
}

/// Shared look and feel for the menus.
enum Palette {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.12)
    static let panel = Color(red: 0.13, green: 0.14, blue: 0.20)
    static let panelBorder = Color.white.opacity(0.12)
    static let primary = Color(red: 0.98, green: 0.74, blue: 0.16)
    static let secondary = Color(red: 0.32, green: 0.78, blue: 0.92)
    static let danger = Color(red: 0.95, green: 0.35, blue: 0.42)
    static let text = Color.white
    static let subtleText = Color.white.opacity(0.65)

    static let storeGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.11, blue: 0.18), Color(red: 0.05, green: 0.06, blue: 0.10)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Font {
    /// Chunky arcade lettering for headings and the HUD.
    static func arcade(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func arcadeBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

extension Vec2 {
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

extension CGPoint {
    var vec2: Vec2 { Vec2(Double(x), Double(y)) }
}
