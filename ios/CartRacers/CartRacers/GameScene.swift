import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let shelf: UInt32 = 1 << 1
        static let pickup: UInt32 = 1 << 2
        static let hazard: UInt32 = 1 << 3
    }

    private enum PickupKind: String {
        case couponBoost
    }

    private struct RivalCart {
        let node: SKNode
        var waypointIndex: Int
        var lap: Int
        let topSpeed: CGFloat
    }

    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let worldSize = CGSize(width: 1_900, height: 2_600)
    private let totalLaps = 3
    private let waypoints = [
        CGPoint(x: -650, y: -900),
        CGPoint(x: 620, y: -900),
        CGPoint(x: 800, y: -420),
        CGPoint(x: 760, y: 650),
        CGPoint(x: 300, y: 1_020),
        CGPoint(x: -640, y: 900),
        CGPoint(x: -820, y: 260),
        CGPoint(x: -780, y: -520)
    ]

    private var playerCart: SKNode!
    private var rivalCarts: [RivalCart] = []
    private var lapLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var speedLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var boostLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var bannerLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var instructionLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    private var didBuildScene = false
    private var lastUpdateTime: TimeInterval = 0
    private var raceTime: TimeInterval = 0
    private var playerHeading: CGFloat = 0
    private var playerSpeed: CGFloat = 0
    private var steering: CGFloat = 0
    private var boostCharge: CGFloat = 1
    private var boostRemaining: TimeInterval = 0
    private var lap = 1
    private var nextWaypointIndex = 1
    private var raceFinished = false

    override func didMove(to view: SKView) {
        guard !didBuildScene else { return }
        buildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        guard didBuildScene else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let deltaTime = min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        if raceFinished {
            playerCart.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            cameraNode.position = playerCart.position
            layoutHUD()
            return
        }

        raceTime += deltaTime
        updatePlayer(deltaTime: deltaTime)
        updateRivals(deltaTime: deltaTime)
        checkPlayerWaypointProgress()
        cameraNode.position = playerCart.position
        layoutHUD()
        updateHUD()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if raceFinished {
            resetRace()
            return
        }

        let touchCount = event?.allTouches?.count ?? touches.count
        if touchCount >= 2 {
            activateBoost()
            return
        }

        if let touch = touches.first {
            updateSteering(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            updateSteering(touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        steering = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        steering = 0
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let first = contact.bodyA
        let second = contact.bodyB
        let categories = first.categoryBitMask | second.categoryBitMask

        guard categories & PhysicsCategory.player != 0 else { return }

        if categories & PhysicsCategory.pickup != 0 {
            let pickupNode = first.categoryBitMask == PhysicsCategory.pickup ? first.node : second.node
            collectPickup(pickupNode)
        } else if categories & PhysicsCategory.hazard != 0 {
            hitSpill()
        } else if categories & PhysicsCategory.shelf != 0 {
            bumpShelf()
        }
    }
}

private extension GameScene {
    func buildScene() {
        didBuildScene = true
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(worldNode)
        camera = cameraNode
        addChild(cameraNode)

        addFloor()
        addTrack()
        addShelves()
        addPickups()
        addHazards()
        addPlayer()
        addRivals()
        addHUD()

        showBanner("Store Cart Racers", duration: 2.4)
    }

    func resetRace() {
        removeAllActions()
        removeAllChildren()
        worldNode.removeAllChildren()
        cameraNode.removeAllChildren()
        rivalCarts.removeAll()

        lastUpdateTime = 0
        raceTime = 0
        playerHeading = 0
        playerSpeed = 0
        steering = 0
        boostCharge = 1
        boostRemaining = 0
        lap = 1
        nextWaypointIndex = 1
        raceFinished = false
        didBuildScene = false

        buildScene()
    }

    func addFloor() {
        let floor = SKShapeNode(rectOf: worldSize)
        floor.fillColor = SKColor(red: 0.84, green: 0.86, blue: 0.81, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -20
        worldNode.addChild(floor)

        let tileSize: CGFloat = 120
        for x in stride(from: -worldSize.width / 2, through: worldSize.width / 2, by: tileSize) {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: worldSize.height))
            line.position = CGPoint(x: x, y: 0)
            line.fillColor = SKColor(white: 0.76, alpha: 0.35)
            line.strokeColor = .clear
            line.zPosition = -19
            worldNode.addChild(line)
        }

        for y in stride(from: -worldSize.height / 2, through: worldSize.height / 2, by: tileSize) {
            let line = SKShapeNode(rectOf: CGSize(width: worldSize.width, height: 2))
            line.position = CGPoint(x: 0, y: y)
            line.fillColor = SKColor(white: 0.76, alpha: 0.35)
            line.strokeColor = .clear
            line.zPosition = -19
            worldNode.addChild(line)
        }
    }

    func addTrack() {
        let path = CGMutablePath()
        path.move(to: waypoints[0])
        waypoints.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()

        let track = SKShapeNode(path: path)
        track.lineWidth = 310
        track.lineCap = .round
        track.lineJoin = .round
        track.strokeColor = SKColor(red: 0.42, green: 0.43, blue: 0.39, alpha: 1)
        track.fillColor = .clear
        track.zPosition = -15
        worldNode.addChild(track)

        let lane = SKShapeNode(path: path)
        lane.lineWidth = 8
        lane.lineCap = .round
        lane.lineJoin = .round
        lane.strokeColor = SKColor(white: 0.95, alpha: 0.7)
        lane.fillColor = .clear
        lane.zPosition = -14
        worldNode.addChild(lane)

        addFinishLine()
    }

    func addFinishLine() {
        let start = waypoints[0]
        let tileSize: CGFloat = 28
        let columns = 8
        let rows = 4

        for column in 0..<columns {
            for row in 0..<rows {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(
                    x: start.x + CGFloat(column - columns / 2) * tileSize,
                    y: start.y + CGFloat(row - rows / 2) * tileSize
                )
                tile.fillColor = (column + row).isMultiple(of: 2) ? .white : .black
                tile.strokeColor = .clear
                tile.zPosition = -13
                worldNode.addChild(tile)
            }
        }
    }

    func addShelves() {
        addShelf(center: CGPoint(x: -40, y: -630), size: CGSize(width: 760, height: 90), title: "Cereal")
        addShelf(center: CGPoint(x: -90, y: -330), size: CGSize(width: 660, height: 90), title: "Snacks")
        addShelf(center: CGPoint(x: -100, y: 10), size: CGSize(width: 680, height: 90), title: "Soda")
        addShelf(center: CGPoint(x: -70, y: 340), size: CGSize(width: 760, height: 90), title: "Frozen")
        addShelf(center: CGPoint(x: -60, y: 675), size: CGSize(width: 640, height: 90), title: "Produce")

        addShelf(center: CGPoint(x: 0, y: -1_170), size: CGSize(width: 1_240, height: 80), title: "Checkout")
        addShelf(center: CGPoint(x: 900, y: 160), size: CGSize(width: 80, height: 1_580), title: "Bakery")
        addShelf(center: CGPoint(x: -900, y: 100), size: CGSize(width: 80, height: 1_530), title: "Deli")
        addShelf(center: CGPoint(x: 100, y: 1_180), size: CGSize(width: 1_090, height: 80), title: "Housewares")
    }

    func addShelf(center: CGPoint, size: CGSize, title: String) {
        let shelf = SKShapeNode(rectOf: size, cornerRadius: 14)
        shelf.position = center
        shelf.fillColor = SKColor(red: 0.34, green: 0.20, blue: 0.12, alpha: 1)
        shelf.strokeColor = SKColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 1)
        shelf.lineWidth = 4
        shelf.zPosition = 2
        shelf.name = "shelf"
        shelf.physicsBody = SKPhysicsBody(rectangleOf: size)
        shelf.physicsBody?.isDynamic = false
        shelf.physicsBody?.categoryBitMask = PhysicsCategory.shelf
        shelf.physicsBody?.collisionBitMask = PhysicsCategory.player
        shelf.physicsBody?.contactTestBitMask = PhysicsCategory.player
        worldNode.addChild(shelf)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = title.uppercased()
        label.fontSize = 20
        label.fontColor = SKColor(red: 1, green: 0.86, blue: 0.42, alpha: 1)
        label.verticalAlignmentMode = .center
        label.zPosition = 3
        shelf.addChild(label)
    }

    func addPickups() {
        [
            CGPoint(x: 260, y: -900),
            CGPoint(x: 760, y: 260),
            CGPoint(x: 220, y: 940),
            CGPoint(x: -795, y: 500),
            CGPoint(x: -760, y: -360)
        ].forEach { addPickup(at: $0, kind: .couponBoost) }
    }

    func addPickup(at position: CGPoint, kind: PickupKind) {
        let pickup = SKShapeNode(rectOf: CGSize(width: 64, height: 42), cornerRadius: 8)
        pickup.position = position
        pickup.fillColor = SKColor(red: 1.0, green: 0.73, blue: 0.12, alpha: 1)
        pickup.strokeColor = SKColor(red: 0.54, green: 0.30, blue: 0.04, alpha: 1)
        pickup.lineWidth = 3
        pickup.zPosition = 4
        pickup.name = "pickup"
        pickup.userData = NSMutableDictionary(dictionary: ["kind": kind.rawValue])
        pickup.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 64, height: 42))
        pickup.physicsBody?.isDynamic = false
        pickup.physicsBody?.categoryBitMask = PhysicsCategory.pickup
        pickup.physicsBody?.collisionBitMask = 0
        pickup.physicsBody?.contactTestBitMask = PhysicsCategory.player

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "$"
        label.fontSize = 28
        label.fontColor = SKColor(red: 0.20, green: 0.12, blue: 0.02, alpha: 1)
        label.verticalAlignmentMode = .center
        pickup.addChild(label)

        pickup.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.55),
            .scale(to: 1.0, duration: 0.55)
        ])))

        worldNode.addChild(pickup)
    }

    func addHazards() {
        [
            CGPoint(x: 580, y: -610),
            CGPoint(x: 700, y: 680),
            CGPoint(x: -510, y: 830),
            CGPoint(x: -690, y: -690)
        ].forEach(addSpill)
    }

    func addSpill(at position: CGPoint) {
        let spill = SKShapeNode(ellipseOf: CGSize(width: 120, height: 70))
        spill.position = position
        spill.fillColor = SKColor(red: 0.78, green: 0.35, blue: 0.08, alpha: 0.88)
        spill.strokeColor = SKColor(red: 0.45, green: 0.16, blue: 0.04, alpha: 1)
        spill.lineWidth = 3
        spill.zPosition = -10
        spill.name = "spill"
        spill.physicsBody = SKPhysicsBody(ellipseOf: CGSize(width: 120, height: 70))
        spill.physicsBody?.isDynamic = false
        spill.physicsBody?.categoryBitMask = PhysicsCategory.hazard
        spill.physicsBody?.collisionBitMask = 0
        spill.physicsBody?.contactTestBitMask = PhysicsCategory.player
        worldNode.addChild(spill)
    }

    func addPlayer() {
        playerCart = makeCartNode(color: SKColor(red: 0.12, green: 0.54, blue: 1.0, alpha: 1), name: "player")
        playerCart.position = CGPoint(x: -720, y: -930)
        playerHeading = angle(from: playerCart.position, to: waypoints[nextWaypointIndex])
        playerCart.zRotation = playerHeading - .pi / 2
        playerCart.zPosition = 10
        playerCart.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 56))
        playerCart.physicsBody?.affectedByGravity = false
        playerCart.physicsBody?.allowsRotation = false
        playerCart.physicsBody?.linearDamping = 0.25
        playerCart.physicsBody?.restitution = 0.15
        playerCart.physicsBody?.friction = 0
        playerCart.physicsBody?.categoryBitMask = PhysicsCategory.player
        playerCart.physicsBody?.collisionBitMask = PhysicsCategory.shelf
        playerCart.physicsBody?.contactTestBitMask = PhysicsCategory.shelf | PhysicsCategory.pickup | PhysicsCategory.hazard
        worldNode.addChild(playerCart)
    }

    func addRivals() {
        let starts = [
            (CGPoint(x: -790, y: -850), SKColor(red: 0.95, green: 0.22, blue: 0.24, alpha: 1), CGFloat(348)),
            (CGPoint(x: -830, y: -960), SKColor(red: 0.35, green: 0.88, blue: 0.28, alpha: 1), CGFloat(334)),
            (CGPoint(x: -900, y: -880), SKColor(red: 0.63, green: 0.34, blue: 1.0, alpha: 1), CGFloat(326))
        ]

        rivalCarts = starts.map { start, color, speed in
            let cart = makeCartNode(color: color, name: "rival")
            cart.position = start
            cart.zPosition = 9
            worldNode.addChild(cart)
            return RivalCart(node: cart, waypointIndex: 1, lap: 1, topSpeed: speed)
        }
    }

    func makeCartNode(color: SKColor, name: String) -> SKNode {
        let cart = SKNode()
        cart.name = name

        let basket = SKShapeNode(rectOf: CGSize(width: 42, height: 58), cornerRadius: 9)
        basket.fillColor = color
        basket.strokeColor = SKColor(white: 0.97, alpha: 1)
        basket.lineWidth = 3
        basket.zPosition = 1
        cart.addChild(basket)

        let wire = SKShapeNode(rectOf: CGSize(width: 30, height: 44), cornerRadius: 5)
        wire.fillColor = .clear
        wire.strokeColor = SKColor(white: 1, alpha: 0.55)
        wire.lineWidth = 2
        wire.zPosition = 2
        cart.addChild(wire)

        let handle = SKShapeNode(rectOf: CGSize(width: 36, height: 7), cornerRadius: 3)
        handle.position = CGPoint(x: 0, y: -36)
        handle.fillColor = SKColor(white: 0.96, alpha: 1)
        handle.strokeColor = .clear
        handle.zPosition = 2
        cart.addChild(handle)

        let nose = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 4)
        nose.position = CGPoint(x: 0, y: 34)
        nose.fillColor = SKColor(red: 1, green: 0.78, blue: 0.18, alpha: 1)
        nose.strokeColor = .clear
        nose.zPosition = 2
        cart.addChild(nose)

        [-16, 16].forEach { x in
            [-26, 24].forEach { y in
                let wheel = SKShapeNode(circleOfRadius: 5)
                wheel.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
                wheel.fillColor = SKColor(white: 0.04, alpha: 1)
                wheel.strokeColor = .clear
                wheel.zPosition = 3
                cart.addChild(wheel)
            }
        }

        return cart
    }

    func addHUD() {
        [lapLabel, speedLabel, boostLabel, bannerLabel, instructionLabel].forEach {
            $0.zPosition = 100
            $0.fontColor = .white
            cameraNode.addChild($0)
        }

        lapLabel.fontSize = 24
        lapLabel.horizontalAlignmentMode = .left
        speedLabel.fontSize = 17
        speedLabel.horizontalAlignmentMode = .left
        boostLabel.fontSize = 17
        boostLabel.horizontalAlignmentMode = .right

        bannerLabel.fontSize = 34
        bannerLabel.verticalAlignmentMode = .center
        bannerLabel.horizontalAlignmentMode = .center
        bannerLabel.fontColor = SKColor(red: 1, green: 0.78, blue: 0.18, alpha: 1)

        instructionLabel.text = "Drag to steer. Two-finger tap for coupon boost."
        instructionLabel.fontSize = 15
        instructionLabel.alpha = 0.92
        instructionLabel.verticalAlignmentMode = .center
        instructionLabel.horizontalAlignmentMode = .center

        layoutHUD()
        updateHUD()
    }

    func layoutHUD() {
        let left = -size.width / 2 + 22
        let right = size.width / 2 - 22
        let top = size.height / 2 - 58
        let bottom = -size.height / 2 + 40

        lapLabel.position = CGPoint(x: left, y: top)
        speedLabel.position = CGPoint(x: left, y: top - 30)
        boostLabel.position = CGPoint(x: right, y: top - 30)
        bannerLabel.position = CGPoint(x: 0, y: size.height * 0.25)
        instructionLabel.position = CGPoint(x: 0, y: bottom)
    }

    func updateHUD() {
        lapLabel.text = "Lap \(min(lap, totalLaps))/\(totalLaps)"
        speedLabel.text = "Speed \(Int(playerSpeed))  Time \(String(format: "%.1f", raceTime))"

        if boostRemaining > 0 {
            boostLabel.text = "Boost \(String(format: "%.1f", boostRemaining))s"
        } else if boostCharge >= 1 {
            boostLabel.text = "Boost READY"
        } else {
            boostLabel.text = "Boost \(Int(boostCharge * 100))%"
        }
    }

    func updateSteering(_ touch: UITouch) {
        let location = touch.location(in: self)
        let normalized = (location.x / max(size.width, 1) - 0.5) * 2
        steering = clamp(normalized, min: -1, max: 1)
    }

    func updatePlayer(deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)
        let onTrack = distanceToTrack(from: playerCart.position) < 180
        let baseSpeed: CGFloat = onTrack ? 390 : 225
        let boostSpeed: CGFloat = onTrack ? 640 : 340
        let desiredSpeed = boostRemaining > 0 ? boostSpeed : baseSpeed
        let acceleration = min(dt * 3.3, 1)
        let turnRate = steering * (2.2 + playerSpeed / 430)

        playerHeading += turnRate * dt
        playerSpeed += (desiredSpeed - playerSpeed) * acceleration
        boostCharge = min(1, boostCharge + dt * 0.18)
        boostRemaining = max(0, boostRemaining - deltaTime)

        let direction = CGVector(dx: cos(playerHeading), dy: sin(playerHeading))
        playerCart.zRotation = playerHeading - .pi / 2
        playerCart.physicsBody?.velocity = CGVector(dx: direction.dx * playerSpeed, dy: direction.dy * playerSpeed)
        clampPlayerToWorld()
    }

    func updateRivals(deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)

        for index in rivalCarts.indices {
            var rival = rivalCarts[index]
            let target = waypoints[rival.waypointIndex]
            let current = rival.node.position
            let toTarget = CGVector(dx: target.x - current.x, dy: target.y - current.y)
            let distance = max(hypot(toTarget.dx, toTarget.dy), 1)

            if distance < 120 {
                rival.waypointIndex = (rival.waypointIndex + 1) % waypoints.count
                if rival.waypointIndex == 1 {
                    rival.lap += 1
                }
            }

            let refreshedTarget = waypoints[rival.waypointIndex]
            let heading = angle(from: rival.node.position, to: refreshedTarget)
            let wobble = sin(CGFloat(raceTime) * 1.7 + CGFloat(index)) * 0.18
            let speed = rival.topSpeed + sin(CGFloat(raceTime) + CGFloat(index) * 2) * 18

            rival.node.zRotation = heading + wobble - .pi / 2
            rival.node.position.x += cos(heading + wobble) * speed * dt
            rival.node.position.y += sin(heading + wobble) * speed * dt
            rivalCarts[index] = rival
        }
    }

    func checkPlayerWaypointProgress() {
        let target = waypoints[nextWaypointIndex]
        guard distance(from: playerCart.position, to: target) < 145 else { return }

        nextWaypointIndex = (nextWaypointIndex + 1) % waypoints.count

        if nextWaypointIndex == 1 {
            if lap >= totalLaps {
                finishRace()
            } else {
                lap += 1
                showBanner("Lap \(lap)", duration: 1.3)
            }
        }
    }

    func activateBoost() {
        guard boostCharge >= 1 else {
            showBanner("Coupon meter charging", duration: 0.7)
            return
        }

        boostCharge = 0
        boostRemaining = 1.65
        showBanner("Coupon boost!", duration: 0.9)
        playerCart.run(.sequence([
            .scale(to: 1.16, duration: 0.08),
            .scale(to: 1.0, duration: 0.16)
        ]))
    }

    func collectPickup(_ node: SKNode?) {
        guard let node, node.parent != nil else { return }
        node.removeFromParent()
        boostCharge = 1
        showBanner("Coupon collected", duration: 0.9)
    }

    func hitSpill() {
        playerSpeed = min(playerSpeed, 175)
        playerCart.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        showBanner("Cereal spill!", duration: 0.7)
    }

    func bumpShelf() {
        playerSpeed *= 0.55
        if let velocity = playerCart.physicsBody?.velocity {
            playerCart.physicsBody?.velocity = CGVector(dx: velocity.dx * 0.35, dy: velocity.dy * 0.35)
        }
    }

    func finishRace() {
        raceFinished = true
        steering = 0
        playerCart.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        showBanner("Finished! Tap to race again", duration: 60)
    }

    func showBanner(_ text: String, duration: TimeInterval) {
        bannerLabel.removeAllActions()
        bannerLabel.text = text
        bannerLabel.alpha = 1
        bannerLabel.run(.sequence([
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.35)
        ]))
    }

    func clampPlayerToWorld() {
        let halfWidth = worldSize.width / 2 - 50
        let halfHeight = worldSize.height / 2 - 50
        playerCart.position.x = clamp(playerCart.position.x, min: -halfWidth, max: halfWidth)
        playerCart.position.y = clamp(playerCart.position.y, min: -halfHeight, max: halfHeight)
    }

    func distanceToTrack(from point: CGPoint) -> CGFloat {
        var shortest = CGFloat.greatestFiniteMagnitude

        for index in waypoints.indices {
            let start = waypoints[index]
            let end = waypoints[(index + 1) % waypoints.count]
            shortest = min(shortest, distance(from: point, toSegmentStart: start, end: end))
        }

        return shortest
    }

    func distance(from point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let segment = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy
        guard lengthSquared > 0 else { return distance(from: point, to: start) }

        let pointVector = CGVector(dx: point.x - start.x, dy: point.y - start.y)
        let projection = clamp((pointVector.dx * segment.dx + pointVector.dy * segment.dy) / lengthSquared, min: 0, max: 1)
        let closest = CGPoint(x: start.x + segment.dx * projection, y: start.y + segment.dy * projection)
        return distance(from: point, to: closest)
    }

    func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    func angle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        atan2(end.y - start.y, end.x - start.x)
    }

    func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.max(lower, Swift.min(upper, value))
    }
}
