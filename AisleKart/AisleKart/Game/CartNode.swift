import SpriteKit

final class CartNode: SKNode {
    let cartIndex: Int
    let isPlayer: Bool
    var lap = 0
    var nextCheckpoint = 0
    var raceProgress: CGFloat = 0
    var finished = false
    var finishPlace: Int?

    private(set) var speed: CGFloat = 0
    var maxSpeed: CGFloat = 280
    var acceleration: CGFloat = 220
    var turnRate: CGFloat = 2.8
    var steerInput: CGFloat = 0
    var throttle: Bool = true

    var heldItem: PowerUpType?
    var hasShield = false
    var boostTimer: TimeInterval = 0
    var spinTimer: TimeInterval = 0
    var slowTimer: TimeInterval = 0
    var invulnTimer: TimeInterval = 0

    private let body: SKShapeNode
    private let basket: SKShapeNode
    private let shieldRing: SKShapeNode
    private let nameLabel: SKLabelNode
    private let wheelFL: SKShapeNode
    private let wheelFR: SKShapeNode
    private let wheelBL: SKShapeNode
    private let wheelBR: SKShapeNode

    init(index: Int, isPlayer: Bool) {
        self.cartIndex = index
        self.isPlayer = isPlayer

        let color = GameTheme.cartColors[index % GameTheme.cartColors.count]

        body = SKShapeNode(rectOf: CGSize(width: 36, height: 52), cornerRadius: 6)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.25)
        body.lineWidth = 2
        body.zPosition = 1

        basket = SKShapeNode(rectOf: CGSize(width: 28, height: 34), cornerRadius: 3)
        basket.fillColor = UIColor(white: 0.85, alpha: 0.35)
        basket.strokeColor = UIColor(white: 0.95, alpha: 0.6)
        basket.lineWidth = 1.5
        basket.position = CGPoint(x: 0, y: 2)
        basket.zPosition = 2

        // Wire grid look
        for i in -1...1 {
            let line = SKShapeNode(rectOf: CGSize(width: 1.2, height: 30))
            line.fillColor = UIColor(white: 1, alpha: 0.35)
            line.strokeColor = .clear
            line.position = CGPoint(x: CGFloat(i) * 8, y: 2)
            line.zPosition = 3
            basket.addChild(line)
        }

        let handle = SKShapeNode(rectOf: CGSize(width: 40, height: 5), cornerRadius: 2)
        handle.fillColor = color.darker(by: 0.35)
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: -28)
        handle.zPosition = 2

        func makeWheel() -> SKShapeNode {
            let w = SKShapeNode(circleOfRadius: 5)
            w.fillColor = GameTheme.ink
            w.strokeColor = UIColor(white: 0.3, alpha: 1)
            w.lineWidth = 1
            w.zPosition = 0
            return w
        }
        wheelFL = makeWheel(); wheelFL.position = CGPoint(x: -16, y: 16)
        wheelFR = makeWheel(); wheelFR.position = CGPoint(x: 16, y: 16)
        wheelBL = makeWheel(); wheelBL.position = CGPoint(x: -16, y: -18)
        wheelBR = makeWheel(); wheelBR.position = CGPoint(x: 16, y: -18)

        shieldRing = SKShapeNode(circleOfRadius: 34)
        shieldRing.strokeColor = UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 0.9)
        shieldRing.fillColor = UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 0.12)
        shieldRing.lineWidth = 3
        shieldRing.isHidden = true
        shieldRing.zPosition = 4

        nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = isPlayer ? "YOU" : GameTheme.cartNames[index]
        nameLabel.fontSize = 11
        nameLabel.fontColor = GameTheme.hudCream
        nameLabel.position = CGPoint(x: 0, y: 38)
        nameLabel.zPosition = 10
        nameLabel.horizontalAlignmentMode = .center

        super.init()

        addChild(wheelFL)
        addChild(wheelFR)
        addChild(wheelBL)
        addChild(wheelBR)
        addChild(body)
        addChild(basket)
        addChild(handle)
        addChild(shieldRing)
        addChild(nameLabel)

        if isPlayer {
            let arrow = SKShapeNode(path: Self.arrowPath())
            arrow.fillColor = GameTheme.checkoutYellow
            arrow.strokeColor = .clear
            arrow.position = CGPoint(x: 0, y: 48)
            arrow.zPosition = 11
            addChild(arrow)
        }

        let physics = SKPhysicsBody(rectangleOf: CGSize(width: 34, height: 48))
        physics.categoryBitMask = PhysicsCategory.cart
        physics.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        physics.contactTestBitMask = PhysicsCategory.itemBox | PhysicsCategory.hazard | PhysicsCategory.projectile | PhysicsCategory.checkpoint | PhysicsCategory.cart
        physics.allowsRotation = false
        physics.friction = 0.2
        physics.restitution = 0.15
        physics.linearDamping = 1.2
        physics.angularDamping = 1
        physicsBody = physics
        name = isPlayer ? "player" : "ai-\(index)"
        zPosition = 50
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func arrowPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 8))
        p.addLine(to: CGPoint(x: -7, y: -4))
        p.addLine(to: CGPoint(x: 7, y: -4))
        p.closeSubpath()
        return p
    }

    func update(delta: TimeInterval) {
        invulnTimer = max(0, invulnTimer - delta)
        boostTimer = max(0, boostTimer - delta)
        spinTimer = max(0, spinTimer - delta)
        slowTimer = max(0, slowTimer - delta)
        shieldRing.isHidden = !hasShield

        if spinTimer > 0 {
            zRotation += CGFloat(delta) * 10
            speed *= 0.92
            physicsBody?.velocity = .zero
            return
        }

        let maxSp = effectiveMaxSpeed()
        if throttle {
            speed = min(maxSp, speed + acceleration * CGFloat(delta))
        } else {
            speed = max(0, speed - acceleration * 1.4 * CGFloat(delta))
        }

        if abs(steerInput) > 0.05 {
            let turnScale = 0.35 + 0.65 * min(1, speed / max(1, maxSpeed * 0.5))
            zRotation += steerInput * turnRate * turnScale * CGFloat(delta)
        }

        let dx = sin(zRotation) * speed
        let dy = cos(zRotation) * speed
        physicsBody?.velocity = CGVector(dx: dx, dy: dy)

        // Wheel spin visual
        let spin = speed * CGFloat(delta) * 0.08
        [wheelFL, wheelFR, wheelBL, wheelBR].forEach { $0.zRotation += spin }

        if boostTimer > 0 {
            emitBoostParticles()
        }
    }

    private func effectiveMaxSpeed() -> CGFloat {
        var m = maxSpeed
        if boostTimer > 0 { m *= 1.45 }
        if slowTimer > 0 { m *= 0.55 }
        return m
    }

    func applyBananaHit() {
        guard invulnTimer <= 0 else { return }
        if hasShield {
            hasShield = false
            invulnTimer = 0.6
            return
        }
        spinTimer = 1.1
        speed = 0
        invulnTimer = 1.2
    }

    func applySodaSlow() {
        guard invulnTimer <= 0 else { return }
        if hasShield {
            hasShield = false
            invulnTimer = 0.5
            return
        }
        slowTimer = 2.0
        invulnTimer = 0.4
    }

    func applyTurkeyHit() {
        applyBananaHit()
    }

    func activateBoost(duration: TimeInterval = 1.4) {
        boostTimer = duration
        speed = max(speed, maxSpeed * 1.1)
    }

    func grantShield() {
        hasShield = true
    }

    private var particleCooldown: TimeInterval = 0
    private func emitBoostParticles() {
        particleCooldown -= 1 / 60
        guard particleCooldown <= 0 else { return }
        particleCooldown = 0.04
        let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
        spark.fillColor = GameTheme.checkoutYellow.withAlphaComponent(0.8)
        spark.strokeColor = .clear
        spark.position = CGPoint(x: CGFloat.random(in: -10...10), y: -30)
        spark.zPosition = -1
        addChild(spark)
        spark.run(.sequence([
            .group([
                .moveBy(x: 0, y: -20, duration: 0.25),
                .fadeOut(withDuration: 0.25),
                .scale(to: 0.2, duration: 0.25)
            ]),
            .removeFromParent()
        ]))
    }
}

extension UIColor {
    func darker(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), alpha: a)
    }
}
