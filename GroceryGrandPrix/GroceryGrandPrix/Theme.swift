import CoreGraphics
import SpriteKit
import SwiftUI
import UIKit

// MARK: - Physics categories

enum PhysicsCategory {
    static let none: UInt32       = 0
    static let cart: UInt32       = 0x1 << 0
    static let wall: UInt32       = 0x1 << 1
    static let shelf: UInt32      = 0x1 << 2
    static let itemBox: UInt32    = 0x1 << 3
    static let hazard: UInt32     = 0x1 << 4
    static let projectile: UInt32 = 0x1 << 5
}

// MARK: - Palette

enum Palette {
    // SpriteKit colors
    static let floor        = SKColor(red: 0.86, green: 0.83, blue: 0.74, alpha: 1)
    static let floorTile    = SKColor(red: 0.90, green: 0.87, blue: 0.79, alpha: 1)
    static let road         = SKColor(red: 0.55, green: 0.57, blue: 0.60, alpha: 1)
    static let roadLine     = SKColor(red: 0.95, green: 0.85, blue: 0.30, alpha: 0.9)
    static let wall         = SKColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1)
    static let shelf        = SKColor(red: 0.30, green: 0.45, blue: 0.55, alpha: 1)
    static let shelfTop     = SKColor(red: 0.40, green: 0.58, blue: 0.68, alpha: 1)

    // Cart body colors
    static let cartColors: [SKColor] = [
        SKColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1), // red (player)
        SKColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1), // blue
        SKColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1), // green
        SKColor(red: 1.00, green: 0.76, blue: 0.03, alpha: 1)  // amber
    ]
}

// SwiftUI colors
extension Color {
    static let ggpAccent = Color(red: 1.0, green: 0.78, blue: 0.2)
    static let ggpDark = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let ggpPanel = Color(red: 0.12, green: 0.15, blue: 0.20)
}

// MARK: - Geometry helpers

extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (l: CGPoint, r: CGFloat) -> CGPoint { CGPoint(x: l.x * r, y: l.y * r) }

    func distance(to p: CGPoint) -> CGFloat { hypot(p.x - x, p.y - y) }
    var length: CGFloat { hypot(x, y) }
    var angle: CGFloat { atan2(y, x) }
    var normalized: CGPoint {
        let len = length
        return len == 0 ? .zero : CGPoint(x: x / len, y: y / len)
    }
    func dot(_ p: CGPoint) -> CGFloat { x * p.x + y * p.y }
}

/// Returns the signed shortest angular difference (in radians) to rotate from `a` to `b`.
func shortestAngleDelta(from a: CGFloat, to b: CGFloat) -> CGFloat {
    var diff = (b - a).truncatingRemainder(dividingBy: .pi * 2)
    if diff < -.pi { diff += .pi * 2 }
    if diff > .pi { diff -= .pi * 2 }
    return diff
}

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    min(max(v, lo), hi)
}

// MARK: - Haptics

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
