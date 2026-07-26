import SpriteKit
import UIKit

final class ItemPadNode: SKNode {
    private let glow: SKShapeNode
    private let icon: SKLabelNode
    private(set) var isActive = true
    private var respawnTimer: TimeInterval = 0

    override init() {
        glow = SKShapeNode(circleOfRadius: 22)
        glow.fillColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.35)
        glow.strokeColor = UIColor(red: 1, green: 0.75, blue: 0.1, alpha: 0.9)
        glow.lineWidth = 2

        icon = SKLabelNode(text: "?")
        icon.fontName = "AvenirNext-Heavy"
        icon.fontSize = 22
        icon.fontColor = UIColor(red: 0.35, green: 0.2, blue: 0.05, alpha: 1)
        icon.verticalAlignmentMode = .center

        super.init()
        zPosition = 10
        addChild(glow)
        addChild(icon)

        physicsBody = SKPhysicsBody(circleOfRadius: 20)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.item
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = PhysicsCategory.cart

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.45)
        ])
        glow.run(SKAction.repeatForever(pulse))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func collect() {
        guard isActive else { return }
        isActive = false
        glow.isHidden = true
        icon.isHidden = true
        physicsBody?.categoryBitMask = 0
        respawnTimer = 5
    }

    func update(deltaTime: TimeInterval) {
        guard !isActive else { return }
        respawnTimer -= deltaTime
        if respawnTimer <= 0 {
            isActive = true
            glow.isHidden = false
            icon.isHidden = false
            physicsBody?.categoryBitMask = PhysicsCategory.item
        }
    }
}

final class HazardNode: SKNode {
    let kind: PowerUpType
    private let owner: CartNode?

    init(kind: PowerUpType, at point: CGPoint, owner: CartNode?) {
        self.kind = kind
        self.owner = owner
        super.init()
        position = point
        zPosition = 12
        name = "hazard"

        let label = SKLabelNode(text: kind.label)
        label.fontSize = kind == .banana ? 28 : 24
        label.verticalAlignmentMode = .center
        addChild(label)

        physicsBody = SKPhysicsBody(circleOfRadius: 16)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.hazard
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = PhysicsCategory.cart
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func shouldAffect(_ cart: CartNode) -> Bool {
        cart !== owner
    }
}

final class ProjectileNode: SKNode {
    let kind: PowerUpType
    let owner: CartNode
    var velocity: CGVector
    private var life: TimeInterval = 2.2
    var homingTarget: CartNode?

    init(kind: PowerUpType, owner: CartNode, velocity: CGVector) {
        self.kind = kind
        self.owner = owner
        self.velocity = velocity
        super.init()
        zPosition = 15
        name = "projectile"

        let label = SKLabelNode(text: kind.label)
        label.fontSize = 22
        label.verticalAlignmentMode = .center
        addChild(label)

        physicsBody = SKPhysicsBody(circleOfRadius: 14)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = PhysicsCategory.hazard
        physicsBody?.collisionBitMask = PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.cart | PhysicsCategory.wall
        physicsBody?.usesPreciseCollisionDetection = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(deltaTime: TimeInterval) -> Bool {
        life -= deltaTime
        if let target = homingTarget, kind == .shoppingList {
            let dx = target.position.x - position.x
            let dy = target.position.y - position.y
            let dist = max(hypot(dx, dy), 1)
            let desired = CGVector(dx: dx / dist * 380, dy: dy / dist * 380)
            velocity.dx += (desired.dx - velocity.dx) * CGFloat(deltaTime) * 4
            velocity.dy += (desired.dy - velocity.dy) * CGFloat(deltaTime) * 4
        }
        position.x += velocity.dx * CGFloat(deltaTime)
        position.y += velocity.dy * CGFloat(deltaTime)
        physicsBody?.velocity = velocity
        return life > 0
    }
}
