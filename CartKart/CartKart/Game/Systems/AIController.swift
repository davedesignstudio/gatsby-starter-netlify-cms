import SpriteKit
import UIKit

final class AIController {
    private let cart: ShoppingCart
    private let checkpoints: [SKNode]
    private var targetIndex: Int
    private var itemCooldown: TimeInterval = 0
    private var steerNoise: CGFloat = 0

    init(cart: ShoppingCart, checkpoints: [SKNode]) {
        self.cart = cart
        self.checkpoints = checkpoints
        self.targetIndex = (cart.checkpointIndex + 1) % max(checkpoints.count, 1)
    }

    func update(delta: TimeInterval, race: RaceScene) {
        guard !cart.finished, !checkpoints.isEmpty else { return }

        targetIndex = (cart.checkpointIndex + 1) % checkpoints.count
        let target = checkpoints[targetIndex].position

        // Look ahead slightly past checkpoint for smoother turns
        let next = checkpoints[(targetIndex + 1) % checkpoints.count].position
        let blend: CGFloat = 0.35
        let aim = CGPoint(
            x: target.x * (1 - blend) + next.x * blend,
            y: target.y * (1 - blend) + next.y * blend
        )

        let dx = aim.x - cart.position.x
        let dy = aim.y - cart.position.y
        let desired = atan2(dy, dx)

        var diff = desired - cart.heading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }

        steerNoise += CGFloat.random(in: -0.8...0.8) * CGFloat(delta)
        steerNoise = max(-0.4, min(0.4, steerNoise))

        let steer = max(-1, min(1, diff * 1.8 + steerNoise))
        cart.applySteer(steer, delta: delta)
        cart.applyThrottle(boosting: abs(diff) < 0.6, delta: delta)
        cart.integrate(delta: delta)

        itemCooldown = max(0, itemCooldown - delta)
        if cart.heldItem != nil, itemCooldown <= 0 {
            // Use items with some personality
            let shouldUse: Bool
            switch cart.heldItem {
            case .sodaBoost:
                shouldUse = abs(diff) < 0.5 && cart.speed > 100
            case .shoppingBag:
                shouldUse = true
            case .banana, .wetFloor:
                shouldUse = cart.speed > 150 && Bool.random()
            case .cannedGoods:
                shouldUse = abs(diff) < 0.4
            case .none:
                shouldUse = false
            }
            if shouldUse {
                cart.useHeldItem(world: race)
                itemCooldown = TimeInterval.random(in: 1.2...2.5)
            }
        }
    }
}
