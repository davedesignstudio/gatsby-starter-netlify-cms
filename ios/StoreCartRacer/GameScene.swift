import Foundation
import SpriteKit

private final class CartNode: SKShapeNode {
    let cartName: String
    let isPlayerCart: Bool

    var speed: CGFloat = 0
    var heading: CGFloat = .pi / 2
    var lap: Int = 1
    var nextWaypointIndex: Int = 1
    var lapGateArmed = false
    var topSpeed: CGFloat
    var acceleration: CGFloat

    init(cartName: String, color: SKColor, isPlayerCart: Bool, topSpeed: CGFloat, acceleration: CGFloat) {
        self.cartName = cartName
        self.isPlayerCart = isPlayerCart
        self.topSpeed = topSpeed
        self.acceleration = acceleration

        super.init()

        path = CGPath(
            roundedRect: CGRect(x: -24, y: -16, width: 48, height: 32),
            cornerWidth: 8,
            cornerHeight: 8,
            transform: nil
        )
        fillColor = color
        strokeColor = .black
        lineWidth = 2
        zPosition = 20

        let frontMarker = SKShapeNode(circleOfRadius: 5)
        frontMarker.fillColor = .white
        frontMarker.strokeColor = .clear
        frontMarker.position = CGPoint(x: 16, y: 0)
        addChild(frontMarker)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GameScene: SKScene {
    private let lapsToWin = 3
    private let startLineHalfWidth: CGFloat = 170

    private var worldNode = SKNode()
    private var hudNode = SKNode()

    private var player = CartNode(
        cartName: "You",
        color: .systemGreen,
        isPlayerCart: true,
        topSpeed: 640,
        acceleration: 520
    )
    private var aiCarts: [CartNode] = []

    private var waypointLoop: [CGPoint] = []
    private var shelfFrames: [CGRect] = []
    private var carts: [CartNode] {
        [player] + aiCarts
    }

    private var lastUpdateTime: TimeInterval = 0
    private var raceStartTime: TimeInterval?
    private var raceFinished = false

    private var steeringInput: CGFloat = 0
    private var throttleInput: CGFloat = 0
    private var brakeInput: CGFloat = 0
    private var activeTouches: [ObjectIdentifier: CGPoint] = [:]

    private var lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var positionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var hintLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private var finishLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    private var centerPoint: CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    private var startLineY: CGFloat {
        centerPoint.y - 620
    }

    private var mapBounds: CGRect {
        CGRect(
            x: centerPoint.x - 760,
            y: centerPoint.y - 760,
            width: 1520,
            height: 1520
        )
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
        isUserInteractionEnabled = true

        removeAllChildren()
        worldNode.removeAllChildren()
        hudNode.removeAllChildren()

        addChild(worldNode)
        addChild(hudNode)

        buildTrack()
        spawnCarts()
        buildHUD()
    }

    private func buildTrack() {
        let floor = SKShapeNode(rect: mapBounds)
        floor.fillColor = SKColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = 0
        worldNode.addChild(floor)

        let storeBorder = SKShapeNode(rect: mapBounds.insetBy(dx: 18, dy: 18))
        storeBorder.strokeColor = SKColor(red: 0.35, green: 0.35, blue: 0.42, alpha: 1)
        storeBorder.lineWidth = 10
        storeBorder.fillColor = .clear
        storeBorder.zPosition = 1
        worldNode.addChild(storeBorder)

        waypointLoop = [
            CGPoint(x: centerPoint.x - 380, y: centerPoint.y - 620),
            CGPoint(x: centerPoint.x + 380, y: centerPoint.y - 620),
            CGPoint(x: centerPoint.x + 620, y: centerPoint.y - 360),
            CGPoint(x: centerPoint.x + 620, y: centerPoint.y + 360),
            CGPoint(x: centerPoint.x + 380, y: centerPoint.y + 620),
            CGPoint(x: centerPoint.x - 380, y: centerPoint.y + 620),
            CGPoint(x: centerPoint.x - 620, y: centerPoint.y + 360),
            CGPoint(x: centerPoint.x - 620, y: centerPoint.y - 360)
        ]

        let route = CGMutablePath()
        route.move(to: waypointLoop[0])
        for point in waypointLoop.dropFirst() {
            route.addLine(to: point)
        }
        route.closeSubpath()

        let routeNode = SKShapeNode(path: route)
        routeNode.strokeColor = SKColor(red: 0.9, green: 0.9, blue: 0.24, alpha: 1)
        routeNode.lineWidth = 12
        routeNode.glowWidth = 2
        routeNode.fillColor = .clear
        routeNode.zPosition = 5
        worldNode.addChild(routeNode)

        let startLine = SKShapeNode(rectOf: CGSize(width: startLineHalfWidth * 2, height: 16))
        startLine.position = CGPoint(x: centerPoint.x, y: startLineY)
        startLine.fillColor = .white
        startLine.strokeColor = .black
        startLine.lineWidth = 2
        startLine.zPosition = 7
        worldNode.addChild(startLine)

        let laneMarkers = SKShapeNode(path: route)
        laneMarkers.strokeColor = SKColor(red: 1, green: 1, blue: 1, alpha: 0.35)
        laneMarkers.lineWidth = 3
        laneMarkers.lineDashPattern = [16, 20]
        laneMarkers.zPosition = 6
        worldNode.addChild(laneMarkers)

        buildShelves()
    }

    private func buildShelves() {
        let shelfColor = SKColor(red: 0.4, green: 0.28, blue: 0.12, alpha: 1)
        let center = centerPoint

        let shelfSpecs: [CGRect] = [
            CGRect(x: center.x - 420, y: center.y - 420, width: 90, height: 840),
            CGRect(x: center.x - 220, y: center.y - 500, width: 90, height: 1000),
            CGRect(x: center.x - 20, y: center.y - 440, width: 90, height: 880),
            CGRect(x: center.x + 180, y: center.y - 500, width: 90, height: 1000),
            CGRect(x: center.x + 380, y: center.y - 420, width: 90, height: 840),
            CGRect(x: center.x - 710, y: center.y - 80, width: 120, height: 170),
            CGRect(x: center.x + 590, y: center.y - 80, width: 120, height: 170),
            CGRect(x: center.x - 120, y: center.y + 650, width: 240, height: 95),
            CGRect(x: center.x - 120, y: center.y - 745, width: 240, height: 95)
        ]

        shelfFrames = shelfSpecs

        for rect in shelfSpecs {
            let shelfNode = SKShapeNode(rect: rect, cornerRadius: 8)
            shelfNode.fillColor = shelfColor
            shelfNode.strokeColor = SKColor(red: 0.2, green: 0.14, blue: 0.08, alpha: 1)
            shelfNode.lineWidth = 3
            shelfNode.zPosition = 10
            worldNode.addChild(shelfNode)
        }
    }

    private func spawnCarts() {
        player.removeFromParent()
        aiCarts.removeAll()

        player.position = CGPoint(x: centerPoint.x - 70, y: startLineY - 60)
        player.heading = .pi / 2
        player.speed = 0
        player.lap = 1
        player.lapGateArmed = false
        player.nextWaypointIndex = 1
        player.zRotation = player.heading
        worldNode.addChild(player)

        let aiColors: [SKColor] = [.systemRed, .systemBlue, .systemOrange]
        let aiNames = ["Aisle Ace", "Turbo Trolley", "Checkout Comet"]
        let aiOffsets: [CGFloat] = [0, 55, 110]

        for index in 0..<aiColors.count {
            let ai = CartNode(
                cartName: aiNames[index],
                color: aiColors[index],
                isPlayerCart: false,
                topSpeed: 580 + CGFloat(index * 20),
                acceleration: 420
            )
            ai.position = CGPoint(x: centerPoint.x + aiOffsets[index], y: startLineY - 95)
            ai.heading = .pi / 2
            ai.lap = 1
            ai.nextWaypointIndex = 1
            ai.lapGateArmed = false
            ai.zRotation = ai.heading
            aiCarts.append(ai)
            worldNode.addChild(ai)
        }
    }

    private func buildHUD() {
        lapLabel.fontSize = 42
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.verticalAlignmentMode = .center
        lapLabel.position = CGPoint(x: 48, y: size.height - 80)
        lapLabel.zPosition = 200
        hudNode.addChild(lapLabel)

        positionLabel.fontSize = 38
        positionLabel.horizontalAlignmentMode = .left
        positionLabel.verticalAlignmentMode = .center
        positionLabel.position = CGPoint(x: 48, y: size.height - 130)
        positionLabel.zPosition = 200
        hudNode.addChild(positionLabel)

        timerLabel.fontSize = 34
        timerLabel.horizontalAlignmentMode = .right
        timerLabel.verticalAlignmentMode = .center
        timerLabel.position = CGPoint(x: size.width - 48, y: size.height - 88)
        timerLabel.zPosition = 200
        hudNode.addChild(timerLabel)

        hintLabel.fontSize = 24
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width * 0.5, y: 74)
        hintLabel.fontColor = SKColor(white: 1, alpha: 0.8)
        hintLabel.zPosition = 200
        hintLabel.text = "Left side: steer   Right side top: gas   Right side bottom: brake"
        hudNode.addChild(hintLabel)

        finishLabel.fontSize = 52
        finishLabel.horizontalAlignmentMode = .center
        finishLabel.verticalAlignmentMode = .center
        finishLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        finishLabel.fontColor = .systemYellow
        finishLabel.zPosition = 220
        finishLabel.text = ""
        hudNode.addChild(finishLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTouches(touches, remove: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTouches(touches, remove: false)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTouches(touches, remove: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTouches(touches, remove: true)
    }

    private func updateTouches(_ touches: Set<UITouch>, remove: Bool) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if remove {
                activeTouches.removeValue(forKey: id)
            } else {
                activeTouches[id] = touch.location(in: self)
            }
        }
        refreshInputs()
    }

    private func refreshInputs() {
        steeringInput = 0
        throttleInput = 0
        brakeInput = 0

        for point in activeTouches.values {
            let normalizedX = ((point.x / max(size.width, 1)) * 2) - 1
            if normalizedX < 0 {
                steeringInput += normalizedX
            } else if point.y > size.height * 0.45 {
                throttleInput = 1
            } else {
                brakeInput = 1
            }
        }

        steeringInput = clamp(steeringInput, min: -1, max: 1)
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            raceStartTime = currentTime
            return
        }

        var deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        deltaTime = min(max(deltaTime, 1.0 / 240.0), 1.0 / 30.0)
        let dt = CGFloat(deltaTime)

        if !raceFinished {
            updatePlayer(dt: dt)
        } else {
            player.speed = max(player.speed - 420 * dt, 0)
        }

        updateAICarts(dt: dt)
        resolveCartCollisions()
        updateHUD(currentTime: currentTime)
        updateCamera()
    }

    private func updatePlayer(dt: CGFloat) {
        let steeringPower = 2.8 + ((player.speed / max(player.topSpeed, 1)) * 2.0)
        player.heading += steeringInput * steeringPower * dt

        if throttleInput > 0 {
            player.speed += player.acceleration * throttleInput * dt
        } else {
            player.speed -= 180 * dt
        }

        if brakeInput > 0 {
            player.speed -= 650 * brakeInput * dt
        }

        player.speed = clamp(player.speed, min: 0, max: player.topSpeed)
        move(cart: player, dt: dt)
    }

    private func updateAICarts(dt: CGFloat) {
        for (index, cart) in aiCarts.enumerated() {
            let target = waypointLoop[cart.nextWaypointIndex]
            let dx = target.x - cart.position.x
            let dy = target.y - cart.position.y
            let distance = hypot(dx, dy)

            if distance < 95 {
                cart.nextWaypointIndex = (cart.nextWaypointIndex + 1) % waypointLoop.count
            }

            let desiredHeading = atan2(dy, dx)
            let turn = shortestSignedAngle(from: cart.heading, to: desiredHeading)
            let maxTurn = (2.2 + CGFloat(index) * 0.2) * dt
            cart.heading += clamp(turn, min: -maxTurn, max: maxTurn)

            let targetSpeed = cart.topSpeed - (CGFloat(index) * 12)
            cart.speed += (targetSpeed - cart.speed) * min(1, dt * 2.0)

            move(cart: cart, dt: dt)
        }
    }

    private func move(cart: CartNode, dt: CGFloat) {
        let oldPosition = cart.position

        let velocity = CGVector(
            dx: cos(cart.heading) * cart.speed * dt,
            dy: sin(cart.heading) * cart.speed * dt
        )

        cart.position.x += velocity.dx
        cart.position.y += velocity.dy
        cart.zRotation = cart.heading

        constrain(cart: cart)
        resolveShelfCollisions(for: cart)
        updateProgress(for: cart, oldPosition: oldPosition)
    }

    private func constrain(cart: CartNode) {
        if cart.position.x < mapBounds.minX {
            cart.position.x = mapBounds.minX
            cart.speed *= 0.6
        } else if cart.position.x > mapBounds.maxX {
            cart.position.x = mapBounds.maxX
            cart.speed *= 0.6
        }

        if cart.position.y < mapBounds.minY {
            cart.position.y = mapBounds.minY
            cart.speed *= 0.6
        } else if cart.position.y > mapBounds.maxY {
            cart.position.y = mapBounds.maxY
            cart.speed *= 0.6
        }
    }

    private func resolveShelfCollisions(for cart: CartNode) {
        for frame in shelfFrames {
            let expanded = frame.insetBy(dx: -30, dy: -30)
            guard expanded.contains(cart.position) else {
                continue
            }

            let left = abs(cart.position.x - expanded.minX)
            let right = abs(expanded.maxX - cart.position.x)
            let bottom = abs(cart.position.y - expanded.minY)
            let top = abs(expanded.maxY - cart.position.y)
            let smallest = min(left, right, bottom, top)

            if smallest == left {
                cart.position.x = expanded.minX
            } else if smallest == right {
                cart.position.x = expanded.maxX
            } else if smallest == bottom {
                cart.position.y = expanded.minY
            } else {
                cart.position.y = expanded.maxY
            }

            cart.speed *= 0.48
        }
    }

    private func resolveCartCollisions() {
        let allCarts = carts
        for firstIndex in 0..<allCarts.count {
            for secondIndex in (firstIndex + 1)..<allCarts.count {
                let first = allCarts[firstIndex]
                let second = allCarts[secondIndex]

                let dx = second.position.x - first.position.x
                let dy = second.position.y - first.position.y
                let distance = hypot(dx, dy)
                let minimumDistance: CGFloat = 56

                if distance > 0, distance < minimumDistance {
                    let overlap = minimumDistance - distance
                    let normal = CGVector(dx: dx / distance, dy: dy / distance)
                    first.position.x -= normal.dx * overlap * 0.5
                    first.position.y -= normal.dy * overlap * 0.5
                    second.position.x += normal.dx * overlap * 0.5
                    second.position.y += normal.dy * overlap * 0.5

                    first.speed *= 0.9
                    second.speed *= 0.9
                }
            }
        }
    }

    private func updateProgress(for cart: CartNode, oldPosition: CGPoint) {
        let target = waypointLoop[cart.nextWaypointIndex]
        let toTarget = hypot(target.x - cart.position.x, target.y - cart.position.y)
        if toTarget < 90 {
            cart.nextWaypointIndex = (cart.nextWaypointIndex + 1) % waypointLoop.count
        }

        if cart.position.y > centerPoint.y + 500 {
            cart.lapGateArmed = true
        }

        let crossedStartLine =
            oldPosition.y < startLineY &&
            cart.position.y >= startLineY &&
            abs(cart.position.x - centerPoint.x) < startLineHalfWidth

        if crossedStartLine && cart.lapGateArmed {
            cart.lap += 1
            cart.lapGateArmed = false

            if cart.isPlayerCart, cart.lap > lapsToWin {
                raceFinished = true
                finishLabel.text = "Finished! Rank \(playerRacePosition())/\(carts.count)"
                finishLabel.run(.sequence([
                    .fadeAlpha(to: 1, duration: 0.1),
                    .scale(to: 1.05, duration: 0.15),
                    .scale(to: 1.0, duration: 0.15)
                ]))
            }
        }
    }

    private func updateHUD(currentTime: TimeInterval) {
        let shownLap = min(player.lap, lapsToWin)
        lapLabel.text = "Lap \(shownLap)/\(lapsToWin)"
        positionLabel.text = "Place \(playerRacePosition())/\(carts.count)"

        if let raceStartTime = raceStartTime {
            timerLabel.text = formatTime(max(0, currentTime - raceStartTime))
        } else {
            timerLabel.text = "00:00.00"
        }
    }

    private func updateCamera() {
        let lookAhead = CGVector(
            dx: cos(player.heading) * 150,
            dy: sin(player.heading) * 150
        )

        let target = CGPoint(
            x: (size.width * 0.5) - player.position.x - lookAhead.dx,
            y: (size.height * 0.42) - player.position.y - lookAhead.dy
        )

        worldNode.position.x += (target.x - worldNode.position.x) * 0.14
        worldNode.position.y += (target.y - worldNode.position.y) * 0.14
    }

    private func playerRacePosition() -> Int {
        let sorted = carts.sorted { progressScore(for: $0) > progressScore(for: $1) }
        return (sorted.firstIndex(where: { $0 === player }) ?? 0) + 1
    }

    private func progressScore(for cart: CartNode) -> CGFloat {
        let target = waypointLoop[cart.nextWaypointIndex]
        let distanceToTarget = hypot(target.x - cart.position.x, target.y - cart.position.y)
        return (CGFloat(cart.lap) * 10_000) + (CGFloat(cart.nextWaypointIndex) * 1_000) - distanceToTarget
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func shortestSignedAngle(from: CGFloat, to: CGFloat) -> CGFloat {
        var angle = to - from
        while angle > .pi {
            angle -= 2 * .pi
        }
        while angle < -.pi {
            angle += 2 * .pi
        }
        return angle
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let centiseconds = Int((interval * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}
