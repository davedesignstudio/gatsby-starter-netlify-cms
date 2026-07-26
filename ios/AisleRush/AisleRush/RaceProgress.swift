enum CheckpointResult: Equatable {
    case ignored
    case checkpoint
    case lapCompleted(Int)
    case raceFinished
}

struct RaceProgress {
    let totalLaps: Int
    let checkpointCount: Int

    private(set) var currentLap = 1
    private(set) var nextCheckpoint = 0
    private(set) var isFinished = false

    init(totalLaps: Int, checkpointCount: Int) {
        precondition(totalLaps > 0, "A race needs at least one lap.")
        precondition(checkpointCount > 0, "A lap needs at least one checkpoint.")
        self.totalLaps = totalLaps
        self.checkpointCount = checkpointCount
    }

    mutating func passCheckpoint(_ index: Int) -> CheckpointResult {
        guard !isFinished, index == nextCheckpoint else {
            return .ignored
        }

        nextCheckpoint = (nextCheckpoint + 1) % checkpointCount
        guard nextCheckpoint == 0 else {
            return .checkpoint
        }

        guard currentLap < totalLaps else {
            isFinished = true
            return .raceFinished
        }

        currentLap += 1
        return .lapCompleted(currentLap)
    }

    mutating func reset() {
        currentLap = 1
        nextCheckpoint = 0
        isFinished = false
    }
}
