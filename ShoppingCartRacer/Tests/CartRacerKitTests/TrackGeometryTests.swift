import XCTest
@testable import CartRacerKit

final class TrackGeometryTests: XCTestCase {
    /// A 40x40 square loop, walked anti-clockwise, with dense sampling.
    private func squareGeometry(halfWidth: Double = 5) -> TrackGeometry {
        var nodes: [TrackNode] = []
        let corners = [Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)]
        for index in 0..<4 {
            let start = corners[index]
            let end = corners[(index + 1) % 4]
            let steps = 20
            for step in 0..<steps {
                nodes.append(
                    TrackNode(
                        position: Vector2.lerp(start, end, Double(step) / Double(steps)),
                        halfWidth: halfWidth,
                        surface: .polishedTile
                    )
                )
            }
        }
        return TrackGeometry(nodes: nodes)
    }

    func testTotalLengthMatchesPerimeter() {
        XCTAssertEqual(squareGeometry().totalLength, 160, accuracy: 1e-9)
    }

    func testStartLineIsAtFirstNode() {
        let geometry = squareGeometry()
        XCTAssertEqual(geometry.point(at: 0).x, -20, accuracy: 1e-9)
        XCTAssertEqual(geometry.point(at: 0).y, -20, accuracy: 1e-9)
    }

    func testWrapKeepsDistanceInRange() {
        let geometry = squareGeometry()
        for distance in stride(from: -500.0, through: 500.0, by: 7.3) {
            let wrapped = geometry.wrap(distance)
            XCTAssertGreaterThanOrEqual(wrapped, 0)
            XCTAssertLessThan(wrapped, geometry.totalLength)
        }
        XCTAssertEqual(geometry.wrap(-10), 150, accuracy: 1e-9)
        XCTAssertEqual(geometry.wrap(170), 10, accuracy: 1e-9)
    }

    func testLateralSignIsPositiveToTheLeft() {
        let geometry = squareGeometry()
        // Halfway along the bottom edge, travelling towards +x. A point at
        // greater y is to the left, so its lateral offset must be positive.
        let left = geometry.location(of: Vector2(0, -17))
        XCTAssertEqual(left.lateral, 3, accuracy: 1e-6)
        let right = geometry.location(of: Vector2(0, -23))
        XCTAssertEqual(right.lateral, -3, accuracy: 1e-6)
    }

    func testProjectionRecoversArcLength() {
        let geometry = squareGeometry()
        for distance in stride(from: 0.0, to: 160.0, by: 3.0) {
            let onCentre = geometry.point(at: distance)
            let location = geometry.location(of: onCentre)
            XCTAssertEqual(location.distance, distance, accuracy: 0.5)
            XCTAssertEqual(location.lateral, 0, accuracy: 1e-6)
        }
    }

    /// Offsetting sideways and projecting back only has to round-trip where the
    /// offset is well inside the radius of curvature — which is exactly the
    /// regime the shipped courses are authored in. (A square's 90° corners are
    /// not: a point offset inward there is genuinely nearest the next edge.)
    func testOffsetPositionRoundTripsOnRealisticCurvature() {
        let control = TrackBuilder.polarLoop(
            baseRadius: 60,
            harmonics: [],
            samples: 48
        ) { _ in (9, .polishedTile) }
        let geometry = TrackGeometry(nodes: TrackBuilder.centreline(from: control, resolution: 1.5))

        for distance in stride(from: 1.0, to: geometry.totalLength, by: 4.0) {
            for lateral in [-8.0, -4.0, 0.0, 4.0, 8.0] {
                let point = geometry.position(at: distance, lateral: lateral)
                let location = geometry.location(of: point)
                XCTAssertEqual(location.lateral, lateral, accuracy: 0.02)
            }
        }

        for definition in TrackLibrary.all {
            let geometry = Track(definition: definition).geometry
            for distance in stride(from: 0.0, to: geometry.totalLength, by: 5.0) {
                let halfWidth = geometry.halfWidth(at: distance)
                for fraction in [-0.9, -0.4, 0.0, 0.4, 0.9] {
                    let lateral = halfWidth * fraction
                    let point = geometry.position(at: distance, lateral: lateral)
                    let location = geometry.location(of: point)
                    XCTAssertEqual(location.lateral, lateral, accuracy: 0.25, "round trip failed on \(definition.id)")
                }
            }
        }
    }

    func testHintedLookupMatchesGlobalLookup() {
        for definition in TrackLibrary.all {
            let geometry = Track(definition: definition).geometry
            let count = geometry.segments.count
            for distance in stride(from: 0.0, to: geometry.totalLength, by: 2.0) {
                let point = geometry.position(at: distance, lateral: 2)
                let global = geometry.location(of: point)

                let hinted = geometry.location(of: point, hint: global.segmentIndex)
                XCTAssertEqual(hinted.distance, global.distance, accuracy: 1e-9)

                // A hint that is slightly behind, as it would be mid-frame.
                let trailing = geometry.location(of: point, hint: (global.segmentIndex - 3 + count) % count)
                XCTAssertEqual(trailing.distance, global.distance, accuracy: 1e-9)

                // A stale hint from the far side of the lap, as after a respawn or
                // an express-lane trip, must not latch onto the wrong place.
                let stale = geometry.location(of: point, hint: (global.segmentIndex + count / 2) % count)
                XCTAssertEqual(stale.distance, global.distance, accuracy: 1e-9, "stale hint resolved wrongly")
            }
        }
    }

    func testSignedGapIsShortestWayRound() {
        let geometry = squareGeometry()
        XCTAssertEqual(geometry.signedGap(from: 10, to: 30), 20, accuracy: 1e-9)
        XCTAssertEqual(geometry.signedGap(from: 155, to: 5), 10, accuracy: 1e-9)
        XCTAssertEqual(geometry.signedGap(from: 5, to: 155), -10, accuracy: 1e-9)
        for a in stride(from: 0.0, to: 160.0, by: 11.0) {
            for b in stride(from: 0.0, to: 160.0, by: 13.0) {
                let gap = geometry.signedGap(from: a, to: b)
                XCTAssertLessThanOrEqual(abs(gap), geometry.totalLength / 2 + 1e-9)
            }
        }
    }

    func testCurvatureIsZeroOnStraightsAndPositiveOnLeftTurns() {
        let geometry = squareGeometry()
        // Mid-way down the bottom straight.
        XCTAssertEqual(geometry.curvature(at: 20, window: 8), 0, accuracy: 1e-9)
        // Approaching the first (left-hand) corner at 40 m.
        XCTAssertGreaterThan(geometry.curvature(at: 38, window: 8), 0)
    }

    func testSplineResamplingProducesEvenlySpacedNodes() {
        let control = TrackBuilder.polarLoop(
            baseRadius: 40,
            harmonics: [(k: 2, amplitude: 6, phase: 0)],
            samples: 24
        ) { _ in (8, .polishedTile) }
        let nodes = TrackBuilder.centreline(from: control, resolution: 1.5)
        XCTAssertGreaterThan(nodes.count, 100)

        var spacings: [Double] = []
        for index in nodes.indices {
            let next = nodes[(index + 1) % nodes.count]
            spacings.append(nodes[index].position.distance(to: next.position))
        }
        XCTAssertGreaterThan(spacings.min()!, 0.2)
        XCTAssertLessThan(spacings.max()!, 3.0)
    }

    func testEveryShippedTrackIsSaneAndDrivable() {
        for definition in TrackLibrary.all {
            let track = Track(definition: definition)
            let geometry = track.geometry

            XCTAssertGreaterThan(geometry.totalLength, 250, "\(definition.id) is too short for three laps")
            XCTAssertLessThan(geometry.totalLength, 900, "\(definition.id) is too long")
            XCTAssertGreaterThan(definition.nodes.count, 80, "\(definition.id) centreline is too coarse")

            // Nothing should be authored outside the walls.
            for box in definition.itemBoxes {
                let location = geometry.location(of: box.position)
                XCTAssertLessThan(abs(location.lateral), location.halfWidth, "crate off track in \(definition.id)")
            }
            for token in definition.tokens {
                let location = geometry.location(of: token.position)
                XCTAssertLessThan(abs(location.lateral), location.halfWidth, "token off track in \(definition.id)")
            }
            for pad in definition.boostPads {
                let location = geometry.location(of: pad.position)
                XCTAssertLessThan(abs(location.lateral), location.halfWidth, "pad off track in \(definition.id)")
            }
            // Obstacles may sit in the run-off, but not inside the shelving.
            for obstacle in definition.obstacles {
                let location = geometry.location(of: obstacle.position)
                XCTAssertLessThan(
                    abs(location.lateral),
                    location.halfWidth + definition.shoulderWidth,
                    "obstacle in the wall in \(definition.id)"
                )
            }

            // No corner should be tighter than a cart can physically take.
            var distance = 0.0
            var tightest = Double.infinity
            while distance < geometry.totalLength {
                let curvature = abs(geometry.curvature(at: distance, window: 10))
                if curvature > 1e-5 { tightest = min(tightest, 1 / curvature) }
                distance += 2
            }
            XCTAssertGreaterThan(tightest, 6, "\(definition.id) has an undrivable corner")

            // The obstacles must never completely block the road.
            for obstacle in definition.obstacles {
                let location = geometry.location(of: obstacle.position)
                let clearance = location.halfWidth - (abs(location.lateral) - obstacle.radius)
                XCTAssertGreaterThan(clearance, 2.0, "no way past \(obstacle.kind) in \(definition.id)")
            }
        }
    }

    func testGridSlotsSitBehindTheLineAndInsideTheTrack() {
        for definition in TrackLibrary.all {
            let track = Track(definition: definition)
            var seen: [Vector2] = []
            for index in 0..<6 {
                let slot = track.gridSlot(index: index)
                let location = track.geometry.location(of: slot.position)
                XCTAssertLessThan(abs(location.lateral), location.halfWidth, "grid slot \(index) off track")
                XCTAssertGreaterThan(slot.distanceBehindLine, 0)
                for other in seen {
                    XCTAssertGreaterThan(other.distance(to: slot.position), 1.6, "grid slots overlap")
                }
                seen.append(slot.position)
            }
        }
    }
}
