import XCTest
@testable import AisleRush

final class RaceProgressTests: XCTestCase {
    func testCheckpointsMustBePassedInOrder() {
        var progress = RaceProgress(totalLaps: 3, checkpointCount: 4)

        XCTAssertEqual(progress.passCheckpoint(1), .ignored)
        XCTAssertEqual(progress.nextCheckpoint, 0)
        XCTAssertEqual(progress.passCheckpoint(0), .checkpoint)
        XCTAssertEqual(progress.nextCheckpoint, 1)
        XCTAssertEqual(progress.passCheckpoint(0), .ignored)
    }

    func testCompletingCircuitAdvancesLap() {
        var progress = RaceProgress(totalLaps: 3, checkpointCount: 4)

        XCTAssertEqual(completeLap(&progress), .lapCompleted(2))
        XCTAssertEqual(progress.currentLap, 2)
        XCTAssertFalse(progress.isFinished)
    }

    func testFinalCircuitFinishesRace() {
        var progress = RaceProgress(totalLaps: 2, checkpointCount: 4)

        XCTAssertEqual(completeLap(&progress), .lapCompleted(2))
        XCTAssertEqual(completeLap(&progress), .raceFinished)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.passCheckpoint(0), .ignored)
    }

    func testResetRestoresInitialState() {
        var progress = RaceProgress(totalLaps: 2, checkpointCount: 2)
        _ = completeLap(&progress)

        progress.reset()

        XCTAssertEqual(progress.currentLap, 1)
        XCTAssertEqual(progress.nextCheckpoint, 0)
        XCTAssertFalse(progress.isFinished)
    }

    @discardableResult
    private func completeLap(_ progress: inout RaceProgress) -> CheckpointResult {
        var result: CheckpointResult = .ignored
        for checkpoint in 0..<progress.checkpointCount {
            result = progress.passCheckpoint(checkpoint)
        }
        return result
    }
}
