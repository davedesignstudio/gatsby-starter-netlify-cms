import Foundation

/// Minimal 2D vector. All world units are metres, all angles radians.
public struct Vector2: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2(0, 0)

    public static func angled(_ radians: Double, length: Double = 1) -> Vector2 {
        Vector2(cos(radians) * length, sin(radians) * length)
    }

    public var length: Double { (x * x + y * y).squareRoot() }
    public var lengthSquared: Double { x * x + y * y }
    public var angle: Double { atan2(y, x) }

    /// Rotated a quarter turn counter-clockwise.
    public var perpendicular: Vector2 { Vector2(-y, x) }

    public var normalized: Vector2 {
        let len = length
        guard len > 1e-9 else { return .zero }
        return Vector2(x / len, y / len)
    }

    public func dot(_ other: Vector2) -> Double { x * other.x + y * other.y }

    /// Z component of the 3D cross product; positive when `other` is to the left.
    public func cross(_ other: Vector2) -> Double { x * other.y - y * other.x }

    public func distance(to other: Vector2) -> Double { (self - other).length }

    public func rotated(by radians: Double) -> Vector2 {
        let c = cos(radians), s = sin(radians)
        return Vector2(x * c - y * s, x * s + y * c)
    }

    public func limited(to maxLength: Double) -> Vector2 {
        let len = length
        guard len > maxLength, len > 1e-9 else { return self }
        return self * (maxLength / len)
    }

    public static func + (a: Vector2, b: Vector2) -> Vector2 { Vector2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vector2, b: Vector2) -> Vector2 { Vector2(a.x - b.x, a.y - b.y) }
    public static func * (v: Vector2, s: Double) -> Vector2 { Vector2(v.x * s, v.y * s) }
    public static func * (s: Double, v: Vector2) -> Vector2 { v * s }
    public static func / (v: Vector2, s: Double) -> Vector2 { Vector2(v.x / s, v.y / s) }
    public static prefix func - (v: Vector2) -> Vector2 { Vector2(-v.x, -v.y) }
    public static func += (a: inout Vector2, b: Vector2) { a = a + b }
    public static func -= (a: inout Vector2, b: Vector2) { a = a - b }
    public static func *= (v: inout Vector2, s: Double) { v = v * s }

    public static func lerp(_ a: Vector2, _ b: Vector2, _ t: Double) -> Vector2 {
        a + (b - a) * t
    }
}

public enum Angle {
    /// Wraps an angle into (-pi, pi].
    public static func normalize(_ radians: Double) -> Double {
        var a = radians.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a <= -.pi { a += 2 * .pi }
        return a
    }

    /// Shortest signed rotation that takes `from` to `to`.
    public static func delta(from: Double, to: Double) -> Double {
        normalize(to - from)
    }

    /// Rotates `from` towards `to` by at most `maxStep`.
    public static func rotate(_ from: Double, towards to: Double, maxStep: Double) -> Double {
        let d = delta(from: from, to: to)
        if abs(d) <= maxStep { return normalize(to) }
        return normalize(from + (d < 0 ? -maxStep : maxStep))
    }
}

@inlinable
public func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

/// Frame-rate independent exponential smoothing.
/// `rate` is the fraction of the remaining gap closed per second.
@inlinable
public func damp(_ current: Double, _ target: Double, rate: Double, dt: Double) -> Double {
    let t = 1 - exp(-rate * dt)
    return current + (target - current) * t
}
