import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum Phase {
        case menu
        case countdown
        case racing
        case finished
    }

    private enum Control: String, Hashable {
        case left
        case right
        case drift
    }

    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private var player: CartNode!
    private var opponents: [CartNode] = []

    private var phase: Phase = .menu
    private var raceProgress = RaceProgress(totalLaps: 3, checkpointCount: StoreTrack.checkpoints.count)
    private var aiFinishOrder: [CartNode] = []
    private var elapsedTime: TimeInterval = 0
    private var countdownRemaining: TimeInterval = 3
    private var lastUpdateTime: TimeInterval = 0
    private var boostRemaining: TimeInterval = 0
    private var spinRemaining: TimeInterval = 0
    private var trailCooldown: TimeInterval = 0

    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let positionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var controls: [Control: SKShapeNode] = [:]
    private var activeTouches: [ObjectIdentifier: Control] = [:]
    private var overlay: SKNode?

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = SKColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        worldNode.name = "world"
        addChild(worldNode)
        StoreTrack.build(in: worldNode)
        createCarts()
        createTrackItems()

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.position = player.position

        configureHUD()
        layoutHUD()
        showMenu()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cameraNode.parent != nil else { return }
        layoutHUD()

        if phase == .menu {
            showMenu()
        }
    }

    private func createCarts() {
        player = CartNode(color: .systemTeal, cartName: "playerCart", isPlayer: true)
        worldNode.addChild(player)

        let colors: [SKColor] = [.systemPink, .systemOrange, .systemPurple]
        let speeds: [CGFloat] = [286, 304, 320]
        for index in 0..<3 {
            let cart = CartNode(
                color: colors[index],
                cartName: "rivalCart\(index + 1)",
                isPlayer: false
            )
            cart.cruiseSpeed = speeds[index]
            opponents.append(cart)
            worldNode.addChild(cart)
        }

        resetCarts()
    }

    private func resetCarts() {
        let starts = [
            CGPoint(x: 165, y: -500),
            CGPoint(x: 165, y: -380),
            CGPoint(x: 35, y: -500),
            CGPoint(x: 35, y: -380)
        ]

        aiFinishOrder.removeAll()
        player.reset(at: starts[0])
        for (index, cart) in opponents.enumerated() {
            cart.reset(at: starts[index + 1])
        }
        cameraNode.position = player.position
    }

    private func createTrackItems() {
        let boosts = [
            CGPoint(x: 630, y: -440),
            CGPoint(x: 970, y: 145),
            CGPoint(x: -520, y: 440),
            CGPoint(x: -970, y: -145)
        ]

        for (index, position) in boosts.enumerated() {
            let pickup = SKShapeNode(circleOfRadius: 42)
            pickup.name = "boost\(index)"
            pickup.fillColor = SKColor(red: 1, green: 0.78, blue: 0.08, alpha: 0.92)
            pickup.strokeColor = .white
            pickup.lineWidth = 6
            pickup.position = position
            pickup.zPosition = 8

            let coupon = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            coupon.text = "¢"
            coupon.fontColor = SKColor(red: 0.18, green: 0.12, blue: 0.04, alpha: 1)
            coupon.fontSize = 42
            coupon.verticalAlignmentMode = .center
            pickup.addChild(coupon)

            let body = SKPhysicsBody(circleOfRadius: 42)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.boost
            body.collisionBitMask = 0
            body.contactTestBitMask = PhysicsCategory.cart
            pickup.physicsBody = body
            worldNode.addChild(pickup)

            pickup.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.55),
                .scale(to: 0.92, duration: 0.55)
            ])))
        }

        let hazards = [
            CGPoint(x: 390, y: 440),
            CGPoint(x: -475, y: -440)
        ]

        for (index, position) in hazards.enumerated() {
            let spill = SKShapeNode(ellipseOf: CGSize(width: 150, height: 105))
            spill.name = "spill\(index)"
            spill.fillColor = SKColor(red: 0.42, green: 0.18, blue: 0.08, alpha: 0.86)
            spill.strokeColor = SKColor(red: 0.72, green: 0.36, blue: 0.10, alpha: 1)
            spill.lineWidth = 5
            spill.position = position
            spill.zRotation = index.isMultiple(of: 2) ? 0.2 : -0.2
            spill.zPosition = 4

            let body = SKPhysicsBody(circleOfRadius: 58)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.hazard
            body.collisionBitMask = 0
            body.contactTestBitMask = PhysicsCategory.cart
            spill.physicsBody = body
            worldNode.addChild(spill)
        }
    }

    private func configureHUD() {
        for label in [lapLabel, positionLabel, timerLabel, statusLabel, countdownLabel] {
            label.zPosition = 1_000
            cameraNode.addChild(label)
        }

        lapLabel.fontSize = 25
        lapLabel.horizontalAlignmentMode = .left
        positionLabel.fontSize = 38
        positionLabel.fontColor = .systemYellow
        positionLabel.horizontalAlignmentMode = .left
        timerLabel.fontSize = 24
        timerLabel.horizontalAlignmentMode = .right
        statusLabel.fontSize = 24
        statusLabel.fontColor = .systemYellow
        countdownLabel.fontSize = 110
        countdownLabel.verticalAlignmentMode = .center

        controls[.left] = makeControlButton(symbol: "‹", name: Control.left.rawValue)
        controls[.right] = makeControlButton(symbol: "›", name: Control.right.rawValue)
        controls[.drift] = makeControlButton(symbol: "DRIFT", name: Control.drift.rawValue, isWide: true)

        controls.values.forEach { cameraNode.addChild($0) }
        updateHUD()
    }

    private func makeControlButton(symbol: String, name: String, isWide: Bool = false) -> SKShapeNode {
        let button = SKShapeNode(
            rectOf: CGSize(width: isWide ? 132 : 86, height: 86),
            cornerRadius: 28
        )
        button.name = "control_\(name)"
        button.fillColor = SKColor(white: 0.08, alpha: 0.62)
        button.strokeColor = SKColor(white: 1, alpha: 0.72)
        button.lineWidth = 4
        button.zPosition = 1_000

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = symbol
        label.fontSize = isWide ? 23 : 56
        label.verticalAlignmentMode = .center
        label.name = button.name
        button.addChild(label)
        return button
    }

    private func layoutHUD() {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let top = halfHeight - 48
        let bottom = -halfHeight + 72

        lapLabel.position = CGPoint(x: -halfWidth + 30, y: top)
        positionLabel.position = CGPoint(x: -halfWidth + 30, y: top - 48)
        timerLabel.position = CGPoint(x: halfWidth - 30, y: top)
        statusLabel.position = CGPoint(x: 0, y: top)
        countdownLabel.position = .zero

        controls[.left]?.position = CGPoint(x: -halfWidth + 72, y: bottom)
        controls[.right]?.position = CGPoint(x: -halfWidth + 172, y: bottom)
        controls[.drift]?.position = CGPoint(x: halfWidth - 94, y: bottom)
    }

    private func showMenu() {
        phase = .menu
        setControls(hidden: true)
        overlay?.removeFromParent()

        let menu = SKNode()
        menu.name = "menu"
        menu.zPosition = 2_000

        let shade = SKShapeNode(rectOf: size)
        shade.fillColor = SKColor(white: 0.02, alpha: 0.72)
        shade.strokeColor = .clear
        menu.addChild(shade)

        let panel = SKShapeNode(
            rectOf: CGSize(width: min(size.width - 50, 650), height: min(size.height - 50, 430)),
            cornerRadius: 36
        )
        panel.fillColor = SKColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 0.96)
        panel.strokeColor = .systemYellow
        panel.lineWidth = 7
        menu.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "AISLE RUSH"
        title.fontSize = min(72, size.width / 10)
        title.fontColor = .systemYellow
        title.position.y = 125
        panel.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = "Runaway carts. One checkout lane."
        subtitle.fontSize = 24
        subtitle.position.y = 75
        panel.addChild(subtitle)

        let instructions = SKLabelNode(fontNamed: "AvenirNext-Medium")
        instructions.text = "AUTO-DRIVE  •  STEER  •  HOLD DRIFT  •  GRAB COUPONS"
        instructions.fontSize = 16
        instructions.fontColor = SKColor(white: 0.82, alpha: 1)
        instructions.position.y = 24
        panel.addChild(instructions)

        let start = SKShapeNode(rectOf: CGSize(width: 250, height: 72), cornerRadius: 24)
        start.name = "startButton"
        start.fillColor = .systemTeal
        start.strokeColor = .white
        start.lineWidth = 4
        start.position.y = -75

        let startLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        startLabel.name = "startButton"
        startLabel.text = "START RACE"
        startLabel.fontSize = 27
        startLabel.verticalAlignmentMode = .center
        start.addChild(startLabel)
        panel.addChild(start)

        let note = SKLabelNode(fontNamed: "AvenirNext-Medium")
        note.text = "3 laps  •  4 carts  •  zero owners"
        note.fontSize = 16
        note.fontColor = SKColor(white: 0.62, alpha: 1)
        note.position.y = -142
        panel.addChild(note)

        cameraNode.addChild(menu)
        overlay = menu
    }

    private func startRace() {
        overlay?.removeFromParent()
        overlay = nil
        activeTouches.removeAll()
        raceProgress.reset()
        elapsedTime = 0
        boostRemaining = 0
        spinRemaining = 0
        countdownRemaining = 3
        resetCarts()
        resetPickups()

        phase = .countdown
        countdownLabel.removeAllActions()
        countdownLabel.alpha = 1
        countdownLabel.isHidden = false
        countdownLabel.text = "3"
        statusLabel.text = ""
        setControls(hidden: false)
        updateHUD()
    }

    private func resetPickups() {
        for node in worldNode.children where node.name?.hasPrefix("boost") == true {
            node.removeAllActions()
            node.isHidden = false
            node.setScale(1)
            node.physicsBody?.categoryBitMask = PhysicsCategory.boost
            node.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.55),
                .scale(to: 0.92, duration: 0.55)
            ])))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }

        let wallClockDelta = max(0, currentTime - lastUpdateTime)
        let simulationDelta = min(wallClockDelta, 1.0 / 30.0)
        lastUpdateTime = currentTime

        switch phase {
        case .menu:
            break
        case .countdown:
            updateCountdown(wallClockDelta)
        case .racing:
            elapsedTime += wallClockDelta
            updatePlayer(simulationDelta)
            updateOpponents(simulationDelta)
            checkPlayerCheckpoint()
            updateHUD()
        case .finished:
            break
        }

        updateCamera()
    }

    private func updateCountdown(_ deltaTime: TimeInterval) {
        countdownRemaining -= deltaTime
        let number = max(1, Int(ceil(countdownRemaining)))
        countdownLabel.text = "\(number)"

        guard countdownRemaining <= 0 else { return }
        phase = .racing
        countdownLabel.text = "GO!"
        countdownLabel.run(.sequence([
            .wait(forDuration: 0.45),
            .fadeOut(withDuration: 0.25),
            .hide()
        ]))
    }

    private func updatePlayer(_ deltaTime: TimeInterval) {
        let delta = CGFloat(deltaTime)
        let leftHeld = activeTouches.values.contains(.left)
        let rightHeld = activeTouches.values.contains(.right)
        let isDrifting = activeTouches.values.contains(.drift)
        let steering: CGFloat = (leftHeld ? 1 : 0) + (rightHeld ? -1 : 0)

        boostRemaining = max(0, boostRemaining - deltaTime)
        spinRemaining = max(0, spinRemaining - deltaTime)
        trailCooldown -= deltaTime

        let maximumSpeed: CGFloat = boostRemaining > 0 ? 470 : (isDrifting ? 300 : 350)
        let acceleration: CGFloat = boostRemaining > 0 ? 4.5 : 2.7
        player.speed += (maximumSpeed - player.speed) * min(1, acceleration * delta)

        if spinRemaining > 0 {
            player.heading += 7.5 * delta
            player.speed *= 0.992
        } else {
            let speedRatio = min(1, player.speed / 350)
            let turnRate: CGFloat = isDrifting ? 2.15 : 1.38
            player.heading += steering * turnRate * (0.35 + 0.65 * speedRatio) * delta
        }

        player.zRotation = player.heading
        player.physicsBody?.angularVelocity = 0
        player.physicsBody?.velocity = CGVector(
            dx: cos(player.heading) * player.speed,
            dy: sin(player.heading) * player.speed
        )

        if trailCooldown <= 0, isDrifting || boostRemaining > 0 {
            leaveTrail(boosting: boostRemaining > 0)
            trailCooldown = 0.07
        }
    }

    private func leaveTrail(boosting: Bool) {
        let trail = SKShapeNode(circleOfRadius: boosting ? 12 : 7)
        trail.fillColor = boosting ? .systemYellow : SKColor(white: 0.92, alpha: 0.55)
        trail.strokeColor = .clear
        trail.position = CGPoint(
            x: player.position.x - cos(player.heading) * 53,
            y: player.position.y - sin(player.heading) * 53
        )
        trail.zPosition = 3
        worldNode.addChild(trail)
        trail.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.55),
                .scale(to: 0.2, duration: 0.55)
            ]),
            .removeFromParent()
        ]))
    }

    private func updateOpponents(_ deltaTime: TimeInterval) {
        let delta = CGFloat(deltaTime)

        for cart in opponents {
            guard !cart.hasFinished else {
                cart.physicsBody?.velocity = .zero
                continue
            }

            var target = StoreTrack.route[cart.routeTargetIndex]
            let reachedTarget = StoreTrack.distance(cart.position, target) < 145
                && (cart.routeTargetIndex != 0 || cart.position.x >= 0)
            if reachedTarget {
                if cart.routeTargetIndex == 0 {
                    cart.completedLaps += 1
                    if cart.completedLaps >= raceProgress.totalLaps {
                        cart.hasFinished = true
                        cart.speed = 0
                        cart.physicsBody?.velocity = .zero
                        aiFinishOrder.append(cart)
                        continue
                    }
                }
                cart.routeTargetIndex = (cart.routeTargetIndex + 1) % StoreTrack.route.count
                target = StoreTrack.route[cart.routeTargetIndex]
            }

            let desiredHeading = atan2(target.y - cart.position.y, target.x - cart.position.x)
            let headingError = atan2(sin(desiredHeading - cart.heading), cos(desiredHeading - cart.heading))
            let maximumTurn = 1.65 * delta
            cart.heading += max(-maximumTurn, min(maximumTurn, headingError))

            let cornerPenalty = min(0.28, abs(headingError) * 0.16)
            let targetSpeed = cart.cruiseSpeed * (1 - cornerPenalty)
            cart.speed += (targetSpeed - cart.speed) * min(1, 2.4 * delta)
            cart.zRotation = cart.heading
            cart.physicsBody?.angularVelocity = 0
            cart.physicsBody?.velocity = CGVector(
                dx: cos(cart.heading) * cart.speed,
                dy: sin(cart.heading) * cart.speed
            )
        }
    }

    private func checkPlayerCheckpoint() {
        let expected = raceProgress.nextCheckpoint
        let checkpoint = StoreTrack.checkpoints[expected]
        let isStartLine = expected == StoreTrack.checkpoints.count - 1
        guard StoreTrack.distance(player.position, checkpoint) < 145,
              !isStartLine || player.position.x >= 0 else { return }

        switch raceProgress.passCheckpoint(expected) {
        case .lapCompleted(let lap):
            showStatus("LAP \(lap) / \(raceProgress.totalLaps)")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .raceFinished:
            finishRace()
        case .checkpoint, .ignored:
            break
        }
    }

    private func updateCamera() {
        let smoothing: CGFloat = phase == .racing ? 0.13 : 0.08
        cameraNode.position = CGPoint(
            x: cameraNode.position.x + (player.position.x - cameraNode.position.x) * smoothing,
            y: cameraNode.position.y + (player.position.y - cameraNode.position.y) * smoothing
        )
    }

    private func updateHUD() {
        lapLabel.text = "LAP \(min(raceProgress.currentLap, raceProgress.totalLaps))/\(raceProgress.totalLaps)"
        positionLabel.text = "\(ordinal(currentPosition())) PLACE"
        timerLabel.text = formattedTime(elapsedTime)

        if boostRemaining > 0 {
            statusLabel.text = "COUPON BOOST!"
            statusLabel.fontColor = .systemYellow
        } else if spinRemaining > 0 {
            statusLabel.text = "SPILL OUT!"
            statusLabel.fontColor = .systemOrange
        } else if statusLabel.action(forKey: "status") == nil {
            statusLabel.text = ""
        }
    }

    private func currentPosition() -> Int {
        if raceProgress.isFinished {
            return min(opponents.count + 1, aiFinishOrder.count + 1)
        }

        let playerScore = CGFloat(raceProgress.currentLap - 1) + StoreTrack.progress(at: player.position)
        let opponentsAhead = opponents.filter {
            if $0.hasFinished {
                return true
            }
            let score = CGFloat($0.completedLaps) + StoreTrack.progress(at: $0.position)
            return score > playerScore + 0.01
        }
        return opponentsAhead.count + 1
    }

    private func showStatus(_ text: String) {
        statusLabel.removeAction(forKey: "status")
        statusLabel.alpha = 1
        statusLabel.text = text
        let action = SKAction.sequence([
            .wait(forDuration: 1.1),
            .fadeOut(withDuration: 0.35),
            .run { [weak self] in
                self?.statusLabel.text = ""
                self?.statusLabel.alpha = 1
            }
        ])
        statusLabel.run(action, withKey: "status")
    }

    private func finishRace() {
        let finishingPosition = currentPosition()
        phase = .finished
        player.physicsBody?.velocity = .zero
        opponents.forEach { $0.physicsBody?.velocity = .zero }
        setControls(hidden: true)
        UINotificationFeedbackGenerator().notificationOccurred(
            finishingPosition == 1 ? .success : .warning
        )

        let finishOverlay = SKNode()
        finishOverlay.zPosition = 2_000

        let shade = SKShapeNode(rectOf: size)
        shade.fillColor = SKColor(white: 0.02, alpha: 0.76)
        shade.strokeColor = .clear
        finishOverlay.addChild(shade)

        let card = SKShapeNode(rectOf: CGSize(width: min(size.width - 50, 560), height: 330), cornerRadius: 34)
        card.fillColor = SKColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 0.98)
        card.strokeColor = finishingPosition == 1 ? .systemYellow : .systemTeal
        card.lineWidth = 7
        finishOverlay.addChild(card)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = finishingPosition == 1 ? "AISLE CHAMPION!" : "\(ordinal(finishingPosition)) PLACE"
        title.fontSize = 46
        title.fontColor = finishingPosition == 1 ? .systemYellow : .white
        title.position.y = 90
        card.addChild(title)

        let time = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        time.text = "CHECKOUT TIME  \(formattedTime(elapsedTime))"
        time.fontSize = 24
        time.position.y = 35
        card.addChild(time)

        let replay = SKShapeNode(rectOf: CGSize(width: 245, height: 70), cornerRadius: 22)
        replay.name = "replayButton"
        replay.fillColor = .systemTeal
        replay.strokeColor = .white
        replay.lineWidth = 4
        replay.position.y = -65

        let replayLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        replayLabel.name = "replayButton"
        replayLabel.text = "RACE AGAIN"
        replayLabel.fontSize = 26
        replayLabel.verticalAlignmentMode = .center
        replay.addChild(replayLabel)
        card.addChild(replay)

        cameraNode.addChild(finishOverlay)
        overlay = finishOverlay
    }

    private func setControls(hidden: Bool) {
        controls.values.forEach { $0.isHidden = hidden }
        if hidden {
            activeTouches.removeAll()
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time - floor(time)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(value)TH"
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: cameraNode)

            if phase == .menu, touchedNode(named: "startButton", at: location) {
                startRace()
                return
            }

            if phase == .finished, touchedNode(named: "replayButton", at: location) {
                startRace()
                return
            }

            guard phase == .racing || phase == .countdown,
                  let control = control(at: location) else { continue }
            activeTouches[ObjectIdentifier(touch)] = control
            controls[control]?.fillColor = SKColor(white: 0.3, alpha: 0.78)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let oldControl = activeTouches.removeValue(forKey: identifier)
            if let oldControl {
                controls[oldControl]?.fillColor = SKColor(white: 0.08, alpha: 0.62)
            }

            let location = touch.location(in: cameraNode)
            if let newControl = control(at: location) {
                activeTouches[identifier] = newControl
                controls[newControl]?.fillColor = SKColor(white: 0.3, alpha: 0.78)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if let control = activeTouches.removeValue(forKey: ObjectIdentifier(touch)) {
                controls[control]?.fillColor = SKColor(white: 0.08, alpha: 0.62)
            }
        }
    }

    private func control(at point: CGPoint) -> Control? {
        controls.first { !$0.value.isHidden && $0.value.contains(point) }?.key
    }

    private func touchedNode(named name: String, at point: CGPoint) -> Bool {
        cameraNode.nodes(at: point).contains { node in
            var candidate: SKNode? = node
            while let current = candidate {
                if current.name == name {
                    return true
                }
                candidate = current.parent
            }
            return false
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let firstIsCart = contact.bodyA.categoryBitMask & PhysicsCategory.cart != 0
        let cartBody = firstIsCart ? contact.bodyA : contact.bodyB
        let itemBody = firstIsCart ? contact.bodyB : contact.bodyA

        guard let cart = cartBody.node as? CartNode else { return }

        if itemBody.categoryBitMask & PhysicsCategory.boost != 0 {
            cart.speed += 80
            if cart.isPlayer {
                boostRemaining = 2.2
                showStatus("COUPON BOOST!")
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            consumePickup(itemBody.node)
        } else if itemBody.categoryBitMask & PhysicsCategory.hazard != 0, cart.isPlayer {
            spinRemaining = max(spinRemaining, 0.85)
            showStatus("SPILL OUT!")
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private func consumePickup(_ node: SKNode?) {
        guard let node, !node.isHidden else { return }
        node.isHidden = true
        node.physicsBody?.categoryBitMask = 0
        node.run(.sequence([
            .wait(forDuration: 6),
            .run { [weak node] in
                node?.isHidden = false
                node?.physicsBody?.categoryBitMask = PhysicsCategory.boost
            }
        ]))
    }
}
