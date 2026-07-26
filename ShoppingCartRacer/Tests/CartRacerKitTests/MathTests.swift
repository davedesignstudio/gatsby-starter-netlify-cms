import XCTest
@testable import CartRacerKit

final class MathTests: XCTestCase {
    func testVectorBasics() {
        let a = Vector2(3, 4)
        XCTAssertEqual(a.length, 5, accuracy: 1e-12)
        XCTAssertEqual(a.normalized.length, 1, accuracy: 1e-12)
        XCTAssertEqual(a.dot(Vector2(1, 0)), 3, accuracy: 1e-12)
        XCTAssertEqual(Vector2(1, 0).cross(Vector2(0, 1)), 1, accuracy: 1e-12)
        XCTAssertEqual(Vector2.zero.normalized, .zero)
    }

    func testPerpendicularPointsLeft() {
        // Travelling along +x, "left" must be +y: the whole lateral-offset sign
        // convention in the simulation depends on this.
        XCTAssertEqual(Vector2(1, 0).perpendicular.x, 0, accuracy: 1e-12)
        XCTAssertEqual(Vector2(1, 0).perpendicular.y, 1, accuracy: 1e-12)
    }

    func testRotation() {
        let rotated = Vector2(1, 0).rotated(by: .pi / 2)
        XCTAssertEqual(rotated.x, 0, accuracy: 1e-12)
        XCTAssertEqual(rotated.y, 1, accuracy: 1e-12)
    }

    func testAngleFromComponents() {
        XCTAssertEqual(Vector2(angle: 0.7, length: 3).angle, 0.7, accuracy: 1e-12)
        XCTAssertEqual(Vector2(angle: 0.7, length: 3).length, 3, accuracy: 1e-12)
    }

    func testNormalizeAngle() {
        XCTAssertEqual(Scalar.normalizeAngle(3 * .pi), .pi, accuracy: 1e-12)
        XCTAssertEqual(Scalar.normalizeAngle(-3 * .pi), .pi, accuracy: 1e-12)
        XCTAssertEqual(Scalar.normalizeAngle(0.5), 0.5, accuracy: 1e-12)
        XCTAssertTrue((-Double.pi...Double.pi).contains(Scalar.normalizeAngle(17.3)))
    }

    func testAngleDeltaTakesShortWayRound() {
        XCTAssertEqual(Scalar.angleDelta(from: 3.0, to: -3.0), 2 * .pi - 6, accuracy: 1e-12)
        XCTAssertEqual(Scalar.angleDelta(from: -3.0, to: 3.0), 6 - 2 * .pi, accuracy: 1e-12)
    }

    func testDampApproachesTargetWithoutOvershoot() {
        var value = 0.0
        for _ in 0..<200 {
            value = Scalar.damp(value, 10, rate: 5, dt: 1.0 / 60)
            XCTAssertLessThanOrEqual(value, 10)
        }
        XCTAssertEqual(value, 10, accuracy: 0.01)
    }

    func testDeterministicRandomIsRepeatableAndUniform() {
        var a = DeterministicRandom(seed: 42)
        var b = DeterministicRandom(seed: 42)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }

        var generator = DeterministicRandom(seed: 7)
        var total = 0.0
        var minimum = 1.0
        var maximum = 0.0
        for _ in 0..<20_000 {
            let value = generator.nextUnit()
            XCTAssertTrue((0..<1).contains(value))
            total += value
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        XCTAssertEqual(total / 20_000, 0.5, accuracy: 0.02)
        XCTAssertLessThan(minimum, 0.01)
        XCTAssertGreaterThan(maximum, 0.99)
    }

    func testWeightedIndexRespectsWeights() {
        var generator = DeterministicRandom(seed: 99)
        var counts = [0, 0, 0]
        for _ in 0..<9000 {
            counts[generator.weightedIndex([1, 2, 6])] += 1
        }
        XCTAssertEqual(Double(counts[0]) / 9000, 1.0 / 9.0, accuracy: 0.02)
        XCTAssertEqual(Double(counts[1]) / 9000, 2.0 / 9.0, accuracy: 0.02)
        XCTAssertEqual(Double(counts[2]) / 9000, 6.0 / 9.0, accuracy: 0.02)
        // A zero weight must never be picked, which is what gates comeback items.
        XCTAssertEqual(generator.weightedIndex([0, 1]), 1)
    }
}
