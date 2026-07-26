import Foundation

struct RaceProgress {
    let totalLaps: Int
    let checkpointCount: Int

    private(set) var lap = 1
    private(set) var nextCheckpoint = 1
    private(set) var isFinished = false

    init(totalLaps: Int = 3, checkpointCount: Int) {
        precondition(totalLaps > 0)
        precondition(checkpointCount > 1)
        self.totalLaps = totalLaps
        self.checkpointCount = checkpointCount
    }

    @discardableResult
    mutating func reachedCheckpoint(_ index: Int) -> Bool {
        guard !isFinished, index == nextCheckpoint else { return false }

        if index == 0 {
            lap += 1
            if lap > totalLaps {
                lap = totalLaps
                isFinished = true
                return true
            }
        }

        nextCheckpoint = (nextCheckpoint + 1) % checkpointCount
        return true
    }

    var completedCheckpointCount: Int {
        if isFinished {
            return totalLaps * checkpointCount
        }

        let progressInLap = nextCheckpoint == 0
            ? checkpointCount - 1
            : max(0, nextCheckpoint - 1)
        return (lap - 1) * checkpointCount + progressInLap
    }
}

enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let pantryItem: UInt32 = 1 << 2
    static let spill: UInt32 = 1 << 3
    static let boostPad: UInt32 = 1 << 4
}
