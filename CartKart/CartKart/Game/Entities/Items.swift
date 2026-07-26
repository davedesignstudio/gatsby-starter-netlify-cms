import SpriteKit
import UIKit

final class ItemBox: SKNode {
    private let cube: SKShapeNode
    private let label: SKLabelNode
    private(set) var active = true
    private var respawnTimer: TimeInterval = 0

    override init() {
        cube = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 6)
        cube.fillColor = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
        cube.strokeColor = UIColor(white: 1, alpha: 0.9)
        cube.lineWidth = 2

        label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "?"
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        super.init()
        zPosition = 20
        addChild(cube)
        addChild(label)

        let body = SKPhysicsBody(circleOfRadius: 16)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.itemBox
        body.contactTestBitMask = PhysicsCategory.cart
        body.collisionBitMask = 0
        physicsBody = body

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.45)
        ])
        run(SKAction.repeatForever(pulse))
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 2.4)
        cube.run(SKAction.repeatForever(spin))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func collect() -> PowerUpKind? {
        guard active else { return nil }
        active = false
        isHidden = true
        physicsBody?.categoryBitMask = 0
        respawnTimer = 5.0
        return PowerUpKind.allCases.randomElement()
    }

    func update(delta: TimeInterval) {
        guard !active else { return }
        respawnTimer -= delta
        if respawnTimer <= 0 {
            active = true
            isHidden = false
            physicsBody?.categoryBitMask = PhysicsCategory.itemBox
            setScale(0.1)
            run(SKAction.scale(to: 1.0, duration: 0.25))
        }
    }
}

final class HazardNode: SKNode {
    let kind: PowerUpKind
    private var life: TimeInterval = 12

    init(kind: PowerUpKind) {
        self.kind = kind
        super.init()
        zPosition = 15
        name = "hazard"

        let shape: SKShapeNode
        switch kind {
        case .banana:
            shape = SKShapeNode(ellipseOf: CGSize(width: 22, height: 14))
            shape.fillColor = PowerUpKind.banana.tint
            shape.strokeColor = UIColor(red: 0.7, green: 0.55, blue: 0.1, alpha: 1)
        case .wetFloor:
            shape = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
            shape.fillColor = PowerUpKind.wetFloor.tint
            shape.strokeColor = .black
            let mark = SKLabelNode(fontNamed: "AvenirNext-Bold")
            mark.text = "WET"
            mark.fontSize = 9
            mark.fontColor = .black
            mark.verticalAlignmentMode = .center
            addChild(mark)
        default:
            shape = SKShapeNode(circleOfRadius: 10)
            shape.fillColor = kind.tint
            shape.strokeColor = .clear
        }
        shape.lineWidth = 1.5
        addChild(shape)

        let body = SKPhysicsBody(circleOfRadius: kind == .wetFloor ? 18 : 12)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.cart
        body.collisionBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(delta: TimeInterval) -> Bool {
        life -= delta
        if life < 2 {
            alpha = CGFloat(life / 2)
        }
        return life <= 0
    }
}

final class ProjectileNode: SKNode {
    let ownerId: String
    var velocity = CGVector.zero
    private var life: TimeInterval = 2.5

    init(ownerId: String, heading: CGFloat) {
        self.ownerId = ownerId
        super.init()
        zPosition = 40
        name = "projectile"

        let can = SKShapeNode(rectOf: CGSize(width: 14, height: 18), cornerRadius: 3)
        can.fillColor = PowerUpKind.cannedGoods.tint
        can.strokeColor = UIColor(white: 0.2, alpha: 1)
        can.lineWidth = 1
        addChild(can)
        zRotation = heading

        let speed: CGFloat = 520
        velocity = CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed)

        let body = SKPhysicsBody(circleOfRadius: 10)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.projectile
        body.contactTestBitMask = PhysicsCategory.cart | PhysicsCategory.wall
        body.collisionBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(delta: TimeInterval) -> Bool {
        position.x += velocity.dx * CGFloat(delta)
        position.y += velocity.dy * CGFloat(delta)
        zRotation += CGFloat(delta) * 10
        life -= delta
        return life <= 0
    }
}
