import SpriteKit

final class RaceScene: SKScene, SKPhysicsContactDelegate {
    static let totalLaps = 3

    private enum RaceState { case countdown, racing, finished }

    private let playerCharacterIndex: Int
    private let track = Track()
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private var hud: HUD!
    private var karts: [Kart] = []
    private var player: Kart!
    private var aiDrivers: [AIDriver] = []
    private var playerAutopilot: AIDriver?

    private var state: RaceState = .countdown
    private var raceClock: TimeInterval = 0
    private var lastUpdate: TimeInterval?
    private var resultsShown = false

    /// Active steering touches mapped to their current direction (+1 left, -1 right).
    private var steeringTouches: [UITouch: CGFloat] = [:]

    private let cameraZoom: CGFloat = 1.6
    private lazy var lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private lazy var heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Init

    init(size: CGSize, playerCharacterIndex: Int) {
        self.playerCharacterIndex = playerCharacterIndex
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(worldNode)
        track.build(into: worldNode)
        spawnKarts()

        cameraNode.setScale(cameraZoom)
        cameraNode.position = player.position
        addChild(cameraNode)
        camera = cameraNode

        hud = HUD(size: size)
        cameraNode.addChild(hud)
        hud.set(lap: 1, totalLaps: RaceScene.totalLaps)
        hud.set(position: karts.count)

        runCountdown()
    }

    private func spawnKarts() {
        let roster = CartCharacter.roster
        // Player starts at the back of the grid; rivals fill the front rows.
        var order = Array(roster.indices)
        order.removeAll { $0 == playerCharacterIndex }
        order.append(playerCharacterIndex)

        let grid = track.gridPositions(count: order.count)
        for (slot, characterIndex) in order.enumerated() {
            let isPlayer = characterIndex == playerCharacterIndex
            let kart = Kart(character: roster[characterIndex], isPlayer: isPlayer)
            kart.position = grid[slot]
            kart.zRotation = track.startRotation
            kart.waypointCount = track.waypoints.count
            worldNode.addChild(kart)
            kart.attachEffects(to: worldNode)
            karts.append(kart)
            if isPlayer {
                player = kart
            } else {
                aiDrivers.append(AIDriver(kart: kart, seed: slot + 1))
            }
        }
    }

    private func runCountdown() {
        let red = UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1)
        let orange = UIColor(red: 0.98, green: 0.65, blue: 0.20, alpha: 1)
        let yellow = UIColor(red: 0.98, green: 0.88, blue: 0.30, alpha: 1)
        let green = UIColor(red: 0.40, green: 0.90, blue: 0.45, alpha: 1)
        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.hud.announce("3", color: red) },
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.hud.announce("2", color: orange) },
            .wait(forDuration: 1.0),
            .run { [weak self] in self?.hud.announce("1", color: yellow) },
            .wait(forDuration: 1.0),
            .run { [weak self] in
                self?.hud.announce("GO!", color: green)
                self?.state = .racing
            },
        ]))
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        guard let last = lastUpdate else {
            lastUpdate = currentTime
            return
        }
        let dt = min(currentTime - last, 1.0 / 30.0)
        lastUpdate = currentTime

        switch state {
        case .countdown:
            for kart in karts {
                kart.throttleInput = 0
                kart.physicsBody?.velocity = .zero
            }
        case .racing, .finished:
            raceClock += dt
            drivePlayer(dt: dt)
            driveAI(dt: dt)
            for kart in karts {
                kart.update(dt: dt)
                advanceWaypoints(for: kart)
            }
            applyRubberBanding()
            checkFinishes()
            refreshHUD()
        }
        updateCamera(dt: dt)
    }

    private func drivePlayer(dt: TimeInterval) {
        if let autopilot = playerAutopilot {
            _ = autopilot.update(dt: dt, track: track)
            return
        }
        player.throttleInput = 1
        let steer = clamp(steeringTouches.values.reduce(0, +), -1, 1)
        player.steerInput = steer
        hud.steeringFeedback(steer)
    }

    private func driveAI(dt: TimeInterval) {
        for driver in aiDrivers {
            if let item = driver.update(dt: dt, track: track), item == driver.kart.heldItem {
                useItem(for: driver.kart)
            }
        }
    }

    private func advanceWaypoints(for kart: Kart) {
        let waypoints = track.waypoints
        let current = waypoints[kart.nextWaypointIndex % waypoints.count]
        if kart.position.distance(to: current.position) < current.radius {
            kart.nextWaypointIndex = (kart.nextWaypointIndex + 1) % waypoints.count
            kart.totalWaypointsPassed += 1
        }
        let next = waypoints[kart.nextWaypointIndex % waypoints.count]
        kart.progressScore = CGFloat(kart.totalWaypointsPassed) * 1000
            - kart.position.distance(to: next.position)
    }

    private func applyRubberBanding() {
        for kart in karts where !kart.isPlayer {
            let gap = player.progressScore - kart.progressScore
            kart.externalSpeedFactor = clamp(1 + gap * 0.00004, 0.90, 1.12)
        }
    }

    private func checkFinishes() {
        for kart in karts where kart.finishTime == nil && kart.lap > RaceScene.totalLaps {
            kart.finishTime = raceClock
            if kart.isPlayer {
                playerDidFinish()
            }
        }
    }

    private func playerDidFinish() {
        state = .finished
        hud.announce("FINISH!", color: UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1), hold: 1.0)
        hud.steeringFeedback(0)
        steeringTouches.removeAll()
        playerAutopilot = AIDriver(kart: player, seed: 42)
        heavyHaptic.impactOccurred()
        run(.sequence([
            .wait(forDuration: 1.4),
            .run { [weak self] in self?.showResults() },
        ]))
    }

    private func showResults() {
        let standings = karts.sorted { a, b in
            switch (a.finishTime, b.finishTime) {
            case let (ta?, tb?): return ta < tb
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.progressScore > b.progressScore
            }
        }
        let rows = standings.enumerated().map { index, kart in
            HUD.ResultRow(place: index + 1,
                          name: kart.character.name,
                          detail: kart.finishTime.map(RaceScene.formatTime) ?? "still racing…",
                          isPlayer: kart.isPlayer)
        }
        hud.showResults(rows)
        resultsShown = true
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = time - TimeInterval(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }

    private func refreshHUD() {
        let rank = 1 + karts.filter { $0 !== player && $0.progressScore > player.progressScore }.count
        if player.finishTime == nil {
            hud.set(position: rank)
            hud.set(lap: player.lap, totalLaps: RaceScene.totalLaps)
        }
        hud.setItem(player.heldItem)
    }

    private func updateCamera(dt: TimeInterval) {
        let velocity = player.physicsBody?.velocity ?? .zero
        var target = player.position + CGPoint(x: velocity.dx, y: velocity.dy) * 0.28
        let halfWidth = size.width / 2 * cameraZoom
        let halfHeight = size.height / 2 * cameraZoom
        if Track.worldSize.width > halfWidth * 2 {
            target.x = clamp(target.x, halfWidth, Track.worldSize.width - halfWidth)
        }
        if Track.worldSize.height > halfHeight * 2 {
            target.y = clamp(target.y, halfHeight, Track.worldSize.height - halfHeight)
        }
        let t = CGFloat(1 - exp(-5 * dt))
        cameraNode.position = CGPoint(x: lerp(cameraNode.position.x, target.x, t),
                                      y: lerp(cameraNode.position.y, target.y, t))
    }

    // MARK: - Items

    private func useItem(for kart: Kart) {
        guard state != .countdown, let item = kart.heldItem, !kart.isSpinning else { return }
        kart.heldItem = nil
        switch item {
        case .turboCola:
            kart.boost(duration: 1.6)
        case .bananaPeel:
            let banana = BananaNode(position: kart.position - kart.forwardVector * 78,
                                    owner: kart, now: raceClock)
            worldNode.addChild(banana)
        case .soupCan:
            let velocity = kart.forwardVector * (kart.currentSpeed + 560)
            let can = CanNode(position: kart.position + kart.forwardVector * 66,
                              velocity: velocity, owner: kart, now: raceClock)
            worldNode.addChild(can)
        }
        if kart.isPlayer {
            lightHaptic.impactOccurred()
        }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        // Soup can ricochets: count wall bounces, explode after too many.
        if let can = (contact.bodyA.node as? CanNode) ?? (contact.bodyB.node as? CanNode) {
            let otherBody = contact.bodyA.node === can ? contact.bodyB : contact.bodyA
            if otherBody.categoryBitMask == PhysicsCategory.wall {
                can.bounces += 1
                if can.bounces > 2 { can.explode() }
                return
            }
        }

        guard let kart = (contact.bodyA.node as? Kart) ?? (contact.bodyB.node as? Kart) else { return }
        let otherNode = contact.bodyA.node === kart ? contact.bodyB.node : contact.bodyA.node

        switch otherNode {
        case let box as ItemBoxNode:
            if box.isAvailable, kart.heldItem == nil, !kart.isSpinning {
                box.collect()
                kart.heldItem = ItemKind.random()
                if kart.isPlayer { lightHaptic.impactOccurred() }
            }
        case let banana as BananaNode:
            let armed = raceClock >= banana.armedAt || banana.owner !== kart
            if armed, !kart.isSpinning, !kart.isInvulnerable {
                banana.squish()
                kart.spinOut()
                if kart.isPlayer { heavyHaptic.impactOccurred() }
            }
        case let can as CanNode:
            let armed = raceClock >= can.armedAt || can.owner !== kart
            if armed, !kart.isSpinning, !kart.isInvulnerable {
                can.explode()
                kart.spinOut()
                if kart.isPlayer { heavyHaptic.impactOccurred() }
            }
        case is PuddleNode:
            kart.slip(duration: 1.1)
        default:
            break
        }
    }

    // MARK: - Touch controls

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: hud)

            if resultsShown {
                let tappedNames = hud.nodes(at: location).compactMap { $0.name }
                if tappedNames.contains("btn-rematch") {
                    presentRematch()
                    return
                }
                if tappedNames.contains("btn-garage") {
                    presentMenu()
                    return
                }
                continue
            }

            if location.distance(to: hud.itemButtonCenter) < hud.itemButtonRadius {
                if playerAutopilot == nil { useItem(for: player) }
                continue
            }
            steeringTouches[touch] = location.x < 0 ? 1 : -1
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where steeringTouches[touch] != nil {
            let location = touch.location(in: hud)
            steeringTouches[touch] = location.x < 0 ? 1 : -1
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { steeringTouches.removeValue(forKey: touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { steeringTouches.removeValue(forKey: touch) }
    }

    // MARK: - Navigation

    private func presentRematch() {
        guard let view = view else { return }
        let scene = RaceScene(size: view.bounds.size, playerCharacterIndex: playerCharacterIndex)
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }

    private func presentMenu() {
        guard let view = view else { return }
        let scene = MenuScene(size: view.bounds.size)
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }
}
