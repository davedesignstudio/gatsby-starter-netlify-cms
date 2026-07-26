import SpriteKit

/// The race itself: top-down shopping-cart karting through the store.
final class GameScene: SKScene {

    // MARK: - Nested types

    private enum State { case countdown, racing, finishing }

    private enum Control: Equatable { case left, right, item }

    private final class Projectile {
        let node: SKShapeNode
        var velocity: CGPoint
        let owner: Cart
        var life: TimeInterval
        init(node: SKShapeNode, velocity: CGPoint, owner: Cart, life: TimeInterval) {
            self.node = node; self.velocity = velocity; self.owner = owner; self.life = life
        }
    }

    private final class Hazard {
        let node: SKShapeNode
        weak var owner: Cart?
        var ownerImmunityUntil: TimeInterval
        var life: TimeInterval
        init(node: SKShapeNode, owner: Cart?, ownerImmunityUntil: TimeInterval, life: TimeInterval) {
            self.node = node; self.owner = owner
            self.ownerImmunityUntil = ownerImmunityUntil; self.life = life
        }
    }

    private final class ItemBox {
        let node: SKShapeNode
        let home: CGPoint
        var active = true
        var respawnAt: TimeInterval = 0
        init(node: SKShapeNode, home: CGPoint) { self.node = node; self.home = home }
    }

    // MARK: - Tunables
    private let pickupRadius: CGFloat = 42
    private let projectileHitRadius: CGFloat = 30
    private let hazardHitRadius: CGFloat = 36
    private let cartSeparation: CGFloat = 46

    // MARK: - World
    private let track = Track()
    private let cameraNode = SKCameraNode()
    private var carts: [Cart] = []
    private var player: Cart!

    private var itemBoxes: [ItemBox] = []
    private var projectiles: [Projectile] = []
    private var hazards: [Hazard] = []

    // MARK: - State
    private var state: State = .countdown
    private var raceTime: TimeInterval = 0
    private var countdown: TimeInterval = 3.9
    private var lastUpdate: TimeInterval = 0

    // MARK: - Input
    private var touchRoles: [UITouch: Control] = [:]
    private var steerLeft = false
    private var steerRight = false

    // MARK: - HUD
    private let lapLabel = SKLabelNode()
    private let posLabel = SKLabelNode()
    private let timeLabel = SKLabelNode()
    private let countdownLabel = SKLabelNode()
    private let itemSlot = SKShapeNode(rectOf: CGSize(width: 70, height: 70), cornerRadius: 12)
    private let itemSlotLabel = SKLabelNode()

    private var leftButton: SKShapeNode!
    private var rightButton: SKShapeNode!
    private var itemButton: SKShapeNode!

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)

        addChild(track.buildNode())

        camera = cameraNode
        cameraNode.zPosition = GameConfig.ZPosition.camera
        addChild(cameraNode)

        setupCarts()
        setupItemBoxes()
        setupHUD()
        setupControls()

        cameraNode.setScale(1.0)
        updateCamera()
        startCountdown()
    }

    private func setupCarts() {
        let slots = track.startingSlots()
        for (i, entry) in Roster.entries.enumerated() {
            let isPlayer = (i == 0)
            let cart = Cart(name: entry.name, tint: entry.tint, isPlayer: isPlayer)
            cart.speedSkill = isPlayer ? 1.0 : CGFloat.random(in: 0.95...1.0)
            if i < slots.count { cart.place(at: slots[i]) }
            addChild(cart)
            carts.append(cart)
            if isPlayer { player = cart }
        }
    }

    private func setupItemBoxes() {
        for anchor in track.itemBoxAnchors() {
            let node = ItemNodeFactory.makeItemBox()
            node.position = anchor
            addChild(node)
            itemBoxes.append(ItemBox(node: node, home: anchor))
        }
    }

    // MARK: - HUD & controls

    private func setupHUD() {
        let halfW = size.width / 2
        let halfH = size.height / 2

        configureLabel(lapLabel, size: 26, align: .left)
        lapLabel.position = CGPoint(x: -halfW + 24, y: halfH - 44)
        cameraNode.addChild(lapLabel)

        configureLabel(posLabel, size: 26, align: .right)
        posLabel.position = CGPoint(x: halfW - 24, y: halfH - 44)
        cameraNode.addChild(posLabel)

        configureLabel(timeLabel, size: 24, align: .center)
        timeLabel.position = CGPoint(x: 0, y: halfH - 44)
        cameraNode.addChild(timeLabel)

        itemSlot.fillColor = SKColor(white: 0, alpha: 0.35)
        itemSlot.strokeColor = SKColor(white: 1, alpha: 0.5)
        itemSlot.lineWidth = 2
        itemSlot.position = CGPoint(x: halfW - 60, y: -halfH + 150)
        itemSlot.zPosition = GameConfig.ZPosition.hud
        cameraNode.addChild(itemSlot)

        itemSlotLabel.fontName = "AvenirNext-Bold"
        itemSlotLabel.fontSize = 40
        itemSlotLabel.verticalAlignmentMode = .center
        itemSlotLabel.horizontalAlignmentMode = .center
        itemSlot.addChild(itemSlotLabel)

        countdownLabel.fontName = "AvenirNext-Heavy"
        countdownLabel.fontSize = 120
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.position = .zero
        countdownLabel.zPosition = GameConfig.ZPosition.overlay
        cameraNode.addChild(countdownLabel)
    }

    private func configureLabel(_ label: SKLabelNode, size fontSize: CGFloat, align: SKLabelHorizontalAlignmentMode) {
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = align
        label.verticalAlignmentMode = .center
        label.zPosition = GameConfig.ZPosition.hud
    }

    private func setupControls() {
        let halfW = size.width / 2
        let halfH = size.height / 2

        leftButton = makeButton(symbol: "◀", radius: 52)
        leftButton.position = CGPoint(x: -halfW + 70, y: -halfH + 70)
        cameraNode.addChild(leftButton)

        rightButton = makeButton(symbol: "▶", radius: 52)
        rightButton.position = CGPoint(x: -halfW + 190, y: -halfH + 70)
        cameraNode.addChild(rightButton)

        itemButton = makeButton(symbol: "USE", radius: 60)
        itemButton.position = CGPoint(x: halfW - 80, y: -halfH + 70)
        cameraNode.addChild(itemButton)
    }

    private func makeButton(symbol: String, radius: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: radius)
        button.fillColor = SKColor(white: 1, alpha: 0.14)
        button.strokeColor = SKColor(white: 1, alpha: 0.5)
        button.lineWidth = 3
        button.zPosition = GameConfig.ZPosition.hud

        let label = SKLabelNode(text: symbol)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = symbol.count > 1 ? 24 : 40
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
        return button
    }

    // MARK: - Countdown

    private func startCountdown() {
        state = .countdown
        countdown = 3.9
        countdownLabel.text = "3"
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        var dt = currentTime - lastUpdate
        lastUpdate = currentTime
        dt = min(dt, 1.0 / 20.0)   // guard against long stalls / first frames

        switch state {
        case .countdown:
            tickCountdown(dt)
        case .racing:
            raceTime += dt
            simulate(dt)
        case .finishing:
            raceTime += dt
            simulate(dt)
        }
    }

    private func tickCountdown(_ dt: TimeInterval) {
        countdown -= dt
        if countdown > 3 {
            countdownLabel.text = "3"
        } else if countdown > 2 {
            countdownLabel.text = "2"
        } else if countdown > 1 {
            countdownLabel.text = "1"
        } else if countdown > 0 {
            if countdownLabel.text != "GO!" {
                countdownLabel.text = "GO!"
                countdownLabel.fontColor = SKColor(red: 0.3, green: 1, blue: 0.4, alpha: 1)
            }
        } else {
            state = .racing
            raceTime = 0
            countdownLabel.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
    }

    private func simulate(_ dt: TimeInterval) {
        for cart in carts {
            if cart === player {
                let steering = (steerLeft ? CGFloat(1) : 0) - (steerRight ? CGFloat(1) : 0)
                cart.update(dt: dt, steering: steering, throttle: 1.0, track: track)
            } else {
                let controls = cart.aiControls(on: track)
                cart.update(dt: dt, steering: controls.steering, throttle: controls.throttle, track: track)
                maybeAIUseItem(cart, dt: dt)
            }
        }

        resolveCartCollisions()
        updateItemBoxes()
        updateProjectiles(dt)
        updateHazards(dt)
        checkFinishers()
        updateCamera()
        updateHUD()
    }

    // MARK: - Items

    private func maybeAIUseItem(_ cart: Cart, dt: TimeInterval) {
        guard cart.heldItem != nil, !cart.isSpinning else { return }
        if CGFloat.random(in: 0...1) < CGFloat(dt) * 0.6 {
            useItem(cart)
        }
    }

    private func attemptUseItem(_ cart: Cart) {
        guard state == .racing || state == .finishing else { return }
        guard cart.heldItem != nil else { return }
        useItem(cart)
    }

    private func useItem(_ cart: Cart) {
        guard let item = cart.heldItem else { return }
        cart.heldItem = nil

        switch item {
        case .energyDrink:
            cart.applyBoost()
            flashBoost(on: cart)
        case .spilledMilk:
            dropMilk(from: cart)
        case .cannedGoods:
            fireCan(from: cart)
        }
    }

    private func flashBoost(on cart: Cart) {
        let spark = SKShapeNode(circleOfRadius: 44)
        spark.strokeColor = SKColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.9)
        spark.lineWidth = 4
        spark.fillColor = .clear
        spark.position = cart.position
        spark.zPosition = GameConfig.ZPosition.cart - 0.1
        addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent()
        ]))
    }

    private func dropMilk(from cart: Cart) {
        let dir = CGPoint(x: cos(cart.zRotation), y: sin(cart.zRotation))
        let pos = cart.position - dir * 45
        let puddle = ItemNodeFactory.makeMilkPuddle(at: pos)
        addChild(puddle)
        hazards.append(Hazard(node: puddle, owner: cart,
                              ownerImmunityUntil: raceTime + 1.0, life: 7.0))
    }

    private func fireCan(from cart: Cart) {
        let dir = CGPoint(x: cos(cart.zRotation), y: sin(cart.zRotation))
        let can = ItemNodeFactory.makeCan()
        can.position = cart.position + dir * 38
        addChild(can)
        can.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.3)))
        projectiles.append(Projectile(node: can,
                                      velocity: dir * GameConfig.projectileSpeed,
                                      owner: cart, life: 2.5))
    }

    private func updateItemBoxes() {
        for box in itemBoxes {
            if box.active {
                for cart in carts where cart.heldItem == nil && !cart.finished {
                    if cart.position.distance(to: box.home) < pickupRadius {
                        cart.heldItem = ItemType.random()
                        box.active = false
                        box.respawnAt = raceTime + 5
                        box.node.run(.sequence([.fadeOut(withDuration: 0.15)]))
                        break
                    }
                }
            } else if raceTime >= box.respawnAt {
                box.active = true
                box.node.run(.fadeIn(withDuration: 0.2))
            }
        }
    }

    private func updateProjectiles(_ dt: TimeInterval) {
        var survivors: [Projectile] = []
        for projectile in projectiles {
            projectile.node.position = projectile.node.position + projectile.velocity * CGFloat(dt)
            projectile.life -= dt

            var hit = false
            for cart in carts where cart !== projectile.owner && !cart.finished {
                if cart.position.distance(to: projectile.node.position) < projectileHitRadius {
                    cart.spinOut()
                    hit = true
                    break
                }
            }

            let p = projectile.node.position
            let outOfBounds = p.x < 0 || p.y < 0 || p.x > GameConfig.worldSize.width || p.y > GameConfig.worldSize.height
            if hit || projectile.life <= 0 || outOfBounds {
                projectile.node.removeFromParent()
            } else {
                survivors.append(projectile)
            }
        }
        projectiles = survivors
    }

    private func updateHazards(_ dt: TimeInterval) {
        var survivors: [Hazard] = []
        for hazard in hazards {
            hazard.life -= dt
            var consumed = false
            for cart in carts where !cart.finished {
                let isImmuneOwner = (cart === hazard.owner) && raceTime < hazard.ownerImmunityUntil
                if isImmuneOwner { continue }
                if cart.position.distance(to: hazard.node.position) < hazardHitRadius {
                    cart.spinOut()
                    consumed = true
                    break
                }
            }
            if consumed || hazard.life <= 0 {
                hazard.node.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
            } else {
                survivors.append(hazard)
            }
        }
        hazards = survivors
    }

    private func resolveCartCollisions() {
        for i in 0..<carts.count {
            for j in (i + 1)..<carts.count {
                let a = carts[i], b = carts[j]
                let delta = b.position - a.position
                let dist = delta.length
                if dist > 0 && dist < cartSeparation {
                    let push = (cartSeparation - dist) / 2
                    let dir = delta.normalized
                    a.position = a.position - dir * push
                    b.position = b.position + dir * push
                }
            }
        }
    }

    // MARK: - Camera & HUD

    private func updateCamera() {
        let halfW = size.width / 2 * cameraNode.xScale
        let halfH = size.height / 2 * cameraNode.yScale
        let x = clamp(player.position.x, halfW, GameConfig.worldSize.width - halfW)
        let y = clamp(player.position.y, halfH, GameConfig.worldSize.height - halfH)
        cameraNode.position = CGPoint(x: x, y: y)
    }

    private func currentOrder() -> [Cart] {
        carts.sorted { lhs, rhs in
            switch (lhs.finished, rhs.finished) {
            case (true, true): return lhs.finishTime < rhs.finishTime
            case (true, false): return true
            case (false, true): return false
            case (false, false): return lhs.progressScore(track: track) > rhs.progressScore(track: track)
            }
        }
    }

    private func updateHUD() {
        let currentLap = min(player.lap + 1, GameConfig.totalLaps)
        lapLabel.text = "LAP \(currentLap)/\(GameConfig.totalLaps)"

        let order = currentOrder()
        if let place = order.firstIndex(where: { $0 === player }) {
            posLabel.text = "\(ordinal(place + 1))/\(carts.count)"
        }

        timeLabel.text = formatRaceTime(raceTime)

        if let item = player.heldItem {
            itemSlotLabel.text = item.symbol
        } else {
            itemSlotLabel.text = ""
        }
    }

    private func ordinal(_ place: Int) -> String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }

    // MARK: - Finishing

    private func checkFinishers() {
        for cart in carts where !cart.finished && cart.lap >= GameConfig.totalLaps {
            cart.markFinished(at: raceTime)
        }

        if player.finished && state == .racing {
            state = .finishing
            countdownLabel.removeAllActions()
            countdownLabel.alpha = 1
            countdownLabel.fontSize = 90
            countdownLabel.fontColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            countdownLabel.text = "FINISH!"
            if countdownLabel.parent == nil { cameraNode.addChild(countdownLabel) }

            run(.sequence([
                .wait(forDuration: 1.6),
                .run { [weak self] in self?.presentResults() }
            ]))
        }
    }

    private func presentResults() {
        let ordered = finalStandings()
        var results: [RaceResult] = []
        for (i, cart) in ordered.enumerated() {
            results.append(RaceResult(place: i + 1,
                                      name: cart.racerName,
                                      tint: cart.tint,
                                      isPlayer: cart.isPlayer,
                                      finished: cart.finished,
                                      time: cart.finishTime))
        }
        let scene = ResultsScene(size: size, results: results)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .fade(withDuration: 0.6))
    }

    private func finalStandings() -> [Cart] {
        carts.sorted { lhs, rhs in
            switch (lhs.finished, rhs.finished) {
            case (true, true): return lhs.finishTime < rhs.finishTime
            case (true, false): return true
            case (false, true): return false
            case (false, false): return lhs.progressScore(track: track) > rhs.progressScore(track: track)
            }
        }
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: cameraNode)
            if let control = control(for: loc) {
                touchRoles[touch] = control
                if control == .item { attemptUseItem(player) }
            }
        }
        recomputeSteering()
        highlightButtons()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: cameraNode)
            let control = control(for: loc)
            if control == .item {
                // Do not re-fire items while dragging; keep prior role if any.
                continue
            }
            if let control = control {
                touchRoles[touch] = control
            } else {
                touchRoles.removeValue(forKey: touch)
            }
        }
        recomputeSteering()
        highlightButtons()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchRoles.removeValue(forKey: touch) }
        recomputeSteering()
        highlightButtons()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func control(for location: CGPoint) -> Control? {
        if location.distance(to: leftButton.position) <= 62 { return .left }
        if location.distance(to: rightButton.position) <= 62 { return .right }
        if location.distance(to: itemButton.position) <= 70 { return .item }
        return nil
    }

    private func recomputeSteering() {
        steerLeft = touchRoles.values.contains(.left)
        steerRight = touchRoles.values.contains(.right)
    }

    private func highlightButtons() {
        leftButton.fillColor = steerLeft ? SKColor(white: 1, alpha: 0.35) : SKColor(white: 1, alpha: 0.14)
        rightButton.fillColor = steerRight ? SKColor(white: 1, alpha: 0.35) : SKColor(white: 1, alpha: 0.14)
    }
}
