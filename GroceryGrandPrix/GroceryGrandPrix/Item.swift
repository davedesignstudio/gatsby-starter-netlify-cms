import SpriteKit

/// A floating pickup that grants a random item on contact, then respawns.
final class ItemBox: SKNode {
    private(set) var active = true
    private var respawnTimer: TimeInterval = 0
    private let visual = SKNode()

    override init() {
        super.init()
        zPosition = 3
        name = "itemBox"

        let box = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)
        box.fillColor = SKColor(red: 0.98, green: 0.85, blue: 0.30, alpha: 0.95)
        box.strokeColor = .white
        box.lineWidth = 3
        visual.addChild(box)

        let mark = SKLabelNode(text: "🛒")
        mark.fontSize = 28
        mark.verticalAlignmentMode = .center
        mark.horizontalAlignmentMode = .center
        visual.addChild(mark)
        addChild(visual)

        visual.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.6),
            .scale(to: 0.94, duration: 0.6)
        ])))

        let pb = SKPhysicsBody(circleOfRadius: 26)
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.itemBox
        pb.collisionBitMask = PhysicsCategory.none
        pb.contactTestBitMask = PhysicsCategory.cart
        physicsBody = pb
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func collect() {
        guard active else { return }
        active = false
        respawnTimer = 3.0
        visual.alpha = 0
        physicsBody?.categoryBitMask = PhysicsCategory.none
    }

    func forceActivate() {
        active = true
        respawnTimer = 0
        visual.alpha = 1
        physicsBody?.categoryBitMask = PhysicsCategory.itemBox
    }

    func update(dt: TimeInterval) {
        guard !active else { return }
        respawnTimer -= dt
        if respawnTimer <= 0 {
            active = true
            visual.alpha = 1
            physicsBody?.categoryBitMask = PhysicsCategory.itemBox
        }
    }
}

/// A slippery milk puddle dropped behind a cart. Spins out the first cart to
/// touch it, then disappears.
final class MilkSlick: SKNode {
    var life: TimeInterval = 8

    init(at point: CGPoint) {
        super.init()
        position = point
        zPosition = 2
        name = "milkSlick"

        let puddle = SKShapeNode(circleOfRadius: 26)
        puddle.fillColor = SKColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 0.9)
        puddle.strokeColor = SKColor(white: 0.85, alpha: 0.9)
        puddle.lineWidth = 2
        addChild(puddle)

        let drop = SKLabelNode(text: "🥛")
        drop.fontSize = 24
        drop.verticalAlignmentMode = .center
        addChild(drop)

        let pb = SKPhysicsBody(circleOfRadius: 24)
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.hazard
        pb.collisionBitMask = PhysicsCategory.none
        pb.contactTestBitMask = PhysicsCategory.cart
        physicsBody = pb

        run(.sequence([.wait(forDuration: 7.5), .fadeOut(withDuration: 0.5)]))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A can hurled forward by a cart. Spins out the first opposing cart it hits.
final class CannedProjectile: SKNode {
    weak var owner: Cart?
    var life: TimeInterval = 2.2

    init(owner: Cart, heading: CGFloat, launchSpeed: CGFloat, from point: CGPoint) {
        self.owner = owner
        super.init()
        position = point
        zPosition = 6
        name = "can"

        let can = SKLabelNode(text: "🥫")
        can.fontSize = 30
        can.verticalAlignmentMode = .center
        addChild(can)
        run(.repeatForever(.rotate(byAngle: 8, duration: 1)))

        let pb = SKPhysicsBody(circleOfRadius: 14)
        pb.affectedByGravity = false
        pb.categoryBitMask = PhysicsCategory.projectile
        pb.collisionBitMask = PhysicsCategory.none
        pb.contactTestBitMask = PhysicsCategory.cart | PhysicsCategory.wall
        pb.velocity = CGVector(dx: cos(heading) * launchSpeed, dy: sin(heading) * launchSpeed)
        pb.linearDamping = 0
        physicsBody = pb
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
