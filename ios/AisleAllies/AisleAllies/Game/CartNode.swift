import SpriteKit

final class CartNode: SKNode {
    let displayName: String
    let isPlayer: Bool
    var raceProgress: RaceProgress
    var targetWaypoint = 1
    var pantryItems = 0
    var boostCharges = 1

    private(set) var heading: CGFloat
    private var speed: CGFloat = 0
    private var boostTimeRemaining: TimeInterval = 0
    private var slowTimeRemaining: TimeInterval = 0
    private var spinTimeRemaining: TimeInterval = 0
    private let maximumSpeed: CGFloat

    init(
        name: String,
        color: SKColor,
        isPlayer: Bool,
        heading: CGFloat = 0,
        checkpointCount: Int
    ) {
        displayName = name
        self.isPlayer = isPlayer
        self.heading = heading
        maximumSpeed = isPlayer ? 430 : CGFloat.random(in: 350...405)
        raceProgress = RaceProgress(checkpointCount: checkpointCount)
        super.init()

        self.name = isPlayer ? "playerCart" : "rivalCart"
        zPosition = 20
        zRotation = heading
        buildCart(color: color)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 82, height: 46))
        body.allowsRotation = false
        body.linearDamping = 1.2
        body.restitution = 0.28
        body.friction = 0.2
        body.mass = 1.2
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.cart
        body.collisionBitMask = PhysicsCategory.cart | PhysicsCategory.wall
        body.contactTestBitMask =
            PhysicsCategory.pantryItem |
            PhysicsCategory.spill |
            PhysicsCategory.boostPad
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePlayer(deltaTime: TimeInterval, steering: CGFloat, canDrive: Bool) {
        tickEffects(deltaTime)
        guard canDrive else {
            physicsBody?.velocity = .zero
            return
        }

        let speedRatio = min(1, abs(speed) / maximumSpeed)
        let steeringRate: CGFloat = 2.65 * (0.35 + speedRatio * 0.65)
        heading -= steering * steeringRate * CGFloat(deltaTime)
        if spinTimeRemaining > 0 {
            heading += 7.5 * CGFloat(deltaTime)
        }

        let targetSpeed = currentMaximumSpeed
        speed += (targetSpeed - speed) * min(1, CGFloat(deltaTime) * 2.4)
        applyVelocity()
    }

    func updateAI(deltaTime: TimeInterval, waypoint: CGPoint, canDrive: Bool) {
        tickEffects(deltaTime)
        guard canDrive else {
            physicsBody?.velocity = .zero
            return
        }

        let desiredHeading = atan2(waypoint.y - position.y, waypoint.x - position.x)
        let difference = normalizedAngle(desiredHeading - heading)
        let maximumTurn = CGFloat(deltaTime) * 2.1
        heading += max(-maximumTurn, min(maximumTurn, difference))
        if spinTimeRemaining > 0 {
            heading += 7 * CGFloat(deltaTime)
        }

        let cornerSlowdown = min(1, 1.15 - abs(difference) / .pi)
        let targetSpeed = currentMaximumSpeed * max(0.7, cornerSlowdown)
        speed += (targetSpeed - speed) * min(1, CGFloat(deltaTime) * 1.8)
        applyVelocity()
    }

    @discardableResult
    func useBoost() -> Bool {
        guard boostCharges > 0, boostTimeRemaining <= 0 else { return false }
        boostCharges -= 1
        boostTimeRemaining = 1.35
        run(.sequence([
            .scale(to: 1.14, duration: 0.1),
            .scale(to: 1, duration: 0.28)
        ]))
        return true
    }

    func collectPantryItem() {
        pantryItems += 1
        if pantryItems.isMultiple(of: 3) {
            boostCharges = min(3, boostCharges + 1)
        }
    }

    func hitSpill() {
        slowTimeRemaining = 1.6
        spinTimeRemaining = 0.52
    }

    func hitBoostPad() {
        boostTimeRemaining = max(boostTimeRemaining, 0.8)
    }

    private var currentMaximumSpeed: CGFloat {
        let boostMultiplier: CGFloat = boostTimeRemaining > 0 ? 1.58 : 1
        let slowMultiplier: CGFloat = slowTimeRemaining > 0 ? 0.48 : 1
        return maximumSpeed * boostMultiplier * slowMultiplier
    }

    private func tickEffects(_ deltaTime: TimeInterval) {
        boostTimeRemaining = max(0, boostTimeRemaining - deltaTime)
        slowTimeRemaining = max(0, slowTimeRemaining - deltaTime)
        spinTimeRemaining = max(0, spinTimeRemaining - deltaTime)
    }

    private func applyVelocity() {
        zRotation = heading
        childNode(withName: "nameLabel")?.zRotation = -heading
        let forward = CGVector(dx: cos(heading), dy: sin(heading))
        physicsBody?.velocity = CGVector(dx: forward.dx * speed, dy: forward.dy * speed)
    }

    private func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle
        while result > .pi { result -= .pi * 2 }
        while result < -.pi { result += .pi * 2 }
        return result
    }

    private func buildCart(color: SKColor) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 88, height: 48))
        shadow.fillColor = .black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: -4, y: -6)
        shadow.zPosition = -2
        addChild(shadow)

        let frame = SKShapeNode(rectOf: CGSize(width: 78, height: 42), cornerRadius: 9)
        frame.fillColor = color
        frame.strokeColor = .white.withAlphaComponent(0.85)
        frame.lineWidth = 4
        addChild(frame)

        let basket = SKShapeNode(rectOf: CGSize(width: 42, height: 31), cornerRadius: 6)
        basket.fillColor = color.withAlphaComponent(0.6)
        basket.strokeColor = .white.withAlphaComponent(0.7)
        basket.lineWidth = 2
        basket.position.x = 7
        addChild(basket)

        for x in [-5, 7, 19] {
            let rail = SKShapeNode(rectOf: CGSize(width: 2, height: 26))
            rail.fillColor = .white.withAlphaComponent(0.55)
            rail.strokeColor = .clear
            rail.position.x = CGFloat(x)
            basket.addChild(rail)
        }

        let handle = SKShapeNode(rectOf: CGSize(width: 13, height: 48), cornerRadius: 4)
        handle.fillColor = .darkGray
        handle.strokeColor = .white.withAlphaComponent(0.8)
        handle.lineWidth = 2
        handle.position.x = -46
        addChild(handle)

        for y in [-21, 21] {
            let wheel = SKShapeNode(circleOfRadius: 7)
            wheel.fillColor = .black
            wheel.strokeColor = .white
            wheel.lineWidth = 2
            wheel.position = CGPoint(x: 24, y: CGFloat(y))
            wheel.zPosition = 2
            addChild(wheel)
        }

        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 48, y: 0))
        arrowPath.addLine(to: CGPoint(x: 34, y: 10))
        arrowPath.addLine(to: CGPoint(x: 34, y: -10))
        arrowPath.closeSubpath()
        let nose = SKShapeNode(path: arrowPath)
        nose.fillColor = .yellow
        nose.strokeColor = .clear
        addChild(nose)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = displayName
        label.fontSize = 14
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 38)
        label.zRotation = -heading
        label.name = "nameLabel"
        addChild(label)
    }
}
