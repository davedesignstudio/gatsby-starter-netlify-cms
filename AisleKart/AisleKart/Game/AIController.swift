import SpriteKit

final class AIController {
    private weak var cart: CartNode?
    private let path: [CGPoint]
    private var waypointIndex = 0
    private var itemCooldown: TimeInterval = 1.5
    private let aggression: CGFloat

    init(cart: CartNode, path: [CGPoint]) {
        self.cart = cart
        self.path = path
        self.aggression = CGFloat.random(in: 0.75...1.15)
        // Stagger AI skill slightly by cart index
        cart.maxSpeed *= CGFloat.random(in: 0.88...1.02)
        cart.acceleration *= CGFloat.random(in: 0.9...1.05)
    }

    func update(delta: TimeInterval, rivals: [CartNode], player: CartNode?) {
        guard let cart, !cart.finished, cart.spinTimer <= 0 else { return }

        itemCooldown -= delta

        // Chase checkpoints / path
        let target = path[waypointIndex % path.count]
        let dx = target.x - cart.position.x
        let dy = target.y - cart.position.y
        let dist = hypot(dx, dy)

        if dist < 100 {
            waypointIndex = (waypointIndex + 1) % path.count
        }

        let desired = atan2(dx, dy)
        var angleDiff = desired - cart.zRotation
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }

        cart.steerInput = max(-1, min(1, angleDiff * 1.8)) * aggression
        cart.throttle = abs(angleDiff) < 1.2

        // Use items opportunistically
        guard itemCooldown <= 0, let item = cart.heldItem else { return }

        let shouldUse: Bool
        switch item {
        case .shield:
            shouldUse = !cart.hasShield && Int.random(in: 0..<100) < 40
        case .boost:
            shouldUse = abs(angleDiff) < 0.4 && Int.random(in: 0..<100) < 55
        case .banana:
            shouldUse = Int.random(in: 0..<100) < 35
        case .soda, .turkey:
            // Fire if someone is roughly ahead
            let ahead = rivals.first { rival in
                rival !== cart && rival.raceProgress > cart.raceProgress - 0.05
            }
            shouldUse = ahead != nil && Int.random(in: 0..<100) < 45
        }

        if shouldUse {
            itemCooldown = TimeInterval.random(in: 2.5...5.0)
            NotificationCenter.default.post(
                name: .aiWantsItemUse,
                object: nil,
                userInfo: ["cart": cart]
            )
        }
    }
}

extension Notification.Name {
    static let aiWantsItemUse = Notification.Name("aiWantsItemUse")
}
