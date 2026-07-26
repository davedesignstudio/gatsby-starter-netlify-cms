import CoreGraphics

/// Lightweight vector / angle helpers used across the game.
/// SpriteKit does not ship most of these, so we keep them small and dependency-free.

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scalar, y: point.y * scalar)
    }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : .zero
    }

    func distance(to other: CGPoint) -> CGFloat {
        (self - other).length
    }

    /// Angle in radians pointing from this point toward `other`.
    func angle(to other: CGPoint) -> CGFloat {
        atan2(other.y - y, other.x - x)
    }
}

/// Wrap an angle to the range (-pi, pi]. Keeps steering math stable.
func normalizeAngle(_ angle: CGFloat) -> CGFloat {
    var a = angle
    while a > .pi { a -= 2 * .pi }
    while a <= -.pi { a += 2 * .pi }
    return a
}

/// Linear interpolation.
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    min(max(value, minValue), maxValue)
}

/// Shortest angular distance to rotate from `from` to `to`.
func shortestAngleDelta(from: CGFloat, to: CGFloat) -> CGFloat {
    normalizeAngle(to - from)
}
