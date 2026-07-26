import Foundation

/// Plain 2D vector used throughout the simulation. The world is measured in
/// metres with +x pointing towards the deli counter and +y towards the tills.
public struct Vector2: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

    public static let zero = Vector2(0, 0)

    /// Unit vector pointing along `angle` radians.
    public init(angle: Double, length: Double = 1) {
        self.init(cos(angle) * length, sin(angle) * length)
    }

    public var lengthSquared: Double { x * x + y * y }
    public var length: Double { (x * x + y * y).squareRoot() }
    public var angle: Double { atan2(y, x) }

    public var normalized: Vector2 {
        let len = length
        guard len > 1e-9 else { return .zero }
        return Vector2(x / len, y / len)
    }

    /// Rotated 90° counter-clockwise; the simulation's "left of travel" normal.
    public var perpendicular: Vector2 { Vector2(-y, x) }

    public func dot(_ other: Vector2) -> Double { x * other.x + y * other.y }

    /// 2D cross product magnitude, positive when `other` is to the left of self.
    public func cross(_ other: Vector2) -> Double { x * other.y - y * other.x }

    public func distance(to other: Vector2) -> Double { (self - other).length }

    public func rotated(by radians: Double) -> Vector2 {
        let c = cos(radians)
        let s = sin(radians)
        return Vector2(x * c - y * s, x * s + y * c)
    }

    public func clampedMagnitude(to maximum: Double) -> Vector2 {
        let len = length
        guard len > maximum, len > 1e-9 else { return self }
        return self * (maximum / len)
    }

    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    public static func * (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(lhs.x * rhs, lhs.y * rhs)
    }

    public static func * (lhs: Double, rhs: Vector2) -> Vector2 { rhs * lhs }

    public static func / (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(lhs.x / rhs, lhs.y / rhs)
    }

    public static prefix func - (value: Vector2) -> Vector2 { Vector2(-value.x, -value.y) }

    public static func += (lhs: inout Vector2, rhs: Vector2) { lhs = lhs + rhs }
    public static func -= (lhs: inout Vector2, rhs: Vector2) { lhs = lhs - rhs }
    public static func *= (lhs: inout Vector2, rhs: Double) { lhs = lhs * rhs }

    public static func lerp(_ a: Vector2, _ b: Vector2, _ t: Double) -> Vector2 {
        Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
}

extension Vector2: CustomStringConvertible {
    public var description: String {
        String(format: "(%.2f, %.2f)", x, y)
    }
}
