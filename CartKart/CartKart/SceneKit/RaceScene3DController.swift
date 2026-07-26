import SceneKit
import SpriteKit
import Combine

enum RacePhase {
    case menu
    case countdown
    case racing
    case finished
}

final class RaceScene3DController: ObservableObject {
    @Published var phase: RacePhase = .menu
    @Published var requestMenu = false
    @Published var hudLapText = "Lap 1/3"
    @Published var hudPositionText = "1st"
    @Published var hudTimeText = "0:00.0"
    @Published var hudItemText = "Item: None"
    @Published var countdownText = "3"

    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var track: TrackDefinition = .grocery
    private var racers: [CartRacer] = []
    private var racerNodes: [SCNNode] = []
    private var aiControllers: [AIController] = []
    private var humanPlayers: [CartRacer] = []
    private var overlayScene = SKScene()
    private var input = InputManager(multiplayer: false)
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var raceTime: TimeInterval = 0
    private var countdown = 3
    private var raceStarted = false
    private var finishOrder: [CartRacer] = []
    private var multiplayer = false

    init() {
        setupCamera()
        setupLighting()
    }

    var overlaySKScene: SKScene { overlayScene }

    func startRace(track: TrackDefinition, multiplayer: Bool) {
        self.track = track
        self.multiplayer = multiplayer
        self.input = InputManager(multiplayer: multiplayer)
        resetRace()
        buildTrack()
        buildRacers()
        setupOverlay()
        phase = .countdown
        startCountdown()
        startLoop()
    }

    private func resetRace() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        racers.removeAll()
        racerNodes.removeAll()
        aiControllers.removeAll()
        humanPlayers.removeAll()
        finishOrder.removeAll()
        raceTime = 0
        countdown = 3
        raceStarted = false
        setupLighting()
        setupCamera()
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.camera?.zFar = 2000
        cameraNode.position = SCNVector3(0, 280, 320)
        cameraNode.eulerAngles = SCNVector3(-0.65, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        ambient.light?.color = UIColor(white: 0.85, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-1.1, 0.6, 0)
        scene.rootNode.addChildNode(sun)
    }

    private func buildTrack() {
        let floor = SCNBox(width: CGFloat(track.outerRect.width), height: 2, length: CGFloat(track.outerRect.height), chamferRadius: 4)
        floor.firstMaterial?.diffuse.contents = uiColor(from: track.floorColor)
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(track.outerRect.midX, -1, -track.outerRect.midY)
        scene.rootNode.addChildNode(floorNode)

        let island = SCNBox(width: CGFloat(track.innerRect.width), height: 12, length: CGFloat(track.innerRect.height), chamferRadius: 3)
        island.firstMaterial?.diffuse.contents = uiColor(from: track.islandColor)
        let islandNode = SCNNode(geometry: island)
        islandNode.position = SCNVector3(track.innerRect.midX, 6, -track.innerRect.midY)
        scene.rootNode.addChildNode(islandNode)

        addShelfLabel(track.islandLabel, at: track.innerRect)

        for (index, shelf) in track.shelfObstacles.enumerated() {
            let box = SCNBox(width: shelf.width, height: 18, length: shelf.height, chamferRadius: 2)
            box.firstMaterial?.diffuse.contents = uiColor(from: track.shelfColor)
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(shelf.midX, 9, -shelf.midY)
            scene.rootNode.addChildNode(node)

            let label = track.shelfLabels[index % track.shelfLabels.count]
            addShelfLabel(label, at: shelf)
        }

        for point in track.itemBoxPositions {
            let crate = SCNBox(width: 20, height: 20, length: 20, chamferRadius: 2)
            crate.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1)
            let node = SCNNode(geometry: crate)
            node.position = SCNVector3(point.x, 12, -point.y)
            node.name = "itemBox"
            scene.rootNode.addChildNode(node)
        }
    }

    private func addShelfLabel(_ text: String, at rect: CGRect) {
        let label = SCNText(string: text, extrusionDepth: 1)
        label.font = UIFont(name: "AvenirNext-Heavy", size: 10)
        label.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.35)
        let node = SCNNode(geometry: label)
        node.scale = SCNVector3(0.35, 0.35, 0.35)
        node.position = SCNVector3(rect.midX - 30, 14, -rect.midY)
        node.eulerAngles = SCNVector3(-.pi / 2, 0, 0)
        scene.rootNode.addChildNode(node)
    }

    private func buildRacers() {
        let names = ["You", "Player 2", "Rusty Ron", "Cart Carl"]
        let colors: [(SKColor, SKColor)] = [
            (SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1), .lightGray),
            (SKColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1), .gray),
            (SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1), SKColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)),
            (SKColor(red: 0.25, green: 0.7, blue: 0.35, alpha: 1), .gray)
        ]

        let humanCount = multiplayer ? 2 : 1

        for index in 0..<4 {
            let isHuman = index < humanCount
            let racer = CartRacer(
                name: isHuman ? (index == 0 ? "You" : "Player 2") : names[index],
                isPlayer: isHuman,
                playerSlot: index,
                bodyColor: colors[index].0,
                cartColor: colors[index].1
            )
            let grid = track.startGrid[index]
            racer.position = grid.0
            racer.zRotation = grid.1
            racers.append(racer)
            if isHuman { humanPlayers.append(racer) }

            let node = makeCartNode(color: uiColor(from: colors[index].0))
            scene.rootNode.addChildNode(node)
            racerNodes.append(node)

            if !isHuman {
                aiControllers.append(AIController(racer: racer, track: track, skill: 0.55 + CGFloat(index) * 0.1))
            }
        }
    }

    private func makeCartNode(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let cart = SCNBox(width: 28, height: 20, length: 36, chamferRadius: 3)
        cart.firstMaterial?.diffuse.contents = UIColor.lightGray
        let cartNode = SCNNode(geometry: cart)
        cartNode.position = SCNVector3(0, 10, 0)
        root.addChildNode(cartNode)

        let body = SCNCylinder(radius: 8, height: 16)
        body.firstMaterial?.diffuse.contents = color
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 24, -4)
        root.addChildNode(bodyNode)

        return root
    }

    private func setupOverlay() {
        overlayScene = SKScene(size: CGSize(width: 390, height: 844))
        overlayScene.scaleMode = .resizeFill
        overlayScene.backgroundColor = .clear
        input.addToHUD(overlayScene)
        input.layout(in: overlayScene.size)
    }

    private func startCountdown() {
        countdownText = "\(countdown)"
        SoundManager.shared.play(.countdown)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.countdown -= 1
            if self.countdown > 0 {
                self.countdownText = "\(self.countdown)"
                SoundManager.shared.play(.countdown)
                self.startCountdown()
            } else if self.countdown == 0 {
                self.countdownText = "GO!"
                SoundManager.shared.play(.go)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.countdownText = ""
                    self.raceStarted = true
                    self.phase = .racing
                }
            }
        }
    }

    private func startLoop() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTime == 0 { lastTime = link.timestamp; return }
        let delta = min(link.timestamp - lastTime, 1.0 / 30.0)
        lastTime = link.timestamp
        update(delta: delta)
    }

    private func update(delta: TimeInterval) {
        if raceStarted {
            raceTime += delta
            updateHumanInput()
            for controller in aiControllers {
                if let item = controller.update(delta: delta, racers: racers) {
                    deployItem(item, from: controller.racer)
                }
            }
        }

        for (index, racer) in racers.enumerated() {
            racer.updateMovement(delta: delta)
            keepOnTrack(racer)
            updateCheckpoint(for: racer)
            syncNode(at: index, with: racer)
        }

        updatePositions()
        updateHUD()
        updateCamera()
    }

    private func updateHumanInput() {
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

    private func syncNode(at index: Int, with racer: CartRacer) {
        let node = racerNodes[index]
        node.position = SCNVector3(racer.position.x, 0, -racer.position.y)
        node.eulerAngles = SCNVector3(0, -racer.zRotation + .pi / 2, 0)
    }

    private func keepOnTrack(_ racer: CartRacer) {
        if !track.isOnTrack(racer.position) {
            racer.position = track.nearestTrackPoint(from: racer.position)
            racer.speed *= 0.6
            SoundManager.shared.play(.collision)
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
                if racer.lap > previousLap && racer.lap < RaceState.totalLaps {
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
        racer.speed = 0
        finishOrder.append(racer)
        SoundManager.shared.play(.raceFinish)

        let humansDone = humanPlayers.allSatisfy(\.finished)
        if humansDone || finishOrder.count == racers.count {
            phase = .finished
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.requestMenu = true
            }
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
        guard let primary = humanPlayers.first else { return }
        hudLapText = "Lap \(min(primary.lap + 1, RaceState.totalLaps))/\(RaceState.totalLaps)"
        hudPositionText = ordinal(primary.racePosition)
        hudTimeText = formatTime(raceTime)
        if let item = primary.heldPowerUp {
            hudItemText = "Item: \(item.icon) \(item.displayName)"
        } else {
            hudItemText = "Item: None"
        }
    }

    private func updateCamera() {
        let target: CGPoint
        if humanPlayers.count > 1 {
            let x = humanPlayers.map(\.position.x).reduce(0, +) / CGFloat(humanPlayers.count)
            let y = humanPlayers.map(\.position.y).reduce(0, +) / CGFloat(humanPlayers.count)
            target = CGPoint(x: x, y: y)
        } else {
            target = humanPlayers.first?.position ?? .zero
        }

        let desired = SCNVector3(target.x, 280, -target.y + 320)
        cameraNode.position = SCNVector3(
            cameraNode.position.x * 0.9 + desired.x * 0.1,
            cameraNode.position.y * 0.9 + desired.y * 0.1,
            cameraNode.position.z * 0.9 + desired.z * 0.1
        )
        cameraNode.look(at: SCNVector3(target.x, 0, -target.y))
    }

    private func deployItem(_ item: PowerUpType, from racer: CartRacer) {
        switch item {
        case .couponBoost:
            racer.applyBoost()
            SoundManager.shared.play(.boost)
        case .bananaPeel, .spilledMilk, .canPyramid:
            SoundManager.shared.play(.spin)
            for other in racers where other !== racer {
                let distance = hypot(other.position.x - racer.position.x, other.position.y - racer.position.y)
                if distance < 100 { other.applySpin() }
            }
        }
    }

    func handleTouches(_ touches: Set<UITouch>, phase: UITouch.Phase) {
        input.handleTouches(touches, in: overlayScene, phase: phase)
    }

    private func uiColor(from skColor: SKColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        skColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r, green: g, blue: b, alpha: a)
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

    deinit {
        displayLink?.invalidate()
    }
}
