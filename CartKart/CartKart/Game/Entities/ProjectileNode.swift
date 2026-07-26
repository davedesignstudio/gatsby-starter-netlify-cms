import SpriteKit

final class ProjectileNode: SKNode {
    let item: RaceItem
    let ownerID: String
    private let velocity: CGVector

    init(item: RaceItem, ownerID: String, position: CGPoint, angle: CGFloat, speed: CGFloat = 280) {
        self.item = item
        self.ownerID = ownerID
        self.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        super.init()

        self.position = position
        self.zPosition = 8
        self.name = "projectile"

        let shape: SKShapeNode
        switch item {
        case .bananaPeel:
            shape = SKShapeNode(ellipseOf: CGSize(width: 22, height: 14))
            shape.fillColor = .yellow
        case .cardboardBox:
            shape = SKShapeNode(rectOf: CGSize(width: 22, height: 22), cornerRadius: 3)
            shape.fillColor = SKColor(red: 0.6, green: 0.45, blue: 0.25, alpha: 1)
        default:
            shape = SKShapeNode(circleOfRadius: 10)
            shape.fillColor = .white
        }
        shape.strokeColor = .black
        shape.lineWidth = 1.5
        addChild(shape)

        physicsBody = SKPhysicsBody(circleOfRadius: 12)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.linearDamping = 0
        physicsBody?.categoryBitMask = PhysicsCategory.projectile
        physicsBody?.contactTestBitMask = PhysicsCategory.cart
        physicsBody?.collisionBitMask = PhysicsCategory.wall
        physicsBody?.velocity = velocity

        run(.sequence([
            .wait(forDuration: 4),
            .removeFromParent()
        ]))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
