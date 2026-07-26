import SpriteKit

final class RaceScene: SKScene {
    private var playerCart: ShoppingCart!
    private var aiCarts: [ShoppingCart] = []
    private var aiControllers: [AIController] = []
    private var raceManager: RaceManager!
    private var powerUpManager: PowerUpManager!
    private var waypoints: [TrackWaypoint] = []

    private var hudNode: SKNode!
    private var lapLabel: SKLabelNode!
    private var positionLabel: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var powerUpLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!

    private var steerInput: CGFloat = 0
    private var isAccelerating = false
    private var isBraking = false
    private var isDrifting = false
    private var raceStarted = false
    private var lastUpdateTime: TimeInterval = 0

    private var leftTouch: UITouch?
    private var rightTouch: UITouch?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.17, blue: 0.2, alpha: 1)
        waypoints = TrackBuilder.waypoints(for: size)
        _ = TrackBuilder.build(in: self, size: size)

        raceManager = RaceManager(waypoints: waypoints)
        setupRacers()
        powerUpManager = PowerUpManager(scene: self, waypoints: waypoints)
        setupHUD()
        setupTouchControls()
        startCountdown()
    }

    private func setupRacers() {
        let playerStart = TrackBuilder.startPosition(for: size, lane: 1)
        playerCart = ShoppingCart(profile: .player, isPlayer: true)
        playerCart.reset(at: playerStart.position, heading: playerStart.angle)
        playerCart.zPosition = 10
        addChild(playerCart)
        raceManager.register(playerCart)

        for (index, profile) in RacerProfile.opponents.enumerated() {
            let start = TrackBuilder.startPosition(for: size, lane: index + 2)
            let cart = ShoppingCart(profile: profile, isPlayer: false)
            cart.reset(at: start.position, heading: start.angle)
            cart.zPosition = 10
            addChild(cart)
            aiCarts.append(cart)
            raceManager.register(cart)

            let skill = CGFloat.random(in: 0.7...0.95)
            let controller = AIController(cart: cart, waypoints: waypoints, skill: skill)
            aiControllers.append(controller)
        }
    }

    private func setupHUD() {
        hudNode = SKNode()
        hudNode.zPosition = 100

        let hudBg = SKShapeNode(rectOf: CGSize(width: size.width - 20, height: 70), cornerRadius: 10)
        hudBg.position = CGPoint(x: size.width / 2, y: size.height - 50)
        hudBg.fillColor = SKColor(white: 0, alpha: 0.55)
        hudBg.strokeColor = SKColor(white: 1, alpha: 0.2)
        hudBg.lineWidth = 1
        hudNode.addChild(hudBg)

        lapLabel = makeHUDLabel(text: "LAP 1/3", position: CGPoint(x: 70, y: size.height - 42))
        positionLabel = makeHUDLabel(text: "1st", position: CGPoint(x: size.width / 2, y: size.height - 42))
        speedLabel = makeHUDLabel(text: "0 MPH", position: CGPoint(x: size.width - 80, y: size.height - 42))

        powerUpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        powerUpLabel.text = "NO ITEM"
        powerUpLabel.fontSize = 13
        powerUpLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        powerUpLabel.position = CGPoint(x: size.width / 2, y: size.height - 68)
        hudNode.addChild(powerUpLabel)

        countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        countdownLabel.fontSize = 72
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        countdownLabel.zPosition = 200
        hudNode.addChild(countdownLabel)

        addChild(hudNode)
    }

    private func makeHUDLabel(text: String, position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.position = position
        hudNode.addChild(label)
        return label
    }

    private func setupTouchControls() {
        let controlHeight: CGFloat = 140
        let controlY = controlHeight / 2 + 10

        let leftZone = SKShapeNode(rectOf: CGSize(width: size.width / 2 - 10, height: controlHeight), cornerRadius: 12)
        leftZone.position = CGPoint(x: size.width / 4, y: controlY)
        leftZone.fillColor = SKColor(white: 1, alpha: 0.08)
        leftZone.strokeColor = SKColor(white: 1, alpha: 0.15)
        leftZone.lineWidth = 1
        leftZone.name = "leftZone"
        leftZone.zPosition = 50
        addChild(leftZone)

        let leftLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        leftLabel.text = "STEER"
        leftLabel.fontSize = 12
        leftLabel.fontColor = SKColor(white: 1, alpha: 0.4)
        leftLabel.position = CGPoint(x: 0, y: -controlHeight / 2 + 16)
        leftZone.addChild(leftLabel)

        let rightZone = SKShapeNode(rectOf: CGSize(width: size.width / 2 - 10, height: controlHeight), cornerRadius: 12)
        rightZone.position = CGPoint(x: size.width * 0.75, y: controlY)
        rightZone.fillColor = SKColor(white: 1, alpha: 0.08)
        rightZone.strokeColor = SKColor(white: 1, alpha: 0.15)
        rightZone.lineWidth = 1
        rightZone.name = "rightZone"
        rightZone.zPosition = 50
        addChild(rightZone)

        let rightLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        rightLabel.text = "GAS / BRAKE"
        rightLabel.fontSize = 12
        rightLabel.fontColor = SKColor(white: 1, alpha: 0.4)
        rightLabel.position = CGPoint(x: 0, y: -controlHeight / 2 + 16)
        rightZone.addChild(rightLabel)

        let itemButton = SKShapeNode(rectOf: CGSize(width: 120, height: 36), cornerRadius: 8)
        itemButton.position = CGPoint(x: size.width / 2, y: controlY + 50)
        itemButton.fillColor = SKColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 0.8)
        itemButton.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1)
        itemButton.lineWidth = 2
        itemButton.name = "itemButton"
        itemButton.zPosition = 55
        addChild(itemButton)

        let itemLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        itemLabel.text = "USE ITEM"
        itemLabel.fontSize = 13
        itemLabel.fontColor = .white
        itemLabel.verticalAlignmentMode = .center
        itemLabel.name = "itemButton"
        itemButton.addChild(itemLabel)
    }

    private func startCountdown() {
        raceStarted = false
        let sequence: [String] = ["3", "2", "1", "GO!"]
        var actions: [SKAction] = []

        for (i, text) in sequence.enumerated() {
            actions.append(SKAction.run { [weak self] in
                self?.countdownLabel.text = text
                self?.countdownLabel.setScale(1.8)
            })
            actions.append(SKAction.scale(to: 1.0, duration: 0.35))
            actions.append(SKAction.wait(forDuration: i == sequence.count - 1 ? 0.5 : 0.7))
        }

        actions.append(SKAction.run { [weak self] in
            self?.countdownLabel.text = ""
            self?.raceStarted = true
        })

        countdownLabel.run(SKAction.sequence(actions))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let nodes = nodes(at: location)

            if nodes.contains(where: { $0.name == "itemButton" }) {
                deployPlayerPowerUp()
                continue
            }

            if location.x < size.width / 2 {
                leftTouch = touch
            } else {
                rightTouch = touch
                isAccelerating = location.y > 100
                isBraking = location.y <= 100
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == leftTouch {
                updateSteer(from: touch)
            }
            if touch == rightTouch {
                let location = touch.location(in: self)
                isAccelerating = location.y > 100
                isBraking = location.y <= 100
                isDrifting = location.x > size.width * 0.85
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == leftTouch {
                leftTouch = nil
                steerInput = 0
            }
            if touch == rightTouch {
                rightTouch = nil
                isAccelerating = false
                isBraking = false
                isDrifting = false
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateSteer(from touch: UITouch) {
        let location = touch.location(in: self)
        let centerX = size.width / 4
        let delta = (location.x - centerX) / (size.width / 4)
        steerInput = max(-1, min(1, delta))
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard raceStarted else { return }

        playerCart.applyInput(
            steer: steerInput,
            accelerate: isAccelerating,
            brake: isBraking,
            drift: isDrifting
        )

        if let powerUp = powerUpManager.checkCollisions(for: playerCart) {
            playerCart.collectPowerUp(powerUp)
        }

        for controller in aiControllers {
            controller.update(delta: delta)
        }

        for cart in aiCarts {
            cart.updateTimers(delta: delta)
            powerUpManager.checkHazardCollisions(for: cart)
        }

        playerCart.updateTimers(delta: delta)
        raceManager.checkPlayerWaypoint(playerCart)
        raceManager.updatePositions()
        powerUpManager.checkHazardCollisions(for: playerCart)

        clampCart(playerCart)
        for cart in aiCarts { clampCart(cart) }

        updateHUD()

        if let winner = raceManager.isRaceFinished() {
            endRace(winner: winner)
        }
    }

    private func clampCart(_ cart: ShoppingCart) {
        let margin: CGFloat = 30
        cart.position.x = max(margin, min(size.width - margin, cart.position.x))
        cart.position.y = max(margin, min(size.height - 130, cart.position.y))
    }

    private func updateHUD() {
        lapLabel.text = "LAP \(min(playerCart.lap + 1, RaceManager.totalLaps))/\(RaceManager.totalLaps)"
        let ordinal = ordinalString(playerCart.racePosition)
        positionLabel.text = ordinal
        let mph = Int(playerCart.speed * 0.45)
        speedLabel.text = "\(mph) MPH"

        if let powerUp = playerCart.heldPowerUp {
            powerUpLabel.text = powerUp.displayName
            powerUpLabel.fontColor = powerUp.color
        } else {
            powerUpLabel.text = "NO ITEM"
            powerUpLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        }
    }

    private func ordinalString(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private func endRace(winner: ShoppingCart) {
        raceStarted = false
        isPaused = true

        let gameOver = GameOverScene(
            size: size,
            winner: winner,
            standings: raceManager.standings(),
            playerWon: winner.isPlayer
        )
        gameOver.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 1.0)
        view?.presentScene(gameOver, transition: transition)
    }
}

extension RaceScene {
    func deployPlayerPowerUp() {
        guard raceStarted, let type = playerCart.consumePowerUp() else { return }
        let deployPos = CGPoint(
            x: playerCart.position.x - sin(playerCart.heading) * 40,
            y: playerCart.position.y - cos(playerCart.heading) * 40
        )
        powerUpManager.deployHazard(type: type, at: deployPos, from: playerCart)
    }
}
