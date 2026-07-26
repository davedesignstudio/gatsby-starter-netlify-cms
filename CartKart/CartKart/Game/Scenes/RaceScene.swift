import SpriteKit
import UIKit

final class RaceScene: SKScene, SKPhysicsContactDelegate {
    private let totalLaps = 3
    private let trackSize = CGSize(width: 1200, height: 1200)

    private var worldNode: SKNode!
    private var track: StoreTrack!
    private var carts: [ShoppingCart] = []
    private var player: ShoppingCart!
    private var aiControllers: [AIController] = []
    private var itemBoxes: [ItemBox] = []
    private var hazards: [HazardNode] = []
    private var projectiles: [ProjectileNode] = []

    private let hud = RaceHUD()
    private var cameraNode = SKCameraNode()

    private var raceState: RaceState = .countdown
    private var countdownValue = 3
    private var countdownTimer: TimeInterval = 1
    private var finishOrder: [ShoppingCart] = []

    private var steerInput: CGFloat = 0
    private var boosting = false
    private var activeTouches: [UITouch: String] = [:]

    private var minimap: SKShapeNode?
    private var minimapDots: [SKShapeNode] = []

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        physicsWorld.speed = 1

        addChild(cameraNode)
        camera = cameraNode

        track = StoreTrack(size: trackSize)
        worldNode = track.build(into: self)

        spawnRacers()
        spawnItemBoxes()
        setupMinimap()

        hud.attach(to: cameraNode)
        hud.layout(size: size)
        hud.showMessage("AISLE CIRCUIT", duration: 1.5)

        cameraNode.position = player.position
    }

    override func didChangeSize(_ oldSize: CGSize) {
        hud.layout(size: size)
        minimap?.position = CGPoint(x: size.width / 2 - 70, y: -size.height / 2 + 160)
    }

    private func spawnRacers() {
        let profiles = RacerProfile.roster
        for (i, profile) in profiles.enumerated() {
            let cart = ShoppingCart(profile: profile)
            let start = track.startPositions[min(i, track.startPositions.count - 1)]
            cart.position = start
            cart.heading = track.startHeading
            cart.updateVisuals()
            worldNode.addChild(cart)
            carts.append(cart)
            if profile.isPlayer {
                player = cart
            } else {
                aiControllers.append(AIController(cart: cart, checkpoints: track.checkpoints))
            }
        }
    }

    private func spawnItemBoxes() {
        for p in track.itemBoxSpawns {
            let box = ItemBox()
            box.position = p
            worldNode.addChild(box)
            itemBoxes.append(box)
        }
    }

    private func setupMinimap() {
        let map = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 8)
        map.fillColor = UIColor(white: 0, alpha: 0.45)
        map.strokeColor = UIColor(white: 1, alpha: 0.3)
        map.lineWidth = 1
        map.zPosition = 480
        map.position = CGPoint(x: size.width / 2 - 70, y: -size.height / 2 + 160)
        cameraNode.addChild(map)
        minimap = map

        for cart in carts {
            let dot = SKShapeNode(circleOfRadius: cart.profile.isPlayer ? 4 : 3)
            dot.fillColor = cart.profile.isPlayer ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : cart.profile.accentColor
            dot.strokeColor = .clear
            map.addChild(dot)
            minimapDots.append(dot)
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (lastUpdateTime ?? currentTime), 1.0 / 120.0), 1.0 / 20.0)
        lastUpdateTime = currentTime

        switch raceState {
        case .countdown:
            updateCountdown(delta: dt)
        case .racing:
            updateRacing(delta: dt)
        case .finished:
            updateFinished(delta: dt)
        }

        updateCamera(delta: dt)
        updateMinimap()
        updateHUD()
        cleanupExpired(delta: dt)
    }

    private var lastUpdateTime: TimeInterval?

    private func updateCountdown(delta: TimeInterval) {
        countdownTimer -= delta
        if countdownTimer <= 0 {
            countdownValue -= 1
            countdownTimer = 1
            if countdownValue < 0 {
                raceState = .racing
                hud.showMessage("RACE!", duration: 0.8)
            }
        }
        // Hold carts still
        for cart in carts {
            cart.velocity = .zero
            cart.updateVisuals()
        }
    }

    private func updateRacing(delta: TimeInterval) {
        for cart in carts {
            cart.syncVelocityFromPhysics()
        }

        player.applySteer(steerInput, delta: delta)
        player.applyThrottle(boosting: boosting, delta: delta)
        player.integrate(delta: delta)

        for ai in aiControllers {
            ai.update(delta: delta, race: self)
        }

        for box in itemBoxes {
            box.update(delta: delta)
        }

        checkLapProgress()
    }

    private func updateFinished(delta: TimeInterval) {
        for cart in carts {
            cart.syncVelocityFromPhysics()
            if cart.finished {
                cart.velocity.dx *= 0.9
                cart.velocity.dy *= 0.9
            } else {
                cart.applySteer(0, delta: delta)
                cart.applyThrottle(boosting: false, delta: delta)
                cart.velocity.dx *= 0.95
                cart.velocity.dy *= 0.95
            }
            cart.integrate(delta: delta)
        }
    }

    private func updateCamera(delta: TimeInterval) {
        let lead = CGPoint(
            x: player.position.x + cos(player.heading) * 40,
            y: player.position.y + sin(player.heading) * 40
        )
        let lerp = 1 - pow(0.001, delta)
        cameraNode.position.x += (lead.x - cameraNode.position.x) * CGFloat(lerp)
        cameraNode.position.y += (lead.y - cameraNode.position.y) * CGFloat(lerp)

        // Slight zoom based on speed
        let targetScale = 1.0 + min(player.speed / 900, 0.25)
        let current = cameraNode.xScale
        let s = current + (targetScale - current) * CGFloat(lerp)
        cameraNode.setScale(s)
    }

    private func updateMinimap() {
        guard let map = minimap else { return }
        let scale = 90 / trackSize.width
        for (i, cart) in carts.enumerated() where i < minimapDots.count {
            minimapDots[i].position = CGPoint(x: cart.position.x * scale, y: cart.position.y * scale)
        }
        map.zRotation = 0
    }

    private func updateHUD() {
        let place = placeOf(player)
        let countdown: Int? = raceState == .countdown ? max(countdownValue, 0) : nil
        hud.update(
            player: player,
            place: place,
            totalLaps: totalLaps,
            raceState: raceState,
            countdown: countdown
        )
    }

    private func cleanupExpired(delta: TimeInterval) {
        hazards = hazards.filter { hazard in
            let dead = hazard.update(delta: delta)
            if dead { hazard.removeFromParent() }
            return !dead
        }
        projectiles = projectiles.filter { proj in
            let dead = proj.update(delta: delta)
            if dead { proj.removeFromParent() }
            return !dead
        }
    }

    // MARK: - Race logic

    private func checkLapProgress() {
        for cart in carts where !cart.finished {
            let next = (cart.checkpointIndex + 1) % track.checkpoints.count
            let cp = track.checkpoints[next]
            let dist = hypot(cart.position.x - cp.position.x, cart.position.y - cp.position.y)
            if dist < 85 {
                let previous = cart.checkpointIndex
                cart.checkpointIndex = next
                if next == 0 && previous == track.checkpoints.count - 1 {
                    cart.currentLap += 1
                    if cart.profile.isPlayer {
                        hud.showMessage("LAP \(min(cart.currentLap + 1, totalLaps))", duration: 1.0)
                    }
                    if cart.currentLap >= totalLaps {
                        finish(cart)
                    }
                }
            }
        }
    }

    private func finish(_ cart: ShoppingCart) {
        guard !cart.finished else { return }
        cart.finished = true
        cart.finishPlace = finishOrder.count + 1
        finishOrder.append(cart)
        if cart.profile.isPlayer {
            raceState = .finished
            let place = cart.finishPlace ?? placeOf(cart)
            hud.showMessage(finishTitle(place), duration: 4)
            hud.setControlsVisible(false)
            scheduleReturnToMenu()
        } else if finishOrder.count == carts.count {
            raceState = .finished
            scheduleReturnToMenu()
        }
    }

    private func finishTitle(_ place: Int) -> String {
        switch place {
        case 1: return "YOU WIN!"
        case 2: return "2ND PLACE"
        case 3: return "3RD PLACE"
        default: return "FINISHED"
        }
    }

    private func scheduleReturnToMenu() {
        run(SKAction.sequence([
            SKAction.wait(forDuration: 4.5),
            SKAction.run { [weak self] in
                guard let self else { return }
                let menu = MenuScene(size: self.size)
                menu.scaleMode = .resizeFill
                self.view?.presentScene(menu, transition: .fade(withDuration: 0.6))
            }
        ]))
    }

    private func placeOf(_ cart: ShoppingCart) -> Int {
        if let fp = cart.finishPlace { return fp }
        let ranked = carts.sorted { a, b in
            if a.finished != b.finished { return a.finished && !b.finished }
            if a.currentLap != b.currentLap { return a.currentLap > b.currentLap }
            if a.checkpointIndex != b.checkpointIndex { return a.checkpointIndex > b.checkpointIndex }
            let na = track.checkpoints[(a.checkpointIndex + 1) % track.checkpoints.count].position
            let nb = track.checkpoints[(b.checkpointIndex + 1) % track.checkpoints.count].position
            let da = hypot(a.position.x - na.x, a.position.y - na.y)
            let db = hypot(b.position.x - nb.x, b.position.y - nb.y)
            return da < db
        }
        return (ranked.firstIndex(where: { $0 === cart }) ?? 0) + 1
    }

    // MARK: - Item spawning (called by carts)

    func spawnHazard(_ kind: PowerUpKind, behind cart: ShoppingCart) {
        let hazard = HazardNode(kind: kind)
        let back = CGPoint(
            x: cart.position.x - cos(cart.heading) * 50,
            y: cart.position.y - sin(cart.heading) * 50
        )
        hazard.position = back
        worldNode.addChild(hazard)
        hazards.append(hazard)
    }

    func spawnProjectile(from cart: ShoppingCart) {
        let proj = ProjectileNode(ownerId: cart.profile.id, heading: cart.heading)
        proj.position = CGPoint(
            x: cart.position.x + cos(cart.heading) * 40,
            y: cart.position.y + sin(cart.heading) * 40
        )
        worldNode.addChild(proj)
        projectiles.append(proj)
    }

    func spawnBoostFX(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.fillColor = .clear
        ring.strokeColor = UIColor(red: 0.3, green: 0.85, blue: 1, alpha: 1)
        ring.lineWidth = 3
        ring.position = point
        ring.zPosition = 60
        worldNode.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 4, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        let mask = a.categoryBitMask | b.categoryBitMask

        if mask & PhysicsCategory.itemBox != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? ShoppingCart
            let box = (a.categoryBitMask == PhysicsCategory.itemBox ? a.node : b.node) as? ItemBox
            if let cartNode, let box, cartNode.heldItem == nil, let item = box.collect() {
                cartNode.heldItem = item
                if cartNode.profile.isPlayer {
                    hud.showMessage(item.displayName, duration: 0.8)
                }
            }
        }

        if mask & PhysicsCategory.hazard != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? ShoppingCart
            let hazard = (a.categoryBitMask == PhysicsCategory.hazard ? a.node : b.node) as? HazardNode
            if let cartNode, let hazard {
                cartNode.hitByHazard(kind: hazard.kind)
                hazard.removeFromParent()
                hazards.removeAll { $0 === hazard }
            }
        }

        if mask & PhysicsCategory.projectile != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? ShoppingCart
            let proj = (a.categoryBitMask == PhysicsCategory.projectile ? a.node : b.node) as? ProjectileNode
            if let cartNode, let proj, proj.ownerId != cartNode.profile.id {
                cartNode.hitByHazard(kind: .cannedGoods)
                proj.removeFromParent()
                projectiles.removeAll { $0 === proj }
            }
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: cameraNode)
            if hud.containsItem(p) {
                activeTouches[touch] = "item"
                if raceState == .racing {
                    player.useHeldItem(world: self)
                }
            } else if hud.containsBoost(p) {
                activeTouches[touch] = "boost"
                boosting = true
            } else if hud.containsLeft(p) {
                activeTouches[touch] = "left"
                refreshSteer()
            } else if hud.containsRight(p) {
                activeTouches[touch] = "right"
                refreshSteer()
            } else {
                // Tilt steer by side of screen
                activeTouches[touch] = p.x < 0 ? "left" : "right"
                refreshSteer()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: cameraNode)
            if activeTouches[touch] == "boost" || activeTouches[touch] == "item" { continue }
            activeTouches[touch] = p.x < 0 ? "left" : "right"
        }
        refreshSteer()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }
        boosting = activeTouches.values.contains("boost")
        refreshSteer()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func refreshSteer() {
        let left = activeTouches.values.contains("left")
        let right = activeTouches.values.contains("right")
        if left && !right { steerInput = 1 }
        else if right && !left { steerInput = -1 }
        else { steerInput = 0 }
    }
}
