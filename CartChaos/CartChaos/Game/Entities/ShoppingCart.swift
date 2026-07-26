import SpriteKit

final class ShoppingCart: SKNode {
    let profile: RacerProfile
    let isPlayer: Bool

    private(set) var speed: CGFloat = 0
    private(set) var heading: CGFloat = 0
    private(set) var waypointIndex: Int = 0
    private(set) var heldPowerUp: PowerUpType?
    private(set) var hasShield = false
    private(set) var isStunned = false

    private let bodyNode: SKNode
    private let shieldNode: SKShapeNode
    private var stunTimer: TimeInterval = 0
    private var boostTimer: TimeInterval = 0
    private var driftFactor: CGFloat = 1.0

    var racePosition: Int = 1

    init(profile: RacerProfile, isPlayer: Bool) {
        self.profile = profile
        self.isPlayer = isPlayer
        self.bodyNode = SKNode()
        self.shieldNode = SKShapeNode(circleOfRadius: 28)
        super.init()

        name = profile.name
        buildCartVisuals()
        shieldNode.strokeColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.8)
        shieldNode.fillColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.15)
        shieldNode.lineWidth = 2
        shieldNode.isHidden = true
        shieldNode.zPosition = 10
        addChild(shieldNode)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildCartVisuals() {
        // Wheels (wobbly for beat-up carts)
        let wheelOffsets: [(CGFloat, CGFloat)] = [(-14, -16), (14, -16), (-14, 14), (14, 14)]
        for (i, offset) in wheelOffsets.enumerated() {
            let wheel = SKShapeNode(circleOfRadius: 5)
            wheel.position = CGPoint(x: offset.0, y: offset.1)
            wheel.fillColor = SKColor(white: 0.15, alpha: 1)
            wheel.strokeColor = SKColor(white: 0.35, alpha: 1)
            wheel.lineWidth = 1
            wheel.zRotation = isPlayer ? 0 : CGFloat(i) * 0.15
            bodyNode.addChild(wheel)
        }

        // Cart basket
        let basket = SKShapeNode(rectOf: CGSize(width: 34, height: 42), cornerRadius: 3)
        basket.fillColor = profile.cartColor
        basket.strokeColor = profile.accentColor
        basket.lineWidth = 2
        basket.zPosition = 2
        bodyNode.addChild(basket)

        // Wire grid lines
        for y in [-10, 0, 10] as [CGFloat] {
            let wire = SKShapeNode(rectOf: CGSize(width: 30, height: 1.5))
            wire.position = CGPoint(x: 0, y: y)
            wire.fillColor = profile.accentColor.withAlphaComponent(0.6)
            wire.strokeColor = .clear
            basket.addChild(wire)
        }

        // Handle (bent on AI carts)
        let handle = SKShapeNode(rectOf: CGSize(width: 4, height: 22), cornerRadius: 2)
        handle.position = CGPoint(x: isPlayer ? 0 : 3, y: 24)
        handle.zRotation = isPlayer ? 0 : 0.25
        handle.fillColor = SKColor(white: 0.55, alpha: 1)
        handle.strokeColor = SKColor(white: 0.3, alpha: 1)
        handle.lineWidth = 1
        bodyNode.addChild(handle)

        // Cardboard rider silhouette
        let rider = SKShapeNode(rectOf: CGSize(width: 16, height: 20), cornerRadius: 4)
        rider.position = CGPoint(x: 0, y: -2)
        rider.fillColor = SKColor(red: 0.72, green: 0.55, blue: 0.35, alpha: 1)
        rider.strokeColor = SKColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        rider.lineWidth = 1
        rider.zPosition = 3
        bodyNode.addChild(rider)

        // Dents on non-player carts
        if !isPlayer {
            let dent = SKShapeNode(circleOfRadius: 4)
            dent.position = CGPoint(x: -8, y: 8)
            dent.fillColor = profile.accentColor.withAlphaComponent(0.5)
            dent.strokeColor = .clear
            basket.addChild(dent)
        }

        // Name tag
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = profile.name
        label.fontSize = 9
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -28)
        label.zPosition = 5
        bodyNode.addChild(label)

        addChild(bodyNode)
    }

    func reset(at position: CGPoint, heading: CGFloat) {
        self.position = position
        self.heading = heading
        self.zRotation = heading
        speed = 0
        lap = 0
        waypointIndex = 0
        heldPowerUp = nil
        hasShield = false
        isStunned = false
        stunTimer = 0
        boostTimer = 0
        shieldNode.isHidden = true
    }

    func consumePowerUp() -> PowerUpType? {
        let type = heldPowerUp
        heldPowerUp = nil
        return type
    }

    func applyInput(steer: CGFloat, accelerate: Bool, brake: Bool, drift: Bool) {
        guard !isStunned else { return }

        let turnRate = profile.handling * (1.0 + min(speed / profile.maxSpeed, 1.0) * 0.3)
        heading += steer * turnRate * 0.05
        zRotation = heading

        driftFactor = drift && speed > 80 ? 0.92 : 1.0

        if accelerate {
            speed += profile.acceleration * 0.016
        } else if brake {
            speed -= profile.acceleration * 0.024
        } else {
            speed *= 0.985
        }

        let maxSpd = profile.maxSpeed * (boostTimer > 0 ? 1.45 : 1.0)
        speed = max(0, min(speed, maxSpd))

        let dx = sin(heading) * speed * 0.016 * driftFactor
        let dy = cos(heading) * speed * 0.016 * driftFactor
        position.x += dx
        position.y += dy

        // Wobble animation at speed
        bodyNode.zRotation = sin(CFAbsoluteTimeGetCurrent() * 12) * min(speed / 500, 0.06)
    }

    func applyAI(steer: CGFloat, throttle: CGFloat) {
        guard !isStunned else { return }

        heading += steer * profile.handling * 0.045
        zRotation = heading

        speed += profile.acceleration * throttle * 0.014
        speed *= 0.988

        let maxSpd = profile.maxSpeed * (boostTimer > 0 ? 1.4 : 1.0)
        speed = max(0, min(speed, maxSpd))

        position.x += sin(heading) * speed * 0.016
        position.y += cos(heading) * speed * 0.016
    }

    func updateTimers(delta: TimeInterval) {
        if stunTimer > 0 {
            stunTimer -= delta
            if stunTimer <= 0 {
                isStunned = false
                bodyNode.alpha = 1.0
            }
        }
        if boostTimer > 0 {
            boostTimer -= delta
        }
    }

    func collectPowerUp(_ type: PowerUpType) {
        heldPowerUp = type
    }

    func activateBoost(duration: TimeInterval = 2.0) {
        boostTimer = duration
    }

    func activateShield() {
        hasShield = true
        shieldNode.isHidden = false
    }

    func breakShield() {
        hasShield = false
        shieldNode.isHidden = true
    }

    func stun(for duration: TimeInterval) {
        if hasShield {
            breakShield()
            return
        }
        isStunned = true
        stunTimer = duration
        speed *= 0.3
        bodyNode.alpha = 0.5
    }

    func advanceWaypoint(total: Int) {
        waypointIndex = (waypointIndex + 1) % total
        if waypointIndex == 0 {
            lap += 1
        }
    }

    func raceProgress(waypoints: [TrackWaypoint]) -> CGFloat {
        guard !waypoints.isEmpty else { return 0 }
        let base = CGFloat(lap) * CGFloat(waypoints.count)
        return base + CGFloat(waypointIndex)
    }
}
