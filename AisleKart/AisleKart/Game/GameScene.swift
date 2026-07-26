import SpriteKit
import CoreMotion

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private var track: TrackData!
    private var carts: [CartNode] = []
    private var player: CartNode!
    private var aiControllers: [AIController] = []
    private var itemBoxes: [ItemBoxNode] = []
    private var turkeys: [TurkeyProjectile] = []
    private let hud = HUDNode()
    private let cameraNode = SKCameraNode()

    private var lastUpdate: TimeInterval?
    private var countdown: Int = 3
    private var raceStarted = false
    private var raceOver = false
    private var finishCount = 0
    private let totalLaps = 3
    private var boostCharge: CGFloat = 0.4
    private var touchSteer: CGFloat = 0
    private var touching = false
    private var motion = CMMotionManager()
    private var useTilt = false

    private var leftTouch = false
    private var rightTouch = false

    override func didMove(to view: SKView) {
        backgroundColor = GameTheme.aisleFloor
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        track = TrackBuilder.buildMegaMart()
        addChild(track.trackNode)

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: track.worldSize.width / 2, y: track.worldSize.height / 2)

        spawnCarts()
        spawnItemBoxes()

        hud.setup(size: size)
        cameraNode.addChild(hud)
        // HUD is in camera space — position relative to camera center
        positionHUD()

        NotificationCenter.default.addObserver(self, selector: #selector(handleAIItem(_:)), name: .aiWantsItemUse, object: nil)

        startCountdown()

        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1 / 30
            motion.startAccelerometerUpdates()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        motion.stopAccelerometerUpdates()
    }

    private func positionHUD() {
        // HUD children use scene-size coordinates; offset so (0,0) is bottom-left of view
        hud.position = CGPoint(x: -size.width / 2, y: -size.height / 2)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        hud.setup(size: size)
        positionHUD()
    }

    private func spawnCarts() {
        for i in 0..<4 {
            let cart = CartNode(index: i, isPlayer: i == 0)
            cart.position = track.startPositions[i]
            cart.zRotation = track.startRotation
            cart.speed = 0
            cart.throttle = false
            addChild(cart)
            carts.append(cart)
            if i == 0 {
                player = cart
            } else {
                aiControllers.append(AIController(cart: cart, path: track.pathPoints))
            }
        }
    }

    private func spawnItemBoxes() {
        for p in track.itemBoxSpawns {
            let box = ItemBoxNode()
            box.position = p
            track.trackNode.addChild(box)
            itemBoxes.append(box)
        }
    }

    private func startCountdown() {
        hud.showMessage("READY?", duration: 0.8)
        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in self?.hud.showMessage("3") },
            .wait(forDuration: 0.7),
            .run { [weak self] in self?.hud.showMessage("2") },
            .wait(forDuration: 0.7),
            .run { [weak self] in self?.hud.showMessage("1") },
            .wait(forDuration: 0.7),
            .run { [weak self] in
                self?.hud.showMessage("GO!", duration: 0.6)
                self?.raceStarted = true
                self?.carts.forEach { $0.throttle = true }
                self?.hud.hideHints()
            }
        ]))
    }

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if let last = lastUpdate {
            delta = min(1 / 20, currentTime - last)
        } else {
            delta = 1 / 60
        }
        lastUpdate = currentTime

        guard !raceOver else { return }

        updateSteering()

        if raceStarted {
            for cart in carts where !cart.finished {
                cart.update(delta: delta)
                updateProgress(for: cart)
            }
            for ai in aiControllers {
                ai.update(delta: delta, rivals: carts, player: player)
            }
            // Passive boost charge
            boostCharge = min(1, boostCharge + CGFloat(delta) * 0.08)
            if player.boostTimer > 0 {
                // spending
            }
        } else {
            carts.forEach { $0.physicsBody?.velocity = .zero }
        }

        itemBoxes.forEach { $0.update(delta: delta) }
        turkeys.forEach { $0.update(delta: delta) }
        turkeys.removeAll { $0.parent == nil }

        updatePlaces()
        let place = placeOf(player)
        hud.update(player: player, place: place, totalLaps: totalLaps, boostCharge: boostCharge)

        // Camera follow with slight look-ahead
        let look: CGFloat = 80
        let target = CGPoint(
            x: player.position.x + sin(player.zRotation) * look,
            y: player.position.y + cos(player.zRotation) * look
        )
        cameraNode.position.x += (target.x - cameraNode.position.x) * 0.12
        cameraNode.position.y += (target.y - cameraNode.position.y) * 0.12
    }

    private func updateSteering() {
        guard raceStarted, !player.finished else { return }

        var steer: CGFloat = 0
        if leftTouch { steer -= 1 }
        if rightTouch { steer += 1 }

        if useTilt || (!leftTouch && !rightTouch), let data = motion.accelerometerData {
            // Landscape-friendly: use Y when device is landscape, else X
            let tilt = CGFloat(data.acceleration.x)
            if abs(tilt) > 0.08 {
                steer = max(-1, min(1, tilt * 2.2))
                useTilt = true
            }
        }

        player.steerInput = steer

        // Center hold coasts slightly / edge steering keeps throttle
        if touching && !leftTouch && !rightTouch {
            // Double-tap zone center for boost when charged
        }
        player.throttle = true
    }

    private func updateProgress(for cart: CartNode) {
        let cps = track.checkpoints
        let cp = cps[cart.nextCheckpoint % cps.count]
        let dist = hypot(cart.position.x - cp.position.x, cart.position.y - cp.position.y)
        if dist < cp.radius {
            let prev = cart.nextCheckpoint
            cart.nextCheckpoint = (cart.nextCheckpoint + 1) % cps.count
            if prev == cps.count - 1 {
                cart.lap += 1
                if cart === player {
                    hud.showMessage("LAP \(min(cart.lap, totalLaps))", duration: 0.8)
                }
                if cart.lap >= totalLaps {
                    finish(cart: cart)
                }
            }
        }
        let base = CGFloat(cart.lap * cps.count + cart.nextCheckpoint)
        let next = cps[cart.nextCheckpoint % cps.count]
        let d = hypot(cart.position.x - next.position.x, cart.position.y - next.position.y)
        cart.raceProgress = base + max(0, 1 - d / 400)
    }

    private func finish(cart: CartNode) {
        guard !cart.finished else { return }
        cart.finished = true
        finishCount += 1
        cart.finishPlace = finishCount
        cart.throttle = false
        cart.speed = 0

        if cart === player {
            raceOver = true
            let place = cart.finishPlace ?? finishCount
            showResults(place: place)
        } else if finishCount >= carts.count {
            raceOver = true
        }
    }

    private func updatePlaces() {
        // Sort by progress for HUD; finishing handled separately
    }

    private func placeOf(_ cart: CartNode) -> Int {
        if let p = cart.finishPlace { return p }
        let ordered = carts.sorted { a, b in
            if a.finished != b.finished { return a.finished && !b.finished }
            if let ap = a.finishPlace, let bp = b.finishPlace { return ap < bp }
            return a.raceProgress > b.raceProgress
        }
        return (ordered.firstIndex(where: { $0 === cart }) ?? 0) + 1
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touching = true
        for t in touches {
            handleTouch(t, ended: false)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        leftTouch = false
        rightTouch = false
        for t in touches {
            handleTouch(t, ended: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        leftTouch = false
        rightTouch = false
        touching = false
    }

    private func handleTouch(_ touch: UITouch, ended: Bool) {
        let p = touch.location(in: cameraNode)
        let x = p.x + size.width / 2
        let y = p.y + size.height / 2

        // Item button
        if hypot(x - (size.width - 52), y - (size.height - 62)) < 50 {
            if !ended { useItem(for: player) }
            return
        }

        // Boost meter
        if abs(x - size.width / 2) < 70 && y < 80 {
            if !ended { tryBoost() }
            return
        }

        if x < size.width * 0.4 {
            leftTouch = true
        } else if x > size.width * 0.6 {
            rightTouch = true
        }
    }

    private func tryBoost() {
        guard raceStarted, boostCharge >= 1, player.boostTimer <= 0 else { return }
        boostCharge = 0
        player.activateBoost(duration: 1.2)
        hud.showMessage("EXPRESS!", duration: 0.5)
    }

    // MARK: - Items

    @objc private func handleAIItem(_ note: Notification) {
        guard let cart = note.userInfo?["cart"] as? CartNode else { return }
        useItem(for: cart)
    }

    private func useItem(for cart: CartNode) {
        guard let item = cart.heldItem, raceStarted, !cart.finished else { return }
        cart.heldItem = nil

        switch item {
        case .banana:
            let peel = BananaHazard(ownerIndex: cart.cartIndex)
            let behind = CGPoint(
                x: cart.position.x - sin(cart.zRotation) * 50,
                y: cart.position.y - cos(cart.zRotation) * 50
            )
            peel.position = behind
            addChild(peel)

        case .soda:
            if let target = cartAhead(of: cart) {
                target.applySodaSlow()
                spawnSpray(from: cart, to: target)
                if cart === player { hud.showMessage("SODA SPRAY!", duration: 0.5) }
            }

        case .shield:
            cart.grantShield()
            if cart === player { hud.showMessage("SHIELDED", duration: 0.5) }

        case .boost:
            cart.activateBoost()
            if cart === player { hud.showMessage("BOOST!", duration: 0.45) }

        case .turkey:
            let target = cartAhead(of: cart)
            let turkey = TurkeyProjectile(ownerIndex: cart.cartIndex, target: target)
            turkey.position = CGPoint(
                x: cart.position.x + sin(cart.zRotation) * 40,
                y: cart.position.y + cos(cart.zRotation) * 40
            )
            addChild(turkey)
            turkeys.append(turkey)
            if cart === player { hud.showMessage("TURKEY AWAY!", duration: 0.5) }
        }
    }

    private func cartAhead(of cart: CartNode) -> CartNode? {
        carts
            .filter { $0 !== cart && !$0.finished }
            .filter { $0.raceProgress >= cart.raceProgress - 0.2 }
            .sorted { $0.raceProgress < $1.raceProgress }
            .first
    }

    private func spawnSpray(from: CartNode, to: CartNode) {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from.position)
        path.addLine(to: to.position)
        line.path = path
        line.strokeColor = UIColor(red: 1, green: 0.4, blue: 0.2, alpha: 0.7)
        line.lineWidth = 4
        line.zPosition = 60
        addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        let mask = a.categoryBitMask | b.categoryBitMask

        func node(_ body: SKPhysicsBody) -> SKNode? { body.node }

        if mask & PhysicsCategory.itemBox != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? CartNode
            let box = (a.categoryBitMask == PhysicsCategory.itemBox ? a.node : b.node) as? ItemBoxNode
            if let cartNode, let box, box.isAvailable, cartNode.heldItem == nil {
                box.collect()
                cartNode.heldItem = PowerUpType.random()
                if cartNode === player {
                    hud.showMessage(cartNode.heldItem?.label.uppercased() ?? "ITEM", duration: 0.6)
                }
            }
        }

        if mask & PhysicsCategory.hazard != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? CartNode
            let hazard = a.categoryBitMask == PhysicsCategory.hazard ? a.node : b.node
            if let cartNode, let banana = hazard as? BananaHazard, banana.ownerIndex != cartNode.cartIndex {
                cartNode.applyBananaHit()
                banana.removeFromParent()
                if cartNode === player { hud.showMessage("SLIPPED!", duration: 0.5) }
            }
        }

        if mask & PhysicsCategory.projectile != 0 && mask & PhysicsCategory.cart != 0 {
            let cartNode = (a.categoryBitMask == PhysicsCategory.cart ? a.node : b.node) as? CartNode
            let proj = (a.categoryBitMask == PhysicsCategory.projectile ? a.node : b.node) as? TurkeyProjectile
            if let cartNode, let proj, proj.ownerIndex != cartNode.cartIndex {
                cartNode.applyTurkeyHit()
                proj.removeFromParent()
                if cartNode === player { hud.showMessage("HIT BY TURKEY!", duration: 0.6) }
            }
        }
    }

    // MARK: - Results

    private func showResults(place: Int) {
        let overlay = SKNode()
        overlay.name = "results"
        overlay.zPosition = 900
        overlay.position = CGPoint(x: -size.width / 2, y: -size.height / 2)

        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.65), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        if place == 1 {
            title.text = "CHECKOUT CHAMP!"
        } else {
            title.text = place == 2 ? "2ND PLACE" : (place == 3 ? "3RD PLACE" : "4TH PLACE")
        }
        title.fontSize = 34
        title.fontColor = place == 1 ? GameTheme.checkoutYellow : GameTheme.hudCream
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        overlay.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = place == 1 ? "The aisles are yours." : "Wheel back for another run."
        sub.fontSize = 15
        sub.fontColor = UIColor(white: 1, alpha: 0.7)
        sub.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - 36)
        overlay.addChild(sub)

        let again = SKLabelNode(fontNamed: "AvenirNext-Bold")
        again.text = "TAP TO RETRY"
        again.fontSize = 18
        again.fontColor = GameTheme.accentOrange
        again.name = "retry"
        again.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        overlay.addChild(again)

        let menu = SKLabelNode(fontNamed: "AvenirNext-Bold")
        menu.text = "MAIN MENU"
        menu.fontSize = 16
        menu.fontColor = GameTheme.hudCream.withAlphaComponent(0.8)
        menu.name = "menu"
        menu.position = CGPoint(x: size.width / 2, y: size.height * 0.38 - 40)
        overlay.addChild(menu)

        cameraNode.addChild(overlay)

        // Capture taps on results via scene touches — override briefly
        let retryBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 44), cornerRadius: 8)
        retryBtn.fillColor = .clear
        retryBtn.strokeColor = .clear
        retryBtn.position = again.position
        retryBtn.name = "retry"
        overlay.addChild(retryBtn)

        let menuBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 8)
        menuBtn.fillColor = .clear
        menuBtn.strokeColor = .clear
        menuBtn.position = menu.position
        menuBtn.name = "menu"
        overlay.addChild(menuBtn)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if raceOver, let t = touches.first {
            let p = t.location(in: cameraNode)
            // Convert to overlay space
            let nodes = cameraNode.nodes(at: p)
            if nodes.contains(where: { $0.name == "retry" }) {
                let game = GameScene(size: size)
                game.scaleMode = .resizeFill
                view?.presentScene(game, transition: .fade(withDuration: 0.35))
                return
            }
            if nodes.contains(where: { $0.name == "menu" }) {
                let menu = MenuScene(size: size)
                menu.scaleMode = .resizeFill
                view?.presentScene(menu, transition: .fade(withDuration: 0.35))
                return
            }
        }

        leftTouch = false
        rightTouch = false
        touching = false

        guard let t = touches.first else { return }
        let p = t.location(in: cameraNode)
        let x = p.x + size.width / 2
        let y = p.y + size.height / 2

        if hypot(x - (size.width - 52), y - (size.height - 62)) < 50 {
            useItem(for: player)
            return
        }
        if abs(x - size.width / 2) < 80 && y < 70 {
            tryBoost()
        }
    }
}
