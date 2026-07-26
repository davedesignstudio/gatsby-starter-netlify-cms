import SpriteKit

final class AIController {
    private let cart: ShoppingCart
    private let waypoints: [TrackWaypoint]
    private var skill: CGFloat
    private var reactionDelay: TimeInterval = 0
    private var targetSteer: CGFloat = 0

    init(cart: ShoppingCart, waypoints: [TrackWaypoint], skill: CGFloat) {
        self.cart = cart
        self.waypoints = waypoints
        self.skill = skill
        self.reactionDelay = Double.random(in: 0...0.3)
    }

    func update(delta: TimeInterval) {
        guard !waypoints.isEmpty else { return }

        reactionDelay -= delta
        let target = waypoints[cart.waypointIndex].position
        let dx = target.x - cart.position.x
        let dy = target.y - cart.position.y
        let dist = hypot(dx, dy)

        if dist < 50 {
            cart.advanceWaypoint(total: waypoints.count)
        }

        let desiredAngle = atan2(dx, dy)
        var angleDiff = desiredAngle - cart.heading
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }

        let steerAmount = max(-1, min(1, angleDiff * 2.5))
        targetSteer = targetSteer * 0.7 + steerAmount * 0.3

        let noise = CGFloat.random(in: -0.15...0.15) * (1.0 - skill)
        let steer = (targetSteer + noise) * skill

        let throttle: CGFloat
        if abs(angleDiff) > 1.0 {
            throttle = 0.3
        } else if abs(angleDiff) > 0.5 {
            throttle = 0.65
        } else {
            throttle = 0.85 + skill * 0.15
        }

        if reactionDelay > 0 {
            cart.applyAI(steer: steer * 0.5, throttle: throttle * 0.7)
        } else {
            cart.applyAI(steer: steer, throttle: throttle)
        }
    }
}
