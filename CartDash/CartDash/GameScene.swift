import SpriteKit

private enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let pickup: UInt32 = 1 << 2
    static let hazard: UInt32 = 1 << 3
}

private extension SKColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: alpha
        )
    }
}

private extension CGVector {
    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }
}

private final class CartNode: SKShapeNode {
    let racerName: String
    var boostUntil: TimeInterval = 0
    var slowUntil: TimeInterval = 0

    init(color: SKColor, racerName: String) {
        self.racerName = racerName
        super.init()

        path = CGPath(
            roundedRect: CGRect(x: -25, y: -37, width: 50, height: 74),
            cornerWidth: 11,
            cornerHeight: 11,
            transform: nil
        )
        fillColor = color
        strokeColor = .white.withAlphaComponent(0.85)
        lineWidth = 3
        name = racerName
        zPosition = 20

        let basket = SKShapeNode(
            rect: CGRect(x: -18, y: -10, width: 36, height: 36),
            cornerRadius: 5
        )
        basket.fillColor = SKColor(rgb: 0x263645, alpha: 0.72)
        basket.strokeColor = .white.withAlphaComponent(0.65)
        basket.lineWidth = 2
        basket.zPosition = 1
        addChild(basket)

        let groceries: [(CGPoint, SKColor)] = [
            (CGPoint(x: -9, y: 1), SKColor(rgb: 0xffc857)),
            (CGPoint(x: 8, y: 7), SKColor(rgb: 0xef476f)),
            (CGPoint(x: 2, y: -7), SKColor(rgb: 0x7bd389))
        ]
        for (position, groceryColor) in groceries {
            let item = SKShapeNode(circleOfRadius: 5)
            item.position = position
            item.fillColor = groceryColor
            item.strokeColor = .clear
            item.zPosition = 2
            basket.addChild(item)
        }

        for x in [CGFloat(-24), CGFloat(24)] {
            for y in [CGFloat(-24), CGFloat(24)] {
                let wheel = SKShapeNode(circleOfRadius: 5)
                wheel.position = CGPoint(x: x, y: y)
                wheel.fillColor = SKColor(rgb: 0x14212b)
                wheel.strokeColor = .clear
                wheel.zPosition = -1
                addChild(wheel)
            }
        }

        physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 46, height: 68))
        physicsBody?.mass = 0.65
        physicsBody?.linearDamping = 1.1
        physicsBody?.angularDamping = 4
        physicsBody?.restitution = 0.15
        physicsBody?.friction = 0.35
        physicsBody?.categoryBitMask = PhysicsCategory.cart
        physicsBody?.collisionBitMask = PhysicsCategory.cart | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.pickup | PhysicsCategory.hazard
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum RaceState {
        case countdown
        case racing
        case finished
    }

    private struct AIRacer {
        let cart: CartNode
        var waypoint = 0
        var completedLaps = 0
        var hasFinished = false
        let topSpeed: CGFloat
    }

    private let worldSize = CGSize(width: 2500, height: 1900)
    private let totalLaps = 3
    private let checkpointRadius = 180.0
    private let waypoints = [
        CGPoint(x: 900, y: -730),
        CGPoint(x: 1030, y: 0),
        CGPoint(x: 900, y: 730),
        CGPoint(x: 0, y: 790),
        CGPoint(x: -900, y: 730),
        CGPoint(x: -1030, y: 0),
        CGPoint(x: -900, y: -730),
        CGPoint(x: 0, y: -730)
    ]

    private let player = CartNode(color: SKColor(rgb: 0xff6b35), racerName: "You")
    private var aiRacers: [AIRacer] = []
    private var lapProgress = LapProgress()
    private var raceState = RaceState.countdown
    private var countdownStart: TimeInterval?
    private var previousUpdateTime: TimeInterval?
    private var currentTime: TimeInterval = 0
    private var finishOrder: [String] = []

    private let cameraNode = SKCameraNode()
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let speedLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let positionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let checkpointArrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let leftButton = SKShapeNode(circleOfRadius: 48)
    private let rightButton = SKShapeNode(circleOfRadius: 48)
    private let driftButton = SKShapeNode(circleOfRadius: 60)

    private var steeringTouches: [ObjectIdentifier: CGFloat] = [:]
    private var driftTouches: Set<ObjectIdentifier> = []
    private var steering: CGFloat = 0
    private var wasDrifting = false
    private var driftCharge: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(rgb: 0x102a2e)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        buildStore()
        spawnRacers()
        buildHUD()

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.position = player.position
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func buildStore() {
        let floor = SKShapeNode(
            rectOf: worldSize,
            cornerRadius: 36
        )
        floor.fillColor = SKColor(rgb: 0xe8e2d4)
        floor.strokeColor = SKColor(rgb: 0x7a8a84)
        floor.lineWidth = 14
        floor.zPosition = -20
        addChild(floor)

        let gridPath = CGMutablePath()
        for x in stride(from: CGFloat(-1200), through: CGFloat(1200), by: 100) {
            gridPath.move(to: CGPoint(x: x, y: -900))
            gridPath.addLine(to: CGPoint(x: x, y: 900))
        }
        for y in stride(from: CGFloat(-900), through: CGFloat(900), by: 100) {
            gridPath.move(to: CGPoint(x: -1200, y: y))
            gridPath.addLine(to: CGPoint(x: 1200, y: y))
        }
        let grid = SKShapeNode(path: gridPath)
        grid.strokeColor = SKColor(rgb: 0xd4cec0)
        grid.lineWidth = 1
        grid.zPosition = -19
        addChild(grid)

        physicsBody = SKPhysicsBody(
            edgeLoopFrom: CGRect(
                x: -worldSize.width / 2,
                y: -worldSize.height / 2,
                width: worldSize.width,
                height: worldSize.height
            )
        )
        physicsBody?.categoryBitMask = PhysicsCategory.wall
        physicsBody?.collisionBitMask = PhysicsCategory.cart

        addShelfIsland()
        addStartLine()
        addDepartmentSigns()
        addPickups()
        addHazards()
    }

    private func addShelfIsland() {
        let island = SKShapeNode(rectOf: CGSize(width: 1480, height: 850), cornerRadius: 24)
        island.fillColor = SKColor(rgb: 0x455a64)
        island.strokeColor = SKColor(rgb: 0x263238)
        island.lineWidth = 12
        island.zPosition = 5
        island.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 1480, height: 850))
        island.physicsBody?.isDynamic = false
        island.physicsBody?.categoryBitMask = PhysicsCategory.wall
        island.physicsBody?.collisionBitMask = PhysicsCategory.cart
        addChild(island)

        let shelfColors = [
            SKColor(rgb: 0xffc857),
            SKColor(rgb: 0x7bd389),
            SKColor(rgb: 0x5dade2),
            SKColor(rgb: 0xef767a)
        ]
        for row in 0..<4 {
            let shelf = SKShapeNode(rectOf: CGSize(width: 1240, height: 115), cornerRadius: 8)
            shelf.position = CGPoint(x: 0, y: CGFloat(row) * 185 - 278)
            shelf.fillColor = SKColor(rgb: 0x35464d)
            shelf.strokeColor = .white.withAlphaComponent(0.25)
            shelf.lineWidth = 3
            island.addChild(shelf)

            for product in 0..<12 {
                let box = SKShapeNode(rectOf: CGSize(width: 60, height: 70), cornerRadius: 5)
                box.position = CGPoint(x: CGFloat(product) * 98 - 539, y: 0)
                box.fillColor = shelfColors[(row + product) % shelfColors.count]
                box.strokeColor = .white.withAlphaComponent(0.55)
                box.lineWidth = 2
                shelf.addChild(box)
            }
        }
    }

    private func addStartLine() {
        for index in 0..<8 {
            let tile = SKShapeNode(rectOf: CGSize(width: 30, height: 65))
            tile.position = CGPoint(x: 0, y: CGFloat(index) * 65 - 907)
            tile.fillColor = index.isMultiple(of: 2) ? .white : SKColor(rgb: 0x1f2933)
            tile.strokeColor = .clear
            tile.zPosition = 2
            addChild(tile)
        }
    }

    private func addDepartmentSigns() {
        let signs: [(String, CGPoint, CGFloat)] = [
            ("FRESH PRODUCE", CGPoint(x: 0, y: 885), 0),
            ("BAKERY", CGPoint(x: 1135, y: 0), -.pi / 2),
            ("PANTRY", CGPoint(x: 0, y: -875), 0),
            ("COMMUNITY MARKET", CGPoint(x: -1135, y: 0), .pi / 2)
        ]
        for (text, position, rotation) in signs {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = text
            label.fontSize = 28
            label.fontColor = SKColor(rgb: 0x24454a)
            label.position = position
            label.zRotation = rotation
            label.zPosition = 1
            addChild(label)
        }
    }

    private func addPickups() {
        let positions = [
            CGPoint(x: 550, y: -730),
            CGPoint(x: 1030, y: 300),
            CGPoint(x: 400, y: 730),
            CGPoint(x: -1030, y: -280)
        ]
        for position in positions {
            let pickup = SKShapeNode(circleOfRadius: 28)
            pickup.position = position
            pickup.fillColor = SKColor(rgb: 0x00d4ff)
            pickup.strokeColor = .white
            pickup.lineWidth = 4
            pickup.glowWidth = 8
            pickup.zPosition = 10
            pickup.name = "boost"

            let bolt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            bolt.text = "⚡"
            bolt.fontSize = 28
            bolt.verticalAlignmentMode = .center
            pickup.addChild(bolt)

            pickup.physicsBody = pickupPhysicsBody()
            pickup.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.8)))
            addChild(pickup)
        }
    }

    private func pickupPhysicsBody() -> SKPhysicsBody {
        let body = SKPhysicsBody(circleOfRadius: 32)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.pickup
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.cart
        return body
    }

    private func addHazards() {
        let positions = [
            CGPoint(x: 1010, y: -350),
            CGPoint(x: -450, y: 745),
            CGPoint(x: -1010, y: 410)
        ]
        for position in positions {
            let spill = SKShapeNode(ellipseOf: CGSize(width: 105, height: 54))
            spill.position = position
            spill.fillColor = SKColor(rgb: 0xb7e4c7, alpha: 0.85)
            spill.strokeColor = SKColor(rgb: 0x40916c)
            spill.lineWidth = 3
            spill.zPosition = 3
            spill.name = "spill"
            spill.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 96, height: 48))
            spill.physicsBody?.isDynamic = false
            spill.physicsBody?.categoryBitMask = PhysicsCategory.hazard
            spill.physicsBody?.collisionBitMask = 0
            spill.physicsBody?.contactTestBitMask = PhysicsCategory.cart
            addChild(spill)
        }
    }

    private func spawnRacers() {
        player.position = CGPoint(x: -180, y: -730)
        player.zRotation = .pi / 2
        addChild(player)

        let rivals: [(String, SKColor, CGPoint, CGFloat)] = [
            ("Maya", SKColor(rgb: 0x9b5de5), CGPoint(x: -290, y: -665), 455),
            ("Jo", SKColor(rgb: 0x00bb8a), CGPoint(x: -390, y: -790), 440),
            ("Rae", SKColor(rgb: 0xf15bb5), CGPoint(x: -500, y: -710), 425)
        ]
        for (name, color, position, speed) in rivals {
            let cart = CartNode(color: color, racerName: name)
            cart.position = position
            cart.zRotation = .pi / 2
            addChild(cart)
            aiRacers.append(AIRacer(cart: cart, topSpeed: speed))
        }
    }

    private func buildHUD() {
        let labels = [lapLabel, speedLabel, positionLabel, countdownLabel, messageLabel, checkpointArrow]
        for label in labels {
            label.zPosition = 1000
            cameraNode.addChild(label)
        }

        lapLabel.fontSize = 25
        lapLabel.horizontalAlignmentMode = .left
        speedLabel.fontSize = 18
        speedLabel.horizontalAlignmentMode = .left
        positionLabel.fontSize = 25
        positionLabel.horizontalAlignmentMode = .right

        countdownLabel.fontSize = 86
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.fontColor = SKColor(rgb: 0xffc857)
        countdownLabel.setScale(1.15)

        messageLabel.fontSize = 24
        messageLabel.fontColor = .white

        checkpointArrow.text = "▲"
        checkpointArrow.fontSize = 32
        checkpointArrow.fontColor = SKColor(rgb: 0x00d4ff)

        configureButton(leftButton, text: "◀", color: SKColor(rgb: 0x294c60))
        configureButton(rightButton, text: "▶", color: SKColor(rgb: 0x294c60))
        configureButton(driftButton, text: "DRIFT", color: SKColor(rgb: 0xf26430))
        cameraNode.addChild(leftButton)
        cameraNode.addChild(rightButton)
        cameraNode.addChild(driftButton)

        layoutHUD()
        updateHUD()
    }

    private func configureButton(_ button: SKShapeNode, text: String, color: SKColor) {
        button.fillColor = color.withAlphaComponent(0.78)
        button.strokeColor = .white.withAlphaComponent(0.72)
        button.lineWidth = 4
        button.zPosition = 900

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = text == "DRIFT" ? 17 : 30
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        button.addChild(label)
    }

    private func layoutHUD() {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        lapLabel.position = CGPoint(x: -halfWidth + 26, y: halfHeight - 45)
        speedLabel.position = CGPoint(x: -halfWidth + 27, y: halfHeight - 74)
        positionLabel.position = CGPoint(x: halfWidth - 26, y: halfHeight - 46)
        countdownLabel.position = .zero
        messageLabel.position = CGPoint(x: 0, y: halfHeight - 52)
        checkpointArrow.position = CGPoint(x: 0, y: halfHeight - 92)
        leftButton.position = CGPoint(x: -halfWidth + 72, y: -halfHeight + 78)
        rightButton.position = CGPoint(x: -halfWidth + 186, y: -halfHeight + 78)
        driftButton.position = CGPoint(x: halfWidth - 88, y: -halfHeight + 85)
    }

    override func update(_ time: TimeInterval) {
        currentTime = time
        guard let previousUpdateTime else {
            self.previousUpdateTime = time
            countdownStart = time
            return
        }
        let deltaTime = min(time - previousUpdateTime, 1.0 / 20.0)
        self.previousUpdateTime = time

        updateCountdown(at: time)
        if raceState == .racing {
            updatePlayer(deltaTime: deltaTime, at: time)
            updateAI(deltaTime: deltaTime)
            updateLapProgress()
        }
        updateCamera(deltaTime: deltaTime)
        updateHUD()
    }

    private func updateCountdown(at time: TimeInterval) {
        guard raceState == .countdown, let countdownStart else { return }
        let elapsed = time - countdownStart

        if elapsed < 3 {
            countdownLabel.text = String(3 - Int(elapsed))
        } else {
            raceState = .racing
            countdownLabel.text = "GO!"
            countdownLabel.run(.sequence([
                .wait(forDuration: 0.55),
                .fadeOut(withDuration: 0.25)
            ]))
            messageLabel.text = "Collect boosts • Hold DRIFT through corners"
            messageLabel.run(.sequence([
                .wait(forDuration: 2.8),
                .fadeOut(withDuration: 0.4)
            ]))
        }
    }

    private func updatePlayer(deltaTime: TimeInterval, at time: TimeInterval) {
        guard let body = player.physicsBody else { return }
        steering = steeringTouches.values.reduce(0, +)
        steering = max(-1, min(1, steering))
        let drifting = !driftTouches.isEmpty

        if drifting && abs(steering) > 0.1 {
            driftCharge += deltaTime
        } else if wasDrifting && !drifting {
            let duration = DriftBoost.duration(for: driftCharge)
            if duration > 0 {
                player.boostUntil = max(player.boostUntil, time + duration)
                showMessage(duration > 1 ? "SUPER BOOST!" : "DRIFT BOOST!")
            }
            driftCharge = 0
        }
        wasDrifting = drifting

        let forward = CGVector(dx: sin(player.zRotation), dy: cos(player.zRotation))
        let boosted = time < player.boostUntil
        let slowed = time < player.slowUntil
        let speedMultiplier: CGFloat = slowed ? 0.55 : 1
        let acceleration: CGFloat = (boosted ? 760 : 520) * speedMultiplier
        let maxSpeed: CGFloat = (boosted ? 710 : 520) * speedMultiplier
        body.applyForce(CGVector(dx: forward.dx * acceleration, dy: forward.dy * acceleration))

        let speed = body.velocity.length
        let steeringScale = min(max(speed / 190, 0.25), 1)
        body.angularVelocity = steering * (drifting ? 2.8 : 2.15) * steeringScale
        body.angularDamping = drifting ? 1.2 : 5

        let forwardSpeed = body.velocity.dx * forward.dx + body.velocity.dy * forward.dy
        let lateral = CGVector(
            dx: body.velocity.dx - forward.dx * forwardSpeed,
            dy: body.velocity.dy - forward.dy * forwardSpeed
        )
        let lateralGrip = CGFloat(pow(drifting ? 0.38 : 0.06, deltaTime))
        body.velocity = CGVector(
            dx: forward.dx * forwardSpeed + lateral.dx * lateralGrip,
            dy: forward.dy * forwardSpeed + lateral.dy * lateralGrip
        )

        if body.velocity.length > maxSpeed {
            let scale = maxSpeed / body.velocity.length
            body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
        }

        player.strokeColor = boosted ? SKColor(rgb: 0x00d4ff) : .white.withAlphaComponent(0.85)
        player.glowWidth = boosted ? 12 : 0
    }

    private func updateAI(deltaTime: TimeInterval) {
        for index in aiRacers.indices {
            let cart = aiRacers[index].cart
            let target = waypoints[aiRacers[index].waypoint]
            let dx = target.x - cart.position.x
            let dy = target.y - cart.position.y
            let distance = hypot(dx, dy)

            if distance < 125 {
                aiRacers[index].waypoint += 1
                if aiRacers[index].waypoint == waypoints.count {
                    aiRacers[index].waypoint = 0
                    if !aiRacers[index].hasFinished {
                        aiRacers[index].completedLaps += 1
                        if aiRacers[index].completedLaps >= totalLaps {
                            aiRacers[index].hasFinished = true
                            finishOrder.append(cart.racerName)
                        }
                    }
                }
            }

            guard distance > 1, let body = cart.physicsBody else { continue }
            let desiredAngle = atan2(dx, dy)
            var angleDifference = desiredAngle - cart.zRotation
            while angleDifference > .pi { angleDifference -= .pi * 2 }
            while angleDifference < -.pi { angleDifference += .pi * 2 }
            cart.zRotation += angleDifference * min(CGFloat(deltaTime) * 4.2, 1)

            var speed = aiRacers[index].topSpeed
            if currentTime < cart.boostUntil {
                speed *= 1.35
            }
            if currentTime < cart.slowUntil {
                speed *= 0.52
            }
            body.velocity = CGVector(dx: dx / distance * speed, dy: dy / distance * speed)
            body.angularVelocity = 0
        }
    }

    private func updateLapProgress() {
        let position = TrackPoint(x: Double(player.position.x), y: Double(player.position.y))
        let checkpoints = waypoints.map { TrackPoint(x: Double($0.x), y: Double($0.y)) }
        let completedLap = lapProgress.visit(
            position: position,
            checkpoints: checkpoints,
            captureRadius: checkpointRadius
        )

        if completedLap && lapProgress.completedLaps < totalLaps {
            showMessage("LAP \(lapProgress.completedLaps + 1)")
        }
        if lapProgress.completedLaps >= totalLaps {
            if !finishOrder.contains(player.racerName) {
                finishOrder.append(player.racerName)
            }
            finishRace()
        }
    }

    private func updateCamera(deltaTime: TimeInterval) {
        let follow = min(CGFloat(deltaTime) * 5.5, 1)
        cameraNode.position = CGPoint(
            x: cameraNode.position.x + (player.position.x - cameraNode.position.x) * follow,
            y: cameraNode.position.y + (player.position.y - cameraNode.position.y) * follow
        )
    }

    private func updateHUD() {
        let shownLap = min(lapProgress.completedLaps + 1, totalLaps)
        lapLabel.text = "LAP \(shownLap) / \(totalLaps)"
        let speed = Int((player.physicsBody?.velocity.length ?? 0) * 0.42)
        speedLabel.text = "\(speed) km/h"

        let playerProgress = raceProgress(
            position: player.position,
            completedLaps: lapProgress.completedLaps,
            nextCheckpoint: lapProgress.nextCheckpoint
        )
        let racersAhead = aiRacers.filter {
            $0.hasFinished || raceProgress(
                position: $0.cart.position,
                completedLaps: $0.completedLaps,
                nextCheckpoint: $0.waypoint
            ) > playerProgress
        }.count
        positionLabel.text = "\(racersAhead + 1) / \(aiRacers.count + 1)"

        if lapProgress.nextCheckpoint < waypoints.count {
            let target = waypoints[lapProgress.nextCheckpoint]
            let angle = atan2(target.y - player.position.y, target.x - player.position.x)
            checkpointArrow.zRotation = angle - .pi / 2
        }
    }

    private func raceProgress(
        position: CGPoint,
        completedLaps: Int,
        nextCheckpoint: Int
    ) -> CGFloat {
        let target = waypoints[nextCheckpoint]
        let previousIndex = (nextCheckpoint - 1 + waypoints.count) % waypoints.count
        let previous = waypoints[previousIndex]
        let segmentLength = max(hypot(target.x - previous.x, target.y - previous.y), 1)
        let distanceRemaining = min(hypot(target.x - position.x, target.y - position.y), segmentLength)
        let segmentProgress = 1 - distanceRemaining / segmentLength
        return CGFloat(completedLaps * waypoints.count + nextCheckpoint) + segmentProgress
    }

    private func finishRace() {
        guard raceState == .racing else { return }
        raceState = .finished
        player.physicsBody?.velocity = .zero
        player.physicsBody?.angularVelocity = 0
        for racer in aiRacers {
            racer.cart.physicsBody?.velocity = .zero
            racer.cart.physicsBody?.angularVelocity = 0
        }
        steeringTouches.removeAll()
        driftTouches.removeAll()

        let finishingPlace = (finishOrder.firstIndex(of: player.racerName) ?? aiRacers.count) + 1
        countdownLabel.alpha = 1
        countdownLabel.fontSize = 44
        countdownLabel.text = finishingPlace == 1 ? "MARKET CHAMPION!" : "FINISHED #\(finishingPlace)!"
        messageLabel.alpha = 1
        messageLabel.text = "Tap anywhere to race again"
    }

    private func showMessage(_ text: String) {
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = text
        messageLabel.run(.sequence([
            .wait(forDuration: 1),
            .fadeOut(withDuration: 0.3)
        ]))
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard raceState == .racing else { return }
        let bodies = [contact.bodyA, contact.bodyB]
        guard let cart = bodies.compactMap({ $0.node as? CartNode }).first else { return }

        if let pickup = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.pickup })?.node {
            collect(pickup: pickup, cart: cart)
        }
        if bodies.contains(where: { $0.categoryBitMask == PhysicsCategory.hazard }) {
            cart.physicsBody?.velocity.dx *= 0.48
            cart.physicsBody?.velocity.dy *= 0.48
            cart.slowUntil = max(cart.slowUntil, currentTime + 1.25)
            if cart === player {
                showMessage("CLEANUP IN AISLE 3!")
            }
        }
    }

    private func collect(pickup: SKNode, cart: CartNode) {
        guard !pickup.isHidden else { return }
        pickup.isHidden = true
        pickup.physicsBody = nil
        cart.boostUntil = max(cart.boostUntil, currentTime + 1.8)
        if cart === player {
            showMessage("TURBO PICKUP!")
        }

        pickup.run(.sequence([
            .wait(forDuration: 4.5),
            .run { [weak self, weak pickup] in
                guard let self, let pickup else { return }
                pickup.physicsBody = self.pickupPhysicsBody()
                pickup.isHidden = false
            }
        ]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if raceState == .finished {
            restart()
            return
        }
        for touch in touches {
            register(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            unregister(touch)
            register(touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            unregister(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func register(_ touch: UITouch) {
        let identifier = ObjectIdentifier(touch)
        let point = touch.location(in: cameraNode)
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        guard point.y < -halfHeight + 175 else { return }
        if point.x > halfWidth - 185 {
            driftTouches.insert(identifier)
        } else if point.x < -halfWidth + 250 {
            steeringTouches[identifier] = point.x < -halfWidth + 130 ? -1 : 1
        }
    }

    private func unregister(_ touch: UITouch) {
        let identifier = ObjectIdentifier(touch)
        steeringTouches.removeValue(forKey: identifier)
        driftTouches.remove(identifier)
    }

    private func restart() {
        guard let view else { return }
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        view.presentScene(newScene, transition: .crossFade(withDuration: 0.45))
    }
}
