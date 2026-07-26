import SpriteKit

enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let boost: UInt32 = 1 << 2
    static let hazard: UInt32 = 1 << 3
}

final class CartNode: SKNode {
    let isPlayer: Bool
    var speed: CGFloat = 0
    var heading: CGFloat = 0
    var routeTargetIndex = 1
    var completedLaps = 0
    var hasFinished = false
    var cruiseSpeed: CGFloat = 300

    init(color: SKColor, cartName: String, isPlayer: Bool) {
        self.isPlayer = isPlayer
        super.init()

        name = cartName
        zPosition = 20
        buildCart(color: color)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 108, height: 68))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0.8
        body.restitution = 0.25
        body.friction = 0.35
        body.categoryBitMask = PhysicsCategory.cart
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        body.contactTestBitMask = PhysicsCategory.boost | PhysicsCategory.hazard
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildCart(color: SKColor) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 116, height: 72))
        shadow.fillColor = SKColor(white: 0.05, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: -3, y: -5)
        shadow.zPosition = -2
        addChild(shadow)

        let basket = SKShapeNode(rectOf: CGSize(width: 84, height: 58), cornerRadius: 9)
        basket.fillColor = color.withAlphaComponent(0.82)
        basket.strokeColor = SKColor(white: 0.92, alpha: 1)
        basket.lineWidth = 4
        basket.position.x = 9
        addChild(basket)

        for x in stride(from: -20, through: 36, by: 14) {
            let bar = SKShapeNode(rectOf: CGSize(width: 2, height: 49))
            bar.fillColor = SKColor(white: 0.95, alpha: 0.75)
            bar.strokeColor = .clear
            bar.position.x = CGFloat(x)
            basket.addChild(bar)
        }

        let nose = SKShapeNode(rectOf: CGSize(width: 18, height: 48), cornerRadius: 5)
        nose.fillColor = color
        nose.strokeColor = .white
        nose.lineWidth = 3
        nose.position.x = 56
        addChild(nose)

        let handleStem = SKShapeNode(rectOf: CGSize(width: 6, height: 66), cornerRadius: 3)
        handleStem.fillColor = SKColor(white: 0.85, alpha: 1)
        handleStem.strokeColor = .clear
        handleStem.position.x = -44
        addChild(handleStem)

        let handle = SKShapeNode(rectOf: CGSize(width: 14, height: 72), cornerRadius: 6)
        handle.fillColor = color
        handle.strokeColor = SKColor(white: 0.95, alpha: 1)
        handle.lineWidth = 2
        handle.position.x = -51
        addChild(handle)

        for x in [CGFloat(-31), CGFloat(39)] {
            for y in [CGFloat(-35), CGFloat(35)] {
                let wheel = SKShapeNode(circleOfRadius: 9)
                wheel.fillColor = SKColor(white: 0.08, alpha: 1)
                wheel.strokeColor = SKColor(white: 0.75, alpha: 1)
                wheel.lineWidth = 2
                wheel.position = CGPoint(x: x, y: y)
                wheel.zPosition = 2
                addChild(wheel)
            }
        }

        if isPlayer {
            let marker = SKShapeNode(circleOfRadius: 10)
            marker.fillColor = .white
            marker.strokeColor = color
            marker.lineWidth = 4
            marker.position = CGPoint(x: 8, y: 0)
            marker.zPosition = 5
            addChild(marker)
        }
    }

    func reset(at position: CGPoint, heading: CGFloat = 0) {
        self.position = position
        self.heading = heading
        zRotation = heading
        speed = 0
        routeTargetIndex = 1
        completedLaps = 0
        hasFinished = false
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
    }
}
