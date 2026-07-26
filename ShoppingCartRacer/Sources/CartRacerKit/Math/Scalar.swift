import Foundation

public enum Scalar {
    /// Wraps an angle into `(-π, π]`.
    public static func normalizeAngle(_ radians: Double) -> Double {
        var value = radians.remainder(dividingBy: 2 * .pi)
        if value <= -.pi { value += 2 * .pi }
        if value > .pi { value -= 2 * .pi }
        return value
    }

    /// Signed smallest rotation that takes `from` to `to`.
    public static func angleDelta(from: Double, to: Double) -> Double {
        normalizeAngle(to - from)
    }

    public static func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }

    public static func clamp(_ value: Int, _ minimum: Int, _ maximum: Int) -> Int {
        min(max(value, minimum), maximum)
    }

    public static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    /// Maps `value` from one range to another without clamping.
    public static func remap(_ value: Double, _ inLow: Double, _ inHigh: Double, _ outLow: Double, _ outHigh: Double) -> Double {
        guard abs(inHigh - inLow) > 1e-12 else { return outLow }
        return outLow + (value - inLow) / (inHigh - inLow) * (outHigh - outLow)
    }

    /// Frame-rate independent exponential approach: pulls `current` towards
    /// `target` so that `rate` fraction of the gap closes every second.
    public static func damp(_ current: Double, _ target: Double, rate: Double, dt: Double) -> Double {
        let factor = 1 - exp(-rate * dt)
        return current + (target - current) * factor
    }

    public static func signum(_ value: Double) -> Double {
        if value > 0 { return 1 }
        if value < 0 { return -1 }
        return 0
    }

    /// Smooth 0→1 ramp with zero derivative at both ends.
    public static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = clamp((value - edge0) / max(edge1 - edge0, 1e-12), 0, 1)
        return t * t * (3 - 2 * t)
    }
}

/// Deterministic PRNG (SplitMix64) so a race can be replayed bit-for-bit from a
/// seed. `SystemRandomNumberGenerator` would make the tests useless here.
public struct DeterministicRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in `[0, 1)`.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    public mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    public mutating func nextBool(probability: Double) -> Bool {
        nextUnit() < probability
    }

    /// Picks an index from `weights`, proportional to each entry's weight.
    public mutating func weightedIndex(_ weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        var roll = nextUnit() * total
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return index }
        }
        return weights.count - 1
    }
}
