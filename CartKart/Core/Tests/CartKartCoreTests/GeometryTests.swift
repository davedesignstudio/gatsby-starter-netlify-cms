import XCTest
@testable import CartKartCore

final class GeometryTests: XCTestCase {
    func testVectorBasics() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v.length, 5, accuracy: 1e-9)
        XCTAssertEqual(v.normalized.length, 1, accuracy: 1e-9)
        XCTAssertEqual(Vec2(1, 0).perpendicular.y, 1, accuracy: 1e-9)
        XCTAssertEqual(Vec2(1, 0).dot(Vec2(0, 1)), 0, accuracy: 1e-9)
        XCTAssertEqual(Vec2(1, 0).cross(Vec2(0, 1)), 1, accuracy: 1e-9)
        XCTAssertEqual(Vec2(10, 0).clampedMagnitude(4).length, 4, accuracy: 1e-9)
    }

    func testRotationHelpers() {
        XCTAssertEqual(Angle.normalize(3 * .pi), .pi, accuracy: 1e-9)
        XCTAssertEqual(Angle.delta(from: 0.1, to: -0.1), -0.2, accuracy: 1e-9)
        // Crossing the +/- pi seam should take the short way round.
        let delta = Angle.delta(from: 3.0, to: -3.0)
        XCTAssertLessThan(abs(delta), 0.6)
        XCTAssertEqual(Angle.rotate(0, towards: 1, maxStep: 0.25), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Angle.rotate(0, towards: 0.1, maxStep: 0.25), 0.1, accuracy: 1e-9)
    }

    func testApproachConvergesWithoutOvershoot() {
        var value = 0.0
        for _ in 0..<600 {
            value = approach(value, 100, rate: 3, dt: 1.0 / 60)
            XCTAssertLessThanOrEqual(value, 100.0001)
        }
        XCTAssertEqual(value, 100, accuracy: 0.01)
    }

    func testSeededRandomIsDeterministicAndBounded() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<500 {
            let x = a.unit()
            XCTAssertEqual(x, b.unit())
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, 1)
        }
        var c = SeededRandom(seed: 43)
        XCTAssertNotEqual(a.unit(), c.unit())
    }

    func testWeightedIndexRespectsZeroWeights() {
        var random = SeededRandom(seed: 7)
        var counts = [0, 0, 0]
        for _ in 0..<2000 {
            counts[random.weightedIndex([0, 1, 3])] += 1
        }
        XCTAssertEqual(counts[0], 0)
        XCTAssertGreaterThan(counts[2], counts[1])
    }
}
