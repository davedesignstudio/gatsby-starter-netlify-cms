import SpriteKit
import UIKit

final class GameScene: SKScene {
    var playerCart: CartArchetype = .speedy

    private var racers: [CartRacer] = []
    private var hazards: [Hazard] = []
    private var projectiles: [Projectile] = []
    private var pickups: [Pickup] = []

    private var roadNode: SKShapeNode!
    private var leftShelfNode: SKShapeNode!
    private var rightShelfNode: SKShapeNode!
    private var horizonNode: SKSpriteNode!
    private var aisleLabel: SKLabelNode!
    private var placeLabel: SKLabelNode!
    private var lapLabel: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var powerLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!
    private var minimapNode: SKNode!

    private var playerCartNode: SKNode!
    private var rivalNodes: [Int: SKNode] = [:]
    private var hazardNodes: [SKNode] = []
    private var pickupNodes: [SKNode] = []

    private var steering: CGFloat = 0
    private var accelerating = false
    private var leftPressed = false
    private var rightPressed = false

    private var raceStarted = false
    private var raceFinished = false
    private var countdown: TimeInterval = 3.2
    private var finishOrder = 0
    private var cameraShake: CGFloat = 0

    private let drawRows = 80
    private var roadPath = CGMutablePath()

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.55, green: 0.62, blue: 0.68, alpha: 1)
        removeAllChildren()
        setupWorld()
        setupRacers()
        setupPickups()
        setupHUD()
        setupControls()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, !racers.isEmpty else { return }
        // Rebuild layout on rotate/resize mid-race is disruptive; keep simple.
    }

    // MARK: - Setup

    private func setupWorld() {
        horizonNode = SKSpriteNode(color: UIColor(red: 0.62, green: 0.70, blue: 0.78, alpha: 1), size: CGSize(width: size.width, height: size.height * 0.42))
        horizonNode.anchorPoint = CGPoint(x: 0.5, y: 1)
        horizonNode.position = CGPoint(x: size.width / 2, y: size.height)
        horizonNode.zPosition = -20
        addChild(horizonNode)

        // Fluorescent lights
        for i in 0..<6 {
            let light = SKSpriteNode(color: UIColor(white: 1.0, alpha: 0.18), size: CGSize(width: size.width * 0.12, height: 10))
            light.position = CGPoint(x: size.width * (0.15 + CGFloat(i) * 0.14), y: size.height * 0.93)
            light.zPosition = -19
            addChild(light)
        }

        leftShelfNode = SKShapeNode()
        leftShelfNode.fillColor = UIColor(red: 0.42, green: 0.32, blue: 0.22, alpha: 1)
        leftShelfNode.strokeColor = .clear
        leftShelfNode.zPosition = -8
        addChild(leftShelfNode)

        rightShelfNode = SKShapeNode()
        rightShelfNode.fillColor = UIColor(red: 0.42, green: 0.32, blue: 0.22, alpha: 1)
        rightShelfNode.strokeColor = .clear
        rightShelfNode.zPosition = -8
        addChild(rightShelfNode)

        roadNode = SKShapeNode()
        roadNode.fillColor = UIColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1)
        roadNode.strokeColor = .clear
        roadNode.zPosition = -10
        addChild(roadNode)

        aisleLabel = makeHUDLabel(fontSize: 18, color: .white)
        aisleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        aisleLabel.fontName = "AvenirNext-Bold"
        addChild(aisleLabel)
    }

    private func setupRacers() {
        let player = CartRacer(id: 0, archetype: playerCart, isPlayer: true, startProgress: 0)
        racers.append(player)

        let rivals = CartArchetype.allCases.filter { $0 != playerCart }.prefix(4)
        for (index, arch) in rivals.enumerated() {
            let racer = CartRacer(
                id: index + 1,
                archetype: arch,
                isPlayer: false,
                startProgress: -CGFloat(index + 1) * 18
            )
            racers.append(racer)
        }

        playerCartNode = CartArt.makeCart(archetype: playerCart, scale: 1.5)
        playerCartNode.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        playerCartNode.zPosition = 50
        addChild(playerCartNode)

        for racer in racers where !racer.isPlayer {
            let node = CartArt.makeCart(archetype: racer.archetype, scale: 0.8)
            node.zPosition = 40
            node.isHidden = true
            addChild(node)
            rivalNodes[racer.id] = node
        }
    }

    private func setupPickups() {
        let kinds = PowerUpKind.allCases
        for i in 0..<12 {
            let progress = CGFloat(i) * (StoreTrack.lapLength / 12) + 40
            let lateral = (i % 2 == 0) ? CGFloat(-0.35) : CGFloat(0.35)
            pickups.append(Pickup(progress: progress, lateral: lateral, kind: kinds[i % kinds.count]))
        }
    }

    private func setupHUD() {
        placeLabel = makeHUDLabel(fontSize: 28, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))
        placeLabel.horizontalAlignmentMode = .left
        placeLabel.position = CGPoint(x: 24, y: size.height - 40)
        placeLabel.fontName = "AvenirNext-Heavy"
        addChild(placeLabel)

        lapLabel = makeHUDLabel(fontSize: 18, color: .white)
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.position = CGPoint(x: 24, y: size.height - 68)
        addChild(lapLabel)

        speedLabel = makeHUDLabel(fontSize: 16, color: UIColor(white: 0.9, alpha: 1))
        speedLabel.horizontalAlignmentMode = .right
        speedLabel.position = CGPoint(x: size.width - 24, y: size.height - 40)
        addChild(speedLabel)

        powerLabel = makeHUDLabel(fontSize: 16, color: UIColor(red: 0.4, green: 0.95, blue: 0.85, alpha: 1))
        powerLabel.horizontalAlignmentMode = .right
        powerLabel.position = CGPoint(x: size.width - 24, y: size.height - 68)
        addChild(powerLabel)

        countdownLabel = makeHUDLabel(fontSize: 72, color: .white)
        countdownLabel.fontName = "AvenirNext-Heavy"
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        countdownLabel.zPosition = 100
        addChild(countdownLabel)

        minimapNode = SKNode()
        minimapNode.position = CGPoint(x: size.width - 70, y: 90)
        minimapNode.zPosition = 80
        addChild(minimapNode)

        let mapBG = SKShapeNode(circleOfRadius: 48)
        mapBG.fillColor = UIColor(white: 0, alpha: 0.45)
        mapBG.strokeColor = UIColor(white: 1, alpha: 0.35)
        mapBG.lineWidth = 2
        minimapNode.addChild(mapBG)
    }

    private func setupControls() {
        addControlButton(name: "left", title: "◀", x: size.width * 0.12, y: 56, color: UIColor(white: 0.2, alpha: 0.55))
        addControlButton(name: "right", title: "▶", x: size.width * 0.28, y: 56, color: UIColor(white: 0.2, alpha: 0.55))
        addControlButton(name: "gas", title: "GAS", x: size.width * 0.78, y: 56, color: UIColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 0.75))
        addControlButton(name: "use", title: "USE", x: size.width * 0.92, y: 56, color: UIColor(red: 0.55, green: 0.2, blue: 0.55, alpha: 0.75))
        addControlButton(name: "pause", title: "MENU", x: size.width * 0.5, y: 28, width: 70, height: 28, color: UIColor(white: 0.15, alpha: 0.5))
    }

    private func addControlButton(name: String, title: String, x: CGFloat, y: CGFloat, width: CGFloat = 64, height: CGFloat = 54, color: UIColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        btn.fillColor = color
        btn.strokeColor = UIColor(white: 1, alpha: 0.25)
        btn.lineWidth = 1
        btn.position = CGPoint(x: x, y: y)
        btn.name = name
        btn.zPosition = 90
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = height > 40 ? 18 : 11
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    private func makeHUDLabel(fontSize: CGFloat, color: UIColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.fontSize = fontSize
        label.fontColor = color
        label.zPosition = 80
        return label
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = 1.0 / 60.0

        if !raceStarted {
            countdown -= dt
            if countdown > 2 {
                countdownLabel.text = "3"
            } else if countdown > 1 {
                countdownLabel.text = "2"
            } else if countdown > 0 {
                countdownLabel.text = "1"
            } else {
                countdownLabel.text = "GO!"
                countdownLabel.fontColor = UIColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 1)
                raceStarted = true
                countdownLabel.run(.sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.3), .removeFromParent()]))
            }
            drawWorld()
            return
        }

        if raceFinished { return }

        updatePlayer(dt: dt)
        updateAI(dt: dt)
        updateHazards(dt: dt)
        updateProjectiles(dt: dt)
        updatePickups(dt: dt)
        resolveCollisions()
        updateHUD()
        drawWorld()
        drawRivals()
        drawMinimap()
        checkFinish()

        if cameraShake > 0 {
            cameraShake = max(0, cameraShake - CGFloat(dt) * 8)
            let shakeX = CGFloat.random(in: -cameraShake...cameraShake)
            playerCartNode.position.x = size.width / 2 + (player?.lateral ?? 0) * size.width * 0.28 + shakeX
        }
    }

    private var player: CartRacer? { racers.first(where: \.isPlayer) }

    private func updatePlayer(dt: TimeInterval) {
        guard let player else { return }
        tickTimers(for: player, dt: dt)

        if player.stunTimer > 0 {
            player.speed *= 0.92
            return
        }

        steering = 0
        if leftPressed { steering -= 1 }
        if rightPressed { steering += 1 }

        let curve = StoreTrack.curvature(at: player.progress)
        player.lateral += (steering * player.archetype.handling - curve * 0.012) * player.speed * 0.35
        player.lateral = max(-StoreTrack.trackHalfWidth, min(StoreTrack.trackHalfWidth, player.lateral))

        if abs(player.lateral) > StoreTrack.trackHalfWidth * 0.92 {
            player.speed *= 0.94
            cameraShake = max(cameraShake, 3)
        }

        if accelerating {
            player.speed = min(player.effectiveTopSpeed, player.speed + player.effectiveAccel)
        } else {
            player.speed = max(0, player.speed - 0.04)
        }

        let prev = player.progress
        player.progress += player.speed
        handleLap(racer: player, previous: prev)

        playerCartNode.position = CGPoint(
            x: size.width / 2 + player.lateral * size.width * 0.28,
            y: size.height * 0.22
        )
        playerCartNode.zRotation = -steering * 0.18 - curve * 0.08

        if let wheelL = playerCartNode.childNode(withName: "wheelL"),
           let wheelR = playerCartNode.childNode(withName: "wheelR") {
            wheelL.zRotation -= player.speed * 0.25
            wheelR.zRotation -= player.speed * 0.25
        }
    }

    private func updateAI(dt: TimeInterval) {
        guard let player else { return }

        for racer in racers where !racer.isPlayer && !racer.finished {
            tickTimers(for: racer, dt: dt)
            if racer.stunTimer > 0 {
                racer.speed *= 0.9
                continue
            }

            racer.aiDecisionTimer -= dt
            if racer.aiDecisionTimer <= 0 {
                racer.aiDecisionTimer = TimeInterval.random(in: 0.4...1.1)
                racer.aiSteerBias = CGFloat.random(in: -0.55...0.55)
                if racer.heldPowerUp != nil, Int.random(in: 0...2) == 0 {
                    usePowerUp(racer: racer)
                }
            }

            let curve = StoreTrack.curvature(at: racer.progress)
            let targetLane = racer.aiSteerBias * 0.55
            let laneError = targetLane - racer.lateral
            racer.lateral += laneError * racer.archetype.handling * 1.4
            racer.lateral -= curve * 0.01 * racer.speed
            racer.lateral = max(-StoreTrack.trackHalfWidth, min(StoreTrack.trackHalfWidth, racer.lateral))

            let gap = player.progress - racer.progress
            let rubberBand: CGFloat
            if gap > 80 {
                rubberBand = 1.18
            } else if gap < -100 {
                rubberBand = 0.88
            } else {
                rubberBand = 1.0
            }

            let target = racer.effectiveTopSpeed * rubberBand * CGFloat.random(in: 0.92...1.05)
            if racer.speed < target {
                racer.speed += racer.effectiveAccel * rubberBand
            } else {
                racer.speed -= 0.03
            }
            racer.speed = max(0, min(racer.effectiveTopSpeed * 1.25, racer.speed))

            let prev = racer.progress
            racer.progress += racer.speed
            handleLap(racer: racer, previous: prev)
        }
    }

    private func tickTimers(for racer: CartRacer, dt: TimeInterval) {
        if racer.stunTimer > 0 { racer.stunTimer -= dt }
        if racer.boostTimer > 0 { racer.boostTimer -= dt }
        if racer.shieldTimer > 0 { racer.shieldTimer -= dt }
    }

    private func handleLap(racer: CartRacer, previous: CGFloat) {
        if previous < StoreTrack.lapLength * CGFloat(racer.lap) &&
            racer.progress >= StoreTrack.lapLength * CGFloat(racer.lap) {
            racer.lap += 1
            if racer.lap > StoreTrack.totalLaps {
                racer.finished = true
                finishOrder += 1
                racer.finishPlace = finishOrder
                racer.speed = 0
            }
        }
    }

    // MARK: - Power-ups & hazards

    private func updatePickups(dt: TimeInterval) {
        for i in pickups.indices {
            if pickups[i].collected {
                pickups[i].respawnIn -= dt
                if pickups[i].respawnIn <= 0 {
                    pickups[i].collected = false
                }
            }
        }

        for racer in racers where !racer.finished {
            for i in pickups.indices where !pickups[i].collected {
                if abs(wrappedDelta(racer.progress, pickups[i].progress)) < 12,
                   abs(racer.lateral - pickups[i].lateral) < 0.28,
                   racer.heldPowerUp == nil {
                    racer.heldPowerUp = pickups[i].kind
                    pickups[i].collected = true
                    pickups[i].respawnIn = 7
                    if racer.isPlayer {
                        flashMessage("Got \(pickups[i].kind.label)!")
                    }
                }
            }
        }
    }

    private func updateHazards(dt: TimeInterval) {
        for i in hazards.indices.reversed() {
            hazards[i].life -= dt
            if hazards[i].life <= 0 {
                hazards.remove(at: i)
                continue
            }
            for racer in racers where !racer.finished {
                if abs(wrappedDelta(racer.progress, hazards[i].progress)) < 10,
                   abs(racer.lateral - hazards[i].lateral) < 0.22 {
                    if racer.shieldTimer > 0 {
                        racer.shieldTimer = 0
                    } else {
                        racer.stunTimer = hazards[i].kind == .spill ? 1.1 : 0.85
                        racer.speed *= 0.35
                        if racer.isPlayer { cameraShake = 8 }
                    }
                    hazards.remove(at: i)
                    break
                }
            }
        }
    }

    private func updateProjectiles(dt: TimeInterval) {
        for i in projectiles.indices.reversed() {
            projectiles[i].progress += 9.5
            projectiles[i].life -= dt
            if projectiles[i].life <= 0 {
                projectiles.remove(at: i)
                continue
            }
            for racer in racers where racer.id != projectiles[i].ownerId && !racer.finished {
                if abs(wrappedDelta(racer.progress, projectiles[i].progress)) < 14,
                   abs(racer.lateral - projectiles[i].lateral) < 0.3 {
                    if racer.shieldTimer > 0 {
                        racer.shieldTimer = 0
                    } else {
                        racer.stunTimer = 1.0
                        racer.speed *= 0.3
                        if racer.isPlayer { cameraShake = 10 }
                    }
                    projectiles.remove(at: i)
                    break
                }
            }
        }
    }

    private func resolveCollisions() {
        for i in 0..<racers.count {
            for j in (i + 1)..<racers.count {
                let a = racers[i]
                let b = racers[j]
                if a.finished || b.finished { continue }
                if abs(wrappedDelta(a.progress, b.progress)) < 10,
                   abs(a.lateral - b.lateral) < 0.24 {
                    let push: CGFloat = 0.08
                    if a.lateral < b.lateral {
                        racers[i].lateral -= push
                        racers[j].lateral += push
                    } else {
                        racers[i].lateral += push
                        racers[j].lateral -= push
                    }
                    racers[i].speed *= 0.96
                    racers[j].speed *= 0.96
                }
            }
        }
    }

    private func usePowerUp(racer: CartRacer) {
        guard let kind = racer.heldPowerUp else { return }
        racer.heldPowerUp = nil

        switch kind {
        case .banana:
            hazards.append(Hazard(progress: racer.progress - 18, lateral: racer.lateral, kind: .banana))
        case .spill:
            hazards.append(Hazard(progress: racer.progress - 14, lateral: racer.lateral + 0.1, kind: .spill))
            hazards.append(Hazard(progress: racer.progress - 20, lateral: racer.lateral - 0.15, kind: .spill))
        case .sodaBoost:
            racer.boostTimer = 1.6
            if racer.isPlayer { flashMessage("SODA BOOST!") }
        case .soupCan:
            projectiles.append(Projectile(progress: racer.progress + 20, lateral: racer.lateral, ownerId: racer.id))
        case .couponShield:
            racer.shieldTimer = 3.5
            if racer.isPlayer { flashMessage("COUPON SHIELD!") }
        }
    }

    private func wrappedDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = a - b
        let half = StoreTrack.lapLength / 2
        while d > half { d -= StoreTrack.lapLength }
        while d < -half { d += StoreTrack.lapLength }
        return d
    }

    // MARK: - Drawing

    private func drawWorld() {
        guard let player else { return }
        let sample = StoreTrack.sample(at: player.progress)
        roadNode.fillColor = sample.floorTone
        aisleLabel.text = "AISLE • \(sample.aisleName)"

        let horizonY = size.height * 0.62
        let bottomY: CGFloat = 0
        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []
        var leftShelf: [CGPoint] = []
        var rightShelf: [CGPoint] = []

        var curveAccum: CGFloat = 0
        let playerCurve = sample.curvature

        for i in 0..<drawRows {
            let t = CGFloat(i) / CGFloat(drawRows - 1)
            // Perspective: near (t=0) at bottom, far (t=1) at horizon
            let y = bottomY + (horizonY - bottomY) * (1 - pow(1 - t, 1.65))
            let perspective = 0.08 + 0.92 * pow(1 - t, 1.35)
            let halfW = size.width * 0.48 * perspective

            let lookAhead = player.progress + t * 140
            let localCurve = StoreTrack.curvature(at: lookAhead)
            curveAccum += (localCurve - playerCurve) * (1 - t) * 2.2
            let centerX = size.width / 2 - player.lateral * size.width * 0.28 * (1 - t) + curveAccum * size.width * 0.12

            leftEdge.append(CGPoint(x: centerX - halfW, y: y))
            rightEdge.append(CGPoint(x: centerX + halfW, y: y))
            leftShelf.append(CGPoint(x: centerX - halfW * 1.35, y: y + 8 * (1 - t)))
            rightShelf.append(CGPoint(x: centerX + halfW * 1.35, y: y + 8 * (1 - t)))
        }

        roadPath = CGMutablePath()
        roadPath.move(to: leftEdge[0])
        for p in leftEdge.dropFirst() { roadPath.addLine(to: p) }
        for p in rightEdge.reversed() { roadPath.addLine(to: p) }
        roadPath.closeSubpath()
        roadNode.path = roadPath

        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: 0, y: 0))
        leftPath.addLine(to: leftEdge[0])
        for p in leftEdge.dropFirst() { leftPath.addLine(to: p) }
        leftPath.addLine(to: CGPoint(x: 0, y: horizonY))
        leftPath.closeSubpath()
        leftShelfNode.path = leftPath

        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: size.width, y: 0))
        rightPath.addLine(to: rightEdge[0])
        for p in rightEdge.dropFirst() { rightPath.addLine(to: p) }
        rightPath.addLine(to: CGPoint(x: size.width, y: horizonY))
        rightPath.closeSubpath()
        rightShelfNode.path = rightPath

        // Center aisle dashes
        enumerateChildNodes(withName: "dash") { node, _ in node.removeFromParent() }
        for i in stride(from: 0, to: drawRows - 1, by: 6) {
            let t = CGFloat(i) / CGFloat(drawRows - 1)
            let y = bottomY + (horizonY - bottomY) * (1 - pow(1 - t, 1.65))
            let perspective = 0.08 + 0.92 * pow(1 - t, 1.35)
            let lookAhead = player.progress + t * 140
            let localCurve = StoreTrack.curvature(at: lookAhead)
            // Approximate center from curvature offset used above
            let centerX = size.width / 2 - player.lateral * size.width * 0.28 * (1 - t)
            let dash = SKShapeNode(rectOf: CGSize(width: 6 * perspective, height: 18 * perspective))
            dash.fillColor = UIColor(white: 1, alpha: 0.35 + 0.25 * (1 - t))
            dash.strokeColor = .clear
            dash.position = CGPoint(x: centerX + localCurve * 8, y: y)
            dash.name = "dash"
            dash.zPosition = -9
            addChild(dash)
        }

        drawPickupMarkers(playerProgress: player.progress, playerLateral: player.lateral)
        drawHazardMarkers(playerProgress: player.progress, playerLateral: player.lateral)
    }

    private func projectOnRoad(progress: CGFloat, lateral: CGFloat, playerProgress: CGFloat, playerLateral: CGFloat) -> (CGPoint, CGFloat, Bool) {
        let delta = progress - playerProgress
        if delta < -20 || delta > 160 { return (.zero, 0, false) }
        let t = max(0, min(1, delta / 160))
        let horizonY = size.height * 0.62
        let y = 0 + (horizonY - 0) * (1 - pow(1 - t, 1.65))
        let perspective = 0.08 + 0.92 * pow(1 - t, 1.35)
        let halfW = size.width * 0.48 * perspective
        let centerX = size.width / 2 - playerLateral * size.width * 0.28 * (1 - t)
        let x = centerX + lateral * halfW
        let scale = 0.25 + 1.1 * perspective
        return (CGPoint(x: x, y: y), scale, true)
    }

    private func drawRivals() {
        guard let player else { return }
        for racer in racers where !racer.isPlayer {
            guard let node = rivalNodes[racer.id] else { continue }
            let (pos, scale, visible) = projectOnRoad(
                progress: racer.progress,
                lateral: racer.lateral,
                playerProgress: player.progress,
                playerLateral: player.lateral
            )
            node.isHidden = !visible || racer.finished
            if visible {
                node.position = pos
                node.setScale(scale)
                node.zPosition = 20 + scale * 20
            }
        }
    }

    private func drawPickupMarkers(playerProgress: CGFloat, playerLateral: CGFloat) {
        pickupNodes.forEach { $0.removeFromParent() }
        pickupNodes.removeAll()
        for pickup in pickups where !pickup.collected {
            let (pos, scale, visible) = projectOnRoad(
                progress: pickup.progress + CGFloat(Int(playerProgress / StoreTrack.lapLength)) * StoreTrack.lapLength,
                lateral: pickup.lateral,
                playerProgress: playerProgress,
                playerLateral: playerLateral
            )
            // Also try relative lap wrapping
            let absProgress = nearestLapProgress(pickup.progress, near: playerProgress)
            let projected = projectOnRoad(progress: absProgress, lateral: pickup.lateral, playerProgress: playerProgress, playerLateral: playerLateral)
            guard projected.2 else { continue }
            let box = SKShapeNode(rectOf: CGSize(width: 22 * projected.1, height: 22 * projected.1), cornerRadius: 4)
            box.fillColor = pickup.kind.color
            box.strokeColor = .white
            box.lineWidth = 1
            box.position = projected.0
            box.zPosition = 25
            box.alpha = 0.9
            addChild(box)
            pickupNodes.append(box)
            _ = pos; _ = scale; _ = visible
        }
    }

    private func drawHazardMarkers(playerProgress: CGFloat, playerLateral: CGFloat) {
        hazardNodes.forEach { $0.removeFromParent() }
        hazardNodes.removeAll()
        for hazard in hazards {
            let absProgress = nearestLapProgress(hazard.progress, near: playerProgress)
            let projected = projectOnRoad(progress: absProgress, lateral: hazard.lateral, playerProgress: playerProgress, playerLateral: playerLateral)
            guard projected.2 else { continue }
            let node = SKShapeNode(circleOfRadius: 10 * projected.1)
            node.fillColor = hazard.kind == .banana ? .systemYellow : UIColor(red: 0.45, green: 0.2, blue: 0.55, alpha: 0.85)
            node.strokeColor = .clear
            node.position = projected.0
            node.zPosition = 24
            addChild(node)
            hazardNodes.append(node)
        }
        for projectile in projectiles {
            let projected = projectOnRoad(progress: projectile.progress, lateral: projectile.lateral, playerProgress: playerProgress, playerLateral: playerLateral)
            guard projected.2 else { continue }
            let node = SKShapeNode(circleOfRadius: 8 * projected.1)
            node.fillColor = .systemOrange
            node.strokeColor = .white
            node.position = projected.0
            node.zPosition = 26
            addChild(node)
            hazardNodes.append(node)
        }
    }

    private func nearestLapProgress(_ local: CGFloat, near reference: CGFloat) -> CGFloat {
        let lap = floor(reference / StoreTrack.lapLength)
        let candidates = [
            local + lap * StoreTrack.lapLength,
            local + (lap - 1) * StoreTrack.lapLength,
            local + (lap + 1) * StoreTrack.lapLength
        ]
        return candidates.min(by: { abs($0 - reference) < abs($1 - reference) }) ?? local
    }

    private func drawMinimap() {
        minimapNode.enumerateChildNodes(withName: "dot") { node, _ in node.removeFromParent() }
        guard let player else { return }

        for racer in racers {
            let angle = (racer.progress / StoreTrack.lapLength) * .pi * 2 - .pi / 2
            let radius: CGFloat = 36
            let dot = SKShapeNode(circleOfRadius: racer.isPlayer ? 5 : 3.5)
            dot.fillColor = racer.isPlayer ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : racer.archetype.accent
            dot.strokeColor = .clear
            dot.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            dot.name = "dot"
            minimapNode.addChild(dot)
        }
        _ = player
    }

    private func updateHUD() {
        guard let player else { return }
        let place = currentPlace(for: player)
        placeLabel.text = ordinal(place)
        lapLabel.text = "LAP \(min(player.lap, StoreTrack.totalLaps))/\(StoreTrack.totalLaps)"
        speedLabel.text = "\(Int(player.speed * 28)) mph"
        if let power = player.heldPowerUp {
            powerLabel.text = "ITEM: \(power.label)"
            powerLabel.fontColor = power.color
        } else if player.shieldTimer > 0 {
            powerLabel.text = "SHIELD"
            powerLabel.fontColor = .systemTeal
        } else if player.boostTimer > 0 {
            powerLabel.text = "BOOST"
            powerLabel.fontColor = .systemRed
        } else {
            powerLabel.text = "ITEM: —"
            powerLabel.fontColor = UIColor(white: 0.7, alpha: 1)
        }
    }

    private func currentPlace(for racer: CartRacer) -> Int {
        if let place = racer.finishPlace { return place }
        let ahead = racers.filter { other in
            if other.finished { return true }
            if other.id == racer.id { return false }
            return other.progress > racer.progress
        }.count
        return ahead + 1
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private func flashMessage(_ text: String) {
        let label = makeHUDLabel(fontSize: 22, color: .white)
        label.text = text
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        label.zPosition = 120
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 20, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent()
        ]))
    }

    private func checkFinish() {
        guard let player, player.finished, !raceFinished else { return }
        raceFinished = true
        let place = player.finishPlace ?? currentPlace(for: player)
        let results = ResultsScene(size: size, place: place, cart: player.archetype, standings: standingsSnapshot())
        results.scaleMode = .resizeFill
        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in
                self?.view?.presentScene(results, transition: .doorsCloseHorizontal(withDuration: 0.5))
            }
        ]))
    }

    private func standingsSnapshot() -> [(String, Int)] {
        racers
            .map { ($0.archetype.displayName, $0.finishPlace ?? currentPlace(for: $0)) }
            .sorted { $0.1 < $1.1 }
    }

    // MARK: - Controls

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, isDown: true)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            handleTouch(touch, isDown: false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        leftPressed = false
        rightPressed = false
        accelerating = false
    }

    private func handleTouch(_ touch: UITouch, isDown: Bool) {
        let location = touch.location(in: self)
        let hit = nodes(at: location)
        for node in hit {
            switch node.name {
            case "left":
                leftPressed = isDown
            case "right":
                rightPressed = isDown
            case "gas":
                accelerating = isDown
            case "use":
                if isDown, let player, raceStarted, !raceFinished {
                    usePowerUp(racer: player)
                }
            case "pause":
                if isDown {
                    let menu = MenuScene(size: size)
                    menu.scaleMode = .resizeFill
                    view?.presentScene(menu, transition: .fade(withDuration: 0.35))
                }
            default:
                break
            }
        }
    }
}
