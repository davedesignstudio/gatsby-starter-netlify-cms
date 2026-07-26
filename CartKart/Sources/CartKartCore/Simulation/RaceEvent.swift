import Foundation

/// Things worth reacting to with a sound, a particle or a bit of HUD text.
/// The engine appends these each frame; the presentation layer drains them.
public enum RaceEvent: Sendable {
    case countdownTick(Int)
    case go
    case rocketStart(kartID: Int)
    case boostPad(kartID: Int)
    case miniTurbo(kartID: Int, tier: DriftTier)
    case itemBoxCollected(kartID: Int, boxID: Int)
    case itemGranted(kartID: Int, kind: ItemKind)
    case itemUsed(kartID: Int, kind: ItemKind)
    case kartHit(kartID: Int, by: Disruption, sourceKartID: Int?)
    case kartBumped(kartID: Int, otherID: Int, impact: Double)
    case wallScrape(kartID: Int, impact: Double)
    case obstacleSmashed(position: Vec2, style: TrackObstacle.Style)
    case lapCompleted(kartID: Int, lap: Int, lapTime: Double)
    case finalLap(kartID: Int)
    case wrongWay(kartID: Int, active: Bool)
    case finished(kartID: Int, place: Int, totalTime: Double)
    case raceComplete
}

/// Overall race lifecycle.
public enum RacePhase: Sendable, Equatable {
    case countdown(remaining: Double)
    case racing
    /// Everyone who matters has crossed the line; the rest are still rolling in.
    case finished
}

/// Final standing for one cart.
public struct RaceResult: Sendable, Identifiable {
    public var id: Int { kartID }
    public let kartID: Int
    public let profile: RacerProfile
    public let place: Int
    public let totalTime: Double?
    public let bestLap: Double?
    public let isPlayer: Bool
    /// Grand Prix points, MK-style.
    public var points: Int {
        switch place {
        case 1: return 15
        case 2: return 12
        case 3: return 10
        case 4: return 8
        case 5: return 6
        case 6: return 4
        case 7: return 2
        default: return 1
        }
    }
}
