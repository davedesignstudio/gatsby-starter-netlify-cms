import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private let playerProfile: RacerProfile
    private var track: TrackData!
    private var world: SKNode!
    private var carts: [CartNode] = []
    private var player: CartNode!
    private var aiControllers: [AIController] = []
    private var itemPads: [ItemPadNode] = []
    private var projectiles: [ProjectileNode] = []
    private var hud: RaceHUD!

    private var lastUpdate: TimeInterval = 0
    private var raceTime: TimeInterval = 0
    private var countdown: TimeInterval = 3.2
    private var racing = false
    private var raceOver = false
    private var cameraNode = SKCameraNode()

    private var steerLeft = false
    private var steerRight = false
    private var braking = false
    private var activeTouches: [UITouch: String] = [:]

    init(size: CGSize, playerProfile: RacerProfile) {
        self.playerProfile = playerProfile
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        track = TrackBuilder.megaMart()
        world = TrackBuilder.buildWorld(in: self, track: track)

        addChild(cameraNode)
        camera = cameraNode

        spawnRacers()
        spawnItemPads()
        setupHUD()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAIItem(_:)),
            name: .aiWantsItemUse,
            object: nil
        )

        cameraNode.position = player.position
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        hud?.layout(size: size)
    }

    private func spawnRacers() {
        var profiles = RacerProfile.roster.filter { $0.id != playerProfile.id }.shuffled()
        let opponents = Array(profiles.prefix(RaceConfig.racerCount - 1))
        let allProfiles = [playerProfile] + opponents

        for (i, profile) in allProfiles.enumerated() {
            let isPlayer = i == 0
            let cart = CartNode(profile: profile, isPlayer: isPlayer)
            let start = track.startPositions[min(i, track.startPositions.count - 1)]
            cart.position = start
            // Face toward first stretch (roughly east/northeast along bottom)
            cart.zRotation = -.pi / 2 + 0.15
            world.addChild(cart)
            carts.append(cart)
            if isPlayer {
                player = cart
                cart.throttleInput = 1
            } else {
                let skill = CGFloat.random(in: 0.72...0.95)
                aiControllers.append(AIController(cart: cart, checkpoints: track.checkpoints, skill: skill))
            }
        }
    }

    private func spawnItemPads() {
        for point in track.itemPads {
            let pad = ItemPadNode()
            pad.position = point
            world.addChild(pad)
            itemPads.append(pad)
        }
    }

    private func setupHUD() {
        hud = RaceHUD(sceneSize: size, trackSize: track.size, racerCount: carts.count)
        cameraNode.addChild(hud.node)
        // HUD is in camera space; offset so (0,0) is bottom-left of screen
        hud.node.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdate == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(currentTime - lastUpdate, 1.0 / 20.0)
        }
        lastUpdate = currentTime

        if !racing && !raceOver {
            countdown -= dt
            if countdown > 2 { hud.setCountdown("3") }
            else if countdown > 1 { hud.setCountdown("2") }
            else if countdown > 0 { hud.setCountdown("1") }
            else {
                hud.setCountdown("GO!")
                racing = true
                run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.45),
                    SKAction.run { [weak self] in self?.hud.setCountdown(nil) }
                ]))
            }
            updateCamera(dt: dt)
            return
        }

        guard !raceOver else {
            updateCamera(dt: dt)
            return
        }

        raceTime += dt
        applyPlayerInput()

        for ai in aiControllers {
            ai.update(deltaTime: dt, rivals: carts)
            if racing { ai.cart.throttleInput = max(ai.cart.throttleInput, 0.3) }
        }

        if racing {
            player.throttleInput = braking ? 0.15 : 1.0
            player.brakeInput = braking ? 1.0 : 0
        } else {
            for cart in carts {
                cart.throttleInput = 0
                cart.brakeInput = 0
                cart.steerInput = 0
                cart.velocity = .zero
                cart.physicsBody?.velocity = .zero
            }
        }

        for cart in carts {
            let onTrack = isOnFloor(cart.position)
            cart.update(deltaTime: dt, onTrack: onTrack)
        }

        for pad in itemPads {
            pad.update(deltaTime: dt)
        }

        projectiles = projectiles.filter { proj in
            let alive = proj.update(deltaTime: dt)
            if !alive { proj.removeFromParent() }
            return alive
        }

        updateRaceProgress()
        hud.update(player: player, carts: carts, raceTime: raceTime)
        updateCamera(dt: dt)

        if player.isFinished && !raceOver {
            finishRaceSoon()
        }
    }

    private func applyPlayerInput() {
        var steer: CGFloat = 0
        if steerLeft { steer -= 1 }
        if steerRight { steer += 1 }
        player.steerInput = steer
    }

    private func isOnFloor(_ point: CGPoint) -> Bool {
        let margin: CGFloat = 70
        if point.x < margin || point.y < margin ||
            point.x > track.size.width - margin ||
            point.y > track.size.height - margin {
            return false
        }
        for shelf in track.shelves {
            if shelf.insetBy(dx: -8, dy: -8).contains(point) { return false }
        }
        return true
    }

    private func updateRaceProgress() {
        for cart in carts {
            let cpIndex = cart.nextCheckpoint % track.checkpoints.count
            let cp = track.checkpoints[cpIndex]
            // Soft progress for ranking
            let prevIndex = (cpIndex - 1 + track.checkpoints.count) % track.checkpoints.count
            let prev = track.checkpoints[prevIndex]
            let segLen = max(hypot(cp.x - prev.x, cp.y - prev.y), 1)
            let along = hypot(cart.position.x - prev.x, cart.position.y - prev.y)
            let lapProgress = (CGFloat(cart.currentLap) * CGFloat(track.checkpoints.count)
                + CGFloat(cpIndex) + min(along / segLen, 0.99))
            cart.progress = lapProgress
        }

        let ranked = carts.sorted { $0.progress > $1.progress }
        for (i, cart) in ranked.enumerated() {
            cart.place = i + 1
        }
    }

    private func updateCamera(dt: TimeInterval) {
        let target = player.position
        let lead = CGPoint(
            x: -sin(player.zRotation) * 60,
            y: cos(player.zRotation) * 60
        )
        let desired = CGPoint(x: target.x + lead.x, y: target.y + lead.y)
        let lerp = CGFloat(min(dt * 5.5, 1))
        cameraNode.position.x += (desired.x - cameraNode.position.x) * lerp
        cameraNode.position.y += (desired.y - cameraNode.position.y) * lerp

        // Keep HUD anchored bottom-left relative to camera
        hud.node.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        handleContact(a: a, b: b)
        handleContact(a: b, b: a)
    }

    private func handleContact(a: SKPhysicsBody, b: SKPhysicsBody) {
        guard let nodeA = a.node else { return }

        if let cart = nodeA as? CartNode ?? nodeA.parent as? CartNode {
            if b.categoryBitMask == PhysicsCategory.checkpoint,
               let name = b.node?.name,
               name.hasPrefix("checkpoint-"),
               let idx = Int(name.replacingOccurrences(of: "checkpoint-", with: "")) {
                handleCheckpoint(cart: cart, index: idx)
            }

            if b.categoryBitMask == PhysicsCategory.item,
               let pad = b.node as? ItemPadNode ?? b.node?.parent as? ItemPadNode {
                if cart.heldItem == nil && pad.isActive {
                    pad.collect()
                    cart.heldItem = PowerUpType.allCases.randomElement()
                    if cart.isPlayer {
                        flashMessage(cart.heldItem?.name ?? "Item")
                    }
                }
            }

            if b.categoryBitMask == PhysicsCategory.hazard {
                if let hazard = b.node as? HazardNode {
                    if hazard.shouldAffect(cart) {
                        cart.hitByItem()
                        hazard.removeFromParent()
                    }
                } else if let proj = b.node as? ProjectileNode {
                    if proj.owner !== cart {
                        cart.hitByItem()
                        proj.removeFromParent()
                        projectiles.removeAll { $0 === proj }
                    }
                }
            }
        }
    }

    private func handleCheckpoint(cart: CartNode, index: Int) {
        guard !cart.isFinished else { return }
        if index == cart.nextCheckpoint {
            cart.nextCheckpoint += 1
            if cart.nextCheckpoint >= track.checkpoints.count {
                cart.nextCheckpoint = 0
                cart.currentLap += 1
                if cart.currentLap >= RaceConfig.lapCount {
                    cart.isFinished = true
                    cart.finishTime = raceTime
                    cart.throttleInput = 0
                    if cart.isPlayer {
                        flashMessage(ordinal(cart.place) + " PLACE!")
                    }
                } else if cart.isPlayer {
                    flashMessage("LAP \(cart.currentLap + 1)")
                }
            }
        }
    }

    // MARK: - Items

    @objc private func handleAIItem(_ note: Notification) {
        guard let cart = note.object as? CartNode else { return }
        useItem(for: cart)
    }

    private func useItem(for cart: CartNode) {
        guard let item = cart.heldItem, !cart.isSpinning, !cart.isFinished else { return }
        cart.heldItem = nil

        switch item {
        case .banana:
            let behind = CGPoint(
                x: cart.position.x + sin(cart.zRotation) * 40,
                y: cart.position.y - cos(cart.zRotation) * 40
            )
            let hazard = HazardNode(kind: .banana, at: behind, owner: cart)
            world.addChild(hazard)
            hazard.run(SKAction.sequence([
                SKAction.wait(forDuration: 12),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))

        case .sodaSplash:
            let forward = CGVector(dx: -sin(cart.zRotation) * 420, dy: cos(cart.zRotation) * 420)
            let proj = ProjectileNode(kind: .sodaSplash, owner: cart, velocity: forward)
            proj.position = CGPoint(
                x: cart.position.x - sin(cart.zRotation) * 36,
                y: cart.position.y + cos(cart.zRotation) * 36
            )
            world.addChild(proj)
            projectiles.append(proj)

        case .beanTurbo:
            cart.applyBoost(multiplier: 1.55, duration: 1.4)

        case .shoppingBag:
            cart.hasShield = true
            cart.run(SKAction.sequence([
                SKAction.wait(forDuration: 5),
                SKAction.run { [weak cart] in cart?.hasShield = false }
            ]))

        case .shoppingList:
            let target = carts
                .filter { $0 !== cart && !$0.isFinished }
                .sorted { $0.progress > $1.progress }
                .first
            let forward = CGVector(dx: -sin(cart.zRotation) * 300, dy: cos(cart.zRotation) * 300)
            let proj = ProjectileNode(kind: .shoppingList, owner: cart, velocity: forward)
            proj.homingTarget = target
            proj.position = CGPoint(
                x: cart.position.x - sin(cart.zRotation) * 36,
                y: cart.position.y + cos(cart.zRotation) * 36
            )
            world.addChild(proj)
            projectiles.append(proj)
        }
    }

    private func flashMessage(_ text: String) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 28
        label.fontColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: size.height * 0.18)
        label.zPosition = 600
        cameraNode.addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.8),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.5),
                    SKAction.fadeOut(withDuration: 0.3)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func finishRaceSoon() {
        raceOver = true
        // Wait for others briefly or timeout
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.run { [weak self] in self?.showResults() }
        ]))
        // Auto-finish remaining AI after short wait
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                guard let self else { return }
                for cart in self.carts where !cart.isFinished {
                    cart.isFinished = true
                    cart.finishTime = self.raceTime + Double(cart.place) * 0.3
                }
            }
        ]))
    }

    private func showResults() {
        let results = carts
            .sorted { ($0.finishTime ?? 9999) < ($1.finishTime ?? 9999) }
            .enumerated()
            .map { idx, cart in
                RaceResult(
                    place: idx + 1,
                    profile: cart.profile,
                    isPlayer: cart.isPlayer,
                    finishTime: cart.finishTime ?? raceTime
                )
            }
        let scene = ResultsScene(size: size, results: results)
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: .fade(with: .black, duration: 0.5))
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let camLoc = touch.location(in: cameraNode)
            let hudLoc = CGPoint(x: camLoc.x + size.width / 2, y: camLoc.y + size.height / 2)
            let action = control(at: hudLoc) ?? sideSteer(at: hudLoc)
            activeTouches[touch] = action
            applyTouchAction(action, active: true)

            if action == "useItem" {
                useItem(for: player)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let camLoc = touch.location(in: cameraNode)
            let hudLoc = CGPoint(x: camLoc.x + size.width / 2, y: camLoc.y + size.height / 2)
            let old = activeTouches[touch]
            let newAction = control(at: hudLoc) ?? sideSteer(at: hudLoc)
            if old != newAction {
                if let old { applyTouchAction(old, active: false) }
                activeTouches[touch] = newAction
                applyTouchAction(newAction, active: true)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let action = activeTouches.removeValue(forKey: touch) {
                applyTouchAction(action, active: false)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func control(at point: CGPoint) -> String? {
        let left = CGPoint(x: 70, y: 90)
        let right = CGPoint(x: 170, y: 90)
        let brake = CGPoint(x: size.width - 70, y: 200)
        let item = CGPoint(x: size.width - 70, y: 265)

        if hypot(point.x - left.x, point.y - left.y) < 50 { return "steerLeft" }
        if hypot(point.x - right.x, point.y - right.y) < 50 { return "steerRight" }
        if abs(point.x - brake.x) < 50 && abs(point.y - brake.y) < 35 { return "brake" }
        if abs(point.x - item.x) < 50 && abs(point.y - item.y) < 35 { return "useItem" }
        return nil
    }

    private func sideSteer(at point: CGPoint) -> String {
        // Fallback: left/right half of lower screen
        if point.y < size.height * 0.45 {
            return point.x < size.width * 0.35 ? "steerLeft" : (point.x > size.width * 0.55 ? "steerRight" : "none")
        }
        return "none"
    }

    private func applyTouchAction(_ action: String, active: Bool) {
        switch action {
        case "steerLeft": steerLeft = active
        case "steerRight": steerRight = active
        case "brake": braking = active
        default: break
        }
    }
}
