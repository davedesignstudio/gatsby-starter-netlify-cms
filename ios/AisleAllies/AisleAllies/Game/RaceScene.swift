import SpriteKit
import UIKit

final class RaceScene: SKScene, SKPhysicsContactDelegate {
    private weak var session: GameSession?
    private let racer: RacerStyle
    private let world = SKNode()
    private let raceCamera = SKCameraNode()

    private var player: CartNode!
    private var racers: [CartNode] = []
    private var finishedRacers: [ObjectIdentifier] = []
    private var lastUpdateTime: TimeInterval = 0
    private var raceStartTime: TimeInterval?
    private var finishTime: TimeInterval?
    private var hasReportedResult = false
    private var steeringTouches: [UITouch: CGFloat] = [:]

    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let positionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let pantryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let boostLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    init(session: GameSession, racer: RacerStyle) {
        self.session = session
        self.racer = racer
        super.init(size: CGSize(width: 1_024, height: 1_366))
        scaleMode = .aspectFill
        backgroundColor = SKColor(red: 0.07, green: 0.06, blue: 0.11, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60

        addChild(world)
        StoreTrack.build(in: world)
        createRacers()
        createCamera()
        createHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        guard player != nil else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let deltaTime = min(1.0 / 20.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        if raceStartTime == nil {
            raceStartTime = currentTime + 3.4
        }

        let canDrive = currentTime >= (raceStartTime ?? currentTime)
        updateCountdown(currentTime: currentTime)

        let steering = steeringTouches.values.reduce(0, +)
        player.updatePlayer(
            deltaTime: deltaTime,
            steering: max(-1, min(1, steering)),
            canDrive: canDrive && !player.raceProgress.isFinished
        )

        for rival in racers where !rival.isPlayer {
            let waypoint = StoreTrack.waypoints[rival.raceProgress.nextCheckpoint]
            rival.updateAI(
                deltaTime: deltaTime,
                waypoint: waypoint,
                canDrive: canDrive && !rival.raceProgress.isFinished
            )
        }

        if canDrive {
            updateRaceProgress(currentTime: currentTime)
        }
        updateCamera()
        updateHUD(currentTime: currentTime)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let cameraLocation = touch.location(in: raceCamera)
            let tappedNodes = raceCamera.nodes(at: cameraLocation)

            if tappedNodes.contains(where: { $0.name == "boostButton" }) {
                if player.useBoost() {
                    showMessage("BOOST!", color: .systemPink)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    showMessage("GRAB 3 BOXES", color: .white)
                }
                continue
            }

            steeringTouches[touch] = cameraLocation.x < 0 ? -1 : 1
            setControlHighlight(left: cameraLocation.x < 0, active: true)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where steeringTouches[touch] != nil {
            let cameraLocation = touch.location(in: raceCamera)
            steeringTouches[touch] = cameraLocation.x < 0 ? -1 : 1
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard
            let cart = cartNode(from: contact.bodyA.node) ?? cartNode(from: contact.bodyB.node)
        else { return }

        let otherNode: SKNode?
        if cartNode(from: contact.bodyA.node) != nil {
            otherNode = contact.bodyB.node
        } else {
            otherNode = contact.bodyA.node
        }

        switch otherNode?.name {
        case "pantryItem":
            cart.collectPantryItem()
            otherNode?.removeAllActions()
            otherNode?.run(.sequence([
                .group([
                    .scale(to: 1.8, duration: 0.12),
                    .fadeOut(withDuration: 0.12)
                ]),
                .removeFromParent()
            ]))
            if cart.isPlayer {
                let earnedBoost = cart.pantryItems.isMultiple(of: 3)
                showMessage(earnedBoost ? "BOOST EARNED!" : "PANTRY +1", color: .systemYellow)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        case "spill":
            cart.hitSpill()
            if cart.isPlayer {
                showMessage("SOAP SPILL!", color: .systemCyan)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        case "boostPad":
            cart.hitBoostPad()
            if cart.isPlayer {
                showMessage("EXPRESS LANE!", color: .systemPink)
            }
        default:
            break
        }
    }

    private func createRacers() {
        let playerColor: SKColor
        switch racer {
        case .sunset:
            playerColor = SKColor(red: 1, green: 0.34, blue: 0.24, alpha: 1)
        case .mint:
            playerColor = SKColor(red: 0.20, green: 0.86, blue: 0.64, alpha: 1)
        case .grape:
            playerColor = SKColor(red: 0.62, green: 0.38, blue: 0.96, alpha: 1)
        }

        player = CartNode(
            name: racer.name,
            color: playerColor,
            isPlayer: true,
            checkpointCount: StoreTrack.waypoints.count
        )
        player.position = CGPoint(x: 650, y: 430)
        world.addChild(player)
        racers.append(player)

        let rivalData: [(String, SKColor, CGPoint)] = [
            ("Patch", .systemTeal, CGPoint(x: 565, y: 520)),
            ("Nova", .systemOrange, CGPoint(x: 480, y: 610)),
            ("Beans", .systemPurple, CGPoint(x: 395, y: 700))
        ]
        for (name, color, position) in rivalData {
            let rival = CartNode(
                name: name,
                color: color,
                isPlayer: false,
                checkpointCount: StoreTrack.waypoints.count
            )
            rival.position = position
            world.addChild(rival)
            racers.append(rival)
        }
    }

    private func createCamera() {
        camera = raceCamera
        addChild(raceCamera)
        raceCamera.position = player.position
        raceCamera.setScale(0.88)
    }

    private func createHUD() {
        let topPanel = SKShapeNode(rectOf: CGSize(width: 930, height: 130), cornerRadius: 35)
        topPanel.position = CGPoint(x: 0, y: 590)
        topPanel.fillColor = .black.withAlphaComponent(0.68)
        topPanel.strokeColor = .white.withAlphaComponent(0.16)
        topPanel.lineWidth = 3
        topPanel.zPosition = 100
        raceCamera.addChild(topPanel)

        positionLabel.fontSize = 58
        positionLabel.fontColor = .systemYellow
        positionLabel.horizontalAlignmentMode = .left
        positionLabel.position = CGPoint(x: -425, y: 566)
        positionLabel.zPosition = 101
        raceCamera.addChild(positionLabel)

        lapLabel.fontSize = 25
        lapLabel.fontColor = .white
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.position = CGPoint(x: -420, y: 626)
        lapLabel.zPosition = 101
        raceCamera.addChild(lapLabel)

        timerLabel.fontSize = 34
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: 0, y: 586)
        timerLabel.zPosition = 101
        raceCamera.addChild(timerLabel)

        pantryLabel.fontSize = 29
        pantryLabel.fontColor = .systemYellow
        pantryLabel.horizontalAlignmentMode = .right
        pantryLabel.position = CGPoint(x: 425, y: 605)
        pantryLabel.zPosition = 101
        raceCamera.addChild(pantryLabel)

        boostLabel.fontSize = 21
        boostLabel.fontColor = .white
        boostLabel.horizontalAlignmentMode = .right
        boostLabel.position = CGPoint(x: 425, y: 565)
        boostLabel.zPosition = 101
        raceCamera.addChild(boostLabel)

        createSteeringControl(x: -330, symbol: "‹", name: "leftControl")
        createSteeringControl(x: 330, symbol: "›", name: "rightControl")
        createBoostButton()

        countdownLabel.fontSize = 150
        countdownLabel.fontColor = .systemYellow
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.zPosition = 110
        raceCamera.addChild(countdownLabel)

        messageLabel.fontSize = 34
        messageLabel.position = CGPoint(x: 0, y: 390)
        messageLabel.zPosition = 108
        messageLabel.alpha = 0
        raceCamera.addChild(messageLabel)
    }

    private func createSteeringControl(x: CGFloat, symbol: String, name: String) {
        let control = SKShapeNode(circleOfRadius: 105)
        control.name = name
        control.position = CGPoint(x: x, y: -505)
        control.fillColor = .black.withAlphaComponent(0.34)
        control.strokeColor = .white.withAlphaComponent(0.35)
        control.lineWidth = 5
        control.zPosition = 100

        let icon = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        icon.name = name
        icon.text = symbol
        icon.fontSize = 110
        icon.fontColor = .white.withAlphaComponent(0.72)
        icon.verticalAlignmentMode = .center
        icon.position.y = 5
        control.addChild(icon)
        raceCamera.addChild(control)
    }

    private func createBoostButton() {
        let button = SKShapeNode(circleOfRadius: 79)
        button.name = "boostButton"
        button.position = CGPoint(x: 0, y: -510)
        button.fillColor = .systemPink.withAlphaComponent(0.7)
        button.strokeColor = .white
        button.lineWidth = 7
        button.zPosition = 102

        let bolt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        bolt.name = "boostButton"
        bolt.text = "⚡"
        bolt.fontSize = 65
        bolt.verticalAlignmentMode = .center
        button.addChild(bolt)
        raceCamera.addChild(button)
    }

    private func updateCountdown(currentTime: TimeInterval) {
        guard let raceStartTime else { return }
        let remaining = raceStartTime - currentTime

        switch remaining {
        case 2.4...:
            countdownLabel.text = "3"
        case 1.4..<2.4:
            countdownLabel.text = "2"
        case 0.4..<1.4:
            countdownLabel.text = "1"
        case 0..<0.4:
            countdownLabel.text = "ROLL!"
            countdownLabel.fontSize = 90
            countdownLabel.fontColor = .systemPink
        default:
            if countdownLabel.parent != nil {
                countdownLabel.run(.sequence([
                    .group([
                        .scale(to: 1.6, duration: 0.2),
                        .fadeOut(withDuration: 0.2)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func updateRaceProgress(currentTime: TimeInterval) {
        for cart in racers where !cart.raceProgress.isFinished {
            let checkpointIndex = cart.raceProgress.nextCheckpoint
            let checkpoint = StoreTrack.waypoints[checkpointIndex]
            let distance = hypot(cart.position.x - checkpoint.x, cart.position.y - checkpoint.y)

            guard distance < 190 else { continue }
            cart.raceProgress.reachedCheckpoint(checkpointIndex)

            if cart.raceProgress.isFinished {
                finishedRacers.append(ObjectIdentifier(cart))

                if cart.isPlayer, finishTime == nil {
                    finishTime = currentTime
                    let elapsed = currentTime - (raceStartTime ?? currentTime)
                    let result = RaceResult(
                        place: finishedRacers.count,
                        time: max(0, elapsed),
                        pantryItems: cart.pantryItems
                    )
                    showMessage("FINISH!", color: .systemYellow)
                    reportResult(result)
                }
            } else if cart.isPlayer, cart.raceProgress.nextCheckpoint == 1 {
                showMessage(
                    cart.raceProgress.lap == 3 ? "FINAL LAP!" : "LAP \(cart.raceProgress.lap)",
                    color: .systemYellow
                )
            }
        }
    }

    private func updateCamera() {
        let halfWidth: CGFloat = 450
        let halfHeight: CGFloat = 600
        let x = min(
            StoreTrack.worldSize.width - halfWidth,
            max(halfWidth, player.position.x)
        )
        let y = min(
            StoreTrack.worldSize.height - halfHeight,
            max(halfHeight, player.position.y)
        )
        raceCamera.position.x += (x - raceCamera.position.x) * 0.12
        raceCamera.position.y += (y - raceCamera.position.y) * 0.12
    }

    private func updateHUD(currentTime: TimeInterval) {
        let place = currentPlace()
        positionLabel.text = ordinal(place)
        lapLabel.text = "LAP \(player.raceProgress.lap) / \(player.raceProgress.totalLaps)"

        let elapsed: TimeInterval
        if let finishTime, let start = raceStartTime {
            elapsed = finishTime - start
        } else if let start = raceStartTime {
            elapsed = max(0, currentTime - start)
        } else {
            elapsed = 0
        }
        timerLabel.text = elapsed.raceTime
        pantryLabel.text = "▣  \(player.pantryItems)"
        boostLabel.text = "BOOST  " + String(repeating: "●", count: player.boostCharges)
    }

    private func currentPlace() -> Int {
        let sorted = racers.sorted { progressScore(for: $0) > progressScore(for: $1) }
        return (sorted.firstIndex { $0 === player } ?? 0) + 1
    }

    private func progressScore(for cart: CartNode) -> CGFloat {
        if let finishIndex = finishedRacers.firstIndex(of: ObjectIdentifier(cart)) {
            return 1_000_000 - CGFloat(finishIndex)
        }

        let target = StoreTrack.waypoints[cart.raceProgress.nextCheckpoint]
        let distance = hypot(cart.position.x - target.x, cart.position.y - target.y)
        return CGFloat(cart.raceProgress.completedCheckpointCount) * 10_000 - distance
    }

    private func showMessage(_ text: String, color: SKColor) {
        messageLabel.removeAllActions()
        messageLabel.text = text
        messageLabel.fontColor = color
        messageLabel.alpha = 1
        messageLabel.setScale(0.7)
        messageLabel.run(.sequence([
            .scale(to: 1, duration: 0.12),
            .wait(forDuration: 0.65),
            .fadeOut(withDuration: 0.25)
        ]))
    }

    private func reportResult(_ result: RaceResult) {
        guard !hasReportedResult else { return }
        hasReportedResult = true
        run(.sequence([
            .wait(forDuration: 1.1),
            .run { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.session?.finishRace(result)
                }
            }
        ]))
    }

    private func cartNode(from node: SKNode?) -> CartNode? {
        var candidate = node
        while let current = candidate {
            if let cart = current as? CartNode {
                return cart
            }
            candidate = current.parent
        }
        return nil
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let direction = steeringTouches.removeValue(forKey: touch) else { continue }
            setControlHighlight(left: direction < 0, active: false)
        }
    }

    private func setControlHighlight(left: Bool, active: Bool) {
        let name = left ? "leftControl" : "rightControl"
        guard let control = raceCamera.childNode(withName: name) as? SKShapeNode else { return }
        control.fillColor = active
            ? .white.withAlphaComponent(0.25)
            : .black.withAlphaComponent(0.34)
    }

    private func ordinal(_ place: Int) -> String {
        switch place {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(place)th"
        }
    }
}
