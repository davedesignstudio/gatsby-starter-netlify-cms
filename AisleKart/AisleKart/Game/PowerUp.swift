import SpriteKit

enum PowerUpType: CaseIterable {
    case banana
    case soda
    case shield
    case boost
    case turkey

    var emoji: String {
        switch self {
        case .banana: return "🍌"
        case .soda: return "🥫"
        case .shield: return "🛡️"
        case .boost: return "⚡"
        case .turkey: return "🦃"
        }
    }

    var label: String {
        switch self {
        case .banana: return "Banana"
        case .soda: return "Soda Spray"
        case .shield: return "Cart Shield"
        case .boost: return "Express"
        case .turkey: return "Frozen Turkey"
        }
    }

    static func random() -> PowerUpType {
        // Slight weight toward bananas / soda for chaos
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<28: return .banana
        case 28..<50: return .soda
        case 50..<68: return .boost
        case 68..<84: return .shield
        default: return .turkey
        }
    }
}

final class ItemBoxNode: SKNode {
    private let bag: SKShapeNode
    private var respawnTimer: TimeInterval = 0
    private(set) var isAvailable = true

    override init() {
        bag = SKShapeNode(rectOf: CGSize(width: 28, height: 32), cornerRadius: 4)
        bag.fillColor = UIColor(red: 0.2, green: 0.55, blue: 0.35, alpha: 1)
        bag.strokeColor = UIColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1)
        bag.lineWidth = 2.5

        super.init()

        let q = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        q.text = "?"
        q.fontSize = 18
        q.fontColor = .white
        q.verticalAlignmentMode = .center
        q.horizontalAlignmentMode = .center
        q.position = CGPoint(x: 0, y: 1)

        addChild(bag)
        addChild(q)

        let physics = SKPhysicsBody(rectangleOf: CGSize(width: 28, height: 32))
        physics.isDynamic = false
        physics.categoryBitMask = PhysicsCategory.itemBox
        physics.collisionBitMask = 0
        physics.contactTestBitMask = PhysicsCategory.cart
        physicsBody = physics
        name = "itemBox"
        zPosition = 20

        run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 0.45),
            .scale(to: 0.95, duration: 0.45)
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func collect() {
        guard isAvailable else { return }
        isAvailable = false
        alpha = 0.15
        respawnTimer = 5.0
        physicsBody?.categoryBitMask = 0
    }

    func update(delta: TimeInterval) {
        guard !isAvailable else { return }
        respawnTimer -= delta
        if respawnTimer <= 0 {
            isAvailable = true
            alpha = 1
            physicsBody?.categoryBitMask = PhysicsCategory.itemBox
        }
    }
}

final class BananaHazard: SKNode {
    let ownerIndex: Int

    init(ownerIndex: Int) {
        self.ownerIndex = ownerIndex
        super.init()

        let peel = SKShapeNode(ellipseOf: CGSize(width: 22, height: 14))
        peel.fillColor = UIColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1)
        peel.strokeColor = UIColor(red: 0.75, green: 0.6, blue: 0.1, alpha: 1)
        peel.lineWidth = 1.5
        addChild(peel)

        let physics = SKPhysicsBody(circleOfRadius: 10)
        physics.isDynamic = false
        physics.categoryBitMask = PhysicsCategory.hazard
        physics.collisionBitMask = 0
        physics.contactTestBitMask = PhysicsCategory.cart
        physicsBody = physics
        name = "banana"
        zPosition = 15

        run(.sequence([.wait(forDuration: 12), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class TurkeyProjectile: SKNode {
    let ownerIndex: Int
    private var life: TimeInterval = 4
    private weak var target: CartNode?

    init(ownerIndex: Int, target: CartNode?) {
        self.ownerIndex = ownerIndex
        self.target = target
        super.init()

        let bird = SKLabelNode(fontNamed: "AppleColorEmoji")
        bird.text = "🦃"
        bird.fontSize = 22
        bird.verticalAlignmentMode = .center
        bird.horizontalAlignmentMode = .center
        addChild(bird)

        let physics = SKPhysicsBody(circleOfRadius: 12)
        physics.affectedByGravity = false
        physics.allowsRotation = false
        physics.categoryBitMask = PhysicsCategory.projectile
        physics.collisionBitMask = PhysicsCategory.wall
        physics.contactTestBitMask = PhysicsCategory.cart
        physics.linearDamping = 0.1
        physicsBody = physics
        name = "turkey"
        zPosition = 40
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(delta: TimeInterval) {
        life -= delta
        if life <= 0 {
            removeFromParent()
            return
        }
        guard let target, target.parent != nil else { return }
        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let dist = max(1, hypot(dx, dy))
        let speed: CGFloat = 320
        physicsBody?.velocity = CGVector(dx: dx / dist * speed, dy: dy / dist * speed)
        zRotation = atan2(dx, dy)
    }
}
