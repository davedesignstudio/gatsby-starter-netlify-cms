import Foundation

struct TrackPoint: Equatable {
    let x: Double
    let y: Double

    func distanceSquared(to other: TrackPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}

struct LapProgress {
    private(set) var completedLaps = 0
    private(set) var nextCheckpoint = 0

    mutating func visit(
        position: TrackPoint,
        checkpoints: [TrackPoint],
        captureRadius: Double
    ) -> Bool {
        guard !checkpoints.isEmpty, nextCheckpoint < checkpoints.count else {
            return false
        }

        let target = checkpoints[nextCheckpoint]
        guard position.distanceSquared(to: target) <= captureRadius * captureRadius else {
            return false
        }

        nextCheckpoint += 1
        guard nextCheckpoint == checkpoints.count else {
            return false
        }

        nextCheckpoint = 0
        completedLaps += 1
        return true
    }

    mutating func reset() {
        completedLaps = 0
        nextCheckpoint = 0
    }
}

enum DriftBoost {
    static func duration(for charge: TimeInterval) -> TimeInterval {
        switch charge {
        case 1.2...:
            return 1.6
        case 0.55...:
            return 0.9
        default:
            return 0
        }
    }
}
