import SpriteKit

protocol CartDelegate: AnyObject {
    func cartDidCompleteLap(_ cart: ShoppingCart)
    func cartDidFinishRace(_ cart: ShoppingCart)
    func cartDidCollectItem(_ cart: ShoppingCart, item: RaceItem)
}

final class ShoppingCart: SKNode {
    let cartID: String
    let displayName: String
    let isPlayer: Bool
    weak var delegate: CartDelegate?

    private(set) var lap = 0
    private(set) var nextCheckpoint = 0
    private(set) var raceFinished = false
    private(set) var heldItem: RaceItem?
    private(set) var speed: CGFloat = 0

    var maxSpeed: CGFloat
    var acceleration: CGFloat
    var turnRate: CGFloat
    var friction: CGFloat

    private var steeringInput: CGFloat = 0
    private var throttleInput: CGFloat = 0
    private var driftCharge: CGFloat = 0
    private var isDrifting = false
    private var boostTimer: TimeInterval = 0
    private var slipTimer: TimeInterval = 0
    private var shieldActive = false
    private var lapStartTime: TimeInterval = 0
    private(set) var bestLapTime: TimeInterval = 0
    private var raceProgress: CGFloat = 0

    private let cartBody: SKShapeNode
    private let wheels: [SKShapeNode]
    private let characterHead: SKShapeNode
    private let driftParticles: SKEmitterNode?

    private var checkpoints: [CGPoint] = []
    private var aiTargetCheckpoint = 0
    private var aiSteerNoise: CGFloat = 0

    init(
        id: String,
        name: String,
        isPlayer: Bool,
        position: CGPoint,
        angle: CGFloat,
        color: SKColor,
        stats: CartStats
    ) {
        cartID = id
        displayName = name
        self.isPlayer = isPlayer
        maxSpeed = stats.maxSpeed
        acceleration = stats.acceleration
        turnRate = stats.turnRate
        friction = stats.friction

        cartBody = SKShapeNode(rectOf: CGSize(width: 28, height: 42), cornerRadius: 6)
        wheels = (0..<4).map { _ in
            let wheel = SKShapeNode(circleOfRadius: 5)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            return wheel
        }
        characterHead = SKShapeNode(circleOfRadius: 8)
        driftParticles = SKEmitterNode()

        super.init()
        self.position = position
        self.zRotation = angle
        self.zPosition = 5
        self.name = "cart"

        cartBody.fillColor = color.withAlphaComponent(0.25)
        cartBody.strokeColor = color
        cartBody.lineWidth = 3
        addChild(cartBody)

        wheels[0].position = CGPoint(x: -14, y: 14)
        wheels[1].position = CGPoint(x: 14, y: 14)
        wheels[2].position = CGPoint(x: -14, y: -14)
        wheels[3].position = CGPoint(x: 14, y: -14)
        wheels.forEach(addChild)

        characterHead.fillColor = SKColor(red: 0.95, green: 0.8, blue: 0.65, alpha: 1)
        characterHead.strokeColor = .black
        characterHead.lineWidth = 1.5
        characterHead.position = CGPoint(x: 0, y: -8)
        addChild(characterHead)

        let blanket = SKShapeNode(rectOf: CGSize(width: 30, height: 10), cornerRadius: 3)
        blanket.fillColor = SKColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 0.9)
        blanket.strokeColor = .clear
        blanket.position = CGPoint(x: 0, y: 6)
        addChild(blanket)

        let handle = SKShapeNode(rectOf: CGSize(width: 4, height: 22), cornerRadius: 2)
        handle.fillColor = .lightGray
        handle.strokeColor = .darkGray
        handle.position = CGPoint(x: 0, y: 24)
        addChild(handle)

        if let driftParticles {
            driftParticles.particleBirthRate = 0
            driftParticles.particleLifetime = 0.4
            driftParticles.particleSpeed = 40
            driftParticles.particleSpeedRange = 20
            driftParticles.emissionAngle = .pi
            driftParticles.particleAlpha = 0.5
            driftParticles.particleAlphaSpeed = -1.2
            driftParticles.particleScale = 0.08
            driftParticles.particleColor = .white
            driftParticles.position = CGPoint(x: 0, y: -20)
            addChild(driftParticles)
        }

        let nameLabel = SKLabelNode(text: name)
        nameLabel.fontName = "AvenirNext-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 38)
        nameLabel.zPosition = 10
        addChild(nameLabel)

        physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 26, height: 38))
        physicsBody?.allowsRotation = true
        physicsBody?.linearDamping = 1.8
        physicsBody?.angularDamping = 3.5
        physicsBody?.categoryBitMask = PhysicsCategory.cart
        physicsBody?.contactTestBitMask = PhysicsCategory.itemBox | PhysicsCategory.projectile | PhysicsCategory.hazard | PhysicsCategory.boostPad
        physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        physicsBody?.restitution = 0.2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureCheckpoints(_ points: [CGPoint]) {
        checkpoints = points
    }

    func setPlayerInput(steering: CGFloat, throttle: CGFloat) {
        guard isPlayer else { return }
        steeringInput = steering
        throttleInput = throttle
        isDrifting = abs(steering) > 0.35 && abs(speed) > 60 && throttle > 0
    }

    func updateAI(deltaTime: TimeInterval, opponents: [ShoppingCart]) {
        guard !isPlayer, !raceFinished, !checkpoints.isEmpty else { return }

        let target = checkpoints[aiTargetCheckpoint]
        let vector = CGVector(dx: target.x - position.x, dy: target.y - position.y)
        let desiredAngle = atan2(vector.dy, vector.dx) - .pi / 2
        var angleDiff = normalizeAngle(desiredAngle - zRotation)

        aiSteerNoise += CGFloat.random(in: -0.8...0.8) * CGFloat(deltaTime)
        aiSteerNoise = max(-0.25, min(0.25, aiSteerNoise))
        angleDiff += aiSteerNoise

        steeringInput = max(-1, min(1, angleDiff * 2.2))
        throttleInput = 1.0

        if abs(angleDiff) > 0.5 && speed > 80 {
            throttleInput = 0.55
        }

        if distance(to: target) < 45 {
            aiTargetCheckpoint = (aiTargetCheckpoint + 1) % checkpoints.count
            if aiTargetCheckpoint == 0 {
                registerCheckpointCrossed()
            }
        }

        if Bool.random() && heldItem != nil && CGFloat.random(in: 0...1) < 0.01 {
            useHeldItem(toward: opponents.first(where: { !$0.raceFinished && $0.cartID != cartID }))
        }
    }

    func update(deltaTime: TimeInterval) {
        guard !raceFinished else { return }

        if slipTimer > 0 {
            slipTimer -= deltaTime
            steeringInput *= 0.3
        }

        if boostTimer > 0 {
            boostTimer -= deltaTime
        }

        let effectiveMaxSpeed = maxSpeed + (boostTimer > 0 ? 90 : 0)
        let effectiveAcceleration = acceleration * (boostTimer > 0 ? 1.4 : 1)

        if throttleInput > 0 {
            speed += effectiveAcceleration * CGFloat(deltaTime) * throttleInput
        } else if throttleInput < 0 {
            speed -= effectiveAcceleration * 1.6 * CGFloat(deltaTime)
        } else {
            speed -= friction * CGFloat(deltaTime)
        }

        speed = max(0, min(effectiveMaxSpeed, speed))

        let turnMultiplier: CGFloat = speed > 30 ? (isDrifting ? 1.35 : 1.0) : 0.4
        zRotation += steeringInput * turnRate * turnMultiplier * CGFloat(deltaTime) * min(1, speed / 80)

        let forward = CGVector(dx: sin(zRotation) * speed, dy: -cos(zRotation) * speed)
        physicsBody?.velocity = forward

        if isDrifting && abs(steeringInput) > 0.3 {
            driftCharge += CGFloat(deltaTime)
            driftParticles?.particleBirthRate = 30
            if driftCharge > 0.8 {
                boostTimer = 1.2
                driftCharge = 0
                showBoostEffect()
            }
        } else {
            driftCharge = max(0, driftCharge - CGFloat(deltaTime) * 0.5)
            driftParticles?.particleBirthRate = 0
        }

        updateRaceProgress()
    }

    func registerCheckpointCrossed() {
        nextCheckpoint = (nextCheckpoint + 1) % checkpoints.count
        if nextCheckpoint == 0 {
            completeLap()
        }
    }

    func checkCheckpointProximity() {
        guard !checkpoints.isEmpty else { return }
        let checkpoint = checkpoints[nextCheckpoint]
        if distance(to: checkpoint) < 50 {
            registerCheckpointCrossed()
        }
    }

    private func completeLap() {
        lap += 1
        let lapTime = CACurrentMediaTime() - lapStartTime
        if bestLapTime == 0 || lapTime < bestLapTime {
            bestLapTime = lapTime
        }
        lapStartTime = CACurrentMediaTime()
        delegate?.cartDidCompleteLap(self)

        if lap >= 3 {
            raceFinished = true
            physicsBody?.velocity = .zero
            delegate?.cartDidFinishRace(self)
        }
    }

    func beginRace() {
        lapStartTime = CACurrentMediaTime()
    }

    func collectItem(_ item: RaceItem) {
        heldItem = item
        delegate?.cartDidCollectItem(self, item: item)
    }

    func useHeldItem(toward target: ShoppingCart?) {
        guard let item = heldItem else { return }
        heldItem = nil

        switch item {
        case .coffeeBoost:
            boostTimer = 2.5
            showBoostEffect()
        case .couponShield:
            shieldActive = true
            run(.sequence([
                .wait(forDuration: 4),
                .run { [weak self] in self?.shieldActive = false }
            ]))
            addShieldVisual()
        case .bananaPeel, .cardboardBox:
            let angle = target.map { atan2($0.position.y - position.y, $0.position.x - position.x) } ?? zRotation
            if let scene {
                let projectile = ProjectileNode(item: item, ownerID: cartID, position: position, angle: angle)
                scene.addChild(projectile)
            }
        }
    }

    func applySlip(duration: TimeInterval = 1.2) {
        guard !shieldActive else { return }
        slipTimer = duration
        speed *= 0.4
        run(.sequence([
            SKAction.rotate(byAngle: 0.3, duration: 0.1),
            SKAction.rotate(byAngle: -0.6, duration: 0.2),
            SKAction.rotate(byAngle: 0.3, duration: 0.1)
        ]))
    }

    func applyBoost() {
        boostTimer = 1.0
        speed = min(maxSpeed + 60, speed + 40)
        showBoostEffect()
    }

    func hitByProjectile(_ projectile: ProjectileNode) -> Bool {
        guard projectile.ownerID != cartID else { return false }
        if shieldActive {
            projectile.removeFromParent()
            return true
        }
        switch projectile.item {
        case .bananaPeel:
            applySlip()
        case .cardboardBox:
            speed *= 0.5
            physicsBody?.velocity.dx *= 0.3
            physicsBody?.velocity.dy *= 0.3
        default:
            break
        }
        projectile.removeFromParent()
        return true
    }

    private func updateRaceProgress() {
        guard !checkpoints.isEmpty else { return }
        let checkpoint = checkpoints[nextCheckpoint]
        let dist = distance(to: checkpoint)
        raceProgress = CGFloat(lap) * 1000 - dist
    }

    var progressScore: CGFloat { raceProgress }

    private func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - position.x, point.y - position.y)
    }

    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle
        while result > .pi { result -= 2 * .pi }
        while result < -.pi { result += 2 * .pi }
        return result
    }

    private func showBoostEffect() {
        let flash = SKAction.sequence([
            SKAction.colorize(with: .cyan, colorBlendFactor: 0.5, duration: 0.08),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.2)
        ])
        cartBody.run(flash)
    }

    private func addShieldVisual() {
        let shield = SKShapeNode(circleOfRadius: 28)
        shield.strokeColor = .cyan
        shield.lineWidth = 3
        shield.fillColor = .clear
        shield.name = "shield"
        addChild(shield)
        shield.run(.sequence([
            .wait(forDuration: 4),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}

struct CartStats {
    let maxSpeed: CGFloat
    let acceleration: CGFloat
    let turnRate: CGFloat
    let friction: CGFloat

    static let player = CartStats(maxSpeed: 220, acceleration: 180, turnRate: 3.8, friction: 90)
    static let aiBalanced = CartStats(maxSpeed: 200, acceleration: 165, turnRate: 3.5, friction: 90)
    static let aiFast = CartStats(maxSpeed: 215, acceleration: 170, turnRate: 3.2, friction: 95)
    static let aiTechnical = CartStats(maxSpeed: 195, acceleration: 175, turnRate: 4.0, friction: 88)
}
