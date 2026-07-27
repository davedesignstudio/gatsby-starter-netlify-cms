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
    private var itemBoxes: [ItemBox3D] = []
    private var hazards: [Hazard3D] = []
    private var pulseTime: TimeInterval = 0

    private struct ItemBox3D {
        let position: CGPoint
        var node: SCNNode
        var active: Bool
    }

    private struct Hazard3D {
        let node: SCNNode
        let kind: String
    }

    init() {
        setupCamera()
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
        SoundManager.shared.startRaceMusic()
    }

    private func resetRace() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        racers.removeAll()
        racerNodes.removeAll()
        aiControllers.removeAll()
        humanPlayers.removeAll()
        finishOrder.removeAll()
        itemBoxes.removeAll()
        hazards.removeAll()
        pulseTime = 0
        raceTime = 0
        countdown = 3
        raceStarted = false
        setupCamera()
        CartModelBuilder.setupTrackLighting(in: scene, track: track)
    }

    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.camera?.zFar = 2000
        cameraNode.position = SCNVector3(0, 280, 320)
        cameraNode.eulerAngles = SCNVector3(-0.65, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func buildTrack() {
        let floor = SCNBox(width: CGFloat(track.outerRect.width), height: 2, length: CGFloat(track.outerRect.height), chamferRadius: 4)
        floor.firstMaterial?.diffuse.contents = CartModelBuilder.uiColor(from: track.floorColor)
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(track.outerRect.midX, -1, -track.outerRect.midY)
        scene.rootNode.addChildNode(floorNode)

        let island = SCNBox(width: CGFloat(track.innerRect.width), height: 12, length: CGFloat(track.innerRect.height), chamferRadius: 3)
        island.firstMaterial?.diffuse.contents = CartModelBuilder.uiColor(from: track.islandColor)
        let islandNode = SCNNode(geometry: island)
        islandNode.position = SCNVector3(track.innerRect.midX, 6, -track.innerRect.midY)
        scene.rootNode.addChildNode(islandNode)

        addShelfLabel(track.islandLabel, at: track.innerRect)

        for (index, shelf) in track.shelfObstacles.enumerated() {
            let box = SCNBox(width: shelf.width, height: 18, length: shelf.height, chamferRadius: 2)
            box.firstMaterial?.diffuse.contents = CartModelBuilder.uiColor(from: track.shelfColor)
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(shelf.midX, 9, -shelf.midY)
            scene.rootNode.addChildNode(node)

            let label = track.shelfLabels[index % track.shelfLabels.count]
            addShelfLabel(label, at: shelf)
            addShelfProducts(on: shelf, seed: label)
        }

        for point in track.itemBoxPositions {
            let node = Item3DModels.makeItemBox()
            node.position = SCNVector3(point.x, 0, -point.y)
            scene.rootNode.addChildNode(node)
            itemBoxes.append(ItemBox3D(position: point, node: node, active: true))
        }
    }

    private func addShelfLabel(_ text: String, at rect: CGRect) {
        let label = SCNText(string: text, extrusionDepth: 1)
        label.font = UIFont(name: "AvenirNext-Heavy", size: 10)
        label.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.35)
        let node = SCNNode(geometry: label)
        node.scale = SCNVector3(0.35, 0.35, 0.35)
        node.position = SCNVector3(rect.midX - 30, 14, -rect.midY)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(node)
    }

    private func addShelfProducts(on shelf: CGRect, seed: String) {
        let shelfKinds: [CartBelongingKind] = [.waterBottle, .snackBag, .recycleCan, .recycleBottle, .wipesPack, .cardboardSheet]
        var hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let slots: [SCNVector3] = [
            SCNVector3(shelf.minX + shelf.width * 0.25, 20, -(shelf.minY + shelf.height * 0.35)),
            SCNVector3(shelf.midX, 20, -shelf.midY),
            SCNVector3(shelf.maxX - shelf.width * 0.25, 20, -(shelf.maxY - shelf.height * 0.35)),
        ]
        for (index, slot) in slots.enumerated() {
            hash = (hash &* 17 &+ index) % 10_000
            let kind = shelfKinds[hash % shelfKinds.count]
            let product = Item3DModels.makeCartBelonging(kind, scale: 0.35)
            product.position = slot
            product.eulerAngles = SCNVector3(0, Float(hash % 628) / 100, 0)
            scene.rootNode.addChildNode(product)
        }
    }

    private func buildRacers() {
        let settings = GameSettings.shared
        let aiCharacters: [CharacterDefinition] = [.speedySal, .driftKing, .tankTanya, .couponCarla]
        let humanCount = multiplayer ? 2 : 1

        for index in 0..<4 {
            let isHuman = index < humanCount
            let racer: CartRacer
            let character: CharacterDefinition
            if isHuman {
                character = index == 0 ? settings.selectedCharacter : settings.selectedCharacterP2
                racer = CartRacer(character: character, isPlayer: true, playerSlot: index)
            } else {
                character = aiCharacters[(index - humanCount) % aiCharacters.count]
                racer = CartRacer(character: character, isPlayer: false, playerSlot: 0)
            }

            let grid = track.startGrid[index]
            racer.position = grid.0
            racer.zRotation = grid.1
            racers.append(racer)
            if isHuman { humanPlayers.append(racer) }

            let node = CartModelBuilder.makeDetailedCart(
                bodyColor: CartModelBuilder.uiColor(from: character.bodyColor),
                cartColor: CartModelBuilder.uiColor(from: character.cartColor),
                characterSeed: character.id
            )
            scene.rootNode.addChildNode(node)
            racerNodes.append(node)

            if !isHuman {
                aiControllers.append(AIController(racer: racer, track: track, skill: 0.55 + CGFloat(index) * 0.1))
            }
        }
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
        pulseTime += delta
        if raceStarted {
            raceTime += delta
            updateHumanInput()
            for controller in aiControllers {
                if let item = controller.update(delta: delta, racers: racers) {
                    deployItem(item, from: controller.racer)
                }
            }
            checkItemPickups()
            checkHazardCollisions()
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
        CartModelBuilder.updateParticles(on: node, speed: racer.driveSpeed, drifting: racer.driftFactor > 0.1)
        CartModelBuilder.updateHeldItem(on: node, item: racer.heldPowerUp)
    }

    private func checkItemPickups() {
        for racer in racers where !racer.finished {
            for index in itemBoxes.indices where itemBoxes[index].active {
                let box = itemBoxes[index]
                let distance = hypot(racer.position.x - box.position.x, racer.position.y - box.position.y)
                if distance < 55 {
                    racer.collectPowerUp(PowerUpType.random())
                    itemBoxes[index].active = false
                    box.node.isHidden = true
                    SoundManager.shared.play(.itemPickup)
                    CartModelBuilder.updateHeldItem(on: racerNodes[racers.firstIndex(where: { $0 === racer }) ?? 0], item: racer.heldPowerUp)

                    let respawnIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                        guard let self, respawnIndex < self.itemBoxes.count else { return }
                        self.itemBoxes[respawnIndex].active = true
                        self.itemBoxes[respawnIndex].node.isHidden = false
                    }
                }
            }
        }
    }

    private func checkHazardCollisions() {
        for racer in racers where !racer.finished && racer.spinTimer <= 0 {
            for index in hazards.indices.reversed() {
                let hazard = hazards[index]
                let hx = hazard.node.position.x
                let hz = hazard.node.position.z
                let distance = hypot(racer.position.x - CGFloat(hx), racer.position.y + CGFloat(hz))
                let radius: CGFloat = hazard.kind == "milk" ? 70 : 45
                if distance < radius {
                    if hazard.kind == "banana" || hazard.kind == "milk" {
                        racer.applySpin()
                    } else if hazard.kind == "cans" {
                        racer.applySpin(duration: 0.8)
                    }
                    SoundManager.shared.play(.spin)
                    hazard.node.removeFromParentNode()
                    hazards.remove(at: index)
                }
            }
        }
    }

    private func keepOnTrack(_ racer: CartRacer) {
        if !track.isOnTrack(racer.position) {
            racer.position = track.nearestTrackPoint(from: racer.position)
            racer.driveSpeed *= 0.6
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
        racer.driveSpeed = 0
        finishOrder.append(racer)
        SoundManager.shared.play(.raceFinish)

        let humansDone = humanPlayers.allSatisfy(\.finished)
        if humansDone || finishOrder.count == racers.count {
            phase = .finished
            SoundManager.shared.stopRaceMusic()
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
        CartModelBuilder.updateHeldItem(
            on: racerNodes[racers.firstIndex(where: { $0 === racer }) ?? 0],
            item: nil
        )

        switch item {
        case .couponBoost:
            racer.applyBoost()
            SoundManager.shared.play(.boost)
        case .bananaPeel:
            spawnHazard(Item3DModels.makeBananaHazard(), kind: "banana", behind: racer, offset: 40)
            SoundManager.shared.play(.spin)
        case .spilledMilk:
            spawnHazard(Item3DModels.makeMilkPuddle(), kind: "milk", behind: racer, offset: 50)
            SoundManager.shared.play(.spin)
        case .canPyramid:
            spawnHazard(Item3DModels.makeCanHazard(), kind: "cans", behind: racer, offset: 50)
            SoundManager.shared.play(.spin)
            for other in racers where other !== racer {
                let distance = hypot(other.position.x - racer.position.x, other.position.y - racer.position.y)
                if distance < 120 { other.applySpin(duration: 0.8) }
            }
        }
    }

    private func spawnHazard(_ node: SCNNode, kind: String, behind racer: CartRacer, offset: CGFloat) {
        let x = racer.position.x - cos(racer.zRotation) * offset
        let z = -(racer.position.y - sin(racer.zRotation) * offset)
        node.position = SCNVector3(x, 0, z)
        scene.rootNode.addChildNode(node)
        hazards.append(Hazard3D(node: node, kind: kind))
    }

    func handleTouches(_ touches: Set<UITouch>, phase: UITouch.Phase) {
        input.handleTouches(touches, in: overlayScene, phase: phase)
    }

    deinit {
        displayLink?.invalidate()
        SoundManager.shared.stopRaceMusic()
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
}
