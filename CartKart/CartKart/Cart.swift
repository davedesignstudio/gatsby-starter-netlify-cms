import SpriteKit

/// A single racer — a runaway shopping cart careening through the store.
///
/// The node owns its own arcade physics (speed + heading), lap/checkpoint
/// progress used for the standings, and helper hooks for items. AI carts reuse
/// the exact same physics via `aiControls(on:)`.
final class Cart: SKNode {

    let racerName: String
    let tint: SKColor
    let isPlayer: Bool

    /// Multiplier on top speed so AI opponents can be tuned easier than the player.
    var speedSkill: CGFloat = 1.0

    // Physics state.
    private(set) var speed: CGFloat = 0
    private(set) var heading: CGFloat = 0

    // Item state.
    var heldItem: ItemType?

    // Timed effects.
    private var boostRemaining: TimeInterval = 0
    private var spinRemaining: TimeInterval = 0

    // Lap / ranking progress.
    private(set) var lap: Int = 0
    private(set) var nextCheckpoint: Int = 1
    private(set) var checkpointsCleared: Int = 0
    private(set) var finished = false
    private(set) var finishTime: TimeInterval = 0

    var isSpinning: Bool { spinRemaining > 0 }
    var isBoosting: Bool { boostRemaining > 0 }

    init(name: String, tint: SKColor, isPlayer: Bool) {
        self.racerName = name
        self.tint = tint
        self.isPlayer = isPlayer
        super.init()
        self.zPosition = GameConfig.ZPosition.cart
        buildVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - Setup

    func place(at slot: Track.StartSlot) {
        position = slot.position
        heading = slot.heading
        zRotation = heading
        speed = 0
        lap = 0
        nextCheckpoint = 1
        checkpointsCleared = 0
        finished = false
        finishTime = 0
        boostRemaining = 0
        spinRemaining = 0
        heldItem = nil
    }

    private func buildVisuals() {
        // Wheels first so they sit under the basket.
        for dx in [CGFloat(-18), 18] {
            for dy in [CGFloat(-16), 16] {
                let wheel = SKShapeNode(circleOfRadius: 6)
                wheel.fillColor = SKColor(white: 0.1, alpha: 1)
                wheel.strokeColor = .clear
                wheel.position = CGPoint(x: dx, y: dy)
                addChild(wheel)
            }
        }

        // Basket body (points toward +x, its nose).
        let body = SKShapeNode(rectOf: CGSize(width: 54, height: 40), cornerRadius: 7)
        body.fillColor = SKColor(white: 0.8, alpha: 1)
        body.strokeColor = SKColor(white: 0.35, alpha: 1)
        body.lineWidth = 3
        addChild(body)

        // Basket grid lines for a wire-cart look.
        let grid = SKNode()
        for x in stride(from: CGFloat(-18), through: 18, by: 12) {
            let line = SKShapeNode(rectOf: CGSize(width: 1.5, height: 34))
            line.fillColor = SKColor(white: 0.5, alpha: 0.7)
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: 0)
            grid.addChild(line)
        }
        addChild(grid)

        // Front push-bar (the nose).
        let nose = SKShapeNode(rectOf: CGSize(width: 8, height: 44), cornerRadius: 3)
        nose.fillColor = tint
        nose.strokeColor = SKColor(white: 0.2, alpha: 1)
        nose.lineWidth = 1.5
        nose.position = CGPoint(x: 28, y: 0)
        addChild(nose)

        // Identifying flag on a little pole at the back.
        let flag = SKShapeNode(rectOf: CGSize(width: 20, height: 14))
        flag.fillColor = tint
        flag.strokeColor = .white
        flag.lineWidth = 1.5
        flag.position = CGPoint(x: -30, y: 8)
        addChild(flag)

        if isPlayer {
            let ring = SKShapeNode(circleOfRadius: 40)
            ring.strokeColor = SKColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.9)
            ring.lineWidth = 3
            ring.fillColor = .clear
            ring.name = "playerRing"
            addChild(ring)
        }

        let label = SKLabelNode(text: racerName)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 42)
        label.zRotation = 0
        label.name = "nameLabel"
        addChild(label)
    }

    // MARK: - Effects

    func applyBoost() {
        boostRemaining = GameConfig.boostDuration
        speed = max(speed, GameConfig.maxSpeedOnTrack * GameConfig.boostMultiplier * 0.9)
    }

    func spinOut() {
        guard spinRemaining <= 0 else { return }
        spinRemaining = GameConfig.spinOutDuration
        speed *= 0.25
    }

    // MARK: - Simulation

    /// Advance the cart one frame. `steering` in [-1, 1], `throttle` in [0, 1].
    func update(dt: TimeInterval, steering: CGFloat, throttle: CGFloat, track: Track) {
        guard !finished else {
            speed *= 0.9
            advance(dt: dt)
            return
        }

        let dtf = CGFloat(dt)

        if spinRemaining > 0 {
            spinRemaining -= dt
            heading += 14 * dtf                // whirl around
            speed *= 0.86
            zRotation = heading
            advance(dt: dt)
            updateProgress(track: track)
            return
        }

        // Steering is more effective the faster you roll.
        let onTrack = track.isOnTrack(position)
        var maxSpeed = (onTrack ? GameConfig.maxSpeedOnTrack : GameConfig.maxSpeedOffTrack) * speedSkill
        if boostRemaining > 0 {
            maxSpeed *= GameConfig.boostMultiplier
            boostRemaining -= dt
        }

        let steerEffect = clamp(speed / (GameConfig.maxSpeedOnTrack * 0.35), 0.35, 1.0)
        heading += steering * GameConfig.turnRate * steerEffect * dtf
        heading = normalizeAngle(heading)

        speed += GameConfig.acceleration * clamp(throttle, 0, 1) * dtf
        speed -= speed * GameConfig.drag * dtf
        speed = clamp(speed, 0, maxSpeed)

        zRotation = heading
        advance(dt: dt)
        updateProgress(track: track)
    }

    private func advance(dt: TimeInterval) {
        let dir = CGPoint(x: cos(heading), y: sin(heading))
        position = position + dir * (speed * CGFloat(dt))

        // Stay inside the store walls.
        let margin: CGFloat = 30
        position.x = clamp(position.x, margin, GameConfig.worldSize.width - margin)
        position.y = clamp(position.y, margin, GameConfig.worldSize.height - margin)

        // Keep name label upright while the cart rotates.
        if let label = childNode(withName: "nameLabel") {
            label.zRotation = -zRotation
        }
    }

    private func updateProgress(track: Track) {
        guard !finished else { return }
        let target = track.checkpoint(nextCheckpoint)
        if position.distance(to: target) < GameConfig.trackWidth * 0.85 {
            checkpointsCleared += 1
            if nextCheckpoint == 0 {
                lap += 1
            }
            nextCheckpoint = (nextCheckpoint + 1) % track.checkpointCount
        }
    }

    func markFinished(at time: TimeInterval) {
        guard !finished else { return }
        finished = true
        finishTime = time
    }

    // MARK: - Ranking

    /// Higher = further along the race. Used to sort the standings.
    func progressScore(track: Track) -> CGFloat {
        let base = CGFloat(checkpointsCleared) * 10_000
        // Closer to the next checkpoint counts as more progress.
        let target = track.checkpoint(nextCheckpoint)
        let remaining = position.distance(to: target)
        return base - remaining
    }

    // MARK: - AI

    /// Compute steering + throttle for a computer-controlled cart.
    func aiControls(on track: Track) -> (steering: CGFloat, throttle: CGFloat) {
        let target = track.checkpoint(nextCheckpoint)
        let desired = position.angle(to: target)
        let delta = shortestAngleDelta(from: heading, to: desired)
        let steering = clamp(delta / 0.6, -1, 1)
        // Ease off the gas a touch in hard corners so the AI does not fly off.
        let throttle: CGFloat = abs(delta) > 1.1 ? 0.7 : 1.0
        return (steering, throttle)
    }
}
