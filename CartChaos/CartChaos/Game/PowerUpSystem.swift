import SpriteKit

final class PowerUpSystem {
    weak var world: SKNode?
    private var boxes: [SKNode] = []
    private var hazards: [SKNode] = []
    private var projectiles: [SKNode] = []
    private let spawnPoints: [CGPoint]

    init(world: SKNode, spawnPoints: [CGPoint]) {
        self.world = world
        self.spawnPoints = spawnPoints
        respawnAllBoxes()
    }

    func respawnAllBoxes() {
        boxes.forEach { $0.removeFromParent() }
        boxes.removeAll()
        for p in spawnPoints {
            spawnBox(at: p)
        }
    }

    private func spawnBox(at point: CGPoint) {
        guard let world else { return }
        let box = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 4)
        box.fillColor = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        box.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.05, alpha: 1)
        box.lineWidth = 2
        box.position = point
        box.zPosition = 4
        box.name = "itembox"
        box.userData = ["ready": true]

        let mark = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        mark.text = "?"
        mark.fontSize = 18
        mark.fontColor = UIColor(red: 0.45, green: 0.25, blue: 0.05, alpha: 1)
        mark.verticalAlignmentMode = .center
        box.addChild(mark)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.45)
        ])
        box.run(.repeatForever(pulse))

        world.addChild(box)
        boxes.append(box)
    }

    func update(carts: [CartNode], dt: TimeInterval) {
        for cart in carts where !cart.finished {
            // Pickup boxes
            if cart.heldItem == nil {
                for box in boxes {
                    guard (box.userData?["ready"] as? Bool) == true else { continue }
                    if hypot(cart.position.x - box.position.x, cart.position.y - box.position.y) < 30 {
                        cart.heldItem = PowerUpKind.allCases.randomElement()
                        box.userData?["ready"] = false
                        box.alpha = 0.15
                        box.run(.sequence([
                            .wait(forDuration: 4.5),
                            .run { [weak box] in
                                box?.alpha = 1
                                box?.userData?["ready"] = true
                            }
                        ]))
                        flash(at: box.position, color: .yellow)
                    }
                }
            }

            // Hazards
            for hazard in hazards {
                if hypot(cart.position.x - hazard.position.x, cart.position.y - hazard.position.y) < 26 {
                    cart.hitByHazard()
                    hazard.removeFromParent()
                    hazards.removeAll { $0 == hazard }
                    flash(at: cart.position, color: .orange)
                    break
                }
            }

            // Projectiles
            for proj in projectiles {
                if proj.userData?["owner"] as? String == cart.name { continue }
                if hypot(cart.position.x - proj.position.x, cart.position.y - proj.position.y) < 28 {
                    cart.hitByHazard()
                    proj.removeFromParent()
                    projectiles.removeAll { $0 == proj }
                    flash(at: cart.position, color: .red)
                    break
                }
            }
        }

        // Move projectiles
        for proj in projectiles {
            let vx = (proj.userData?["vx"] as? CGFloat) ?? 0
            let vy = (proj.userData?["vy"] as? CGFloat) ?? 0
            proj.position.x += vx * CGFloat(dt)
            proj.position.y += vy * CGFloat(dt)
            var life = (proj.userData?["life"] as? TimeInterval) ?? 0
            life -= dt
            proj.userData?["life"] = life
            if life <= 0 {
                proj.removeFromParent()
            }
        }
        projectiles.removeAll { $0.parent == nil }
    }

    func useItem(for cart: CartNode) {
        guard let kind = cart.heldItem else { return }
        cart.heldItem = nil
        switch kind {
        case .banana:
            dropBanana(from: cart)
        case .soda:
            cart.activateBoost()
            flash(at: cart.position, color: UIColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1))
        case .soup:
            fireSoup(from: cart)
        case .coupon:
            cart.activateShield()
        }
    }

    private func dropBanana(from cart: CartNode) {
        guard let world else { return }
        let peel = SKShapeNode(ellipseOf: CGSize(width: 22, height: 14))
        peel.fillColor = PowerUpKind.banana.color
        peel.strokeColor = UIColor(red: 0.6, green: 0.45, blue: 0.05, alpha: 1)
        peel.lineWidth = 1.5
        peel.position = CGPoint(
            x: cart.position.x - cos(cart.heading) * 40,
            y: cart.position.y - sin(cart.heading) * 40
        )
        peel.zPosition = 3
        peel.name = "banana"
        world.addChild(peel)
        hazards.append(peel)
    }

    private func fireSoup(from cart: CartNode) {
        guard let world else { return }
        let can = SKShapeNode(rectOf: CGSize(width: 14, height: 18), cornerRadius: 3)
        can.fillColor = PowerUpKind.soup.color
        can.strokeColor = .white
        can.lineWidth = 1
        can.position = CGPoint(
            x: cart.position.x + cos(cart.heading) * 36,
            y: cart.position.y + sin(cart.heading) * 36
        )
        can.zRotation = cart.heading
        can.zPosition = 8
        let speed: CGFloat = 520
        can.userData = [
            "vx": cos(cart.heading) * speed,
            "vy": sin(cart.heading) * speed,
            "life": 2.2,
            "owner": cart.name ?? ""
        ]
        world.addChild(can)
        projectiles.append(can)
    }

    private func flash(at point: CGPoint, color: UIColor) {
        guard let world else { return }
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.position = point
        ring.zPosition = 20
        world.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 3.5, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ]),
            .removeFromParent()
        ]))
    }
}
