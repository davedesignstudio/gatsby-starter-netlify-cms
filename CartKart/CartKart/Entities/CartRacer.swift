import SpriteKit

final class CartRacer: SKNode {
    let racerName: String
    let isPlayer: Bool
    let playerSlot: Int
    let bodyColor: SKColor
    let cartColor: SKColor

    var driveSpeed: CGFloat = 0
    var maxSpeed: CGFloat = 320
    var acceleration: CGFloat = 520
    var turnRate: CGFloat = 3.8
    var velocity = CGVector(dx: 0, dy: 0)
    var driftFactor: CGFloat = 0
    var boostTimer: TimeInterval = 0
    var slipTimer: TimeInterval = 0
    var spinTimer: TimeInterval = 0
    var heldPowerUp: PowerUpType?
    var lap = 0
    var checkpointIndex = 0
    var racePosition = 1
    var finished = false
    var finishTime: TimeInterval = 0
    var weight: CGFloat = 1.0
    var characterID: String = "will"

    private let cartNode = SKNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 54, height: 28))
    private let wheels: [SKShapeNode]

    init(character: CharacterDefinition, isPlayer: Bool, playerSlot: Int = 0) {
        self.racerName = character.name
        self.isPlayer = isPlayer
        self.playerSlot = playerSlot
        self.bodyColor = character.bodyColor
        self.cartColor = character.cartColor
        self.characterID = character.id

        wheels = (0..<4).map { _ in
            let wheel = SKShapeNode(circleOfRadius: 7)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            return wheel
        }

        super.init()
        self.name = character.name
        character.apply(to: self)
        buildVisuals()
        setupPhysics()
    }

    init(name: String, isPlayer: Bool, playerSlot: Int = 0, bodyColor: SKColor, cartColor: SKColor) {
        self.racerName = name
        self.isPlayer = isPlayer
        self.playerSlot = playerSlot
        self.bodyColor = bodyColor
        self.cartColor = cartColor

        wheels = (0..<4).map { _ in
            let wheel = SKShapeNode(circleOfRadius: 7)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            return wheel
        }

        super.init()
        self.name = name
        buildVisuals()
        setupPhysics()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        shadowNode.fillColor = SKColor(white: 0, alpha: 0.25)
        shadowNode.strokeColor = .clear
        shadowNode.position = CGPoint(x: 0, y: -18)
        shadowNode.zPosition = -2
        addChild(shadowNode)

        let body = SKShapeNode(rectOf: CGSize(width: 22, height: 30), cornerRadius: 8)
        body.fillColor = bodyColor
        body.strokeColor = bodyColor.darker(by: 0.25)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 8)
        cartNode.addChild(body)

        let head = SKShapeNode(circleOfRadius: 10)
        head.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1)
        head.strokeColor = SKColor(red: 0.7, green: 0.5, blue: 0.35, alpha: 1)
        head.position = CGPoint(x: 0, y: 24)
        cartNode.addChild(head)

        let beanie = SKShapeNode(rectOf: CGSize(width: 24, height: 8), cornerRadius: 3)
        beanie.fillColor = bodyColor.darker(by: 0.15)
        beanie.strokeColor = .clear
        beanie.position = CGPoint(x: 0, y: 32)
        cartNode.addChild(beanie)

        let cartFrame = SKShapeNode(rectOf: CGSize(width: 44, height: 34), cornerRadius: 6)
        cartFrame.fillColor = cartColor
        cartFrame.strokeColor = .darkGray
        cartFrame.lineWidth = 2
        cartFrame.position = CGPoint(x: 0, y: -10)
        cartNode.addChild(cartFrame)

        let handle = SKShapeNode(rectOf: CGSize(width: 36, height: 4), cornerRadius: 2)
        handle.fillColor = .lightGray
        handle.strokeColor = .gray
        handle.position = CGPoint(x: 0, y: 8)
        cartFrame.addChild(handle)

        let wheelPositions: [CGPoint] = [
            CGPoint(x: -18, y: -18),
            CGPoint(x: 18, y: -18),
            CGPoint(x: -18, y: 2),
            CGPoint(x: 18, y: 2)
        ]
        for (wheel, position) in zip(wheels, wheelPositions) {
            wheel.position = position
            cartNode.addChild(wheel)
        }

        if isPlayer {
            let marker = SKLabelNode(text: playerSlot == 0 ? "P1" : "P2")
            marker.fontName = "AvenirNext-Heavy"
            marker.fontSize = 11
            marker.fontColor = playerSlot == 0 ? .yellow : .cyan
            marker.position = CGPoint(x: 0, y: 48)
            cartNode.addChild(marker)
        }

        cartNode.zPosition = 1
        addChild(cartNode)
    }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 22)
        body.affectedByGravity = false
        body.allowsRotation = true
        body.linearDamping = 0.2
        body.angularDamping = 2.0
        body.restitution = 0.35
        body.friction = 0.15
        body.categoryBitMask = PhysicsCategory.racer
        body.contactTestBitMask = PhysicsCategory.itemBox | PhysicsCategory.hazard | PhysicsCategory.racer
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.shelf | PhysicsCategory.racer
        physicsBody = body
    }

    func applyInput(steer: CGFloat, accelerate: Bool, brake: Bool, drift: Bool, useItem: Bool) -> PowerUpType? {
        guard !finished, spinTimer <= 0 else { return nil }

        let effectiveMax = maxSpeed * (boostTimer > 0 ? 1.35 : 1.0) * (slipTimer > 0 ? 0.55 : 1.0)
        let steerMultiplier = slipTimer > 0 ? 1.8 : 1.0

        if accelerate {
            driveSpeed = min(driveSpeed + acceleration * 0.016, effectiveMax)
        } else if brake {
            driveSpeed = max(driveSpeed - acceleration * 1.4 * 0.016, -effectiveMax * 0.35)
        } else {
            driveSpeed *= 0.985
        }

        if abs(driveSpeed) > 20 {
            zRotation += steer * turnRate * steerMultiplier * CGFloat(driveSpeed / effectiveMax) * 0.016
        }

        driftFactor = drift && abs(driveSpeed) > 120 ? 0.35 : 0

        var usedItem: PowerUpType?
        if useItem, let item = heldPowerUp {
            heldPowerUp = nil
            usedItem = item
        }

        return usedItem
    }

    func updateMovement(delta: TimeInterval) {
        if spinTimer > 0 {
            spinTimer -= delta
            zRotation += CGFloat(delta) * 12
            driveSpeed *= 0.92
        }

        if boostTimer > 0 { boostTimer -= delta }
        if slipTimer > 0 { slipTimer -= delta }

        let forward = CGVector(dx: cos(zRotation), dy: sin(zRotation))
        let sideways = CGVector(dx: -sin(zRotation), dy: cos(zRotation))

        let forwardSpeed = driveSpeed
        let sideSpeed = driveSpeed * driftFactor * 0.5

        velocity = CGVector(
            dx: forward.dx * forwardSpeed + sideways.dx * sideSpeed,
            dy: forward.dy * forwardSpeed + sideways.dy * sideSpeed
        )

        position.x += velocity.dx * CGFloat(delta)
        position.y += velocity.dy * CGFloat(delta)

        let wobble = sin(CFAbsoluteTimeGetCurrent() * 14) * CGFloat(min(abs(driveSpeed) / maxSpeed, 1)) * 0.04
        cartNode.zRotation = wobble

        for wheel in wheels {
            wheel.zRotation += driveSpeed * CGFloat(delta) * 0.05
        }
    }

    func applyBoost(duration: TimeInterval = 1.8) {
        boostTimer = max(boostTimer, duration)
    }

    func applySlip(duration: TimeInterval = 1.4) {
        slipTimer = max(slipTimer, duration)
    }

    func applySpin(duration: TimeInterval = 1.0) {
        spinTimer = max(spinTimer, duration)
        driveSpeed *= 0.4
    }

    func collectPowerUp(_ type: PowerUpType) {
        heldPowerUp = type
    }
}

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let racer: UInt32 = 0x1 << 0
    static let wall: UInt32 = 0x1 << 1
    static let shelf: UInt32 = 0x1 << 2
    static let itemBox: UInt32 = 0x1 << 3
    static let hazard: UInt32 = 0x1 << 4
}

extension SKColor {
    func darker(by amount: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: max(r - amount, 0), green: max(g - amount, 0), blue: max(b - amount, 0), alpha: a)
    }
}
