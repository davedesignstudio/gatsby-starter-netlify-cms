import SpriteKit
import CoreMotion

final class GameScene: SKScene {
    private let world = SKNode()
    private let hud = SKNode()
    private let track = TrackBuilder()
    private var powerUps: PowerUpSystem!
    private var carts: [CartNode] = []
    private var player: CartNode!
    private var aiControllers: [AIController] = []
    private var checkpoints: [Checkpoint] = []

    private var throttle: CGFloat = 0
    private var steer: CGFloat = 0
    private var lastTime: TimeInterval?
    private var countdown: Int = 3
    private var racing = false
    private var raceOver = false
    private var finishCount = 0

    private var lapLabel: SKLabelNode!
    private var posLabel: SKLabelNode!
    private var itemLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!
    private var minimap: SKShapeNode!

    private let motion = CMMotionManager()
    private var useTilt = true

    // Touch control regions
    private var leftDown = false
    private var rightDown = false
    private var gasDown = false

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        removeAllChildren()
        addChild(world)
        addChild(hud)
        hud.zPosition = 100

        let built = track.build(into: world)
        checkpoints = built.checkpoints

        setupCarts(starts: built.startPositions, heading: built.startHeading)
        setupPowerUps()
        setupHUD()
        setupControls()
        startCountdown()

        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates()
        }
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }

    private func setupCarts(starts: [CGPoint], heading: CGFloat) {
        let playerProfile = RaceSession.shared.selectedCart
        var aiProfiles = CartProfile.roster.filter { $0.id != playerProfile.id }
        aiProfiles.shuffle()

        player = CartNode(profile: playerProfile, isPlayer: true)
        player.position = starts[0]
        player.heading = heading
        player.zRotation = heading + .pi / 2
        world.addChild(player)
        carts.append(player)

        for i in 1..<RaceConfig.racerCount {
            let profile = aiProfiles[i - 1]
            let ai = CartNode(profile: profile, isPlayer: false)
            ai.position = starts[i]
            ai.heading = heading
            ai.zRotation = heading + .pi / 2
            world.addChild(ai)
            carts.append(ai)
            aiControllers.append(AIController(track: track, aggression: 0.85 + CGFloat(i) * 0.05))
        }
    }

    private func setupPowerUps() {
        let spawns = [
            CGPoint(x: 900, y: 280),
            CGPoint(x: 1900, y: 400),
            CGPoint(x: 2050, y: 1100),
            CGPoint(x: 1300, y: 1550),
            CGPoint(x: 400, y: 1300),
            CGPoint(x: 320, y: 550),
            CGPoint(x: 1400, y: 320),
            CGPoint(x: 1800, y: 1400)
        ]
        powerUps = PowerUpSystem(world: world, spawnPoints: spawns)
    }

    private func setupHUD() {
        lapLabel = makeHUDLabel(text: "LAP 1/\(RaceConfig.totalLaps)", x: 20, y: size.height - 50, align: .left)
        posLabel = makeHUDLabel(text: "POS 1/4", x: size.width - 20, y: size.height - 50, align: .right)
        itemLabel = makeHUDLabel(text: "ITEM —", x: size.width / 2, y: size.height - 50, align: .center)

        countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        countdownLabel.fontSize = 72
        countdownLabel.fontColor = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        countdownLabel.zPosition = 200
        hud.addChild(countdownLabel)

        // Minimap frame
        minimap = SKShapeNode(rectOf: CGSize(width: 120, height: 90), cornerRadius: 8)
        minimap.fillColor = UIColor(white: 0.1, alpha: 0.55)
        minimap.strokeColor = UIColor(white: 1, alpha: 0.3)
        minimap.lineWidth = 1.5
        minimap.position = CGPoint(x: size.width - 80, y: size.height - 130)
        minimap.name = "minimap"
        hud.addChild(minimap)
    }

    private func makeHUDLabel(text: String, x: CGFloat, y: CGFloat, align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = align
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 110
        // Soft shadow via duplicate would be overkill; keep crisp
        hud.addChild(label)
        return label
    }

    private func setupControls() {
        let btnH: CGFloat = 64
        let btnW: CGFloat = 72
        let bottom: CGFloat = 36

        makeControl(name: "left", title: "◀", x: 50, y: bottom + btnH / 2, w: btnW, h: btnH, color: UIColor(white: 0.2, alpha: 0.65))
        makeControl(name: "right", title: "▶", x: 130, y: bottom + btnH / 2, w: btnW, h: btnH, color: UIColor(white: 0.2, alpha: 0.65))
        makeControl(name: "brake", title: "BRK", x: size.width - 200, y: bottom + btnH / 2, w: btnW, h: btnH, color: UIColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 0.7))
        makeControl(name: "gas", title: "GAS", x: size.width - 110, y: bottom + btnH / 2 + 10, w: 88, h: 78, color: UIColor(red: 0.2, green: 0.55, blue: 0.3, alpha: 0.75))
        makeControl(name: "item", title: "ITEM", x: size.width / 2, y: bottom + 40, w: 90, h: 54, color: UIColor(red: 0.85, green: 0.65, blue: 0.15, alpha: 0.8))
    }

    private func makeControl(name: String, title: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: UIColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 14)
        btn.fillColor = color
        btn.strokeColor = UIColor(white: 1, alpha: 0.35)
        btn.lineWidth = 1.5
        btn.position = CGPoint(x: x, y: y)
        btn.name = name
        btn.zPosition = 120
        hud.addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = title.count > 2 ? 16 : 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    private func startCountdown() {
        countdown = 3
        racing = false
        runCountdownStep()
    }

    private func runCountdownStep() {
        if countdown > 0 {
            countdownLabel.text = "\(countdown)"
            countdownLabel.setScale(1.4)
            countdownLabel.alpha = 1
            countdownLabel.run(.group([
                .scale(to: 1.0, duration: 0.35),
                .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.2)])
            ]))
            countdown -= 1
            run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in self?.runCountdownStep() }]))
        } else {
            countdownLabel.text = "GO!"
            countdownLabel.fontColor = UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1)
            countdownLabel.alpha = 1
            countdownLabel.setScale(1.2)
            countdownLabel.run(.sequence([
                .group([.scale(to: 1.6, duration: 0.4), .fadeOut(withDuration: 0.5)]),
                .run { [weak self] in self?.racing = true }
            ]))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(1.0 / 30.0, lastTime.map { currentTime - $0 } ?? 1 / 60)
        lastTime = currentTime

        updateInputFromTilt()
        applyControls(dt: dt)
        updateCheckpoints()
        powerUps.update(carts: carts, dt: dt)
        resolveCartCollisions()
        updateCamera()
        updateHUD()
        updateMinimap()
        checkRaceOver()
    }

    private func updateInputFromTilt() {
        guard useTilt, let data = motion.deviceMotion else { return }
        // Roll steers when buttons aren't held
        if !leftDown && !rightDown {
            let roll = CGFloat(data.attitude.roll)
            steer = max(-1, min(1, roll * 2.2))
        }
    }

    private func applyControls(dt: TimeInterval) {
        // Player
        var playerThrottle = throttle
        var playerSteer = steer
        if leftDown { playerSteer = -1 }
        if rightDown { playerSteer = 1 }
        if !racing { playerThrottle = 0; playerSteer = 0 }
        player.applyInput(throttle: playerThrottle, steer: playerSteer, dt: dt)
        constrainToWorld(player)

        // AI
        if racing {
            for (i, cart) in carts.enumerated() where !cart.isPlayer && !cart.finished {
                let aiIndex = i - 1
                guard aiIndex >= 0, aiIndex < aiControllers.count else { continue }
                let input = aiControllers[aiIndex].steer(for: cart)
                cart.applyInput(throttle: input.throttle, steer: input.steer, dt: dt)
                if input.useItem {
                    powerUps.useItem(for: cart)
                }
                constrainToWorld(cart)
            }
        } else {
            for cart in carts where !cart.isPlayer {
                cart.applyInput(throttle: 0, steer: 0, dt: dt)
            }
        }

        // Off-track slowdown
        for cart in carts {
            if !track.isOnTrack(cart.position) {
                cart.velocity.dx *= 0.9
                cart.velocity.dy *= 0.9
            }
        }
    }

    private func constrainToWorld(_ cart: CartNode) {
        let m: CGFloat = 40
        cart.position.x = max(m, min(track.worldSize.width - m, cart.position.x))
        cart.position.y = max(m, min(track.worldSize.height - m, cart.position.y))
    }

    private func updateCheckpoints() {
        for cart in carts where !cart.finished {
            let next = cart.checkpointIndex % checkpoints.count
            let cp = checkpoints[next]
            if hypot(cart.position.x - cp.position.x, cart.position.y - cp.position.y) < cp.radius {
                cart.checkpointIndex += 1
                if cart.checkpointIndex > 0 && cart.checkpointIndex % checkpoints.count == 0 {
                    cart.currentLap += 1
                    if cart.currentLap >= RaceConfig.totalLaps {
                        finishCount += 1
                        cart.finished = true
                        cart.finishPlace = finishCount
                        cart.velocity = .zero
                        if cart.isPlayer {
                            // allow others to finish briefly
                        }
                    }
                }
            }
            cart.progress = CGFloat(cart.currentLap * checkpoints.count) + track.nearestProgress(for: cart.position, checkpointIndex: cart.checkpointIndex)
        }
    }

    private func resolveCartCollisions() {
        for i in 0..<carts.count {
            for j in (i + 1)..<carts.count {
                let a = carts[i], b = carts[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = hypot(dx, dy)
                let minDist = a.radius + b.radius
                if dist < minDist && dist > 0.1 {
                    let nx = dx / dist, ny = dy / dist
                    let overlap = (minDist - dist) / 2
                    a.position.x -= nx * overlap
                    a.position.y -= ny * overlap
                    b.position.x += nx * overlap
                    b.position.y += ny * overlap

                    let wa = a.profile.weight, wb = b.profile.weight
                    let rvx = a.velocity.dx - b.velocity.dx
                    let rvy = a.velocity.dy - b.velocity.dy
                    let impact = rvx * nx + rvy * ny
                    if impact > 0 { continue }
                    let impulse = 1.6 * impact / (wa + wb)
                    a.velocity.dx -= impulse * wb * nx
                    a.velocity.dy -= impulse * wb * ny
                    b.velocity.dx += impulse * wa * nx
                    b.velocity.dy += impulse * wa * ny
                }
            }
        }
    }

    private func updateCamera() {
        let target = CGPoint(x: player.position.x - size.width / 2, y: player.position.y - size.height / 2)
        let blend: CGFloat = 0.12
        world.position.x += (-target.x - world.position.x) * blend
        world.position.y += (-target.y - world.position.y) * blend
    }

    private func updateHUD() {
        let lap = min(player.currentLap + 1, RaceConfig.totalLaps)
        lapLabel.text = "LAP \(lap)/\(RaceConfig.totalLaps)"

        let sorted = carts.sorted { $0.progress > $1.progress }
        let place = (sorted.firstIndex(where: { $0 === player }) ?? 0) + 1
        posLabel.text = "POS \(place)/\(carts.count)"

        if let item = player.heldItem {
            itemLabel.text = "ITEM \(item.displayName)"
            itemLabel.fontColor = item.color
        } else {
            itemLabel.text = "ITEM —"
            itemLabel.fontColor = .white
        }
    }

    private func updateMinimap() {
        minimap.children.forEach { $0.removeFromParent() }
        let scaleX = 100 / track.worldSize.width
        let scaleY = 70 / track.worldSize.height
        for cart in carts {
            let dot = SKShapeNode(circleOfRadius: cart.isPlayer ? 4 : 3)
            dot.fillColor = cart.isPlayer ? UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1) : cart.profile.bodyColor
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: (cart.position.x - track.worldSize.width / 2) * scaleX,
                y: (cart.position.y - track.worldSize.height / 2) * scaleY
            )
            minimap.addChild(dot)
        }
    }

    private func checkRaceOver() {
        guard !raceOver, player.finished else { return }
        raceOver = true
        // Fill unfinished by progress
        var order = carts.filter { $0.finished }.sorted { $0.finishPlace < $1.finishPlace }.map(\.profile.name)
        let rest = carts.filter { !$0.finished }.sorted { $0.progress > $1.progress }.map(\.profile.name)
        order.append(contentsOf: rest)
        RaceSession.shared.finishingOrder = order
        RaceSession.shared.playerFinishPosition = player.finishPlace

        run(.sequence([
            .wait(forDuration: 1.4),
            .run { [weak self] in
                guard let self else { return }
                let results = ResultsScene(size: self.size)
                results.scaleMode = .resizeFill
                self.view?.presentScene(results, transition: .fade(with: .black, duration: 0.5))
            }
        ]))
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, down: true) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Keep button state from began/ended; optional drag-off ignored for simplicity
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { handleTouch(touch, down: false) }
        // If no touches remain, clear holds
        if let view, view.window == nil || touches.count > 0 {
            // cleared per-button below
        }
        // Reset when all fingers up — check remaining
        if (event?.allTouches?.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }.isEmpty) ?? true {
            leftDown = false; rightDown = false; gasDown = false; throttle = 0; steer = 0
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        leftDown = false; rightDown = false; gasDown = false; throttle = 0; steer = 0
    }

    private func handleTouch(_ touch: UITouch, down: Bool) {
        let loc = touch.location(in: hud)
        let hit = hud.nodes(at: loc)
        if hit.contains(where: { $0.name == "left" }) {
            leftDown = down
            if down { steer = -1 }
        }
        if hit.contains(where: { $0.name == "right" }) {
            rightDown = down
            if down { steer = 1 }
        }
        if hit.contains(where: { $0.name == "gas" }) {
            gasDown = down
            throttle = down ? 1 : 0
        }
        if hit.contains(where: { $0.name == "brake" }) {
            throttle = down ? -0.35 : (gasDown ? 1 : 0)
        }
        if down, hit.contains(where: { $0.name == "item" }) {
            powerUps.useItem(for: player)
        }
    }
}
