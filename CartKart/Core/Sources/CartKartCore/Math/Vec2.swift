import Foundation

/// Minimal 2D vector used across the simulation.
///
/// The core simulation deliberately avoids CoreGraphics so it can be compiled
/// and unit tested on any platform, including Linux CI.
public struct Vec2: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double = 0, _ y: Double = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    /// Unit vector pointing at `angle` radians (0 = +x, counter-clockwise).
    public static func direction(_ angle: Double) -> Vec2 {
        Vec2(cos(angle), sin(angle))
    }

    public var lengthSquared: Double { x * x + y * y }
    public var length: Double { lengthSquared.squareRoot() }
    public var angle: Double { atan2(y, x) }

    /// Rotated 90° counter-clockwise.
    public var perpendicular: Vec2 { Vec2(-y, x) }

    public var normalized: Vec2 {
        let len = length
        guard len > 1e-9 else { return .zero }
        return Vec2(x / len, y / len)
    }

    public func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    /// 2D analogue of the cross product; positive when `other` is counter-clockwise from `self`.
    public func cross(_ other: Vec2) -> Double { x * other.y - y * other.x }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    public func rotated(by angle: Double) -> Vec2 {
        let c = cos(angle)
        let s = sin(angle)
        return Vec2(x * c - y * s, x * s + y * c)
    }

    /// Shortens the vector to `maxLength` without changing its direction.
    public func clampedMagnitude(_ maxLength: Double) -> Vec2 {
        let len = length
        guard len > maxLength, len > 1e-9 else { return self }
        return self * (maxLength / len)
    }

    public static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x + rhs.x, lhs.y + rhs.y) }
    public static func - (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x - rhs.x, lhs.y - rhs.y) }
    public static func * (lhs: Vec2, rhs: Double) -> Vec2 { Vec2(lhs.x * rhs, lhs.y * rhs) }
    public static func * (lhs: Double, rhs: Vec2) -> Vec2 { rhs * lhs }
    public static func / (lhs: Vec2, rhs: Double) -> Vec2 { Vec2(lhs.x / rhs, lhs.y / rhs) }
    public static prefix func - (v: Vec2) -> Vec2 { Vec2(-v.x, -v.y) }
    public static func += (lhs: inout Vec2, rhs: Vec2) { lhs = lhs + rhs }
    public static func -= (lhs: inout Vec2, rhs: Vec2) { lhs = lhs - rhs }
    public static func *= (lhs: inout Vec2, rhs: Double) { lhs = lhs * rhs }
}

public enum Angle {
    /// Wraps an angle into (-pi, pi].
    public static func normalize(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a <= -.pi { a += 2 * .pi }
        return a
    }

    /// Shortest signed rotation that takes `from` to `to`.
    public static func delta(from: Double, to: Double) -> Double {
        normalize(to - from)
    }

    /// Rotates `from` towards `to` by at most `maxStep` radians.
    public static func rotate(_ from: Double, towards to: Double, maxStep: Double) -> Double {
        let d = delta(from: from, to: to)
        if abs(d) <= maxStep { return normalize(to) }
        return normalize(from + (d < 0 ? -maxStep : maxStep))
    }
}

@inlinable
public func clamp<T: Comparable>(_ value: T, _ minimum: T, _ maximum: T) -> T {
    min(max(value, minimum), maximum)
}

@inlinable
public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * clamp(t, 0, 1)
}

/// Frame-rate independent exponential approach, used for smoothing.
@inlinable
public func approach(_ current: Double, _ target: Double, rate: Double, dt: Double) -> Double {
    let t = 1 - exp(-rate * dt)
    return current + (target - current) * t
}
