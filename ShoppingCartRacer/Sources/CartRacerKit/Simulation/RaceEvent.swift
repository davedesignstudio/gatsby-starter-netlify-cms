import Foundation

/// Discrete things that happened during a step. The simulation never touches
/// audio, haptics or particles itself — it just reports, and the presentation
/// layer drains the queue each frame.
public enum RaceEvent: Equatable, Sendable {
    case countdownBeep(count: Int)
    case raceStarted
    case rocketStart(cartID: Int)
    case floodedEngine(cartID: Int)
    case boostStarted(cartID: Int, strength: Double)
    case miniTurbo(cartID: Int, tier: Int)
    case driftStarted(cartID: Int)
    case wallScrape(cartID: Int, intensity: Double, position: Vector2)
    case cartBump(cartID: Int, otherID: Int, intensity: Double, position: Vector2)
    case obstacleHit(cartID: Int, kind: Obstacle.Kind, position: Vector2)
    case itemCollected(cartID: Int, item: ItemKind)
    case itemUsed(cartID: Int, item: ItemKind)
    case projectileHit(cartID: Int, position: Vector2)
    case shieldBlocked(cartID: Int, position: Vector2)
    case slipped(cartID: Int, position: Vector2)
    case spunOut(cartID: Int)
    case stalled(cartID: Int)
    case tokenCollected(cartID: Int, total: Int)
    case lapCompleted(cartID: Int, lap: Int, lapTime: Double)
    case finished(cartID: Int, racePosition: Int, totalTime: Double)
    case raceComplete
    case respawned(cartID: Int)
}
