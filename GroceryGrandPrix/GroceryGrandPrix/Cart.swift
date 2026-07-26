import SpriteKit

/// A shopping-cart racer (player or AI). Faces +x by default; `zRotation`
/// tracks `heading`. Movement uses a lightweight arcade model and drives the
/// physics body's velocity so wall/cart collisions are resolved by SpriteKit.
final class Cart: SKNode {

    // Identity
    let isPlayer: Bool
    let displayName: String
    let colorIndex: Int

    // Tunable movement constants
    let baseMaxSpeed: CGFloat = 520
    let acceleration: CGFloat = 340
    let brakeDecel: CGFloat = 560
    let coastDecel: CGFloat = 220
    let turnRate: CGFloat = 3.1

    // Movement state
    var heading: CGFloat = 0
    var speed: CGFloat = 0
    var maxSpeed: CGFloat = 520

    // Effect timers (seconds)
    var boostTimer: TimeInterval = 0
    var spinTimer: TimeInterval = 0
    var driftCharge: TimeInterval = 0
    var isDrifting = false

    // Items
    var heldItem: ItemType? = nil

    // Race progress
    var checkpointsPassed: Int = 0
    var progressScore: CGFloat = 0
    var finished = false
    var finishTime: TimeInterval = 0

    // AI
    var aiLateralOffset: CGFloat = 0
    var aiItemCooldown: TimeInterval = 0

    private var boostPuff: SKLabelNode!
    private var spinStars: SKLabelNode!

    var isBoosting: Bool { boostTimer > 0 }
    var isSpinning: Bool { spinTimer > 0 }

    init(isPlayer: Bool, name: String, colorIndex: Int) {
        self.isPlayer = isPlayer
        self.displayName = name
        self.colorIndex = colorIndex
        super.init()
        self.zPosition = 5
        buildAppearance()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Appearance

    private func buildAppearance() {
        let color = Palette.cartColors[colorIndex % Palette.cartColors.count]

        for (dx, dy) in [(20, 15), (20, -15), (-20, 15), (-20, -15)] {
            let wheel = SKShapeNode(circleOfRadius: 6)
            wheel.fillColor = .black
            wheel.strokeColor = .clear
            wheel.position = CGPoint(x: CGFloat(dx), y: CGFloat(dy))
            addChild(wheel)
        }

        let basket = SKShapeNode(rectOf: CGSize(width: 58, height: 40), cornerRadius: 7)
        basket.fillColor = color
        basket.strokeColor = .white
        basket.lineWidth = isPlayer ? 3 : 2
        basket.zPosition = 1
        addChild(basket)

        // Basket mesh lines.
        let mesh = CGMutablePath()
        for gx in stride(from: CGFloat(-22), through: 22, by: 11) {
            mesh.move(to: CGPoint(x: gx, y: -18)); mesh.addLine(to: CGPoint(x: gx, y: 18))
        }
        for gy in stride(from: CGFloat(-14), through: 14, by: 14) {
            mesh.move(to: CGPoint(x: -26, y: gy)); mesh.addLine(to: CGPoint(x: 26, y: gy))
        }
        let meshNode = SKShapeNode(path: mesh)
        meshNode.strokeColor = SKColor.white.withAlphaComponent(0.35)
        meshNode.lineWidth = 1
        meshNode.zPosition = 2
        addChild(meshNode)

        // White nose bar (front).
        let nose = SKShapeNode(rectOf: CGSize(width: 6, height: 42), cornerRadius: 3)
        nose.fillColor = SKColor.white.withAlphaComponent(0.9)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 30, y: 0)
        nose.zPosition = 3
        addChild(nose)

        // Handle bar (back).
        let handle = SKShapeNode(rectOf: CGSize(width: 6, height: 32), cornerRadius: 3)
        handle.fillColor = SKColor.darkGray
        handle.strokeColor = .clear
        handle.position = CGPoint(x: -32, y: 0)
        handle.zPosition = 1
        addChild(handle)

        let rider = SKLabelNode(text: isPlayer ? "🧑" : "🧍")
        rider.fontSize = 22
        rider.verticalAlignmentMode = .center
        rider.horizontalAlignmentMode = .center
        rider.position = CGPoint(x: -12, y: 0)
        rider.zPosition = 4
        addChild(rider)

        boostPuff = SKLabelNode(text: "💨")
        boostPuff.fontSize = 26
        boostPuff.verticalAlignmentMode = .center
        boostPuff.position = CGPoint(x: -44, y: 0)
        boostPuff.zPosition = 0
        boostPuff.alpha = 0
        addChild(boostPuff)

        spinStars = SKLabelNode(text: "💫")
        spinStars.fontSize = 26
        spinStars.verticalAlignmentMode = .center
        spinStars.position = CGPoint(x: 0, y: 26)
        spinStars.zPosition = 6
        spinStars.alpha = 0
        addChild(spinStars)
    }

    private func buildPhysics() {
        let pb = SKPhysicsBody(rectangleOf: CGSize(width: 56, height: 38))
        pb.categoryBitMask = PhysicsCategory.cart
        pb.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.cart
        pb.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.cart |
            PhysicsCategory.itemBox | PhysicsCategory.hazard | PhysicsCategory.projectile
        pb.allowsRotation = false
        pb.affectedByGravity = false
        pb.friction = 0.1
        pb.restitution = 0.15
        pb.linearDamping = 0
        pb.mass = 0.6
        physicsBody = pb
    }

    // MARK: - Lifecycle

    func reset(position: CGPoint, heading: CGFloat) {
        self.position = position
        self.heading = heading
        self.zRotation = heading
        speed = 0
        maxSpeed = baseMaxSpeed
        boostTimer = 0
        spinTimer = 0
        driftCharge = 0
        isDrifting = false
        heldItem = nil
        checkpointsPassed = 0
        progressScore = 0
        finished = false
        finishTime = 0
        physicsBody?.velocity = .zero
        aiItemCooldown = TimeInterval.random(in: 2...5)
        aiLateralOffset = CGFloat.random(in: -80...80)
        boostPuff.alpha = 0
        spinStars.alpha = 0
    }

    // MARK: - Effects

    func spinOut() {
        guard spinTimer <= 0 else { return }
        spinTimer = 1.3
        speed = baseMaxSpeed * 0.18
        boostTimer = 0
    }

    func applyBoost(_ duration: TimeInterval = 1.6) {
        boostTimer = max(boostTimer, duration)
    }

    func bumpWall() {
        speed *= 0.55
    }

    // MARK: - Driving

    func drive(dt: TimeInterval, steer: CGFloat, accelerate: Bool, brake: Bool, drift: Bool) {
        let dtf = CGFloat(dt)

        if boostTimer > 0 { boostTimer -= dt }
        if spinTimer > 0 { spinTimer -= dt }

        boostPuff.alpha = isBoosting ? 1 : 0
        spinStars.alpha = isSpinning ? 1 : 0

        maxSpeed = baseMaxSpeed * (isBoosting ? 1.55 : 1.0)

        // Spinning out: no control, whirl around.
        if spinTimer > 0 {
            speed = max(speed - brakeDecel * 0.4 * dtf, baseMaxSpeed * 0.12)
            heading += 13 * dtf
            zRotation = heading
            physicsBody?.velocity = CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed)
            return
        }

        let accel = acceleration * (isBoosting ? 1.7 : 1.0)
        if brake {
            speed -= brakeDecel * dtf
        } else if accelerate {
            speed += accel * dtf
        } else {
            speed -= coastDecel * dtf
        }
        speed -= speed * 0.25 * dtf
        speed = clamp(speed, -90, maxSpeed)

        let speedFactor = clamp(abs(speed) / baseMaxSpeed, 0, 1)
        let gripMultiplier: CGFloat = drift ? 1.7 : 1.0
        let turn = steer * turnRate * gripMultiplier * dtf * (0.35 + 0.65 * speedFactor)
        heading += speed >= 0 ? turn : -turn

        // Drift charges a mini-turbo.
        if drift && abs(steer) > 0.1 && speed > baseMaxSpeed * 0.4 {
            isDrifting = true
            driftCharge += dt
        } else {
            if isDrifting && driftCharge > 0.6 {
                applyBoost(min(1.4, driftCharge * 0.9))
            }
            isDrifting = false
            driftCharge = 0
        }

        zRotation = heading
        physicsBody?.velocity = CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed)
    }
}
