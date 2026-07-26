import CoreMotion
import SpriteKit

private enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let pickup: UInt32 = 1 << 1
}

private enum PickupKind: String, CaseIterable {
    case boost
    case supplies
    case shield
}

private final class Racer {
    let name: String
    let node: SKNode
    let isPlayer: Bool
    var velocity = CGVector.zero
    var heading: CGFloat
    var targetWaypoint: Int
    var lap = 1
    var boostedUntil: TimeInterval = 0
    var shieldUntil: TimeInterval = 0

    init(name: String, node: SKNode, isPlayer: Bool, heading: CGFloat, targetWaypoint: Int) {
        self.name = name
        self.node = node
        self.isPlayer = isPlayer
        self.heading = heading
        self.targetWaypoint = targetWaypoint
    }
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private let world = SKNode()
    private let hud = SKNode()
    private let motionManager = CMMotionManager()

    private var racers: [Racer] = []
    private var player: Racer?
    private var trackWaypoints: [CGPoint] = []
    private var obstacleRects: [CGRect] = []

    private var lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var suppliesLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var speedLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var standingsLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    private var sceneTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var steeringInput: CGFloat = 0
    private var throttleInput: CGFloat = 0.78
    private var suppliesCollected = 0
    private var isGameOver = false

    private let totalLaps = 3

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        startMotionUpdates()
        buildLevel()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        buildLevel()
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
    }

    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
        motionManager.startAccelerometerUpdates()
    }

    private func buildLevel() {
        removeAllChildren()
        world.removeAllChildren()
        hud.removeAllChildren()
        racers.removeAll()
        obstacleRects.removeAll()
        suppliesCollected = 0
        isGameOver = false
        addChild(world)
        addChild(hud)

        backgroundColor = SKColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        drawStoreFloor()
        drawTrack()
        drawShelves()
        drawCheckoutStartLine()
        spawnRacers()
        spawnInitialPickups()
        buildHUD()
    }

    private func drawStoreFloor() {
        let floor = SKShapeNode(rectOf: CGSize(width: size.width * 1.1, height: size.height * 1.1))
        floor.fillColor = SKColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1)
        floor.strokeColor = SKColor(red: 0.24, green: 0.25, blue: 0.27, alpha: 1)
        floor.lineWidth = 8
        floor.zPosition = -20
        world.addChild(floor)

        let tileSpacing: CGFloat = 48
        let columns = Int(size.width / tileSpacing) + 4
        let rows = Int(size.height / tileSpacing) + 4
        for column in -columns...columns {
            let line = SKShapeNode()
            let path = CGMutablePath()
            let x = CGFloat(column) * tileSpacing
            path.move(to: CGPoint(x: x, y: -size.height))
            path.addLine(to: CGPoint(x: x, y: size.height))
            line.path = path
            line.strokeColor = SKColor(white: 1, alpha: 0.04)
            line.lineWidth = 1
            line.zPosition = -19
            world.addChild(line)
        }
        for row in -rows...rows {
            let line = SKShapeNode()
            let path = CGMutablePath()
            let y = CGFloat(row) * tileSpacing
            path.move(to: CGPoint(x: -size.width, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            line.path = path
            line.strokeColor = SKColor(white: 1, alpha: 0.04)
            line.lineWidth = 1
            line.zPosition = -19
            world.addChild(line)
        }
    }

    private func drawTrack() {
        let trackWidth: CGFloat = 96
        let left = -size.width * 0.36
        let right = size.width * 0.36
        let top = size.height * 0.30
        let bottom = -size.height * 0.30

        trackWaypoints = [
            CGPoint(x: left, y: bottom),
            CGPoint(x: left, y: 0),
            CGPoint(x: left, y: top),
            CGPoint(x: 0, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: right, y: 0),
            CGPoint(x: right, y: bottom),
            CGPoint(x: 0, y: bottom)
        ]

        let path = CGMutablePath()
        path.move(to: trackWaypoints[7])
        for point in trackWaypoints {
            path.addLine(to: point)
        }
        path.closeSubpath()

        let trackShadow = SKShapeNode(path: path)
        trackShadow.strokeColor = SKColor(white: 0, alpha: 0.32)
        trackShadow.lineWidth = trackWidth + 14
        trackShadow.lineCap = .round
        trackShadow.lineJoin = .round
        trackShadow.zPosition = -10
        world.addChild(trackShadow)

        let track = SKShapeNode(path: path)
        track.strokeColor = SKColor(red: 0.28, green: 0.30, blue: 0.33, alpha: 1)
        track.lineWidth = trackWidth
        track.lineCap = .round
        track.lineJoin = .round
        track.zPosition = -9
        world.addChild(track)

        let dashedCenter = SKShapeNode(path: path)
        dashedCenter.strokeColor = SKColor(white: 1, alpha: 0.22)
        dashedCenter.lineWidth = 3
        dashedCenter.lineCap = .round
        dashedCenter.lineJoin = .round
        dashedCenter.zPosition = -8
        world.addChild(dashedCenter)

        for (index, point) in trackWaypoints.enumerated() {
            let marker = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            marker.text = "\(index + 1)"
            marker.fontSize = 12
            marker.fontColor = SKColor(white: 1, alpha: 0.22)
            marker.position = CGPoint(x: point.x, y: point.y - 5)
            marker.zPosition = -7
            world.addChild(marker)
        }
    }

    private func drawShelves() {
        addShelf(center: CGPoint(x: -size.width * 0.12, y: 0), size: CGSize(width: 54, height: size.height * 0.42), label: "CANNED GOODS")
        addShelf(center: CGPoint(x: size.width * 0.12, y: 0), size: CGSize(width: 54, height: size.height * 0.42), label: "BLANKETS")
        addShelf(center: CGPoint(x: 0, y: size.height * 0.04), size: CGSize(width: size.width * 0.16, height: 42), label: "CHECKOUT SNACKS")
        addShelf(center: CGPoint(x: -size.width * 0.28, y: size.height * 0.05), size: CGSize(width: 46, height: size.height * 0.20), label: "AISLE 2")
        addShelf(center: CGPoint(x: size.width * 0.28, y: -size.height * 0.05), size: CGSize(width: 46, height: size.height * 0.20), label: "AISLE 6")
    }

    private func addShelf(center: CGPoint, size shelfSize: CGSize, label: String) {
        let rect = CGRect(
            x: center.x - shelfSize.width / 2,
            y: center.y - shelfSize.height / 2,
            width: shelfSize.width,
            height: shelfSize.height
        )
        obstacleRects.append(rect.insetBy(dx: -5, dy: -5))

        let shelf = SKShapeNode(rectOf: shelfSize, cornerRadius: 8)
        shelf.position = center
        shelf.fillColor = SKColor(red: 0.51, green: 0.31, blue: 0.15, alpha: 1)
        shelf.strokeColor = SKColor(red: 0.83, green: 0.66, blue: 0.38, alpha: 1)
        shelf.lineWidth = 3
        shelf.zPosition = -2
        world.addChild(shelf)

        let stripeCount = max(2, Int(shelfSize.height / 34))
        for stripe in 0..<stripeCount {
            let stripeNode = SKShapeNode(rectOf: CGSize(width: shelfSize.width - 8, height: 4), cornerRadius: 2)
            stripeNode.position = CGPoint(x: center.x, y: center.y - shelfSize.height / 2 + CGFloat(stripe + 1) * shelfSize.height / CGFloat(stripeCount + 1))
            stripeNode.fillColor = SKColor(white: 1, alpha: 0.18)
            stripeNode.strokeColor = .clear
            stripeNode.zPosition = -1
            world.addChild(stripeNode)
        }

        let shelfLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        shelfLabel.text = label
        shelfLabel.fontSize = 9
        shelfLabel.fontColor = SKColor(white: 1, alpha: 0.76)
        shelfLabel.position = CGPoint(x: center.x, y: center.y - 5)
        shelfLabel.zRotation = shelfSize.height > shelfSize.width ? -.pi / 2 : 0
        shelfLabel.zPosition = 0
        world.addChild(shelfLabel)
    }

    private func drawCheckoutStartLine() {
        guard let start = trackWaypoints.last else { return }

        let line = SKShapeNode(rectOf: CGSize(width: 88, height: 8), cornerRadius: 2)
        line.position = CGPoint(x: start.x, y: start.y)
        line.fillColor = SKColor(red: 0.95, green: 0.83, blue: 0.18, alpha: 1)
        line.strokeColor = .clear
        line.zPosition = -4
        world.addChild(line)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "CHECKOUT START"
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.98, green: 0.90, blue: 0.38, alpha: 1)
        label.position = CGPoint(x: start.x, y: start.y - 28)
        label.zPosition = 4
        world.addChild(label)
    }

    private func spawnRacers() {
        guard let start = trackWaypoints.last else { return }

        let playerNode = makeCartNode(color: SKColor(red: 0.10, green: 0.55, blue: 0.95, alpha: 1), name: "player")
        playerNode.position = CGPoint(x: start.x + 8, y: start.y + 24)
        playerNode.zRotation = .pi / 2
        world.addChild(playerNode)
        let playerRacer = Racer(name: "You", node: playerNode, isPlayer: true, heading: .pi, targetWaypoint: 0)
        racers.append(playerRacer)
        player = playerRacer

        let rivals: [(String, SKColor, CGPoint)] = [
            ("Lucky", SKColor(red: 0.95, green: 0.42, blue: 0.18, alpha: 1), CGPoint(x: 44, y: 22)),
            ("Patch", SKColor(red: 0.72, green: 0.30, blue: 0.86, alpha: 1), CGPoint(x: 84, y: -18)),
            ("Beans", SKColor(red: 0.18, green: 0.78, blue: 0.36, alpha: 1), CGPoint(x: 126, y: 18))
        ]

        for rival in rivals {
            let node = makeCartNode(color: rival.1, name: rival.0)
            node.position = CGPoint(x: start.x + rival.2.x, y: start.y + rival.2.y)
            node.zRotation = .pi / 2
            world.addChild(node)
            racers.append(Racer(name: rival.0, node: node, isPlayer: false, heading: .pi, targetWaypoint: 0))
        }
    }

    private func makeCartNode(color: SKColor, name: String) -> SKNode {
        let cart = SKNode()
        cart.name = "cart.\(name)"
        cart.zPosition = 8

        let basket = SKShapeNode(rectOf: CGSize(width: 34, height: 48), cornerRadius: 7)
        basket.fillColor = color
        basket.strokeColor = SKColor(white: 1, alpha: 0.82)
        basket.lineWidth = 3
        basket.zPosition = 2
        cart.addChild(basket)

        for y in stride(from: -13, through: 13, by: 13) {
            let rail = SKShapeNode(rectOf: CGSize(width: 26, height: 2), cornerRadius: 1)
            rail.position = CGPoint(x: 0, y: CGFloat(y))
            rail.fillColor = SKColor(white: 1, alpha: 0.32)
            rail.strokeColor = .clear
            rail.zPosition = 3
            cart.addChild(rail)
        }

        let handle = SKShapeNode(rectOf: CGSize(width: 42, height: 5), cornerRadius: 2)
        handle.position = CGPoint(x: 0, y: 28)
        handle.fillColor = SKColor(white: 0.92, alpha: 1)
        handle.strokeColor = .clear
        handle.zPosition = 1
        cart.addChild(handle)

        for wheelX in [-14, 14] {
            for wheelY in [-20, 20] {
                let wheel = SKShapeNode(circleOfRadius: 5)
                wheel.position = CGPoint(x: CGFloat(wheelX), y: CGFloat(wheelY))
                wheel.fillColor = SKColor(white: 0.04, alpha: 1)
                wheel.strokeColor = SKColor(white: 0.85, alpha: 1)
                wheel.lineWidth = 1.5
                wheel.zPosition = 1
                cart.addChild(wheel)
            }
        }

        let shield = SKShapeNode(circleOfRadius: 34)
        shield.name = "shieldRing"
        shield.strokeColor = SKColor(red: 0.40, green: 0.86, blue: 1, alpha: 0.85)
        shield.lineWidth = 4
        shield.fillColor = .clear
        shield.isHidden = true
        shield.zPosition = 0
        cart.addChild(shield)

        cart.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 52))
        cart.physicsBody?.affectedByGravity = false
        cart.physicsBody?.allowsRotation = false
        cart.physicsBody?.categoryBitMask = PhysicsCategory.cart
        cart.physicsBody?.contactTestBitMask = PhysicsCategory.pickup
        cart.physicsBody?.collisionBitMask = 0
        return cart
    }

    private func spawnInitialPickups() {
        let placements: [(PickupKind, Int, CGFloat, CGFloat)] = [
            (.boost, 1, 35, 0),
            (.supplies, 2, 0, -36),
            (.shield, 3, -36, 0),
            (.boost, 4, 0, -34),
            (.supplies, 5, -36, 0),
            (.shield, 6, 0, 34),
            (.supplies, 7, 36, 0)
        ]

        for placement in placements where placement.1 < trackWaypoints.count {
            let point = trackWaypoints[placement.1]
            createPickup(
                kind: placement.0,
                at: CGPoint(x: point.x + placement.2, y: point.y + placement.3)
            )
        }
    }

    private func createPickup(kind: PickupKind, at position: CGPoint) {
        let pickup = SKNode()
        pickup.name = "pickup.\(kind.rawValue)"
        pickup.position = position
        pickup.zPosition = 5

        let color: SKColor
        let symbol: String
        switch kind {
        case .boost:
            color = SKColor(red: 1.00, green: 0.40, blue: 0.10, alpha: 1)
            symbol = ">"
        case .supplies:
            color = SKColor(red: 0.20, green: 0.82, blue: 0.44, alpha: 1)
            symbol = "+"
        case .shield:
            color = SKColor(red: 0.22, green: 0.76, blue: 1.00, alpha: 1)
            symbol = "*"
        }

        let token = SKShapeNode(circleOfRadius: 16)
        token.fillColor = color
        token.strokeColor = SKColor(white: 1, alpha: 0.88)
        token.lineWidth = 3
        pickup.addChild(token)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = symbol
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        pickup.addChild(label)

        pickup.physicsBody = SKPhysicsBody(circleOfRadius: 18)
        pickup.physicsBody?.affectedByGravity = false
        pickup.physicsBody?.categoryBitMask = PhysicsCategory.pickup
        pickup.physicsBody?.contactTestBitMask = PhysicsCategory.cart
        pickup.physicsBody?.collisionBitMask = 0
        world.addChild(pickup)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.18, duration: 0.45),
            SKAction.scale(to: 1.0, duration: 0.45)
        ])
        pickup.run(SKAction.repeatForever(pulse))
    }

    private func buildHUD() {
        lapLabel = makeHUDLabel(fontSize: 22, alignment: .left)
        lapLabel.position = CGPoint(x: -size.width * 0.47, y: size.height * 0.42)
        hud.addChild(lapLabel)

        suppliesLabel = makeHUDLabel(fontSize: 17, alignment: .left)
        suppliesLabel.position = CGPoint(x: -size.width * 0.47, y: size.height * 0.34)
        hud.addChild(suppliesLabel)

        speedLabel = makeHUDLabel(fontSize: 17, alignment: .right)
        speedLabel.position = CGPoint(x: size.width * 0.47, y: size.height * 0.42)
        hud.addChild(speedLabel)

        standingsLabel = makeHUDLabel(fontSize: 15, alignment: .right)
        standingsLabel.position = CGPoint(x: size.width * 0.47, y: size.height * 0.34)
        hud.addChild(standingsLabel)

        statusLabel = makeHUDLabel(fontSize: 16, alignment: .center)
        statusLabel.position = CGPoint(x: 0, y: -size.height * 0.44)
        hud.addChild(statusLabel)
        updateHUD()
    }

    private func makeHUDLabel(fontSize: CGFloat, alignment: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = fontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.zPosition = 100
        return label
    }

    override func update(_ currentTime: TimeInterval) {
        sceneTime = currentTime
        let deltaTime: CGFloat
        if lastUpdateTime == 0 {
            deltaTime = 1.0 / 60.0
        } else {
            deltaTime = min(CGFloat(currentTime - lastUpdateTime), 1.0 / 20.0)
        }
        lastUpdateTime = currentTime

        for racer in racers {
            update(racer: racer, deltaTime: deltaTime)
        }
        updateHUD()
    }

    private func update(racer: Racer, deltaTime: CGFloat) {
        let previousPosition = racer.node.position
        if racer.isPlayer {
            updatePlayer(racer, deltaTime: deltaTime)
        } else {
            updateOpponent(racer, deltaTime: deltaTime)
        }

        racer.node.position.x += racer.velocity.dx * deltaTime
        racer.node.position.y += racer.velocity.dy * deltaTime
        racer.node.zRotation = racer.heading - .pi / 2
        keep(racer: racer, within: previousPosition)
        updateWaypoint(for: racer)
        updateShieldRing(for: racer)
    }

    private func updatePlayer(_ racer: Racer, deltaTime: CGFloat) {
        guard !isGameOver else {
            racer.velocity.dx *= 0.95
            racer.velocity.dy *= 0.95
            return
        }

        let tilt = CGFloat(motionManager.accelerometerData?.acceleration.y ?? 0)
        let steer = clamp(steeringInput + tilt * 1.25, -1, 1)
        let speed = vectorLength(racer.velocity)
        let maxSpeed: CGFloat = racer.boostedUntil > sceneTime ? 560 : 380
        let turnRate = (2.2 + min(speed / maxSpeed, 1.0) * 2.0) * deltaTime
        racer.heading += steer * turnRate

        let direction = CGVector(dx: cos(racer.heading), dy: sin(racer.heading))
        let throttle = isGameOver ? 0 : throttleInput
        let acceleration: CGFloat = racer.boostedUntil > sceneTime ? 520 : 330
        racer.velocity.dx += direction.dx * acceleration * throttle * deltaTime
        racer.velocity.dy += direction.dy * acceleration * throttle * deltaTime

        applyDrag(to: racer, amount: throttle < 0.2 ? 0.91 : 0.985)
        capSpeed(of: racer, to: maxSpeed)
    }

    private func updateOpponent(_ racer: Racer, deltaTime: CGFloat) {
        guard !trackWaypoints.isEmpty else { return }
        let target = trackWaypoints[racer.targetWaypoint]
        let offsetTarget = CGPoint(
            x: target.x + (racer.name == "Lucky" ? 20 : racer.name == "Patch" ? -18 : 0),
            y: target.y + (racer.name == "Beans" ? 22 : 0)
        )
        let desiredHeading = atan2(offsetTarget.y - racer.node.position.y, offsetTarget.x - racer.node.position.x)
        let turn = clamp(shortestAngle(from: racer.heading, to: desiredHeading), -2.6 * deltaTime, 2.6 * deltaTime)
        racer.heading += turn

        let desiredSpeed: CGFloat = racer.boostedUntil > sceneTime ? 430 : 285
        let direction = CGVector(dx: cos(racer.heading), dy: sin(racer.heading))
        racer.velocity.dx += (direction.dx * desiredSpeed - racer.velocity.dx) * 0.045
        racer.velocity.dy += (direction.dy * desiredSpeed - racer.velocity.dy) * 0.045
        applyDrag(to: racer, amount: 0.992)
        capSpeed(of: racer, to: desiredSpeed)
    }

    private func keep(racer: Racer, within previousPosition: CGPoint) {
        let cartBounds = racer.node.calculateAccumulatedFrame().insetBy(dx: 8, dy: 8)
        let hasShelfCollision = obstacleRects.contains { $0.intersects(cartBounds) }

        if hasShelfCollision {
            if racer.shieldUntil > sceneTime {
                racer.shieldUntil = 0
                racer.velocity.dx *= 0.45
                racer.velocity.dy *= 0.45
            } else {
                racer.node.position = previousPosition
                racer.velocity.dx *= -0.25
                racer.velocity.dy *= -0.25
            }
        }

        let xLimit = size.width * 0.49
        let yLimit = size.height * 0.49
        racer.node.position.x = clamp(racer.node.position.x, -xLimit, xLimit)
        racer.node.position.y = clamp(racer.node.position.y, -yLimit, yLimit)
    }

    private func updateWaypoint(for racer: Racer) {
        guard !trackWaypoints.isEmpty else { return }
        let target = trackWaypoints[racer.targetWaypoint]
        guard distance(from: racer.node.position, to: target) < 78 else { return }
        racer.targetWaypoint = (racer.targetWaypoint + 1) % trackWaypoints.count
        if racer.targetWaypoint == 0 {
            racer.lap += 1
            if racer.isPlayer && racer.lap > totalLaps {
                isGameOver = true
                racer.lap = totalLaps
                showFinishMessage()
            }
        }
    }

    private func showFinishMessage() {
        let banner = SKShapeNode(rectOf: CGSize(width: min(size.width * 0.74, 560), height: 92), cornerRadius: 18)
        banner.fillColor = SKColor(white: 0.02, alpha: 0.82)
        banner.strokeColor = SKColor(red: 0.95, green: 0.83, blue: 0.18, alpha: 1)
        banner.lineWidth = 3
        banner.zPosition = 90
        hud.addChild(banner)

        let message = SKLabelNode(fontNamed: "AvenirNext-Bold")
        message.text = "Checkout champion!"
        message.fontSize = 30
        message.fontColor = .white
        message.verticalAlignmentMode = .center
        message.position = CGPoint(x: 0, y: 14)
        message.zPosition = 91
        hud.addChild(message)

        let subMessage = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subMessage.text = "Supplies gathered: \(suppliesCollected)  Tap to race again"
        subMessage.fontSize = 16
        subMessage.fontColor = SKColor(white: 1, alpha: 0.78)
        subMessage.verticalAlignmentMode = .center
        subMessage.position = CGPoint(x: 0, y: -22)
        subMessage.zPosition = 91
        hud.addChild(subMessage)
    }

    private func updateShieldRing(for racer: Racer) {
        racer.node.childNode(withName: "shieldRing")?.isHidden = racer.shieldUntil <= sceneTime
    }

    private func updateHUD() {
        guard let player else { return }
        lapLabel.text = "Lap \(min(player.lap, totalLaps))/\(totalLaps)"
        suppliesLabel.text = "Supplies \(suppliesCollected)"
        speedLabel.text = "Speed \(Int(vectorLength(player.velocity) / 6))"

        let standings = racers.sorted {
            if $0.lap == $1.lap {
                return $0.targetWaypoint > $1.targetWaypoint
            }
            return $0.lap > $1.lap
        }
        standingsLabel.text = standings.enumerated()
            .map { "\($0.offset + 1). \($0.element.name)" }
            .joined(separator: "  ")

        if isGameOver {
            statusLabel.text = "Tap anywhere to restart"
        } else if player.boostedUntil > sceneTime {
            statusLabel.text = "Boost! Hold top half to keep pushing."
        } else if player.shieldUntil > sceneTime {
            statusLabel.text = "Shield ready: one shelf bump is covered."
        } else {
            statusLabel.text = "Touch left/right to steer. Top half accelerates, bottom half brakes."
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let nodes = [contact.bodyA.node, contact.bodyB.node].compactMap { $0 }
        guard
            let pickupNode = nodes.first(where: { $0.name?.hasPrefix("pickup.") == true }),
            let cartNode = nodes.first(where: { $0.name?.hasPrefix("cart.") == true }),
            let kindName = pickupNode.name?.split(separator: ".").last,
            let kind = PickupKind(rawValue: String(kindName)),
            let racer = racers.first(where: { $0.node === cartNode })
        else {
            return
        }

        apply(kind, to: racer)
        let respawnKind = kind
        pickupNode.removeFromParent()
        world.run(.sequence([
            .wait(forDuration: 2.5),
            .run { [weak self] in
                self?.createPickup(kind: respawnKind, at: self?.randomPickupPoint() ?? .zero)
            }
        ]))
    }

    private func apply(_ kind: PickupKind, to racer: Racer) {
        switch kind {
        case .boost:
            racer.boostedUntil = sceneTime + 2.2
        case .supplies:
            if racer.isPlayer {
                suppliesCollected += 1
            } else {
                racer.boostedUntil = sceneTime + 1.0
            }
        case .shield:
            racer.shieldUntil = sceneTime + 6.0
        }
    }

    private func randomPickupPoint() -> CGPoint {
        guard let point = trackWaypoints.randomElement() else { return .zero }
        return CGPoint(
            x: point.x + CGFloat.random(in: -38...38),
            y: point.y + CGFloat.random(in: -38...38)
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            buildLevel()
            return
        }
        updateTouchControls(from: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTouchControls(from: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        steeringInput = 0
        throttleInput = 0.65
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        steeringInput = 0
        throttleInput = 0.65
    }

    private func updateTouchControls(from touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        steeringInput = clamp(location.x / max(size.width * 0.33, 1), -1, 1)
        throttleInput = location.y > -size.height * 0.12 ? 1.0 : -0.28
    }

    private func applyDrag(to racer: Racer, amount: CGFloat) {
        racer.velocity.dx *= amount
        racer.velocity.dy *= amount
    }

    private func capSpeed(of racer: Racer, to maximum: CGFloat) {
        let speed = vectorLength(racer.velocity)
        guard speed > maximum, speed > 0 else { return }
        let scale = maximum / speed
        racer.velocity.dx *= scale
        racer.velocity.dy *= scale
    }

    private func vectorLength(_ vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func shortestAngle(from current: CGFloat, to target: CGFloat) -> CGFloat {
        var angle = target - current
        while angle > .pi { angle -= .pi * 2 }
        while angle < -.pi { angle += .pi * 2 }
        return angle
    }

    private func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }
}
