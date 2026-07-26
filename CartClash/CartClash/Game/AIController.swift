import SpriteKit
import CoreGraphics

final class AIController {
    let cart: CartNode
    private let checkpoints: [CGPoint]
    private var aggression: CGFloat
    private var lookAhead: Int
    private var itemTimer: TimeInterval = 0

    init(cart: CartNode, checkpoints: [CGPoint], skill: CGFloat) {
        self.cart = cart
        self.checkpoints = checkpoints
        self.aggression = skill
        self.lookAhead = skill > 0.85 ? 2 : 1
    }

    func update(deltaTime: TimeInterval, rivals: [CartNode]) {
        guard !cart.isFinished, !cart.isSpinning else {
            cart.throttleInput = 0
            cart.steerInput = 0
            return
        }

        let current = checkpoints[cart.nextCheckpoint % checkpoints.count]
        let nextIdx = (cart.nextCheckpoint + 1) % checkpoints.count
        let next = checkpoints[nextIdx]
        let blend: CGFloat = lookAhead > 1 ? 0.55 : 0.25
        let target = CGPoint(
            x: current.x * (1 - blend) + next.x * blend,
            y: current.y * (1 - blend) + next.y * blend
        )

        let dx = target.x - cart.position.x
        let dy = target.y - cart.position.y
        let desiredAngle = atan2(-dx, dy)
        var angleDiff = desiredAngle - cart.zRotation
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }

        cart.steerInput = max(-1, min(1, angleDiff * 1.6))
        cart.throttleInput = abs(angleDiff) > 1.1 ? 0.45 : aggression
        cart.brakeInput = abs(angleDiff) > 1.4 && hypot(cart.velocity.dx, cart.velocity.dy) > 220 ? 0.5 : 0

        for rival in rivals where rival !== cart {
            let rdx = rival.position.x - cart.position.x
            let rdy = rival.position.y - cart.position.y
            let dist = hypot(rdx, rdy)
            if dist < 70 && dist > 1 {
                let avoid = atan2(-rdx, rdy) - cart.zRotation
                cart.steerInput = max(-1, min(1, cart.steerInput - CGFloat(avoid) * 0.25))
            }
        }

        itemTimer -= deltaTime
        if itemTimer <= 0, cart.heldItem != nil {
            if cart.heldItem == .beanTurbo || cart.heldItem == .shoppingBag {
                itemTimer = 0.35
                NotificationCenter.default.post(name: .aiWantsItemUse, object: cart)
            } else {
                let nearby = rivals.contains {
                    $0 !== cart &&
                    hypot($0.position.x - cart.position.x, $0.position.y - cart.position.y) < 220
                }
                if nearby || CGFloat.random(in: 0...1) < 0.012 {
                    itemTimer = 1.2
                    NotificationCenter.default.post(name: .aiWantsItemUse, object: cart)
                }
            }
        }
    }
}

extension Notification.Name {
    static let aiWantsItemUse = Notification.Name("aiWantsItemUse")
}
