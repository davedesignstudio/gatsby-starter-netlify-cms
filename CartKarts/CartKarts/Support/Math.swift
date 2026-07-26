import CoreGraphics
import Foundation

// MARK: - Physics categories

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let kart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let itemBox: UInt32 = 1 << 2
    static let banana: UInt32 = 1 << 3
    static let can: UInt32 = 1 << 4
    static let puddle: UInt32 = 1 << 5
}

// MARK: - Scalar helpers

func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    return min(max(value, lower), upper)
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    return a + (b - a) * t
}

/// Shortest signed angular difference from `a` to `b`, in (-pi, pi].
func angleDelta(from a: CGFloat, to b: CGFloat) -> CGFloat {
    var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return d
}

// MARK: - CGPoint / CGVector helpers

extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }

    var length: CGFloat { sqrt(x * x + y * y) }

    var normalized: CGPoint {
        let len = length
        guard len > 0.0001 else { return .zero }
        return CGPoint(x: x / len, y: y / len)
    }

    func dot(_ other: CGPoint) -> CGFloat { x * other.x + y * other.y }

    func distance(to other: CGPoint) -> CGFloat { (self - other).length }

    /// Angle of the vector in radians (atan2 convention).
    var angle: CGFloat { atan2(y, x) }
}

extension CGVector {
    init(point: CGPoint) { self.init(dx: point.x, dy: point.y) }
    var point: CGPoint { CGPoint(x: dx, y: dy) }
}

/// Unit vector pointing in the given angle (atan2 convention).
func unitVector(angle: CGFloat) -> CGPoint {
    CGPoint(x: cos(angle), y: sin(angle))
}

// MARK: - Deterministic RNG (SplitMix64)

/// Small seeded RNG so procedural art is stable between launches.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform CGFloat in [0, 1).
    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(1 << 53)
    }

    mutating func range(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        lower + unit() * (upper - lower)
    }

    mutating func int(_ upper: Int) -> Int {
        upper <= 0 ? 0 : Int(next() % UInt64(upper))
    }
}
