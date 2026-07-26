import SpriteKit
import UIKit

final class ShoppingCart: SKNode {
    let profile: RacerProfile
    private let bodyNode: SKShapeNode
    private let basketNode: SKShapeNode
    private let wheelFL: SKShapeNode
    private let wheelFR: SKShapeNode
    private let wheelBL: SKShapeNode
    private let wheelBR: SKShapeNode
    private let nameLabel: SKLabelNode
    private let shieldAura: SKShapeNode

    var velocity = CGVector.zero
    var heading: CGFloat = -.pi / 2
    var currentLap = 0
    var checkpointIndex = 0
    var finished = false
    var finishPlace: Int?
    var heldItem: PowerUpKind?
    var hasShield = false
    var slipTimer: TimeInterval = 0
    var boostTimer: TimeInterval = 0
    var slowTimer: TimeInterval = 0
    var invulnTimer: TimeInterval = 0

    var speed: CGFloat {
        hypot(velocity.dx, velocity.dy)
    }

    init(profile: RacerProfile) {
        self.profile = profile

        let cartWidth: CGFloat = 36
        let cartHeight: CGFloat = 52

        bodyNode = SKShapeNode(rectOf: CGSize(width: cartWidth, height: cartHeight), cornerRadius: 4)
        bodyNode.fillColor = profile.cartColor
        bodyNode.strokeColor = UIColor(white: 0.15, alpha: 1)
        bodyNode.lineWidth = 2
        bodyNode.zPosition = 1

        basketNode = SKShapeNode(rectOf: CGSize(width: cartWidth - 8, height: cartHeight * 0.45), cornerRadius: 2)
        basketNode.fillColor = profile.cartColor.withAlphaComponent(0.55)
        basketNode.strokeColor = profile.accentColor
        basketNode.lineWidth = 1.5
        basketNode.position = CGPoint(x: 0, y: 6)
        basketNode.zPosition = 2

        let wheelSize = CGSize(width: 8, height: 12)
        func makeWheel() -> SKShapeNode {
            let w = SKShapeNode(rectOf: wheelSize, cornerRadius: 2)
            w.fillColor = UIColor(white: 0.12, alpha: 1)
            w.strokeColor = .clear
            w.zPosition = 0
            return w
        }
        wheelFL = makeWheel()
        wheelFR = makeWheel()
        wheelBL = makeWheel()
        wheelBR = makeWheel()
        wheelFL.position = CGPoint(x: -16, y: 18)
        wheelFR.position = CGPoint(x: 16, y: 18)
        wheelBL.position = CGPoint(x: -16, y: -18)
        wheelBR.position = CGPoint(x: 16, y: -18)

        let handle = SKShapeNode(rectOf: CGSize(width: cartWidth + 6, height: 4), cornerRadius: 2)
        handle.fillColor = profile.accentColor
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: -cartHeight / 2 + 2)
        handle.zPosition = 3

        nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = profile.name
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 40)
        nameLabel.zPosition = 10

        let nameBg = SKShapeNode(rectOf: CGSize(width: 58, height: 16), cornerRadius: 8)
        nameBg.fillColor = UIColor(white: 0, alpha: 0.55)
        nameBg.strokeColor = .clear
        nameBg.zPosition = -1
        nameLabel.addChild(nameBg)

        shieldAura = SKShapeNode(circleOfRadius: 34)
        shieldAura.fillColor = UIColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 0.18)
        shieldAura.strokeColor = UIColor(red: 0.5, green: 0.9, blue: 1.0, alpha: 0.85)
        shieldAura.lineWidth = 2
        shieldAura.zPosition = -1
        shieldAura.isHidden = true

        super.init()

        name = profile.id
        zPosition = 50
        addChild(bodyNode)
        addChild(basketNode)
        addChild(wheelFL)
        addChild(wheelFR)
        addChild(wheelBL)
        addChild(wheelBR)
        addChild(handle)
        addChild(nameLabel)
        addChild(shieldAura)

        let physics = SKPhysicsBody(rectangleOf: CGSize(width: cartWidth - 4, height: cartHeight - 4))
        physics.categoryBitMask = PhysicsCategory.cart
        physics.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        physics.contactTestBitMask = PhysicsCategory.itemBox | PhysicsCategory.hazard | PhysicsCategory.projectile | PhysicsCategory.checkpoint | PhysicsCategory.cart
        physics.affectedByGravity = false
        physics.allowsRotation = false
        physics.linearDamping = 0
        physics.angularDamping = 0
        physics.restitution = 0.2
        physics.friction = 0.1
        physics.mass = profile.isPlayer ? 1.0 : 0.95
        physicsBody = physics
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateVisuals() {
        zRotation = heading + .pi / 2
        shieldAura.isHidden = !hasShield
        if hasShield {
            shieldAura.alpha = 0.7 + 0.3 * sin(CACurrentMediaTime() * 8)
        }
        if invulnTimer > 0 {
            alpha = Int(invulnTimer * 10) % 2 == 0 ? 0.45 : 1.0
        } else {
            alpha = 1
        }
        let spin = speed * 0.08
        [wheelFL, wheelFR, wheelBL, wheelBR].forEach { $0.zRotation = spin }
    }

    func applySteer(_ input: CGFloat, delta: TimeInterval) {
        guard slipTimer <= 0 else {
            heading += CGFloat(delta) * 4.5
            return
        }
        let turnRate = profile.handling * (1.0 - min(speed / profile.topSpeed, 1) * 0.25)
        heading += input * turnRate * CGFloat(delta)
    }

    func applyThrottle(boosting: Bool, delta: TimeInterval) {
        let dt = CGFloat(delta)
        var maxSpeed = profile.topSpeed
        var accel = profile.acceleration

        if boostTimer > 0 {
            maxSpeed *= 1.45
            accel *= 1.6
        } else if boosting {
            maxSpeed *= 1.12
            accel *= 1.15
        }
        if slowTimer > 0 {
            maxSpeed *= 0.55
            accel *= 0.5
        }
        if slipTimer > 0 {
            accel *= 0.2
        }

        let dir = CGVector(dx: cos(heading), dy: sin(heading))
        velocity.dx += dir.dx * accel * dt
        velocity.dy += dir.dy * accel * dt

        let current = speed
        if current > maxSpeed {
            let scale = maxSpeed / current
            velocity.dx *= scale
            velocity.dy *= scale
        }

        // Align velocity toward heading (kart grip)
        let grip: CGFloat = slipTimer > 0 ? 0.02 : 0.18
        let aligned = CGVector(dx: dir.dx * current, dy: dir.dy * current)
        velocity.dx += (aligned.dx - velocity.dx) * grip
        velocity.dy += (aligned.dy - velocity.dy) * grip

        // Drag
        let drag: CGFloat = 1.0 - (0.55 * dt)
        velocity.dx *= drag
        velocity.dy *= drag
    }

    func integrate(delta: TimeInterval) {
        // Drive through physics so shelf/wall collisions resolve naturally.
        physicsBody?.velocity = CGVector(dx: velocity.dx, dy: velocity.dy)
        physicsBody?.angularVelocity = 0

        slipTimer = max(0, slipTimer - delta)
        boostTimer = max(0, boostTimer - delta)
        slowTimer = max(0, slowTimer - delta)
        invulnTimer = max(0, invulnTimer - delta)
        updateVisuals()
    }

    func syncVelocityFromPhysics() {
        if let v = physicsBody?.velocity {
            // Blend so bumps from walls affect our sim velocity
            velocity.dx = velocity.dx * 0.35 + v.dx * 0.65
            velocity.dy = velocity.dy * 0.35 + v.dy * 0.65
        }
    }

    func hitByHazard(kind: PowerUpKind) {
        guard invulnTimer <= 0 else { return }
        if hasShield {
            hasShield = false
            invulnTimer = 0.6
            return
        }
        switch kind {
        case .banana:
            slipTimer = 1.2
            velocity.dx *= 0.35
            velocity.dy *= 0.35
        case .wetFloor:
            slowTimer = 1.8
            velocity.dx *= 0.5
            velocity.dy *= 0.5
        case .cannedGoods:
            slipTimer = 0.8
            velocity.dx *= 0.2
            velocity.dy *= 0.2
            invulnTimer = 0.5
        default:
            break
        }
    }

    func useHeldItem(world: RaceScene) {
        guard let item = heldItem else { return }
        heldItem = nil
        switch item {
        case .sodaBoost:
            boostTimer = 1.6
            world.spawnBoostFX(at: position)
        case .shoppingBag:
            hasShield = true
        case .banana:
            world.spawnHazard(.banana, behind: self)
        case .wetFloor:
            world.spawnHazard(.wetFloor, behind: self)
        case .cannedGoods:
            world.spawnProjectile(from: self)
        }
    }
}
