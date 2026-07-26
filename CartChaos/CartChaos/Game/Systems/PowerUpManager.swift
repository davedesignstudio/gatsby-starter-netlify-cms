import SpriteKit

final class PowerUpManager {
    private weak var scene: SKScene?
    private var pickups: [SKNode] = []
    private var hazards: [SKNode] = []
    private let waypoints: [TrackWaypoint]

    init(scene: SKScene, waypoints: [TrackWaypoint]) {
        self.scene = scene
        self.waypoints = waypoints
        spawnPickups()
    }

    private func spawnPickups() {
        guard let scene else { return }

        let spawnIndices = stride(from: 0, to: waypoints.count, by: 2)
        for index in spawnIndices {
            let wp = waypoints[index]
            let type = PowerUpType.allCases.randomElement() ?? .couponBoost
            let pickup = createPickup(type: type)
            let offset = CGFloat.random(in: -30...30)
            pickup.position = CGPoint(x: wp.position.x + offset, y: wp.position.y + offset)
            pickup.name = "pickup"
            pickup.userData = NSMutableDictionary()
            pickup.userData?["type"] = type.rawValue
            scene.addChild(pickup)
            pickups.append(pickup)

            let spin = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 2))
            pickup.run(spin)
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 6, duration: 0.6),
                SKAction.moveBy(x: 0, y: -6, duration: 0.6)
            ])
            pickup.run(SKAction.repeatForever(bob))
        }
    }

    private func createPickup(type: PowerUpType) -> SKNode {
        let container = SKNode()
        container.zPosition = 5

        let glow = SKShapeNode(circleOfRadius: 18)
        glow.fillColor = type.color.withAlphaComponent(0.25)
        glow.strokeColor = type.color.withAlphaComponent(0.6)
        glow.lineWidth = 2
        container.addChild(glow)

        let icon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        icon.text = type.iconLetter
        icon.fontSize = 20
        icon.fontColor = type.color
        icon.verticalAlignmentMode = .center
        container.addChild(icon)

        return container
    }

    func checkCollisions(for cart: ShoppingCart) -> PowerUpType? {
        guard let scene else { return nil }

        for pickup in pickups {
            guard pickup.parent != nil else { continue }
            let dist = hypot(pickup.position.x - cart.position.x, pickup.position.y - cart.position.y)
            if dist < 30 {
                let raw = pickup.userData?["type"] as? String ?? ""
                let type = PowerUpType(rawValue: raw) ?? .couponBoost
                pickup.removeFromParent()
                respawnPickup(near: pickup.position)
                return type
            }
        }
        return nil
    }

    private func respawnPickup(near point: CGPoint) {
        guard let scene else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, let scene = self.scene else { return }
            let type = PowerUpType.allCases.randomElement() ?? .couponBoost
            let pickup = self.createPickup(type: type)
            pickup.position = point
            pickup.name = "pickup"
            pickup.userData = NSMutableDictionary()
            pickup.userData?["type"] = type.rawValue
            scene.addChild(pickup)
            self.pickups.append(pickup)
            pickup.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 2)))
        }
    }

    func deployHazard(type: PowerUpType, at position: CGPoint, from cart: ShoppingCart) {
        guard let scene else { return }

        switch type {
        case .couponBoost:
            cart.activateBoost()
        case .paperBagShield:
            cart.activateShield()
        case .wetFloorSign:
            let sign = createWetFloorSign()
            sign.position = position
            scene.addChild(sign)
            hazards.append(sign)
            removeAfterDelay(sign, seconds: 8)
        case .spilledSoda:
            let spill = createSodaSpill()
            spill.position = position
            scene.addChild(spill)
            hazards.append(spill)
            removeAfterDelay(spill, seconds: 6)
        }
    }

    func checkHazardCollisions(for cart: ShoppingCart) {
        for hazard in hazards {
            guard hazard.parent != nil else { continue }
            let dist = hypot(hazard.position.x - cart.position.x, hazard.position.y - cart.position.y)
            if dist < 25 {
                if hazard.name == "wetfloor" || hazard.name == "soda" {
                    cart.stun(for: 1.2)
                }
            }
        }
    }

    private func createWetFloorSign() -> SKNode {
        let sign = SKNode()
        sign.name = "wetfloor"
        sign.zPosition = 4

        let triangle = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 14))
        path.addLine(to: CGPoint(x: -12, y: -10))
        path.addLine(to: CGPoint(x: 12, y: -10))
        path.closeSubpath()
        triangle.path = path
        triangle.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1)
        triangle.strokeColor = .black
        triangle.lineWidth = 1
        sign.addChild(triangle)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "!"
        label.fontSize = 14
        label.fontColor = .black
        label.position = CGPoint(x: 0, y: -6)
        label.verticalAlignmentMode = .center
        sign.addChild(label)

        return sign
    }

    private func createSodaSpill() -> SKNode {
        let spill = SKShapeNode(circleOfRadius: 22)
        spill.name = "soda"
        spill.fillColor = SKColor(red: 0.45, green: 0.1, blue: 0.55, alpha: 0.7)
        spill.strokeColor = SKColor(red: 0.6, green: 0.2, blue: 0.7, alpha: 1)
        spill.lineWidth = 2
        spill.zPosition = 3
        return spill
    }

    private func removeAfterDelay(_ node: SKNode, seconds: TimeInterval) {
        node.run(SKAction.sequence([
            SKAction.wait(forDuration: seconds),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
}
