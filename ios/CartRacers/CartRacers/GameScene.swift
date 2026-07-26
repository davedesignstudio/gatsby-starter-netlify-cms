import SpriteKit

final class StoreCartRaceScene: SKScene {
    private enum RaceState {
        case running
        case finished
        case crashed
    }

    private enum PickupKind: String {
        case boost
        case pantry
    }

    private let totalLaps = 3
    private let lapLength: CGFloat = 3400
    private let baseSpeed: CGFloat = 270
    private let maxCartDurability = 3

    private var raceState: RaceState = .running
    private var lastUpdateTime: TimeInterval = 0
    private var desiredPlayerX: CGFloat = 0
    private var currentLap = 1
    private var score = 0
    private var cartDurability = 3
    private var raceDistance: CGFloat = 0
    private var boostRemaining: CGFloat = 0
    private var hitCooldown: CGFloat = 0
    private var nextHazardTime: TimeInterval = 0
    private var nextPickupTime: TimeInterval = 0
    private var nextRivalTime: TimeInterval = 0

    private let player = SKNode()
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var tileRows: [SKNode] = []
    private var shelfRows: [SKNode] = []
    private var hazards: [SKNode] = []
    private var pickups: [SKNode] = []
    private var rivals: [SKNode] = []

    private var trackWidth: CGFloat {
        min(size.width * 0.86, 460)
    }

    private var leftTrackEdge: CGFloat {
        (size.width - trackWidth) / 2 + 24
    }

    private var rightTrackEdge: CGFloat {
        (size.width + trackWidth) / 2 - 24
    }

    private var playerY: CGFloat {
        max(96, size.height * 0.18)
    }

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        setupGame()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHud()
        desiredPlayerX = clampedToTrack(desiredPlayerX)
        player.position = CGPoint(x: desiredPlayerX, y: playerY)
    }

    override func update(_ currentTime: TimeInterval) {
        guard raceState == .running else {
            lastUpdateTime = currentTime
            return
        }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let deltaTime = min(CGFloat(currentTime - lastUpdateTime), 1 / 20)
        lastUpdateTime = currentTime

        boostRemaining = max(0, boostRemaining - deltaTime)
        hitCooldown = max(0, hitCooldown - deltaTime)

        let currentSpeed = baseSpeed * (boostRemaining > 0 ? 1.55 : 1)
        raceDistance += currentSpeed * deltaTime
        advanceLapIfNeeded()

        let steeringEase = min(1, deltaTime * 9)
        player.position.x += (desiredPlayerX - player.position.x) * steeringEase
        player.position.y = playerY

        scrollDecor(by: currentSpeed * deltaTime)
        spawnObjectsIfNeeded(currentTime: currentTime)
        moveRaceObjects(by: currentSpeed * deltaTime)
        detectCollisions()
        removeOffscreenObjects()
        updateHud()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches)
    }

    private func setupGame() {
        removeAllChildren()
        removeAllActions()

        raceState = .running
        lastUpdateTime = 0
        desiredPlayerX = size.width / 2
        currentLap = 1
        score = 0
        cartDurability = maxCartDurability
        raceDistance = 0
        boostRemaining = 0
        hitCooldown = 0
        nextHazardTime = 0.6
        nextPickupTime = 1.2
        nextRivalTime = 2.0
        tileRows = []
        shelfRows = []
        hazards = []
        pickups = []
        rivals = []

        buildStoreFloor()
        buildHud()
        buildPlayer()
        updateHud()
        flashMessage("Drag to steer. Finish 3 laps.")
    }

    private func buildStoreFloor() {
        let backdrop = SKShapeNode(rectOf: CGSize(width: trackWidth, height: size.height + 220), cornerRadius: 28)
        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop.fillColor = SKColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1)
        backdrop.strokeColor = SKColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        backdrop.lineWidth = 4
        backdrop.zPosition = 0
        addChild(backdrop)

        let leftWall = makeWall()
        leftWall.position = CGPoint(x: leftTrackEdge - 18, y: size.height / 2)
        addChild(leftWall)

        let rightWall = makeWall()
        rightWall.position = CGPoint(x: rightTrackEdge + 18, y: size.height / 2)
        addChild(rightWall)

        for index in 0..<12 {
            let row = makeTileRow()
            row.position = CGPoint(x: size.width / 2, y: CGFloat(index) * 82 - 80)
            tileRows.append(row)
            addChild(row)
        }

        for index in 0..<8 {
            let row = makeShelfRow()
            row.position = CGPoint(x: size.width / 2, y: CGFloat(index) * 138 - 60)
            shelfRows.append(row)
            addChild(row)
        }
    }

    private func makeWall() -> SKNode {
        let wall = SKShapeNode(rectOf: CGSize(width: 18, height: size.height + 260), cornerRadius: 9)
        wall.fillColor = SKColor(red: 0.46, green: 0.21, blue: 0.12, alpha: 1)
        wall.strokeColor = SKColor(red: 0.70, green: 0.36, blue: 0.18, alpha: 1)
        wall.lineWidth = 2
        wall.zPosition = 2
        return wall
    }

    private func makeTileRow() -> SKNode {
        let row = SKNode()
        row.zPosition = 1

        let centerLine = SKShapeNode(rectOf: CGSize(width: trackWidth - 50, height: 2), cornerRadius: 1)
        centerLine.fillColor = SKColor(white: 1, alpha: 0.12)
        centerLine.strokeColor = .clear
        row.addChild(centerLine)

        return row
    }

    private func makeShelfRow() -> SKNode {
        let row = SKNode()
        row.zPosition = 3

        let shelfOffsets = [-trackWidth * 0.24, trackWidth * 0.24]
        for offset in shelfOffsets {
            let shelf = SKShapeNode(rectOf: CGSize(width: 76, height: 24), cornerRadius: 6)
            shelf.position = CGPoint(x: offset, y: 0)
            shelf.fillColor = SKColor(red: 0.22, green: 0.31, blue: 0.42, alpha: 1)
            shelf.strokeColor = SKColor(red: 0.48, green: 0.60, blue: 0.72, alpha: 1)
            shelf.lineWidth = 2
            row.addChild(shelf)

            for itemIndex in 0..<3 {
                let item = SKShapeNode(rectOf: CGSize(width: 14, height: 12), cornerRadius: 2)
                item.position = CGPoint(x: offset - 22 + CGFloat(itemIndex) * 22, y: 0)
                item.fillColor = itemIndex == 1
                    ? SKColor(red: 0.98, green: 0.80, blue: 0.28, alpha: 1)
                    : SKColor(red: 0.86, green: 0.35, blue: 0.26, alpha: 1)
                item.strokeColor = .clear
                row.addChild(item)
            }
        }

        return row
    }

    private func buildHud() {
        titleLabel.fontSize = 22
        titleLabel.fontColor = SKColor(red: 0.98, green: 0.93, blue: 0.72, alpha: 1)
        titleLabel.zPosition = 100
        titleLabel.text = "Aisle Dash: Cart Racers"
        addChild(titleLabel)

        statusLabel.fontSize = 15
        statusLabel.fontColor = .white
        statusLabel.zPosition = 100
        statusLabel.horizontalAlignmentMode = .center
        addChild(statusLabel)

        messageLabel.fontSize = 24
        messageLabel.fontColor = SKColor(red: 0.98, green: 0.93, blue: 0.72, alpha: 1)
        messageLabel.zPosition = 101
        messageLabel.numberOfLines = 3
        messageLabel.preferredMaxLayoutWidth = min(size.width - 48, 360)
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        addChild(messageLabel)

        layoutHud()
    }

    private func layoutHud() {
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 54)
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height - 82)
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        messageLabel.preferredMaxLayoutWidth = min(size.width - 48, 360)
    }

    private func buildPlayer() {
        player.removeAllChildren()
        let cart = makeCart(color: SKColor(red: 0.20, green: 0.78, blue: 0.86, alpha: 1), label: "YOU")
        player.addChild(cart)
        player.position = CGPoint(x: desiredPlayerX, y: playerY)
        player.zPosition = 30
        addChild(player)
    }

    private func makeCart(color: SKColor, label: String) -> SKNode {
        let cart = SKNode()

        let basket = SKShapeNode(rectOf: CGSize(width: 52, height: 72), cornerRadius: 11)
        basket.fillColor = color
        basket.strokeColor = .white
        basket.lineWidth = 3
        cart.addChild(basket)

        let basketLines = SKShapeNode(rectOf: CGSize(width: 36, height: 48), cornerRadius: 6)
        basketLines.fillColor = .clear
        basketLines.strokeColor = SKColor(white: 1, alpha: 0.45)
        basketLines.lineWidth = 2
        cart.addChild(basketLines)

        let handle = SKShapeNode(rectOf: CGSize(width: 62, height: 8), cornerRadius: 4)
        handle.position = CGPoint(x: 0, y: 42)
        handle.fillColor = SKColor(white: 0.92, alpha: 1)
        handle.strokeColor = .clear
        cart.addChild(handle)

        let cargo = SKShapeNode(rectOf: CGSize(width: 32, height: 14), cornerRadius: 4)
        cargo.position = CGPoint(x: 0, y: -8)
        cargo.fillColor = SKColor(red: 0.55, green: 0.34, blue: 0.18, alpha: 1)
        cargo.strokeColor = SKColor(red: 0.85, green: 0.66, blue: 0.39, alpha: 1)
        cargo.lineWidth = 2
        cart.addChild(cargo)

        for xOffset in [-25, 25] {
            for yOffset in [-32, 29] {
                let wheel = SKShapeNode(circleOfRadius: 6)
                wheel.position = CGPoint(x: xOffset, y: yOffset)
                wheel.fillColor = SKColor(white: 0.07, alpha: 1)
                wheel.strokeColor = SKColor(white: 0.8, alpha: 1)
                wheel.lineWidth = 1
                cart.addChild(wheel)
            }
        }

        let labelNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
        labelNode.text = label
        labelNode.fontSize = 9
        labelNode.fontColor = .white
        labelNode.verticalAlignmentMode = .center
        labelNode.position = CGPoint(x: 0, y: 12)
        cart.addChild(labelNode)

        return cart
    }

    private func scrollDecor(by distance: CGFloat) {
        for row in tileRows {
            row.position.y -= distance
            if row.position.y < -90 {
                row.position.y += 12 * 82
            }
        }

        for row in shelfRows {
            row.position.y -= distance * 0.92
            if row.position.y < -90 {
                row.position.y += 8 * 138
            }
        }
    }

    private func spawnObjectsIfNeeded(currentTime: TimeInterval) {
        if currentTime >= nextHazardTime {
            spawnHazard()
            nextHazardTime = currentTime + TimeInterval(CGFloat.random(in: 0.55...1.0))
        }

        if currentTime >= nextPickupTime {
            spawnPickup()
            nextPickupTime = currentTime + TimeInterval(CGFloat.random(in: 1.4...2.4))
        }

        if currentTime >= nextRivalTime {
            spawnRival()
            nextRivalTime = currentTime + TimeInterval(CGFloat.random(in: 2.2...3.4))
        }
    }

    private func spawnHazard() {
        let hazardType = Int.random(in: 0...2)
        let hazard: SKNode

        switch hazardType {
        case 0:
            hazard = makeSpill()
        case 1:
            hazard = makeBoxStack()
        default:
            hazard = makeCautionSign()
        }

        hazard.position = CGPoint(x: randomTrackX(margin: 44), y: size.height + 70)
        hazard.zPosition = 20
        hazards.append(hazard)
        addChild(hazard)
    }

    private func makeSpill() -> SKNode {
        let spill = SKShapeNode(ellipseOf: CGSize(width: 62, height: 34))
        spill.fillColor = SKColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 0.80)
        spill.strokeColor = SKColor(red: 0.70, green: 0.90, blue: 1.0, alpha: 0.95)
        spill.lineWidth = 3
        return spill
    }

    private func makeBoxStack() -> SKNode {
        let stack = SKNode()
        for index in 0..<3 {
            let box = SKShapeNode(rectOf: CGSize(width: 42, height: 28), cornerRadius: 4)
            box.position = CGPoint(x: CGFloat(index - 1) * 16, y: CGFloat(index) * 11)
            box.fillColor = SKColor(red: 0.62, green: 0.39, blue: 0.18, alpha: 1)
            box.strokeColor = SKColor(red: 0.92, green: 0.70, blue: 0.38, alpha: 1)
            box.lineWidth = 2
            stack.addChild(box)
        }
        return stack
    }

    private func makeCautionSign() -> SKNode {
        let sign = SKNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 32))
        path.addLine(to: CGPoint(x: -28, y: -24))
        path.addLine(to: CGPoint(x: 28, y: -24))
        path.closeSubpath()

        let triangle = SKShapeNode(path: path)
        triangle.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.16, alpha: 1)
        triangle.strokeColor = SKColor(red: 0.15, green: 0.12, blue: 0.04, alpha: 1)
        triangle.lineWidth = 3
        sign.addChild(triangle)

        let mark = SKLabelNode(fontNamed: "AvenirNext-Bold")
        mark.text = "!"
        mark.fontSize = 32
        mark.fontColor = SKColor(red: 0.12, green: 0.09, blue: 0.03, alpha: 1)
        mark.verticalAlignmentMode = .center
        mark.position = CGPoint(x: 0, y: -4)
        sign.addChild(mark)

        return sign
    }

    private func spawnPickup() {
        let isBoost = Bool.random()
        let pickup = isBoost ? makeBoostPickup() : makePantryPickup()
        pickup.position = CGPoint(x: randomTrackX(margin: 42), y: size.height + 70)
        pickup.zPosition = 19
        pickup.userData = NSMutableDictionary(dictionary: [
            "kind": isBoost ? PickupKind.boost.rawValue : PickupKind.pantry.rawValue
        ])
        pickups.append(pickup)
        addChild(pickup)
    }

    private func makeBoostPickup() -> SKNode {
        let coupon = SKShapeNode(rectOf: CGSize(width: 62, height: 30), cornerRadius: 7)
        coupon.fillColor = SKColor(red: 0.99, green: 0.72, blue: 0.18, alpha: 1)
        coupon.strokeColor = .white
        coupon.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "BOOST"
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.18, green: 0.10, blue: 0.02, alpha: 1)
        label.verticalAlignmentMode = .center
        coupon.addChild(label)

        return coupon
    }

    private func makePantryPickup() -> SKNode {
        let crate = SKShapeNode(rectOf: CGSize(width: 52, height: 38), cornerRadius: 8)
        crate.fillColor = SKColor(red: 0.24, green: 0.65, blue: 0.34, alpha: 1)
        crate.strokeColor = .white
        crate.lineWidth = 2

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+HP"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        crate.addChild(label)

        return crate
    }

    private func spawnRival() {
        let colors = [
            SKColor(red: 0.86, green: 0.24, blue: 0.23, alpha: 1),
            SKColor(red: 0.52, green: 0.35, blue: 0.94, alpha: 1),
            SKColor(red: 0.18, green: 0.62, blue: 0.38, alpha: 1)
        ]
        let rival = makeCart(color: colors.randomElement() ?? .red, label: "AI")
        rival.setScale(0.82)
        rival.position = CGPoint(x: randomTrackX(margin: 48), y: size.height + 90)
        rival.zPosition = 25
        rivals.append(rival)
        addChild(rival)
    }

    private func moveRaceObjects(by distance: CGFloat) {
        for hazard in hazards {
            hazard.position.y -= distance
        }

        for pickup in pickups {
            pickup.position.y -= distance
            pickup.zRotation += 0.08
        }

        for rival in rivals {
            rival.position.y -= distance * CGFloat.random(in: 0.92...1.08)
        }
    }

    private func detectCollisions() {
        let playerFrame = player.calculateAccumulatedFrame().insetBy(dx: 8, dy: 8)

        for hazard in hazards where playerFrame.intersects(hazard.calculateAccumulatedFrame()) {
            hitHazard(hazard)
            break
        }

        for rival in rivals where playerFrame.intersects(rival.calculateAccumulatedFrame()) {
            hitRival(rival)
            break
        }

        for pickup in pickups where playerFrame.intersects(pickup.calculateAccumulatedFrame()) {
            collectPickup(pickup)
            break
        }
    }

    private func hitHazard(_ hazard: SKNode) {
        hazard.removeFromParent()
        hazards.removeAll { $0 === hazard }
        damageCart(message: "Ouch! Store hazard.")
    }

    private func hitRival(_ rival: SKNode) {
        rival.removeFromParent()
        rivals.removeAll { $0 === rival }
        damageCart(message: "Rival cart bump.")
    }

    private func damageCart(message: String) {
        guard hitCooldown == 0 else {
            return
        }

        cartDurability -= 1
        hitCooldown = 1.0
        boostRemaining = 0
        flashMessage(message)

        player.run(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.08),
            .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.35, duration: 0.08),
            .fadeAlpha(to: 1.0, duration: 0.08)
        ]))

        if cartDurability <= 0 {
            crashRace()
        }
    }

    private func collectPickup(_ pickup: SKNode) {
        pickup.removeFromParent()
        pickups.removeAll { $0 === pickup }

        let kind = pickup.userData?["kind"] as? String
        if kind == PickupKind.boost.rawValue {
            boostRemaining = 2.5
            score += 100
            flashMessage("Coupon boost!")
        } else {
            cartDurability = min(maxCartDurability, cartDurability + 1)
            score += 75
            flashMessage("Pantry pickup!")
        }
    }

    private func advanceLapIfNeeded() {
        guard raceDistance >= lapLength else {
            return
        }

        raceDistance -= lapLength
        currentLap += 1
        score += 250

        if currentLap > totalLaps {
            finishRace()
        } else {
            flashMessage("Lap \(currentLap)!")
        }
    }

    private func finishRace() {
        raceState = .finished
        score += cartDurability * 150
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = "Pantry run complete!\nScore \(score)\nTap to race again."
    }

    private func crashRace() {
        raceState = .crashed
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.text = "Cart retired in aisle \(currentLap).\nScore \(score)\nTap to restart."
    }

    private func removeOffscreenObjects() {
        hazards.removeAll { node in
            if node.position.y < -120 {
                node.removeFromParent()
                return true
            }
            return false
        }

        pickups.removeAll { node in
            if node.position.y < -120 {
                node.removeFromParent()
                return true
            }
            return false
        }

        rivals.removeAll { node in
            if node.position.y < -140 {
                node.removeFromParent()
                return true
            }
            return false
        }
    }

    private func updateHud() {
        let lapText = "Lap \(min(currentLap, totalLaps))/\(totalLaps)"
        let boostText = boostRemaining > 0 ? "  BOOST" : ""
        statusLabel.text = "\(lapText)  Score \(score)  Durability \(cartDurability)/\(maxCartDurability)\(boostText)"
    }

    private func flashMessage(_ text: String) {
        guard raceState == .running else {
            return
        }

        messageLabel.removeAllActions()
        messageLabel.text = text
        messageLabel.alpha = 1
        messageLabel.run(.sequence([
            .wait(forDuration: 1.15),
            .fadeOut(withDuration: 0.35)
        ]))
    }

    private func handleTouches(_ touches: Set<UITouch>) {
        guard raceState == .running else {
            setupGame()
            return
        }

        guard let touch = touches.first else {
            return
        }

        desiredPlayerX = clampedToTrack(touch.location(in: self).x)
    }

    private func randomTrackX(margin: CGFloat) -> CGFloat {
        CGFloat.random(in: (leftTrackEdge + margin)...(rightTrackEdge - margin))
    }

    private func clampedToTrack(_ xPosition: CGFloat) -> CGFloat {
        min(max(xPosition, leftTrackEdge + 34), rightTrackEdge - 34)
    }
}
