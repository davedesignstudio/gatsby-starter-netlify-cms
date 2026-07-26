import SpriteKit
import UIKit

final class CartNode: SKNode {
    let profile: RacerProfile
    let isPlayer: Bool

    private let bodyNode: SKShapeNode
    private let basketNode: SKShapeNode
    private let wheelFL: SKShapeNode
    private let wheelFR: SKShapeNode
    private let wheelBL: SKShapeNode
    private let wheelBR: SKShapeNode
    private let cargoLabel: SKLabelNode
    private let nameTag: SKLabelNode
    private let shieldAura: SKShapeNode

    var velocity = CGVector.zero
    var steerInput: CGFloat = 0
    var throttleInput: CGFloat = 0
    var brakeInput: CGFloat = 0

    var currentLap = 0
    var nextCheckpoint = 0
    var progress: CGFloat = 0
    var finishTime: TimeInterval?
    var isFinished = false
    var isSpinning = false
    var hasShield = false
    var heldItem: PowerUpType?
    var place = 1

    private var spinTimer: TimeInterval = 0
    private var boostTimer: TimeInterval = 0
    private var boostMultiplier: CGFloat = 1
    private var driftHeld: TimeInterval = 0
    private var wasDrifting = false

    init(profile: RacerProfile, isPlayer: Bool) {
        self.profile = profile
        self.isPlayer = isPlayer

        let cartW: CGFloat = 34
        let cartH: CGFloat = 48

        bodyNode = SKShapeNode(rectOf: CGSize(width: cartW, height: cartH), cornerRadius: 6)
        bodyNode.fillColor = profile.cartColor
        bodyNode.strokeColor = UIColor(white: 0.15, alpha: 1)
        bodyNode.lineWidth = 2

        basketNode = SKShapeNode(rectOf: CGSize(width: cartW - 8, height: cartH - 18), cornerRadius: 4)
        basketNode.fillColor = UIColor(white: 1, alpha: 0.18)
        basketNode.strokeColor = profile.accentColor
        basketNode.lineWidth = 1.5
        basketNode.position = CGPoint(x: 0, y: 4)

        let wheelSize = CGSize(width: 8, height: 12)
        func makeWheel() -> SKShapeNode {
            let w = SKShapeNode(rectOf: wheelSize, cornerRadius: 3)
            w.fillColor = UIColor(white: 0.12, alpha: 1)
            w.strokeColor = .clear
            return w
        }
        wheelFL = makeWheel(); wheelFL.position = CGPoint(x: -16, y: 16)
        wheelFR = makeWheel(); wheelFR.position = CGPoint(x: 16, y: 16)
        wheelBL = makeWheel(); wheelBL.position = CGPoint(x: -16, y: -18)
        wheelBR = makeWheel(); wheelBR.position = CGPoint(x: 16, y: -18)

        cargoLabel = SKLabelNode(text: profile.cargo)
        cargoLabel.fontSize = 16
        cargoLabel.verticalAlignmentMode = .center
        cargoLabel.horizontalAlignmentMode = .center
        cargoLabel.position = CGPoint(x: 0, y: 6)
        cargoLabel.zPosition = 2

        nameTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameTag.text = isPlayer ? "YOU" : profile.name.split(separator: " ").last.map(String.init) ?? profile.name
        nameTag.fontSize = 10
        nameTag.fontColor = .white
        nameTag.verticalAlignmentMode = .center
        nameTag.position = CGPoint(x: 0, y: -38)
        nameTag.zPosition = 3

        shieldAura = SKShapeNode(circleOfRadius: 30)
        shieldAura.strokeColor = UIColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.9)
        shieldAura.fillColor = UIColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.15)
        shieldAura.lineWidth = 2
        shieldAura.isHidden = true
        shieldAura.zPosition = 1

        super.init()

        zPosition = 20
        addChild(bodyNode)
        addChild(basketNode)
        addChild(wheelFL)
        addChild(wheelFR)
        addChild(wheelBL)
        addChild(wheelBR)
        addChild(cargoLabel)
        addChild(nameTag)
        addChild(shieldAura)

        physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: cartW * 0.85, height: cartH * 0.8))
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.allowsRotation = false
        physicsBody?.linearDamping = 1.2
        physicsBody?.restitution = 0.15
        physicsBody?.friction = 0.2
        physicsBody?.categoryBitMask = PhysicsCategory.cart
        physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        physicsBody?.contactTestBitMask = PhysicsCategory.checkpoint | PhysicsCategory.item | PhysicsCategory.hazard | PhysicsCategory.cart
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(deltaTime: TimeInterval, onTrack: Bool) {
        guard !isFinished else {
            velocity = .zero
            physicsBody?.velocity = .zero
            return
        }

        if isSpinning {
            spinTimer -= deltaTime
            zRotation += CGFloat(deltaTime) * 10
            velocity = CGVector(dx: velocity.dx * 0.9, dy: velocity.dy * 0.9)
            physicsBody?.velocity = CGVector(dx: velocity.dx, dy: velocity.dy)
            if spinTimer <= 0 {
                isSpinning = false
            }
            return
        }

        if boostTimer > 0 {
            boostTimer -= deltaTime
            if boostTimer <= 0 { boostMultiplier = 1 }
        }

        let maxSpeed = RaceConfig.maxSpeed * profile.speed * boostMultiplier * (onTrack ? 1 : 0.45)
        let accel = RaceConfig.acceleration * profile.speed
        let turn = RaceConfig.turnSpeed * profile.handling

        let speed = hypot(velocity.dx, velocity.dy)
        let drifting = abs(steerInput) > 0.35 && speed > maxSpeed * 0.55 && throttleInput > 0.4
        if drifting {
            driftHeld += deltaTime
            wasDrifting = true
            bodyNode.strokeColor = profile.accentColor
        } else {
            if wasDrifting && driftHeld >= RaceConfig.driftBoostWindow {
                applyBoost(multiplier: 1.35, duration: 0.55)
                spawnDriftSparks()
            }
            driftHeld = 0
            wasDrifting = false
            bodyNode.strokeColor = UIColor(white: 0.15, alpha: 1)
        }

        zRotation += steerInput * turn * CGFloat(deltaTime) * (0.55 + min(speed / maxSpeed, 1) * 0.45)

        let forward = CGVector(dx: -sin(zRotation), dy: cos(zRotation))
        if throttleInput > 0 {
            velocity.dx += forward.dx * accel * throttleInput * CGFloat(deltaTime)
            velocity.dy += forward.dy * accel * throttleInput * CGFloat(deltaTime)
        }
        if brakeInput > 0 {
            velocity.dx -= velocity.dx * RaceConfig.brakeForce * brakeInput * CGFloat(deltaTime) / max(speed, 1)
            velocity.dy -= velocity.dy * RaceConfig.brakeForce * brakeInput * CGFloat(deltaTime) / max(speed, 1)
        }

        // Align velocity slightly toward facing for arcade feel
        let forwardSpeed = velocity.dx * forward.dx + velocity.dy * forward.dy
        let lateral = CGVector(dx: velocity.dx - forward.dx * forwardSpeed, dy: velocity.dy - forward.dy * forwardSpeed)
        let grip: CGFloat = drifting ? 0.82 : 0.94
        velocity.dx = forward.dx * forwardSpeed + lateral.dx * grip
        velocity.dy = forward.dy * forwardSpeed + lateral.dy * grip

        let currentSpeed = hypot(velocity.dx, velocity.dy)
        if currentSpeed > maxSpeed {
            let scale = maxSpeed / currentSpeed
            velocity.dx *= scale
            velocity.dy *= scale
        }

        // Natural drag
        velocity.dx *= 0.992
        velocity.dy *= 0.992

        physicsBody?.velocity = CGVector(dx: velocity.dx, dy: velocity.dy)

        let wheelAngle = steerInput * 0.45
        wheelFL.zRotation = wheelAngle
        wheelFR.zRotation = wheelAngle

        shieldAura.isHidden = !hasShield
        if hasShield {
            shieldAura.alpha = 0.7 + 0.3 * sin(CGFloat(CACurrentMediaTime()) * 6)
        }
    }

    func applyBoost(multiplier: CGFloat, duration: TimeInterval) {
        boostMultiplier = max(boostMultiplier, multiplier)
        boostTimer = max(boostTimer, duration)
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.bodyNode.fillColor = .white },
            SKAction.wait(forDuration: 0.08),
            SKAction.run { [weak self] in self?.bodyNode.fillColor = self?.profile.cartColor ?? .gray }
        ])
        run(flash)
    }

    func spinOut(duration: TimeInterval = 1.1) {
        if hasShield {
            hasShield = false
            return
        }
        isSpinning = true
        spinTimer = duration
        heldItem = nil
    }

    func hitByItem() {
        spinOut()
    }

    private func spawnDriftSparks() {
        for i in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = profile.accentColor
            spark.strokeColor = .clear
            spark.position = CGPoint(x: CGFloat.random(in: -12...12), y: -24)
            spark.zPosition = 5
            addChild(spark)
            let dx = CGFloat.random(in: -40...40)
            let dy = CGFloat.random(in: -60 ... -20)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.35),
                    SKAction.fadeOut(withDuration: 0.35)
                ]),
                SKAction.removeFromParent()
            ]))
            _ = i
        }
    }
}

enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let checkpoint: UInt32 = 1 << 2
    static let item: UInt32 = 1 << 3
    static let hazard: UInt32 = 1 << 4
}
