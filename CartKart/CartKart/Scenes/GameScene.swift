import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private var racers: [CartRacer] = []
    private var aiControllers: [AIController] = []
    private var player: CartRacer!
    private let input = InputManager()
    private var cameraNode = SKCameraNode()
    private var hud = SKNode()
    private var raceTime: TimeInterval = 0
    private var countdown = 3
    private var raceStarted = false
    private var finishOrder: [CartRacer] = []
    private var itemBoxes: [SKNode] = []
    private var hazards: [SKNode] = []

    private let lapLabel = SKLabelNode(text: "Lap 1/3")
    private let positionLabel = SKLabelNode(text: "1st")
    private let timerLabel = SKLabelNode(text: "0:00.0")
    private let itemLabel = SKLabelNode(text: "No Item")
    private let countdownLabel = SKLabelNode(text: "3")

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        buildTrack()
        buildRacers()
        setupCamera()
        setupHUD()
        setupInput()
        startCountdown()
    }

    private func buildTrack() {
        let floor = SKShapeNode(rect: TrackLayout.outerRect, cornerRadius: 12)
        floor.fillColor = SKColor(red: 0.78, green: 0.75, blue: 0.7, alpha: 1)
        floor.strokeColor = SKColor(red: 0.55, green: 0.52, blue: 0.48, alpha: 1)
        floor.lineWidth = 6
        floor.zPosition = -10
        addChild(floor)

        let island = SKShapeNode(rect: TrackLayout.innerRect, cornerRadius: 10)
        island.fillColor = SKColor(red: 0.65, green: 0.62, blue: 0.58, alpha: 1)
        island.strokeColor = SKColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1)
        island.lineWidth = 4
        island.zPosition = -9
        addChild(island)

        addShelf(at: TrackLayout.innerRect, label: "DAIRY")
        for shelf in TrackLayout.shelfObstacles {
            addShelfBlock(shelf, label: ["CEREAL", "SOUP", "CHIPS", "PASTA", "COOKIES", "JUICE"].randomElement()!)
        }

        addWalls()
        addDecor()
        addItemBoxes()
        addStartLine()
    }

    private func addShelf(at rect: CGRect, label: String) {
        let shelf = SKShapeNode(rect: rect, cornerRadius: 8)
        shelf.fillColor = SKColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        shelf.strokeColor = SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1)
        shelf.lineWidth = 3
        shelf.zPosition = -5
        addChild(shelf)

        let text = SKLabelNode(text: label)
        text.fontName = "AvenirNext-Heavy"
        text.fontSize = 28
        text.fontColor = SKColor(white: 1, alpha: 0.25)
        text.position = CGPoint(x: rect.midX, y: rect.midY - 10)
        text.zPosition = -4
        addChild(text)
    }

    private func addShelfBlock(_ rect: CGRect, label: String) {
        let block = SKShapeNode(rect: rect, cornerRadius: 4)
        block.fillColor = SKColor(red: 0.42, green: 0.3, blue: 0.18, alpha: 1)
        block.strokeColor = .black
        block.lineWidth = 2
        block.zPosition = 2

        let body = SKPhysicsBody(rectangleOf: rect.size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.shelf
        body.collisionBitMask = PhysicsCategory.racer
        block.physicsBody = body
        block.position = CGPoint(x: rect.midX, y: rect.midY)
        addChild(block)

        let tag = SKLabelNode(text: label)
        tag.fontName = "AvenirNext-Bold"
        tag.fontSize = 11
        tag.fontColor = SKColor(white: 1, alpha: 0.7)
        tag.position = .zero
        tag.verticalAlignmentMode = .center
        block.addChild(tag)
    }

    private func addWalls() {
        let outer = TrackLayout.outerRect
        let walls: [(CGPoint, CGSize)] = [
            (CGPoint(x: outer.midX, y: outer.maxY), CGSize(width: outer.width, height: 20)),
            (CGPoint(x: outer.midX, y: outer.minY), CGSize(width: outer.width, height: 20)),
            (CGPoint(x: outer.maxX, y: outer.midY), CGSize(width: 20, height: outer.height)),
            (CGPoint(x: outer.minX, y: outer.midY), CGSize(width: 20, height: outer.height))
        ]

        for (position, size) in walls {
            let wall = SKNode()
            wall.position = position
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.racer
            wall.physicsBody = body
            addChild(wall)
        }

        let inner = TrackLayout.innerRect
        let innerWalls: [(CGPoint, CGSize)] = [
            (CGPoint(x: inner.midX, y: inner.maxY), CGSize(width: inner.width, height: 16)),
            (CGPoint(x: inner.midX, y: inner.minY), CGSize(width: inner.width, height: 16)),
            (CGPoint(x: inner.maxX, y: inner.midY), CGSize(width: 16, height: inner.height)),
            (CGPoint(x: inner.minX, y: inner.midY), CGSize(width: 16, height: inner.height))
        ]

        for (position, size) in innerWalls {
            let wall = SKNode()
            wall.position = position
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.racer
            wall.physicsBody = body
            addChild(wall)
        }
    }

    private func addDecor() {
        let colors: [SKColor] = [
            SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
            SKColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 1),
            SKColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1),
            SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1)
        ]

        for index in 0..<24 {
            let tile = SKShapeNode(rectOf: CGSize(width: 48, height: 48), cornerRadius: 4)
            tile.fillColor = colors[index % colors.count].withAlphaComponent(0.18)
            tile.strokeColor = .clear
            let angle = CGFloat(index) / 24 * .pi * 2
            let radius: CGFloat = 420
            tile.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            tile.zPosition = -8
            addChild(tile)
        }
    }

    private func addItemBoxes() {
        for point in TrackLayout.itemBoxPositions {
            let box = SKShapeNode(rectOf: CGSize(width: 36, height: 36), cornerRadius: 6)
            box.fillColor = SKColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 0.85)
            box.strokeColor = .white
            box.lineWidth = 2
            box.position = point
            box.zPosition = 1
            box.name = "itemBox"

            let sparkle = SKLabelNode(text: "?")
            sparkle.fontName = "AvenirNext-Heavy"
            sparkle.fontSize = 20
            sparkle.fontColor = .white
            sparkle.verticalAlignmentMode = .center
            box.addChild(sparkle)

            let body = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 36))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.itemBox
            body.contactTestBitMask = PhysicsCategory.racer
            body.collisionBitMask = PhysicsCategory.none
            box.physicsBody = body

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            box.run(SKAction.repeatForever(pulse))

            addChild(box)
            itemBoxes.append(box)
        }
    }

    private func addStartLine() {
        let line = SKShapeNode(rectOf: CGSize(width: 120, height: 8))
        line.fillColor = .white
        line.strokeColor = .black
        line.lineWidth = 1
        line.position = TrackLayout.startPosition
        line.zRotation = .pi / 2
        line.zPosition = 0
        addChild(line)

        for offset in stride(from: -50, through: 50, by: 20) {
            let checker = SKShapeNode(rectOf: CGSize(width: 10, height: 8))
            checker.fillColor = offset.truncatingRemainder(dividingBy: 40) == 0 ? .black : .white
            checker.strokeColor = .clear
            checker.position = CGPoint(x: offset, y: 0)
            line.addChild(checker)
        }
    }

    private func buildRacers() {
        let configs: [(String, Bool, SKColor, SKColor, CGPoint, CGFloat)] = [
            ("You", true, SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1), .lightGray, CGPoint(x: -40, y: -360), .pi / 2),
            ("Rusty Ron", false, SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1), SKColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1), CGPoint(x: 40, y: -360), .pi / 2),
            ("Cart Carl", false, SKColor(red: 0.25, green: 0.7, blue: 0.35, alpha: 1), .gray, CGPoint(x: -40, y: -400), .pi / 2),
            ("Wheels Wendy", false, SKColor(red: 0.75, green: 0.35, blue: 0.85, alpha: 1), SKColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1), CGPoint(x: 40, y: -400), .pi / 2)
        ]

        for (index, config) in configs.enumerated() {
            let racer = CartRacer(name: config.0, isPlayer: config.1, bodyColor: config.2, cartColor: config.3)
            racer.position = config.4
            racer.zRotation = config.5
            racer.zPosition = 10
            addChild(racer)
            racers.append(racer)

            if config.1 {
                player = racer
            } else {
                let skill = CGFloat(0.55 + Double(index) * 0.12)
                aiControllers.append(AIController(racer: racer, skill: skill))
            }
        }
    }

    private func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = player.position
    }

    private func setupHUD() {
        hud.zPosition = 200
        cameraNode.addChild(hud)

        configureLabel(lapLabel, fontSize: 18)
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.position = CGPoint(x: -size.width / 2 + 20, y: size.height / 2 - 50)

        configureLabel(positionLabel, fontSize: 28)
        positionLabel.horizontalAlignmentMode = .right
        positionLabel.position = CGPoint(x: size.width / 2 - 20, y: size.height / 2 - 50)

        configureLabel(timerLabel, fontSize: 16)
        timerLabel.position = CGPoint(x: 0, y: size.height / 2 - 50)

        configureLabel(itemLabel, fontSize: 14)
        itemLabel.position = CGPoint(x: 0, y: size.height / 2 - 80)

        hud.addChild(lapLabel)
        hud.addChild(positionLabel)
        hud.addChild(timerLabel)
        hud.addChild(itemLabel)

        configureLabel(countdownLabel, fontSize: 96)
        countdownLabel.position = .zero
        countdownLabel.alpha = 0
        hud.addChild(countdownLabel)
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat) {
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize
        label.fontColor = .white
        label.zPosition = 201
    }

    private func setupInput() {
        hud.addChild(input.joystick)
        hud.addChild(input.accelerateButton)
        hud.addChild(input.driftButton)
        hud.addChild(input.itemButton)
        input.layout(in: size)
    }

    private func startCountdown() {
        countdownLabel.alpha = 1
        countdownLabel.text = "\(countdown)"
        countdownLabel.setScale(1.4)

        let tick = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.countdown -= 1
                if self.countdown > 0 {
                    self.countdownLabel.text = "\(self.countdown)"
                    self.countdownLabel.run(SKAction.sequence([
                        SKAction.scale(to: 1.6, duration: 0.1),
                        SKAction.scale(to: 1.0, duration: 0.25)
                    ]))
                } else if self.countdown == 0 {
                    self.countdownLabel.text = "GO!"
                    self.countdownLabel.fontColor = SKColor(red: 0.3, green: 0.95, blue: 0.45, alpha: 1)
                } else {
                    self.countdownLabel.run(SKAction.fadeOut(withDuration: 0.2))
                    self.raceStarted = true
                }
            },
            SKAction.wait(forDuration: 1.0)
        ])

        run(SKAction.repeat(tick, count: 4))
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = 1.0 / 60.0

        if raceStarted {
            raceTime += delta
            updatePlayerInput()
            for controller in aiControllers {
                if let item = controller.update(delta: delta, racers: racers) {
                    deployItem(item, from: controller.racer)
                }
            }
        }

        for racer in racers {
            racer.updateMovement(delta: delta)
            keepOnTrack(racer)
            updateCheckpoint(for: racer)
        }

        updatePositions()
        updateHUD()
        cameraNode.position = player.position
    }

    private func updatePlayerInput() {
        guard !player.finished else { return }

        let usedItem = player.applyInput(
            steer: input.steer,
            accelerate: input.accelerate,
            brake: input.brake,
            drift: input.drift,
            useItem: input.consumeItemTap()
        )

        if let item = usedItem {
            deployItem(item, from: player)
        }
    }

    private func keepOnTrack(_ racer: CartRacer) {
        if !TrackLayout.isOnTrack(racer.position) {
            racer.position = TrackLayout.nearestTrackPoint(from: racer.position)
            racer.speed *= 0.6
        }
    }

    private func updateCheckpoint(for racer: CartRacer) {
        let checkpoints: [CGPoint] = [
            CGPoint(x: 0, y: -360),
            CGPoint(x: 560, y: 0),
            CGPoint(x: 0, y: 360),
            CGPoint(x: -560, y: 0)
        ]

        let target = checkpoints[racer.checkpointIndex % checkpoints.count]
        let distance = hypot(racer.position.x - target.x, racer.position.y - target.y)

        if distance < 90 {
            racer.checkpointIndex += 1
            if racer.checkpointIndex % checkpoints.count == 0 {
                racer.lap += 1
                if racer.lap >= RaceState.totalLaps && !racer.finished {
                    finishRacer(racer)
                }
            }
        }
    }

    private func finishRacer(_ racer: CartRacer) {
        racer.finished = true
        racer.finishTime = raceTime
        racer.speed = 0
        finishOrder.append(racer)

        if racer.isPlayer || finishOrder.count == racers.count {
            presentResults()
        }
    }

    private func updatePositions() {
        let sorted = racers.sorted {
            if $0.lap != $1.lap { return $0.lap > $1.lap }
            if $0.checkpointIndex != $1.checkpointIndex { return $0.checkpointIndex > $1.checkpointIndex }
            return distanceToNextCheckpoint($0) < distanceToNextCheckpoint($1)
        }

        for (index, racer) in sorted.enumerated() {
            racer.racePosition = index + 1
        }
    }

    private func distanceToNextCheckpoint(_ racer: CartRacer) -> CGFloat {
        let checkpoints: [CGPoint] = [
            CGPoint(x: 0, y: -360),
            CGPoint(x: 560, y: 0),
            CGPoint(x: 0, y: 360),
            CGPoint(x: -560, y: 0)
        ]
        let target = checkpoints[racer.checkpointIndex % checkpoints.count]
        return hypot(racer.position.x - target.x, racer.position.y - target.y)
    }

    private func updateHUD() {
        lapLabel.text = "Lap \(min(player.lap + 1, RaceState.totalLaps))/\(RaceState.totalLaps)"
        positionLabel.text = ordinal(player.racePosition)
        timerLabel.text = formatTime(raceTime)
        if let item = player.heldPowerUp {
            itemLabel.text = "Item: \(item.icon) \(item.displayName)"
        } else {
            itemLabel.text = "Item: None"
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let masks = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if masks.contains(PhysicsCategory.itemBox) {
            handleItemBoxContact(contact)
        }

        if masks.contains(PhysicsCategory.hazard) {
            handleHazardContact(contact)
        }
    }

    private func handleItemBoxContact(_ contact: SKPhysicsContact) {
        let boxBody = contact.bodyA.categoryBitMask == PhysicsCategory.itemBox ? contact.bodyA : contact.bodyB
        let racerBody = contact.bodyA.categoryBitMask == PhysicsCategory.racer ? contact.bodyA : contact.bodyB
        guard let boxNode = boxBody.node, let racerNode = racerBody.node as? CartRacer else { return }

        racerNode.collectPowerUp(PowerUpType.random())
        boxNode.removeFromParent()
        itemBoxes.removeAll { $0 == boxNode }
        respawnItemBox(after: 4.0)
    }

    private func respawnItemBox(after delay: TimeInterval) {
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in
                guard let self else { return }
                let point = TrackLayout.itemBoxPositions.randomElement() ?? .zero
                let box = SKShapeNode(rectOf: CGSize(width: 36, height: 36), cornerRadius: 6)
                box.fillColor = SKColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 0.85)
                box.strokeColor = .white
                box.lineWidth = 2
                box.position = point
                box.zPosition = 1
                box.name = "itemBox"

                let sparkle = SKLabelNode(text: "?")
                sparkle.fontName = "AvenirNext-Heavy"
                sparkle.fontSize = 20
                sparkle.fontColor = .white
                sparkle.verticalAlignmentMode = .center
                box.addChild(sparkle)

                let body = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 36))
                body.isDynamic = false
                body.categoryBitMask = PhysicsCategory.itemBox
                body.contactTestBitMask = PhysicsCategory.racer
                box.physicsBody = body

                self.addChild(box)
                self.itemBoxes.append(box)
            }
        ]))
    }

    private func handleHazardContact(_ contact: SKPhysicsContact) {
        let hazardBody = contact.bodyA.categoryBitMask == PhysicsCategory.hazard ? contact.bodyA : contact.bodyB
        let racerBody = contact.bodyA.categoryBitMask == PhysicsCategory.racer ? contact.bodyA : contact.bodyB
        guard let hazard = hazardBody.node, let racer = racerBody.node as? CartRacer else { return }

        if hazard.name == "banana" {
            racer.applySpin()
        } else if hazard.name == "milk" {
            racer.applySlip()
        } else if hazard.name == "cans" {
            racer.applySpin(duration: 0.6)
            racer.speed *= 0.7
        }

        hazard.removeFromParent()
        hazards.removeAll { $0 == hazard }
    }

    private func deployItem(_ item: PowerUpType, from racer: CartRacer) {
        switch item {
        case .bananaPeel:
            spawnBanana(at: CGPoint(x: racer.position.x - cos(racer.zRotation) * 40, y: racer.position.y - sin(racer.zRotation) * 40))
        case .couponBoost:
            racer.applyBoost()
            showFloatingText("BOOST!", at: racer.position, color: .green)
        case .spilledMilk:
            spawnMilk(at: CGPoint(x: racer.position.x - cos(racer.zRotation) * 50, y: racer.position.y - sin(racer.zRotation) * 50))
        case .canPyramid:
            spawnCans(at: CGPoint(x: racer.position.x - cos(racer.zRotation) * 50, y: racer.position.y - sin(racer.zRotation) * 50))
            for other in racers where other !== racer {
                let distance = hypot(other.position.x - racer.position.x, other.position.y - racer.position.y)
                if distance < 120 {
                    other.applySpin(duration: 0.8)
                }
            }
        }
    }

    private func spawnBanana(at position: CGPoint) {
        let banana = SKLabelNode(text: "🍌")
        banana.fontSize = 28
        banana.position = position
        banana.zPosition = 5
        banana.name = "banana"

        let body = SKPhysicsBody(circleOfRadius: 16)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.racer
        banana.physicsBody = body

        addChild(banana)
        hazards.append(banana)
    }

    private func spawnMilk(at position: CGPoint) {
        let milk = SKShapeNode(circleOfRadius: 34)
        milk.fillColor = SKColor(white: 1, alpha: 0.55)
        milk.strokeColor = SKColor(white: 1, alpha: 0.8)
        milk.lineWidth = 2
        milk.position = position
        milk.zPosition = 3
        milk.name = "milk"

        let body = SKPhysicsBody(circleOfRadius: 34)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.racer
        milk.physicsBody = body

        addChild(milk)
        hazards.append(milk)
    }

    private func spawnCans(at position: CGPoint) {
        let cans = SKLabelNode(text: "🥫🥫🥫")
        cans.fontSize = 22
        cans.position = position
        cans.zPosition = 5
        cans.name = "cans"

        let body = SKPhysicsBody(circleOfRadius: 24)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.racer
        cans.physicsBody = body

        addChild(cans)
        hazards.append(cans)
    }

    private func showFloatingText(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 22
        label.fontColor = color
        label.position = position
        label.zPosition = 50
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 0.8),
                SKAction.fadeOut(withDuration: 0.8)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func presentResults() {
        guard let view else { return }
        let results = ResultsScene(size: size)
        results.scaleMode = .resizeFill
        results.finishOrder = finishOrder
        results.raceTime = raceTime
        view.presentScene(results, transition: SKTransition.fade(withDuration: 0.8))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.handleTouches(touches, in: self, phase: .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.handleTouches(touches, in: self, phase: .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.handleTouches(touches, in: self, phase: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.handleTouches(touches, in: self, phase: .cancelled)
    }
}
