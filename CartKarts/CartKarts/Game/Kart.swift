import SpriteKit

/// A racing shopping cart. Movement is a hybrid arcade model: we steer the
/// node's rotation directly, rebuild the physics velocity from forward/lateral
/// components each frame (so grip and drift are tunable), and let SpriteKit's
/// physics engine resolve collisions with walls and other carts.
final class Kart: SKNode {
    let character: CartCharacter
    let isPlayer: Bool

    // MARK: Inputs (written by the player controls or an AIDriver)

    /// -1 = full right, +1 = full left.
    var steerInput: CGFloat = 0
    /// 0...1 forward, negative values reverse (AI un-stuck maneuver).
    var throttleInput: CGFloat = 0

    // MARK: Race bookkeeping

    var nextWaypointIndex = 0
    var totalWaypointsPassed = 0
    /// Monotonic score used for ranking; updated by the race scene.
    var progressScore: CGFloat = 0
    var finishTime: TimeInterval?
    var heldItem: ItemKind?
    /// Rubber-banding multiplier applied by the race scene (1 = neutral).
    var externalSpeedFactor: CGFloat = 1

    var lap: Int { totalWaypointsPassed / max(1, waypointCount) + 1 }
    var waypointCount = 1

    // MARK: Status effects

    private(set) var boostTimer: TimeInterval = 0
    private var boostStrength: CGFloat = 1
    private(set) var spinTimer: TimeInterval = 0
    private(set) var slipTimer: TimeInterval = 0
    private(set) var invulnerableTimer: TimeInterval = 0
    private var driftTime: TimeInterval = 0
    private var wasDrifting = false
    private var slipPhase: CGFloat = 0

    var isSpinning: Bool { spinTimer > 0 }
    var isInvulnerable: Bool { invulnerableTimer > 0 }

    // MARK: Nodes

    private let spinContainer = SKNode()
    private let sprite: SKSpriteNode
    private let smoke: SKEmitterNode
    private let flame: SKEmitterNode

    /// World-space direction the cart is pointing.
    var heading: CGFloat { zRotation + .pi / 2 }
    var forwardVector: CGPoint { unitVector(angle: heading) }

    var currentSpeed: CGFloat {
        guard let v = physicsBody?.velocity else { return 0 }
        return CGPoint(x: v.dx, y: v.dy).length
    }

    // MARK: - Init

    init(character: CartCharacter, isPlayer: Bool) {
        self.character = character
        self.isPlayer = isPlayer
        sprite = SKSpriteNode(texture: TextureFactory.cart(color: character.color, name: character.name))
        sprite.size = CGSize(width: 56, height: 84)
        smoke = Kart.makeEmitter(color: .white, speed: 30, lifetime: 0.45, birthRate: 0)
        flame = Kart.makeEmitter(color: UIColor(red: 1, green: 0.6, blue: 0.15, alpha: 1),
                                 speed: 90, lifetime: 0.3, birthRate: 0)
        super.init()

        addChild(spinContainer)
        spinContainer.addChild(sprite)

        // Rattly-cart charm: the basket jitters slightly, forever.
        sprite.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.02, duration: 0.06),
            .rotate(toAngle: -0.02, duration: 0.06),
        ])))

        for emitter in [smoke, flame] {
            emitter.position = CGPoint(x: 0, y: -40)
            emitter.zPosition = -1
            addChild(emitter)
        }

        let body = SKPhysicsBody(circleOfRadius: 26)
        body.mass = character.weight
        body.allowsRotation = false
        body.friction = 0.1
        body.restitution = 0.35
        body.linearDamping = 0.3
        body.categoryBitMask = PhysicsCategory.kart
        body.collisionBitMask = PhysicsCategory.kart | PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.itemBox | PhysicsCategory.banana
            | PhysicsCategory.can | PhysicsCategory.puddle
        physicsBody = body
        zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Emitters need a target node so particles trail behind in world space.
    func attachEffects(to worldNode: SKNode) {
        smoke.targetNode = worldNode
        flame.targetNode = worldNode
    }

    // MARK: - Simulation

    func update(dt: TimeInterval) {
        boostTimer = max(0, boostTimer - dt)
        spinTimer = max(0, spinTimer - dt)
        slipTimer = max(0, slipTimer - dt)
        invulnerableTimer = max(0, invulnerableTimer - dt)
        guard let body = physicsBody else { return }

        let forward = forwardVector
        let right = unitVector(angle: heading - .pi / 2)
        let velocity = body.velocity.point
        var forwardSpeed = velocity.dot(forward)
        var lateralSpeed = velocity.dot(right)

        if isSpinning {
            // No control while spun out; scrub speed off quickly.
            forwardSpeed *= CGFloat(exp(-4.0 * dt))
            lateralSpeed *= CGFloat(exp(-4.0 * dt))
            body.velocity = CGVector(point: forward * forwardSpeed + right * lateralSpeed)
            smoke.particleBirthRate = 60
            return
        }

        // Steering effectiveness ramps up with speed so carts don't pivot in place.
        let speedFactor = clamp(abs(forwardSpeed) / 220, 0, 1)
        let reverseSign: CGFloat = forwardSpeed < -10 ? -1 : 1
        zRotation += steerInput * character.steering * speedFactor * reverseSign * CGFloat(dt)

        if slipTimer > 0 {
            // Wobble on spilled milk.
            slipPhase += CGFloat(dt) * 18
            zRotation += sin(slipPhase) * 1.4 * CGFloat(dt)
        }

        // Drift: hard steering at speed loosens grip; holding it earns a mini-turbo.
        let drifting = abs(steerInput) > 0.85 && forwardSpeed > character.topSpeed * 0.55
        if drifting {
            driftTime += dt
        } else {
            if wasDrifting && driftTime > 0.9 {
                boost(duration: 0.7, strength: 1.30)
            }
            driftTime = 0
        }
        wasDrifting = drifting

        // Longitudinal: approach target speed.
        let boostMultiplier: CGFloat = boostTimer > 0 ? boostStrength : 1
        let targetSpeed = character.topSpeed * throttleInput * boostMultiplier * externalSpeedFactor
        let blend = CGFloat(min(1.0, Double(character.acceleration) * dt))
        forwardSpeed += (targetSpeed - forwardSpeed) * blend

        // Lateral: grip bleeds sideways velocity. Less grip while drifting/slipping.
        let grip: CGFloat = slipTimer > 0 ? 1.2 : (drifting ? 3.2 : 9.0)
        lateralSpeed *= CGFloat(exp(-Double(grip) * dt))

        body.velocity = CGVector(point: forward * forwardSpeed + right * lateralSpeed)

        smoke.particleBirthRate = drifting || slipTimer > 0 ? 90 : 0
        flame.particleBirthRate = boostTimer > 0 ? 140 : 0
    }

    // MARK: - Status effects

    func boost(duration: TimeInterval, strength: CGFloat = 1.45) {
        boostTimer = max(boostTimer, duration)
        boostStrength = strength
        if let body = physicsBody {
            let kick = forwardVector * (character.topSpeed * 0.25)
            body.velocity = CGVector(dx: body.velocity.dx + kick.x, dy: body.velocity.dy + kick.y)
        }
    }

    func spinOut() {
        guard !isSpinning, !isInvulnerable else { return }
        spinTimer = 1.0
        invulnerableTimer = 2.2
        driftTime = 0
        heldItemDropCheck()
        spinContainer.run(.rotate(byAngle: .pi * 4, duration: 1.0), withKey: "spin")
        // Blink while invulnerable.
        sprite.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.35, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)]), count: 11),
            .fadeAlpha(to: 1, duration: 0.05),
        ]), withKey: "blink")
    }

    private func heldItemDropCheck() {
        // Getting wrecked knocks your groceries out of the basket.
        heldItem = nil
    }

    func slip(duration: TimeInterval) {
        guard !isInvulnerable else { return }
        slipTimer = max(slipTimer, duration)
    }

    // MARK: - Particles

    private static func makeEmitter(color: UIColor, speed: CGFloat,
                                    lifetime: CGFloat, birthRate: CGFloat) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = TextureFactory.softDot
        e.particleBirthRate = birthRate
        e.particleLifetime = lifetime
        e.particleAlpha = 0.55
        e.particleAlphaSpeed = -1.2
        e.particleScale = 0.6
        e.particleScaleSpeed = 1.6
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.5
        e.emissionAngleRange = .pi * 2
        e.particleColor = color
        e.particleColorBlendFactor = 1
        return e
    }
}
