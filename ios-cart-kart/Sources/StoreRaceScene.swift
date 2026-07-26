import SpriteKit
import UIKit

final class StoreRaceScene: SKScene {
    private let lapTarget = 3
    private let outerTrackBounds = CGRect(x: -930, y: -620, width: 1860, height: 1240)
    private let centerShelfBounds = CGRect(x: -340, y: -190, width: 680, height: 380)

    private var shelfObstacles: [CGRect] = []
    private var waypoints: [CGPoint] = []
    private var raceIsOver = false

    private let playerCart = CartNode(color: .systemRed)
    private var botCarts: [CartNode] = []

    private var steeringInput: CGFloat = 0
    private var throttleInput: CGFloat = 0
    private var touchRoles: [ObjectIdentifier: ControlRole] = [:]

    private let cameraRig = SKCameraNode()
    private let hud = HUDNode()
    private var lastFrameTimestamp: TimeInterval = 0

    enum ControlRole {
        case steering
        case throttle
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.90, green: 0.93, blue: 0.90, alpha: 1.0)
        physicsWorld.gravity = .zero

        setupTrack()
        setupWaypoints()
        setupCarts()
        setupCameraAndHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        hud.layout(in: size)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            let role: ControlRole = point.x <= size.width * 0.5 ? .steering : .throttle
            touchRoles[ObjectIdentifier(touch)] = role
            updateInput(for: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            updateInput(for: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearInput(for: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearInput(for: touches)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = frameDelta(currentTime: currentTime)
        guard delta > 0 else { return }

        if !raceIsOver {
            updatePlayer(deltaTime: delta)
            updateBots(deltaTime: delta)
            checkRaceEnd()
        }

        updateCamera()
        hud.updateSpeed(to: playerCart.speed)
    }

    private func setupTrack() {
        let floor = SKShapeNode(rect: outerTrackBounds)
        floor.fillColor = SKColor(red: 0.88, green: 0.84, blue: 0.76, alpha: 1.0)
        floor.strokeColor = .clear
        addChild(floor)

        let aisle = SKShapeNode(rect: centerShelfBounds)
        aisle.fillColor = SKColor(red: 0.73, green: 0.68, blue: 0.57, alpha: 1.0)
        aisle.strokeColor = .clear
        addChild(aisle)

        let trackOutline = SKShapeNode(rect: outerTrackBounds)
        trackOutline.strokeColor = .black
        trackOutline.lineWidth = 14
        addChild(trackOutline)

        let innerOutline = SKShapeNode(rect: centerShelfBounds)
        innerOutline.strokeColor = .black
        innerOutline.lineWidth = 10
        addChild(innerOutline)

        addShelfObstacle(
            at: CGRect(x: -730, y: -110, width: 170, height: 220),
            color: SKColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0)
        )
        addShelfObstacle(
            at: CGRect(x: -90, y: -520, width: 180, height: 140),
            color: SKColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0)
        )
        addShelfObstacle(
            at: CGRect(x: 560, y: -110, width: 170, height: 220),
            color: SKColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0)
        )
        addShelfObstacle(
            at: CGRect(x: -90, y: 380, width: 180, height: 140),
            color: SKColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0)
        )

        let finishLine = SKShapeNode(
            rect: CGRect(x: -45, y: -615, width: 90, height: 80),
            cornerRadius: 4
        )
        finishLine.fillColor = .white
        finishLine.strokeColor = .black
        finishLine.lineWidth = 3
        addChild(finishLine)
    }

    private func addShelfObstacle(at rect: CGRect, color: SKColor) {
        shelfObstacles.append(rect)
        let shelfNode = SKShapeNode(rect: rect, cornerRadius: 8)
        shelfNode.fillColor = color
        shelfNode.strokeColor = .black
        shelfNode.lineWidth = 3
        addChild(shelfNode)
    }

    private func setupWaypoints() {
        waypoints = [
            CGPoint(x: -780, y: -505),
            CGPoint(x: -250, y: -540),
            CGPoint(x: 250, y: -540),
            CGPoint(x: 790, y: -500),
            CGPoint(x: 850, y: 0),
            CGPoint(x: 790, y: 500),
            CGPoint(x: 250, y: 540),
            CGPoint(x: -250, y: 540),
            CGPoint(x: -790, y: 500),
            CGPoint(x: -850, y: 0)
        ]
    }

    private func setupCarts() {
        playerCart.position = CGPoint(x: -130, y: -565)
        playerCart.heading = 0
        addChild(playerCart)

        let botColors: [SKColor] = [
            .systemBlue,
            .systemGreen,
            .systemOrange
        ]
        let botSpawnX: [CGFloat] = [0, 130, 260]

        for (index, color) in botColors.enumerated() {
            let bot = CartNode(color: color)
            bot.position = CGPoint(x: botSpawnX[index], y: -565)
            bot.heading = 0
            bot.speed = 120
            bot.targetWaypointIndex = index * 2
            botCarts.append(bot)
            addChild(bot)
        }
    }

    private func setupCameraAndHUD() {
        camera = cameraRig
        addChild(cameraRig)
        cameraRig.addChild(hud)
        hud.layout(in: size)
        hud.setLap(current: 1, target: lapTarget)
        hud.showMessage("Race carts around the store aisles!")
        hud.showControlHint("Left half = steer, right half = gas/brake")
    }

    private func updateInput(for touch: UITouch) {
        let key = ObjectIdentifier(touch)
        guard let role = touchRoles[key] else { return }
        let point = touch.location(in: self)

        switch role {
        case .steering:
            let normalized = ((point.x / max(size.width * 0.5, 1)) * 2) - 1
            steeringInput = normalized.clamped(to: -1...1)
        case .throttle:
            let normalized = ((point.y / max(size.height, 1)) * 2) - 1
            throttleInput = normalized.clamped(to: -1...1)
        }
    }

    private func clearInput(for touches: Set<UITouch>) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let role = touchRoles.removeValue(forKey: key) else { continue }
            switch role {
            case .steering:
                steeringInput = 0
            case .throttle:
                throttleInput = 0
            }
        }
    }

    private func updatePlayer(deltaTime: CGFloat) {
        playerCart.updateMotion(
            deltaTime: deltaTime,
            steering: steeringInput,
            throttle: throttleInput
        )
        resolveCollisions(for: playerCart)
        updateLapState(for: playerCart)
        hud.setLap(current: min(playerCart.lap + 1, lapTarget), target: lapTarget)
    }

    private func updateBots(deltaTime: CGFloat) {
        for bot in botCarts {
            let waypoint = waypoints[bot.targetWaypointIndex]
            let ai = bot.aiControls(target: waypoint)
            bot.updateMotion(deltaTime: deltaTime, steering: ai.steering, throttle: ai.throttle)
            resolveCollisions(for: bot)
            updateLapState(for: bot)

            if bot.position.distance(to: waypoint) < 90 {
                bot.targetWaypointIndex = (bot.targetWaypointIndex + 1) % waypoints.count
            }
        }
    }

    private func updateLapState(for cart: CartNode) {
        let checkpoint = waypoints[cart.checkpointIndex]
        if cart.position.distance(to: checkpoint) < 130 {
            cart.checkpointIndex += 1
            if cart.checkpointIndex >= waypoints.count {
                cart.checkpointIndex = 0
                cart.lap += 1
            }
        }
    }

    private func checkRaceEnd() {
        if playerCart.lap >= lapTarget {
            raceIsOver = true
            hud.showMessage("You win! Store Cup champion.")
            return
        }

        if let winningBot = botCarts.first(where: { $0.lap >= lapTarget }) {
            raceIsOver = true
            if let index = botCarts.firstIndex(where: { $0 === winningBot }) {
                hud.showMessage("Cart #\(index + 2) won. Retry for first place!")
            } else {
                hud.showMessage("A rival cart won. Retry for first place!")
            }
        }
    }

    private func updateCamera() {
        let easing: CGFloat = 0.15
        cameraRig.position.x += (playerCart.position.x - cameraRig.position.x) * easing
        cameraRig.position.y += (playerCart.position.y - cameraRig.position.y) * easing
    }

    private func resolveCollisions(for cart: CartNode) {
        let margin: CGFloat = 20
        let boundedX = cart.position.x.clamped(to: (outerTrackBounds.minX + margin)...(outerTrackBounds.maxX - margin))
        let boundedY = cart.position.y.clamped(to: (outerTrackBounds.minY + margin)...(outerTrackBounds.maxY - margin))
        if boundedX != cart.position.x || boundedY != cart.position.y {
            cart.position = CGPoint(x: boundedX, y: boundedY)
            cart.speed *= -0.25
        }

        if centerShelfBounds.insetBy(dx: -margin, dy: -margin).contains(cart.position) {
            pushOutOfRect(centerShelfBounds.insetBy(dx: -margin, dy: -margin), cart: cart)
            cart.speed *= -0.25
        }

        for obstacle in shelfObstacles {
            let expanded = obstacle.insetBy(dx: -margin, dy: -margin)
            if expanded.contains(cart.position) {
                pushOutOfRect(expanded, cart: cart)
                cart.speed *= -0.30
            }
        }
    }

    private func pushOutOfRect(_ rect: CGRect, cart: CartNode) {
        let leftDistance = abs(cart.position.x - rect.minX)
        let rightDistance = abs(cart.position.x - rect.maxX)
        let bottomDistance = abs(cart.position.y - rect.minY)
        let topDistance = abs(cart.position.y - rect.maxY)
        let minimumDistance = min(leftDistance, rightDistance, bottomDistance, topDistance)

        if minimumDistance == leftDistance {
            cart.position.x = rect.minX
        } else if minimumDistance == rightDistance {
            cart.position.x = rect.maxX
        } else if minimumDistance == bottomDistance {
            cart.position.y = rect.minY
        } else {
            cart.position.y = rect.maxY
        }
    }

    private func frameDelta(currentTime: TimeInterval) -> CGFloat {
        guard lastFrameTimestamp > 0 else {
            lastFrameTimestamp = currentTime
            return 0
        }

        let unclamped = currentTime - lastFrameTimestamp
        lastFrameTimestamp = currentTime
        return CGFloat(min(max(unclamped, 1.0 / 120.0), 1.0 / 20.0))
    }
}

final class CartNode: SKSpriteNode {
    var heading: CGFloat = 0 {
        didSet { zRotation = heading - (.pi / 2) }
    }
    var speed: CGFloat = 0
    var lap = 0
    var checkpointIndex = 0
    var targetWaypointIndex = 0

    private let maxForwardSpeed: CGFloat = 600
    private let maxReverseSpeed: CGFloat = -220
    private let acceleration: CGFloat = 640
    private let dragPerFrame: CGFloat = 0.985
    private let turnRate: CGFloat = 2.3

    init(color: SKColor) {
        super.init(texture: nil, color: color, size: CGSize(width: 34, height: 54))
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let frameNode = SKShapeNode(rectOf: size, cornerRadius: 7)
        frameNode.strokeColor = .black
        frameNode.lineWidth = 2
        frameNode.fillColor = .clear
        frameNode.zPosition = 2
        addChild(frameNode)

        let basket = SKShapeNode(rectOf: CGSize(width: size.width - 12, height: 12), cornerRadius: 3)
        basket.fillColor = .white
        basket.strokeColor = .black
        basket.lineWidth = 1
        basket.position = CGPoint(x: 0, y: 12)
        basket.zPosition = 3
        addChild(basket)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateMotion(deltaTime: CGFloat, steering: CGFloat, throttle: CGFloat) {
        speed += throttle * acceleration * deltaTime
        speed = speed.clamped(to: maxReverseSpeed...maxForwardSpeed)

        let frameDrag = CGFloat(pow(Double(dragPerFrame), Double(deltaTime * 60)))
        speed *= frameDrag

        let turnStrength = (abs(speed) / maxForwardSpeed).clamped(to: 0.25...1.0)
        heading += steering * turnRate * turnStrength * deltaTime * (speed >= 0 ? 1 : -1)

        let direction = CGVector(dx: cos(heading), dy: sin(heading))
        position.x += direction.dx * speed * deltaTime
        position.y += direction.dy * speed * deltaTime
    }

    func aiControls(target: CGPoint) -> (steering: CGFloat, throttle: CGFloat) {
        let desiredAngle = atan2(target.y - position.y, target.x - position.x)
        let angleDelta = shortestSignedAngle(from: heading, to: desiredAngle)
        let steering = (angleDelta * 1.6).clamped(to: -1...1)
        let throttle: CGFloat = abs(angleDelta) < .pi / 2 ? 1.0 : 0.5
        return (steering, throttle)
    }

    private func shortestSignedAngle(from: CGFloat, to: CGFloat) -> CGFloat {
        var angle = to - from
        while angle > .pi { angle -= 2 * .pi }
        while angle < -.pi { angle += 2 * .pi }
        return angle
    }
}

final class HUDNode: SKNode {
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let speedLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let controlLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    override init() {
        super.init()

        lapLabel.fontSize = 28
        lapLabel.fontColor = .white
        lapLabel.horizontalAlignmentMode = .left

        speedLabel.fontSize = 24
        speedLabel.fontColor = .white
        speedLabel.horizontalAlignmentMode = .right

        messageLabel.fontSize = 34
        messageLabel.fontColor = .yellow
        messageLabel.horizontalAlignmentMode = .center

        controlLabel.fontSize = 20
        controlLabel.fontColor = .white
        controlLabel.horizontalAlignmentMode = .center

        addChild(lapLabel)
        addChild(speedLabel)
        addChild(messageLabel)
        addChild(controlLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(in size: CGSize) {
        lapLabel.position = CGPoint(x: -size.width * 0.46, y: size.height * 0.42)
        speedLabel.position = CGPoint(x: size.width * 0.46, y: size.height * 0.42)
        messageLabel.position = CGPoint(x: 0, y: size.height * 0.30)
        controlLabel.position = CGPoint(x: 0, y: -size.height * 0.44)
    }

    func setLap(current: Int, target: Int) {
        lapLabel.text = "Lap \(current)/\(target)"
    }

    func updateSpeed(to speed: CGFloat) {
        let speedKmh = max(Int(abs(speed) * 0.17), 0)
        speedLabel.text = "\(speedKmh) km/h"
    }

    func showMessage(_ text: String) {
        messageLabel.text = text
    }

    func showControlHint(_ text: String) {
        controlLabel.text = text
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - x, point.y - y)
    }
}
