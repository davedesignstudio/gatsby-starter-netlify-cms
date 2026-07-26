import XCTest
@testable import CartDash

final class GameRulesTests: XCTestCase {
    func testCheckpointsMustBeVisitedInOrder() {
        let checkpoints = [
            TrackPoint(x: 10, y: 0),
            TrackPoint(x: 20, y: 0)
        ]
        var progress = LapProgress()

        XCTAssertFalse(
            progress.visit(
                position: TrackPoint(x: 20, y: 0),
                checkpoints: checkpoints,
                captureRadius: 2
            )
        )
        XCTAssertEqual(progress.nextCheckpoint, 0)

        XCTAssertFalse(
            progress.visit(
                position: TrackPoint(x: 10, y: 0),
                checkpoints: checkpoints,
                captureRadius: 2
            )
        )
        XCTAssertEqual(progress.nextCheckpoint, 1)
    }

    func testCompletingEveryCheckpointAwardsOneLap() {
        let checkpoints = [
            TrackPoint(x: 10, y: 0),
            TrackPoint(x: 20, y: 0)
        ]
        var progress = LapProgress()

        _ = progress.visit(
            position: TrackPoint(x: 10, y: 0),
            checkpoints: checkpoints,
            captureRadius: 2
        )
        let completed = progress.visit(
            position: TrackPoint(x: 20, y: 0),
            checkpoints: checkpoints,
            captureRadius: 2
        )

        XCTAssertTrue(completed)
        XCTAssertEqual(progress.completedLaps, 1)
        XCTAssertEqual(progress.nextCheckpoint, 0)
    }

    func testDriftBoostUsesChargeThresholds() {
        XCTAssertEqual(DriftBoost.duration(for: 0.4), 0)
        XCTAssertEqual(DriftBoost.duration(for: 0.7), 0.9)
        XCTAssertEqual(DriftBoost.duration(for: 1.4), 1.6)
    }
}
