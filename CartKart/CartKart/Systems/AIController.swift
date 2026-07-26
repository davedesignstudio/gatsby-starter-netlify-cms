import SpriteKit

final class AIController {
    let racer: CartRacer
    private var targetCheckpoint = 0
    private var reactionDelay: TimeInterval
    private var nextDecision: TimeInterval = 0
    private var steerBias: CGFloat

    init(racer: CartRacer, skill: CGFloat) {
        self.racer = racer
        reactionDelay = TimeInterval(0.08 + (1 - skill) * 0.12)
        steerBias = CGFloat.random(in: -0.08...0.08)
        racer.maxSpeed *= 0.85 + skill * 0.2
        racer.acceleration *= 0.9 + skill * 0.15
    }

    @discardableResult
    func update(delta: TimeInterval, racers: [CartRacer]) -> PowerUpType? {
        guard !racer.finished else { return nil }

        nextDecision -= delta
        if nextDecision > 0 {
            _ = racer.applyInput(steer: lastSteer, accelerate: lastAccelerate, brake: false, drift: lastDrift, useItem: false)
            return nil
        }
        nextDecision = reactionDelay

        let target = checkpointTarget(for: racer)
        let vector = CGVector(dx: target.x - racer.position.x, dy: target.y - racer.position.y)
        let desiredAngle = atan2(vector.dy, vector.dx)
        var angleDiff = desiredAngle - racer.zRotation

        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }

        let steer = max(-1, min(1, angleDiff * 1.6 + steerBias))
        let accelerate = abs(angleDiff) < 1.2
        let drift = abs(angleDiff) > 0.7 && racer.speed > 140

        lastSteer = steer
        lastAccelerate = accelerate
        lastDrift = drift

        let useItem = racer.heldPowerUp != nil && shouldUseItem(nearby: racers)
        return racer.applyInput(steer: steer, accelerate: accelerate, brake: false, drift: drift, useItem: useItem)
    }

    private var lastSteer: CGFloat = 0
    private var lastAccelerate = true
    private var lastDrift = false

    private func checkpointTarget(for racer: CartRacer) -> CGPoint {
        let checkpoints: [CGPoint] = [
            CGPoint(x: 0, y: -360),
            CGPoint(x: 560, y: 0),
            CGPoint(x: 0, y: 360),
            CGPoint(x: -560, y: 0)
        ]
        let index = racer.checkpointIndex % checkpoints.count
        var target = checkpoints[index]

        // Lane offset so AI racers don't stack perfectly.
        let lane = CGFloat(racer.racePosition) * 28 - 42
        switch index {
        case 0: target.x += lane
        case 1: target.y += lane
        case 2: target.x -= lane
        default: target.y -= lane
        }

        if !TrackLayout.isOnTrack(target) {
            target = TrackLayout.nearestTrackPoint(from: target)
        }
        return target
    }

    private func shouldUseItem(nearby racers: [CartRacer]) -> Bool {
        guard racer.heldPowerUp != nil else { return false }
        let leaders = racers.filter { !$0.finished && $0.lap >= racer.lap && distance(to: $0) < 180 }
        return !leaders.isEmpty || Bool.random(probability: 0.02)
    }

    private func distance(to other: CartRacer) -> CGFloat {
        hypot(other.position.x - racer.position.x, other.position.y - racer.position.y)
    }
}

private extension Bool {
    static func random(probability: Double) -> Bool {
        Double.random(in: 0...1) < probability
    }
}
