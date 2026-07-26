import XCTest
@testable import AisleAllies

final class RaceProgressTests: XCTestCase {
    func testCheckpointsMustBeReachedInOrder() {
        var progress = RaceProgress(totalLaps: 3, checkpointCount: 4)

        XCTAssertFalse(progress.reachedCheckpoint(2))
        XCTAssertEqual(progress.nextCheckpoint, 1)

        XCTAssertTrue(progress.reachedCheckpoint(1))
        XCTAssertEqual(progress.nextCheckpoint, 2)
        XCTAssertEqual(progress.completedCheckpointCount, 1)
    }

    func testCrossingStartLineAdvancesLap() {
        var progress = RaceProgress(totalLaps: 3, checkpointCount: 4)

        for checkpoint in [1, 2, 3, 0] {
            XCTAssertTrue(progress.reachedCheckpoint(checkpoint))
        }

        XCTAssertEqual(progress.lap, 2)
        XCTAssertEqual(progress.nextCheckpoint, 1)
        XCTAssertFalse(progress.isFinished)
        XCTAssertEqual(progress.completedCheckpointCount, 4)
    }

    func testCompletingFinalLapFinishesRace() {
        var progress = RaceProgress(totalLaps: 2, checkpointCount: 3)

        for checkpoint in [1, 2, 0, 1, 2, 0] {
            XCTAssertTrue(progress.reachedCheckpoint(checkpoint))
        }

        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.lap, 2)
        XCTAssertEqual(progress.completedCheckpointCount, 6)
        XCTAssertFalse(progress.reachedCheckpoint(1))
    }
}
