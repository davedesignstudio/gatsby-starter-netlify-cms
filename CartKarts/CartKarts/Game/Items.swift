import SpriteKit

// MARK: - Item kinds

enum ItemKind: CaseIterable {
    /// Off-brand energy soda: short speed boost.
    case turboCola
    /// Classic. Dropped behind the cart; spins out whoever runs it over.
    case bananaPeel
    /// Expired cream of mushroom, fired forward. Ricochets off shelves.
    case soupCan

    var displayName: String {
        switch self {
        case .turboCola: return "Turbo Cola"
        case .bananaPeel: return "Banana Peel"
        case .soupCan: return "Soup Can"
        }
    }

    var icon: SKTexture {
        switch self {
        case .turboCola: return TextureFactory.colaCan
        case .bananaPeel: return TextureFactory.banana
        case .soupCan: return TextureFactory.soupCan
        }
    }

    static func random() -> ItemKind {
        allCases.randomElement() ?? .turboCola
    }
}

// MARK: - Item box (mystery grocery bag)

final class ItemBoxNode: SKSpriteNode {
    private(set) var isAvailable = true

    init(position: CGPoint) {
        let texture = TextureFactory.itemBag
        super.init(texture: texture, color: .clear, size: texture.size())
        self.position = position
        zPosition = 5

        let body = SKPhysicsBody(circleOfRadius: 26)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.itemBox
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.kart
        physicsBody = body

        run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.5), .rotate(toAngle: 0.12, duration: 0.5)]),
            .group([.scale(to: 0.95, duration: 0.5), .rotate(toAngle: -0.12, duration: 0.5)]),
        ])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Consumes the box and schedules its respawn.
    func collect() {
        guard isAvailable else { return }
        isAvailable = false
        run(.sequence([
            .group([.scale(to: 1.6, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .wait(forDuration: 4.0),
            .scale(to: 0.1, duration: 0),
            .fadeIn(withDuration: 0.1),
            .scale(to: 1.0, duration: 0.25),
            .run { [weak self] in self?.isAvailable = true },
        ]))
    }
}

// MARK: - Deployed hazards

/// Common bookkeeping for things one cart deploys against the others.
protocol DeployedItem: SKNode {
    var owner: Kart? { get }
    var armedAt: TimeInterval { get }
}

final class BananaNode: SKSpriteNode, DeployedItem {
    weak private(set) var ownerKart: Kart?
    var owner: Kart? { ownerKart }
    let armedAt: TimeInterval

    init(position: CGPoint, owner: Kart?, now: TimeInterval) {
        let texture = TextureFactory.banana
        armedAt = now + 0.5
        ownerKart = owner
        super.init(texture: texture, color: .clear, size: texture.size())
        self.position = position
        zPosition = 4
        zRotation = CGFloat.random(in: 0...(2 * .pi))

        let body = SKPhysicsBody(circleOfRadius: 18)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.banana
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.kart
        physicsBody = body

        setScale(0.2)
        run(.scale(to: 1.0, duration: 0.15))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func squish() {
        physicsBody = nil
        run(.sequence([
            .group([.scaleX(to: 1.5, y: 0.3, duration: 0.15), .fadeOut(withDuration: 0.2)]),
            .removeFromParent(),
        ]))
    }
}

final class CanNode: SKSpriteNode, DeployedItem {
    weak private(set) var ownerKart: Kart?
    var owner: Kart? { ownerKart }
    let armedAt: TimeInterval
    var bounces = 0

    init(position: CGPoint, velocity: CGPoint, owner: Kart?, now: TimeInterval) {
        let texture = TextureFactory.soupCan
        armedAt = now + 0.25
        ownerKart = owner
        super.init(texture: texture, color: .clear, size: texture.size())
        self.position = position
        zPosition = 12

        let body = SKPhysicsBody(circleOfRadius: 15)
        body.mass = 0.4
        body.friction = 0
        body.restitution = 1.0
        body.linearDamping = 0
        body.allowsRotation = true
        body.categoryBitMask = PhysicsCategory.can
        body.collisionBitMask = PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.kart | PhysicsCategory.wall
        physicsBody = body
        body.velocity = CGVector(point: velocity)

        run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.4)))
        run(.sequence([.wait(forDuration: 4.0), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func explode() {
        physicsBody = nil
        removeAllActions()
        run(.sequence([
            .group([.scale(to: 1.8, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent(),
        ]))
    }
}

/// Permanent track hazard: spilled milk. Slippery, obviously.
final class PuddleNode: SKSpriteNode {
    init(position: CGPoint) {
        let texture = TextureFactory.puddle
        super.init(texture: texture, color: .clear, size: texture.size())
        self.position = position
        zPosition = -80
        zRotation = CGFloat.random(in: 0...(2 * .pi))

        let body = SKPhysicsBody(circleOfRadius: 55)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.puddle
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.kart
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }
}
