import SpriteKit

/// Simple waypoint-chasing driver for rival carts (also takes over the
/// player's cart after they finish, so the camera keeps moving).
final class AIDriver {
    let kart: Kart
    /// 0.88...1.02 — multiplies top speed so every rival feels different.
    let skill: CGFloat
    /// Personal lateral offset from the racing line, to avoid cart trains.
    private let lineBias: CGFloat
    private var itemTimer: TimeInterval

    private var stuckTimer: TimeInterval = 0
    private var reverseTimer: TimeInterval = 0

    init(kart: Kart, seed: Int) {
        self.kart = kart
        var rng = SeededRandom(seed: UInt64(seed * 7919 + 13))
        skill = rng.range(0.88, 1.02)
        lineBias = rng.range(-55, 55)
        itemTimer = TimeInterval(rng.range(0.8, 2.4))
    }

    /// Returns an item to use this frame, if the driver decided to.
    func update(dt: TimeInterval, track: Track) -> ItemKind? {
        guard !kart.isSpinning else { return nil }

        let waypoints = track.waypoints
        let index = kart.nextWaypointIndex % waypoints.count
        let current = waypoints[index]
        let following = waypoints[(index + 1) % waypoints.count]

        // Aim at the next waypoint, nudged by this driver's personal bias
        // (perpendicular to the approach direction, capped by the radius).
        let approach = (current.position - kart.position).normalized
        let perpendicular = CGPoint(x: -approach.y, y: approach.x)
        let bias = min(current.radius * 0.5, abs(lineBias)) * (lineBias < 0 ? -1 : 1)
        let target = current.position + perpendicular * bias

        let desired = (target - kart.position).angle
        let delta = angleDelta(from: kart.heading, to: desired)

        if reverseTimer > 0 {
            // Un-stuck maneuver: back away while counter-steering.
            reverseTimer -= dt
            kart.throttleInput = -0.6
            kart.steerInput = delta > 0 ? -1 : 1
            return nil
        }

        kart.steerInput = clamp(delta * 2.5, -1, 1)

        // Brake for sharp upcoming corners; braking distance grows with speed.
        let cornerAngle = abs(angleDelta(from: (following.position - current.position).angle,
                                         to: (current.position - kart.position).angle))
        let speed = kart.currentSpeed
        let nearCorner = kart.position.distance(to: current.position) < max(220, speed * 0.55)
        let sharp = cornerAngle > 0.9
        kart.throttleInput = (sharp && nearCorner && speed > kart.character.topSpeed * 0.5)
            ? 0.42 * skill : skill

        // Stuck detection: pinned against a shelf at near-zero speed.
        if kart.currentSpeed < 30 {
            stuckTimer += dt
            if stuckTimer > 1.4 {
                stuckTimer = 0
                reverseTimer = 0.8
            }
        } else {
            stuckTimer = 0
        }

        // Use whatever is in the basket after a short "thinking" delay.
        if kart.heldItem != nil {
            itemTimer -= dt
            if itemTimer <= 0 {
                itemTimer = TimeInterval.random(in: 1.0...2.6)
                return kart.heldItem
            }
        }
        return nil
    }
}
