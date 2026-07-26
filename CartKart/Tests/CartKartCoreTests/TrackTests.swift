import XCTest
@testable import CartKartCore

final class TrackTests: XCTestCase {
    private let track = TrackLibrary.producePlaza

    func testEveryLibraryTrackIsSane() {
        for track in TrackLibrary.all {
            XCTAssertGreaterThan(track.trackLength, 1500, "\(track.id) is suspiciously short")
            XCTAssertGreaterThan(track.samples.count, 100, "\(track.id) has too few samples")
            XCTAssertFalse(track.itemBoxes.isEmpty, "\(track.id) has no item boxes")
            XCTAssertGreaterThanOrEqual(track.lapCount, 3)

            // Arc lengths must increase monotonically around the loop.
            for i in 1..<track.samples.count {
                XCTAssertGreaterThan(track.samples[i].arcLength, track.samples[i - 1].arcLength)
            }

            // Every placed feature should sit on driveable floor.
            for box in track.itemBoxes {
                let projection = track.project(box.position)
                XCTAssertLessThanOrEqual(
                    abs(projection.lateralOffset),
                    projection.halfWidth + 1,
                    "\(track.id) item box is off the lane"
                )
            }
            for pad in track.boostPads {
                let projection = track.project(pad.position)
                XCTAssertLessThanOrEqual(abs(projection.lateralOffset), projection.halfWidth + 1)
            }
        }
    }

    func testProjectionOfCentrelinePoints() {
        for index in stride(from: 0, to: track.samples.count, by: 7) {
            let sample = track.samples[index]
            let projection = track.project(sample.position)
            XCTAssertEqual(projection.lateralOffset, 0, accuracy: 2.0)
            XCTAssertEqual(projection.arcLength, sample.arcLength, accuracy: 15)
        }
    }

    func testProjectionSignConvention() {
        let sample = track.samples[10]
        let left = sample.position + sample.tangent.perpendicular * 50
        let right = sample.position - sample.tangent.perpendicular * 50
        XCTAssertGreaterThan(track.project(left).lateralOffset, 0)
        XCTAssertLessThan(track.project(right).lateralOffset, 0)
    }

    func testArcDeltaWrapsForwardAcrossTheLine() {
        let length = track.trackLength
        let delta = track.arcDelta(from: length - 50, to: 30)
        XCTAssertEqual(delta, 80, accuracy: 1)
        let backwards = track.arcDelta(from: 30, to: length - 50)
        XCTAssertEqual(backwards, -80, accuracy: 1)
    }

    func testPositionAtArcLengthMatchesProjection() {
        for fraction in stride(from: 0.0, to: 1.0, by: 0.05) {
            let arc = fraction * track.trackLength
            let point = track.position(atArcLength: arc)
            let projection = track.project(point)
            XCTAssertEqual(projection.arcLength, arc, accuracy: 20)
        }
    }

    func testStartingGridIsOnTrackAndFacingForward() {
        let grid = track.startingGrid(count: 8)
        XCTAssertEqual(grid.count, 8)
        for slot in grid {
            let projection = track.project(slot.position)
            XCTAssertLessThan(abs(projection.lateralOffset), projection.halfWidth)
            let facing = Vec2.direction(slot.heading)
            XCTAssertGreaterThan(facing.dot(projection.tangent), 0.9, "grid slot faces the wrong way")
        }
        // Pole position starts ahead of the back row.
        let pole = track.project(grid[0].position).arcLength
        let last = track.project(grid[7].position).arcLength
        XCTAssertGreaterThan(track.arcDelta(from: last, to: pole), 0)
    }

    func testSurfaceClassification() {
        let sample = track.samples[20]
        XCTAssertEqual(track.surface(at: sample.position), .tile)
        let offLane = sample.position + sample.tangent.perpendicular * (sample.halfWidth + 40)
        XCTAssertEqual(track.surface(at: offLane), .rough)
        if let puddle = track.puddles.first {
            XCTAssertEqual(track.surface(at: puddle.position), .slick)
        }
    }

    func testNearestSampleHintMatchesGlobalSearch() {
        for index in stride(from: 0, to: track.samples.count, by: 11) {
            let point = track.samples[index].position + Vec2(9, -7)
            let global = track.nearestSampleIndex(to: point)
            let hinted = track.nearestSampleIndex(to: point, hint: index)
            XCTAssertEqual(global, hinted)
        }
    }
}
