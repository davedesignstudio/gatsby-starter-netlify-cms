import XCTest
@testable import AisleRushCore

final class TrackGeometryTests: XCTestCase {
    private let tracks = Tracks.all.map { Track(definition: $0) }

    func testCoursesAreARacingLength() {
        for track in tracks {
            XCTAssertGreaterThan(track.length, 380, "\(track.definition.name) is too short for three laps")
            XCTAssertLessThan(track.length, 1200, "\(track.definition.name) would take all afternoon")
            XCTAssertEqual(track.length, Double(track.sampleCount) * track.sampleSpacing, accuracy: 1e-6)
        }
    }

    func testProjectionRoundTripsThroughPositions() {
        for track in tracks {
            var distance = 0.0
            while distance < track.length {
                for lateral in [-4.0, -1.0, 0.0, 2.5] {
                    let point = track.position(distance: distance, lateral: lateral)
                    let projection = track.project(point)
                    let gap = abs(track.signedGap(from: distance, to: projection.distance))
                    XCTAssertLessThan(gap, 1.0, "\(track.definition.name) lost track of \(distance)")
                    XCTAssertEqual(projection.lateral, lateral, accuracy: 0.35)
                }
                distance += 7
            }
        }
    }

    func testProjectionHintAgreesWithFullSearch() {
        for track in tracks {
            var distance = 3.0
            var hint = 0
            while distance < track.length {
                let point = track.position(distance: distance, lateral: 1.5)
                let full = track.project(point)
                let hinted = track.project(point, hint: hint)
                XCTAssertEqual(full.distance, hinted.distance, accuracy: 0.05)
                hint = hinted.sampleIndex
                distance += 2
            }
        }
    }

    /// A course that folds back on itself would make the lateral projection
    /// ambiguous and the lap counter unreliable.
    func testCoursesNeverRunAlongsideThemselves() {
        for track in tracks {
            let count = track.sampleCount
            let separation = Int(60 / track.sampleSpacing)
            for i in stride(from: 0, to: count, by: 2) {
                var j = i + separation
                while j < i + count - separation {
                    let a = track.centerline[i]
                    let b = track.centerline[j % count]
                    let required = track.wallDistance(atDistance: Double(i) * track.sampleSpacing)
                        + track.wallDistance(atDistance: Double(j % count) * track.sampleSpacing)
                    XCTAssertGreaterThan(
                        a.distance(to: b),
                        required,
                        "\(track.definition.name) overlaps itself near samples \(i) and \(j % count)"
                    )
                    j += 2
                }
            }
        }
    }

    func testRacingLineStaysOnTheTrack() {
        for track in tracks {
            for index in 0..<track.sampleCount {
                XCTAssertLessThan(
                    abs(track.racingLineOffsets[index]),
                    track.halfWidths[index],
                    "\(track.definition.name) puts its racing line into the shelves"
                )
            }
        }
    }

    func testCornerSpeedLimitsAreSaneAndBrakingIsAnticipated() {
        for track in tracks {
            var slowest = Double.infinity
            for limit in track.speedLimits {
                XCTAssertTrue(limit.isFinite)
                XCTAssertGreaterThan(limit, 6, "\(track.definition.name) has an impassable corner")
                slowest = min(slowest, limit)
            }
            XCTAssertLessThan(slowest, 60, "\(track.definition.name) has no corners worth braking for")

            // The limit may only rise as fast as a cart can plausibly brake.
            for index in 0..<track.sampleCount {
                let here = track.speedLimits[index]
                let next = track.speedLimits[(index + 1) % track.sampleCount]
                let reachable = (next * next + 2 * 9.5 * track.sampleSpacing).squareRoot()
                XCTAssertLessThanOrEqual(here, reachable + 1e-6)
            }
        }
    }

    func testItemBoxesAndPropsSitInsideTheAisles() {
        for track in tracks {
            for box in track.itemBoxes {
                let projection = track.project(box.position)
                XCTAssertLessThan(
                    abs(projection.lateral),
                    track.halfWidth(atDistance: projection.distance),
                    "\(track.definition.name) hid an item crate in the shelving"
                )
            }
            for prop in track.props {
                let projection = track.project(prop.position)
                XCTAssertLessThan(
                    abs(projection.lateral) + prop.radius,
                    track.wallDistance(atDistance: projection.distance),
                    "\(track.definition.name) has a \(prop.kind.rawValue) inside a wall"
                )
            }
        }
    }

    func testStartingGridIsBehindTheLineAndInsideTheAisle() {
        for track in tracks {
            for index in 0..<8 {
                let slot = track.startingSlot(index, of: 8)
                let projection = track.project(slot.position)
                XCTAssertGreaterThan(projection.distance, track.length - 40)
                XCTAssertLessThan(abs(projection.lateral), track.halfWidth(atDistance: projection.distance))
                let headingError = abs(Angle.delta(from: slot.heading, to: projection.tangent.angle))
                XCTAssertLessThan(headingError, 0.3)
            }
        }
    }

    func testSurfacesResolveToTheAuthoredPatches() {
        let track = Track(definition: Tracks.frozenFoods)
        let icy = track.surface(atDistance: track.length * 0.27, lateral: 0)
        XCTAssertEqual(icy, .ice)
        let clean = track.surface(atDistance: track.length * 0.45, lateral: 0)
        XCTAssertEqual(clean, .linoleum)
        let outside = track.surface(atDistance: track.length * 0.45, lateral: track.halfWidth(atDistance: track.length * 0.45) + 1)
        XCTAssertEqual(outside, .scuffed)
    }

    func testSignedGapWrapsTheShortWayRound() {
        let track = Track(definition: Tracks.produceLoop)
        XCTAssertEqual(track.signedGap(from: 10, to: 30), 20, accuracy: 1e-9)
        XCTAssertEqual(track.signedGap(from: 5, to: track.length - 5), -10, accuracy: 1e-9)
        XCTAssertEqual(track.signedGap(from: track.length - 5, to: 5), 10, accuracy: 1e-9)
    }
}
