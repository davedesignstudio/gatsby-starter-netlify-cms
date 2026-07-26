import Foundation

/// Small, fast, fully deterministic PRNG (SplitMix64).
///
/// Determinism matters here: races are simulated with a fixed timestep so a
/// given seed plus a given input sequence always produces the same result,
/// which is what makes the headless tests meaningful.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<1`.
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    public mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// Picks an index from a weight table. Zero or negative weights are skipped.
    public mutating func weightedIndex(_ weights: [Double]) -> Int {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return 0 }
        var roll = unit() * total
        for (index, weight) in weights.enumerated() {
            roll -= max(0, weight)
            if roll <= 0 { return index }
        }
        return weights.count - 1
    }
}
