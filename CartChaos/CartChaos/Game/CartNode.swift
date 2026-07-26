import SpriteKit

final class CartNode: SKNode {
    let profile: CartProfile
    let isPlayer: Bool

    private let body: SKShapeNode
    private let basket: SKShapeNode
    private let wheelFL: SKShapeNode
    private let wheelFR: SKShapeNode
    private let wheelBL: SKShapeNode
    private let wheelBR: SKShapeNode
    private let nameLabel: SKLabelNode
    private let glow: SKShapeNode

    var velocity = CGVector.zero
    var heading: CGFloat = -.pi / 2
    var currentLap = 0
    var checkpointIndex = 0
    var progress: CGFloat = 0
    var heldItem: PowerUpKind?
    var isSpinning = false
    var hasShield = false
    var boostTimer: TimeInterval = 0
    var spinTimer: TimeInterval = 0
    var shieldTimer: TimeInterval = 0
    var finished = false
    var finishPlace = 0

    var maxSpeed: CGFloat {
        RaceConfig.baseMaxSpeed * profile.speed * (boostTimer > 0 ? RaceConfig.boostMultiplier : 1)
    }

    init(profile: CartProfile, isPlayer: Bool) {
        self.profile = profile
        self.isPlayer = isPlayer

        body = SKShapeNode(rectOf: CGSize(width: 36, height: 52), cornerRadius: 6)
        body.fillColor = profile.bodyColor
        body.strokeColor = profile.accentColor
        body.lineWidth = 2.5

        basket = SKShapeNode(rectOf: CGSize(width: 28, height: 22), cornerRadius: 3)
        basket.fillColor = profile.bodyColor.withAlphaComponent(0.35)
        basket.strokeColor = .white.withAlphaComponent(0.55)
        basket.lineWidth = 1.5
        basket.position = CGPoint(x: 0, y: 4)

        func wheel() -> SKShapeNode {
            let w = SKShapeNode(circleOfRadius: 5)
            w.fillColor = UIColor(white: 0.15, alpha: 1)
            w.strokeColor = UIColor(white: 0.45, alpha: 1)
            w.lineWidth = 1
            return w
        }
        wheelFL = wheel(); wheelFL.position = CGPoint(x: -16, y: 18)
        wheelFR = wheel(); wheelFR.position = CGPoint(x: 16, y: 18)
        wheelBL = wheel(); wheelBL.position = CGPoint(x: -16, y: -20)
        wheelBR = wheel(); wheelBR.position = CGPoint(x: 16, y: -20)

        glow = SKShapeNode(circleOfRadius: 28)
        glow.fillColor = profile.accentColor.withAlphaComponent(isPlayer ? 0.22 : 0.08)
        glow.strokeColor = .clear
        glow.zPosition = -1

        nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = isPlayer ? "YOU" : profile.name.split(separator: " ").last.map(String.init) ?? profile.name
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 36)
        nameLabel.verticalAlignmentMode = .center

        super.init()

        addChild(glow)
        addChild(body)
        addChild(basket)
        addChild(wheelFL)
        addChild(wheelFR)
        addChild(wheelBL)
        addChild(wheelBR)
        addChild(nameLabel)

        // Wire grid lines for shopping-cart look
        for i in -1...1 {
            let line = SKShapeNode(rectOf: CGSize(width: 22, height: 1.2))
            line.fillColor = .white.withAlphaComponent(0.35)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: CGFloat(i) * 6 + 4)
            addChild(line)
        }

        zPosition = 10
        name = isPlayer ? "player" : "ai_\(profile.id)"
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func applyInput(throttle: CGFloat, steer: CGFloat, dt: TimeInterval) {
        guard !finished, !isSpinning else {
            velocity.dx *= 0.92
            velocity.dy *= 0.92
            position.x += velocity.dx * CGFloat(dt)
            position.y += velocity.dy * CGFloat(dt)
            return
        }

        let turnRate: CGFloat = 2.8 * profile.handling
        heading += steer * turnRate * CGFloat(dt)

        let accel = throttle * 780 * profile.speed
        let drag: CGFloat = throttle > 0.1 ? 0.985 : 0.94

        velocity.dx += cos(heading) * accel * CGFloat(dt)
        velocity.dy += sin(heading) * accel * CGFloat(dt)
        velocity.dx *= drag
        velocity.dy *= drag

        let speed = hypot(velocity.dx, velocity.dy)
        if speed > maxSpeed {
            let s = maxSpeed / speed
            velocity.dx *= s
            velocity.dy *= s
        }

        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
        zRotation = heading + .pi / 2

        // Wheel spin visual
        let spin = speed * CGFloat(dt) * 0.08
        [wheelFL, wheelFR, wheelBL, wheelBR].forEach { $0.zRotation += spin }

        tickStatus(dt: dt)
    }

    func tickStatus(dt: TimeInterval) {
        if boostTimer > 0 {
            boostTimer -= dt
            glow.fillColor = UIColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.35)
        }
        if spinTimer > 0 {
            spinTimer -= dt
            zRotation += CGFloat(dt) * 12
            if spinTimer <= 0 { isSpinning = false }
        }
        if shieldTimer > 0 {
            shieldTimer -= dt
            hasShield = shieldTimer > 0
            glow.fillColor = UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.4)
            if !hasShield {
                glow.fillColor = profile.accentColor.withAlphaComponent(isPlayer ? 0.22 : 0.08)
            }
        } else if boostTimer <= 0 {
            glow.fillColor = profile.accentColor.withAlphaComponent(isPlayer ? 0.22 : 0.08)
        }
    }

    func hitByHazard() {
        if hasShield {
            shieldTimer = 0
            hasShield = false
            return
        }
        isSpinning = true
        spinTimer = RaceConfig.spinDuration
        velocity.dx *= 0.2
        velocity.dy *= 0.2
    }

    func activateBoost() {
        boostTimer = RaceConfig.boostDuration
    }

    func activateShield() {
        shieldTimer = RaceConfig.shieldDuration
        hasShield = true
    }

    var radius: CGFloat { 22 }
}
