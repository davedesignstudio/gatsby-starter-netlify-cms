import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private let track: TrackDefinition
    private let multiplayer: Bool
    private var racers: [CartRacer] = []
    private var aiControllers: [AIController] = []
    private var humanPlayers: [CartRacer] = []
    private var input: InputManager
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

    init(size: CGSize, track: TrackDefinition = GameSettings.shared.selectedTrack, multiplayer: Bool = GameSettings.shared.playerMode == .localMultiplayer) {
        self.track = track
        self.multiplayer = multiplayer
        self.input = InputManager(multiplayer: multiplayer)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.track = .grocery
        self.multiplayer = false
        self.input = InputManager(multiplayer: false)
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = track.isDarkStore
            ? SKColor(red: 0.06, green: 0.07, blue: 0.1, alpha: 1)
            : SKColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        buildTrack()
        buildRacers()
        setupCamera()
        setupHUD()
        setupInput()
        startCountdown()
        SoundManager.shared.startRaceMusic()

        if GameSettings.shared.playerMode == .onlineMultiplayer {
            setupNetworkObservers()
        }
    }

    deinit {
        SoundManager.shared.stopRaceMusic()
    }

    private func buildTrack() {
        let floor = SKShapeNode(rect: track.outerRect, cornerRadius: 12)
        floor.fillColor = track.floorColor
        floor.strokeColor = track.floorColor.darker(by: 0.2)
        floor.lineWidth = 6
        floor.zPosition = -10
        addChild(floor)

        let island = SKShapeNode(rect: track.innerRect, cornerRadius: 10)
        island.fillColor = track.islandColor
        island.strokeColor = track.islandColor.darker(by: 0.15)
        island.lineWidth = 4
        island.zPosition = -9
        addChild(island)

        addShelf(at: track.innerRect, label: track.islandLabel)
        for (index, shelf) in track.shelfObstacles.enumerated() {
            let label = track.shelfLabels[index % track.shelfLabels.count]
            addShelfBlock(shelf, label: label)
        }

        addWalls()
        addDecor()
        if track.isDarkStore { addDarkStoreOverlay() }
        addItemBoxes()
        addStartLine()
    }

    private func addShelf(at rect: CGRect, label: String) {
        let shelf = SKShapeNode(rect: rect, cornerRadius: 8)
        shelf.fillColor = track.shelfColor
        shelf.strokeColor = track.shelfColor.darker(by: 0.15)
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
        let outer = track.outerRect
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

        let inner = track.innerRect
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
        for index in 0..<24 {
            let tile = SKShapeNode(rectOf: CGSize(width: 48, height: 48), cornerRadius: 4)
            tile.fillColor = track.decorColors[index % track.decorColors.count].withAlphaComponent(0.18)
            tile.strokeColor = .clear
            let angle = CGFloat(index) / 24 * .pi * 2
            let radius: CGFloat = 420
            tile.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            tile.zPosition = -8
            addChild(tile)
        }
    }

    private func addDarkStoreOverlay() {
        let glow = SKShapeNode(rect: track.outerRect, cornerRadius: 12)
        glow.fillColor = SKColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 0.35)
        glow.strokeColor = .clear
        glow.zPosition = -6
        addChild(glow)

        for index in 0..<8 {
            let light = SKShapeNode(circleOfRadius: 60)
            light.fillColor = SKColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.06)
            light.strokeColor = .clear
            let point = track.itemBoxPositions[index % track.itemBoxPositions.count]
            light.position = point
            light.zPosition = -5
            addChild(light)
        }
    }

    private func addItemBoxes() {
        for point in track.itemBoxPositions {
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
        line.position = track.startPosition
        line.zRotation = .pi / 2
        line.zPosition = 0
        addChild(line)

        for offset in stride(from: -50, through: 50, by: 20) {
            let checker = SKShapeNode(rectOf: CGSize(width: 10, height: 8))
            checker.fillColor = offset % 40 == 0 ? .black : .white
            checker.strokeColor = .clear
            checker.position = CGPoint(x: offset, y: 0)
            line.addChild(checker)
        }
    }

    private var remoteRacers: [String: CartRacer] = [:]

    private func setupNetworkObservers() {
        NotificationCenter.default.addObserver(forName: .cartKartNetworkStateReceived, object: nil, queue: .main) { [weak self] note in
            guard let self, let data = note.userInfo?["data"] as? Data,
                  let state = try? JSONDecoder().decode(NetworkRacerState.self, from: data) else { return }
            self.applyRemoteState(state)
        }
    }

    private func applyRemoteState(_ state: NetworkRacerState) {
        let racer: CartRacer
        if let existing = remoteRacers[state.name] {
            racer = existing
        } else if let aiRacer = racers.first(where: { !$0.isPlayer && $0.racerName == state.name }) {
            racer = aiRacer
            remoteRacers[state.name] = aiRacer
        } else {
            return
        }
        racer.position = CGPoint(x: state.x, y: state.y)
        racer.zRotation = state.rotation
        racer.driveSpeed = state.speed
        racer.lap = state.lap
        racer.checkpointIndex = state.checkpoint
    }

    private func broadcastLocalState() {
        guard GameSettings.shared.playerMode == .onlineMultiplayer,
              let player = humanPlayers.first else { return }
        let state = NetworkRacerState(
            name: player.racerName,
            x: player.position.x,
            y: player.position.y,
            rotation: player.zRotation,
            speed: player.driveSpeed,
            lap: player.lap,
            checkpoint: player.checkpointIndex
        )
        GameCenterManager.shared.sendRacerState(state)
    }

    private func buildRacers() {
        let settings = GameSettings.shared
        let aiCharacters: [CharacterDefinition] = [.speedySal, .driftKing, .tankTanya, .couponCarla]
        let humanCount = multiplayer ? 2 : 1

        for index in 0..<4 {
            let isHuman = index < humanCount
            let racer: CartRacer
            if isHuman {
                let character = index == 0 ? settings.selectedCharacter : settings.selectedCharacterP2
                racer = CartRacer(character: character, isPlayer: true, playerSlot: index)
            } else {
                let aiChar = aiCharacters[(index - humanCount) % aiCharacters.count]
                racer = CartRacer(character: aiChar, isPlayer: false, playerSlot: 0)
            }

            let grid = track.startGrid[index]
            racer.position = grid.0
            racer.zRotation = grid.1
            racer.zPosition = 10
            addChild(racer)
            racers.append(racer)

            if isHuman {
                humanPlayers.append(racer)
            } else {
                let skill = CGFloat(0.55 + Double(index) * 0.12)
                aiControllers.append(AIController(racer: racer, track: track, skill: skill))
            }
        }
    }

    private func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)
        if let first = humanPlayers.first {
            cameraNode.position = first.position
        }
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
        input.addToHUD(hud)
        input.layout(in: size)
    }

    private func startCountdown() {
        countdownLabel.alpha = 1
        countdownLabel.text = "\(countdown)"
        countdownLabel.setScale(1.4)
        SoundManager.shared.play(.countdown)

        let tick = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.countdown -= 1
                if self.countdown > 0 {
                    self.countdownLabel.text = "\(self.countdown)"
                    SoundManager.shared.play(.countdown)
                    self.countdownLabel.run(SKAction.sequence([
                        SKAction.scale(to: 1.6, duration: 0.1),
                        SKAction.scale(to: 1.0, duration: 0.25)
                    ]))
                } else if self.countdown == 0 {
                    self.countdownLabel.text = "GO!"
                    self.countdownLabel.fontColor = SKColor(red: 0.3, green: 0.95, blue: 0.45, alpha: 1)
                    SoundManager.shared.play(.go)
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
        updateCamera()
        broadcastLocalState()
    }

    private func updateCamera() {
        if humanPlayers.count > 1 {
            let x = humanPlayers.map(\.position.x).reduce(0, +) / CGFloat(humanPlayers.count)
            let y = humanPlayers.map(\.position.y).reduce(0, +) / CGFloat(humanPlayers.count)
            cameraNode.position = CGPoint(x: x, y: y)
        } else if let player = humanPlayers.first {
            cameraNode.position = player.position
        }
    }

    private func updatePlayerInput() {
        for player in humanPlayers where !player.finished {
            let slot = player.playerSlot
            let usedItem = player.applyInput(
                steer: input.steer(for: slot),
                accelerate: input.accelerate(for: slot),
                brake: input.brake(for: slot),
                drift: input.drift(for: slot),
                useItem: input.consumeItemTap(for: slot)
            )

            if let item = usedItem {
                deployItem(item, from: player)
            }
        }
    }

    private func keepOnTrack(_ racer: CartRacer) {
        if !track.isOnTrack(racer.position) {
            racer.position = track.nearestTrackPoint(from: racer.position)
            racer.driveSpeed *= 0.6
            if racer.isPlayer {
                SoundManager.shared.play(.collision)
            }
        }
    }

    private func updateCheckpoint(for racer: CartRacer) {
        let target = track.checkpoints[racer.checkpointIndex % track.checkpoints.count]
        let distance = hypot(racer.position.x - target.x, racer.position.y - target.y)

        if distance < 90 {
            let previousLap = racer.lap
            racer.checkpointIndex += 1
            if racer.checkpointIndex % track.checkpoints.count == 0 {
                racer.lap += 1
                if racer.lap > previousLap && racer.lap < RaceState.totalLaps && racer.isPlayer {
                    SoundManager.shared.play(.lapComplete)
                }
                if racer.lap >= RaceState.totalLaps && !racer.finished {
                    finishRacer(racer)
                }
            }
        }
    }

    private func finishRacer(_ racer: CartRacer) {
        racer.finished = true
        racer.finishTime = raceTime
        racer.driveSpeed = 0
        finishOrder.append(racer)

        if racer.isPlayer {
            SoundManager.shared.play(.raceFinish)
        }

        let humansDone = humanPlayers.allSatisfy(\.finished)
        if humansDone || finishOrder.count == racers.count {
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
        let target = track.checkpoints[racer.checkpointIndex % track.checkpoints.count]
        return hypot(racer.position.x - target.x, racer.position.y - target.y)
    }

    private func updateHUD() {
        guard let player = humanPlayers.first else { return }
        lapLabel.text = "Lap \(min(player.lap + 1, RaceState.totalLaps))/\(RaceState.totalLaps)"
        if multiplayer, humanPlayers.count > 1 {
            let p2 = humanPlayers[1]
            positionLabel.text = "P1 \(ordinal(player.racePosition)) • P2 \(ordinal(p2.racePosition))"
        } else {
            positionLabel.text = ordinal(player.racePosition)
        }
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

        if (masks & PhysicsCategory.itemBox) != 0 {
            handleItemBoxContact(contact)
        }

        if (masks & PhysicsCategory.hazard) != 0 {
            handleHazardContact(contact)
        }
    }

    private func handleItemBoxContact(_ contact: SKPhysicsContact) {
        let boxBody = contact.bodyA.categoryBitMask == PhysicsCategory.itemBox ? contact.bodyA : contact.bodyB
        let racerBody = contact.bodyA.categoryBitMask == PhysicsCategory.racer ? contact.bodyA : contact.bodyB
        guard let boxNode = boxBody.node, let racerNode = racerBody.node as? CartRacer else { return }

        racerNode.collectPowerUp(PowerUpType.random())
        SoundManager.shared.play(.itemPickup)
        boxNode.removeFromParent()
        itemBoxes.removeAll { $0 == boxNode }
        respawnItemBox(after: 4.0)
    }

    private func respawnItemBox(after delay: TimeInterval) {
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in
                guard let self else { return }
                let point = self.track.itemBoxPositions.randomElement() ?? .zero
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
            SoundManager.shared.play(.spin)
        } else if hazard.name == "milk" {
            racer.applySlip()
            SoundManager.shared.play(.spin)
        } else if hazard.name == "cans" {
            racer.applySpin(duration: 0.6)
            racer.driveSpeed *= 0.7
            SoundManager.shared.play(.collision)
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
            SoundManager.shared.play(.boost)
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
        SoundManager.shared.stopRaceMusic()

        if let session = GameSettings.shared.cupSession {
            session.recordRace(finishOrder: finishOrder)
            if session.isComplete {
                let cupResults = CupResultsScene(size: size, session: session)
                cupResults.scaleMode = .resizeFill
                view.presentScene(cupResults, transition: SKTransition.fade(withDuration: 0.8))
                return
            }
            let interim = ResultsScene(size: size, track: track, multiplayer: multiplayer, cupInterim: session)
            interim.scaleMode = .resizeFill
            interim.finishOrder = finishOrder
            interim.raceTime = raceTime
            view.presentScene(interim, transition: SKTransition.fade(withDuration: 0.8))
            return
        }

        let results = ResultsScene(size: size, track: track, multiplayer: multiplayer)
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
