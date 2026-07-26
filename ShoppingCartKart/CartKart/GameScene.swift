import SpriteKit

/// Top-down "Mario Kart"-style racer where homeless shopping carts race around
/// the aisles of a grocery store. All gameplay lives here; SwiftUI only draws the
/// menus and the read-only HUD (via `GameState`).
final class GameScene: SKScene {

    // Wired up from SwiftUI so the overlay can react to race state.
    weak var gameState: GameState?

    // World / track
    private var track = Track.store()
    private let totalLaps = 3

    // Racers
    private var carts: [Cart] = []
    private var player: Cart!

    // Dynamic objects
    private var hazards: [Hazard] = []
    private var projectiles: [Projectile] = []

    // Item boxes
    private struct ItemBox { let node: SKShapeNode; var respawn: CGFloat }
    private var itemBoxes: [ItemBox] = []

    // Layers
    private let worldNode = SKNode()
    private let cam = SKCameraNode()
    private let hudLayer = SKNode()

    // HUD controls
    private var leftButton: SKShapeNode!
    private var rightButton: SKShapeNode!
    private var itemButton: SKShapeNode!
    private var itemButtonLabel: SKLabelNode!

    // Input
    private var touchControl: [ObjectIdentifier: String] = [:]

    // Phase
    private enum Phase { case menu, countdown, racing, finished }
    private var phase: Phase = .menu
    private var countdown: CGFloat = 0
    private var raceTime: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var finishCounter = 0

    private let cartNames = ["You", "Cans McGee", "Buggy", "Wheelie", "Squeaky", "Rusty"]
    private let cartColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow,
        .systemGreen, .systemBlue, .systemPurple
    ]

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.85, green: 0.86, blue: 0.88, alpha: 1)
        view.isMultipleTouchEnabled = true

        addChild(worldNode)
        addChild(cam)
        camera = cam
        cam.addChild(hudLayer)

        buildStore()
        buildTrack()
        buildItemBoxes()
        buildCarts()
        buildHUD()

        resetRace()
    }

    // MARK: - World building

    private func buildStore() {
        // Store floor.
        let floor = SKShapeNode(rectOf: CGSize(width: 6000, height: 4400), cornerRadius: 40)
        floor.fillColor = UIColor(red: 0.93, green: 0.93, blue: 0.90, alpha: 1)
        floor.strokeColor = UIColor(white: 0.7, alpha: 1)
        floor.lineWidth = 8
        floor.zPosition = -100
        worldNode.addChild(floor)

        // Tile grid on the floor.
        let grid = SKShapeNode()
        let gp = CGMutablePath()
        for x in stride(from: CGFloat(-2900), through: 2900, by: 200) {
            gp.move(to: CGPoint(x: x, y: -2100))
            gp.addLine(to: CGPoint(x: x, y: 2100))
        }
        for y in stride(from: CGFloat(-2100), through: 2100, by: 200) {
            gp.move(to: CGPoint(x: -2900, y: y))
            gp.addLine(to: CGPoint(x: 2900, y: y))
        }
        grid.path = gp
        grid.strokeColor = UIColor(white: 0.8, alpha: 0.6)
        grid.lineWidth = 2
        grid.zPosition = -99
        worldNode.addChild(grid)

        // Shelving in the infield to sell the "inside a store" look.
        addShelfBlock(center: CGPoint(x: -520, y: 0), rows: 3)
        addShelfBlock(center: CGPoint(x: 520, y: 0), rows: 3)
        addShelfBlock(center: CGPoint(x: 0, y: 430), rows: 2)
        addShelfBlock(center: CGPoint(x: 0, y: -430), rows: 2)

        // A checkout counter / entrance sign in the outfield.
        let sign = SKLabelNode(text: "★ MEGA-MART GRAND PRIX ★")
        sign.fontName = "AvenirNext-Heavy"
        sign.fontSize = 120
        sign.fontColor = UIColor(white: 0.72, alpha: 0.55)
        sign.position = CGPoint(x: 0, y: 0)
        sign.zPosition = -98
        worldNode.addChild(sign)
    }

    private func addShelfBlock(center: CGPoint, rows: Int) {
        let shelfProducts: [UIColor] = [.systemRed, .systemBlue, .systemGreen,
                                        .systemOrange, .systemPurple, .systemTeal]
        for r in 0..<rows {
            let shelf = SKShapeNode(rectOf: CGSize(width: 360, height: 60), cornerRadius: 6)
            shelf.position = CGPoint(x: center.x, y: center.y + CGFloat(r) * 95 - CGFloat(rows - 1) * 47.5)
            shelf.fillColor = UIColor(white: 0.6, alpha: 1)
            shelf.strokeColor = UIColor(white: 0.35, alpha: 1)
            shelf.lineWidth = 3
            shelf.zPosition = -90
            worldNode.addChild(shelf)
            // Products on the shelf.
            for i in 0..<8 {
                let p = SKShapeNode(rectOf: CGSize(width: 26, height: 34), cornerRadius: 3)
                p.position = CGPoint(x: -160 + CGFloat(i) * 45, y: 0)
                p.fillColor = shelfProducts.randomElement()!
                p.strokeColor = .clear
                shelf.addChild(p)
            }
        }
    }

    private func buildTrack() {
        let n = track.count

        // Track edge (slightly wider, darker) underneath the drivable surface.
        let edge = SKShapeNode(path: loopPath())
        edge.strokeColor = UIColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 1)
        edge.lineWidth = track.width + 26
        edge.fillColor = .clear
        edge.zPosition = -60
        worldNode.addChild(edge)

        // Drivable asphalt.
        let road = SKShapeNode(path: loopPath())
        road.strokeColor = UIColor(red: 0.42, green: 0.42, blue: 0.45, alpha: 1)
        road.lineWidth = track.width
        road.fillColor = .clear
        road.zPosition = -59
        worldNode.addChild(road)

        // Dashed centre line.
        let dashed = SKShapeNode(path: loopPath().copy(dashingWithPhase: 0, lengths: [40, 40]))
        dashed.strokeColor = UIColor(white: 1, alpha: 0.6)
        dashed.lineWidth = 5
        dashed.fillColor = .clear
        dashed.zPosition = -58
        worldNode.addChild(dashed)

        // Start / finish line (checkered).
        let start = track.centerline[0]
        let dir = track.direction(at: 0)
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let squares = 8
        let squareLen = track.width / CGFloat(squares)
        let lineNode = SKNode()
        for i in 0..<squares {
            for j in 0..<2 {
                if (i + j) % 2 == 0 {
                    let sq = SKShapeNode(rectOf: CGSize(width: 30, height: squareLen))
                    let along = CGFloat(j) * 30 - 15
                    let across = (CGFloat(i) - CGFloat(squares - 1) / 2) * squareLen
                    sq.position = start + dir * along + perp * across
                    sq.zRotation = dir.angle
                    sq.fillColor = .white
                    sq.strokeColor = .clear
                    lineNode.addChild(sq)
                }
            }
        }
        lineNode.zPosition = -57
        worldNode.addChild(lineNode)
        _ = n
    }

    private func loopPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: track.centerline[0])
        for i in 1..<track.count {
            path.addLine(to: track.centerline[i])
        }
        path.closeSubpath()
        return path
    }

    private func buildItemBoxes() {
        for idx in [6, 18, 30, 42] {
            let box = SKShapeNode(rectOf: CGSize(width: 46, height: 46), cornerRadius: 6)
            box.position = track.centerline[idx % track.count]
            box.zRotation = .pi / 4
            box.fillColor = UIColor(red: 0.1, green: 0.8, blue: 0.9, alpha: 0.9)
            box.strokeColor = .white
            box.lineWidth = 3
            box.zPosition = -50
            let q = SKLabelNode(text: "?")
            q.fontName = "AvenirNext-Heavy"
            q.fontSize = 30
            q.fontColor = .white
            q.verticalAlignmentMode = .center
            q.horizontalAlignmentMode = .center
            q.zRotation = -.pi / 4
            box.addChild(q)
            box.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.6),
                .scale(to: 0.92, duration: 0.6)
            ])))
            worldNode.addChild(box)
            itemBoxes.append(ItemBox(node: box, respawn: 0))
        }
    }

    private func buildCarts() {
        for i in 0..<cartNames.count {
            let c = Cart(isPlayer: i == 0, name: cartNames[i], color: cartColors[i])
            c.zPosition = 10
            c.lineOffset = CGFloat.random(in: -70...70)
            worldNode.addChild(c)
            carts.append(c)
            if i == 0 { player = c }
        }
    }

    // MARK: - HUD (touch controls)

    private func buildHUD() {
        leftButton = makeControlButton(text: "◀", fill: UIColor(white: 0.1, alpha: 0.35))
        leftButton.name = "steerLeft"
        rightButton = makeControlButton(text: "▶", fill: UIColor(white: 0.1, alpha: 0.35))
        rightButton.name = "steerRight"

        itemButton = SKShapeNode(circleOfRadius: 62)
        itemButton.name = "itemBtn"
        itemButton.fillColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.45)
        itemButton.strokeColor = UIColor(white: 1, alpha: 0.8)
        itemButton.lineWidth = 4
        itemButtonLabel = SKLabelNode(text: "USE")
        itemButtonLabel.fontName = "AvenirNext-Bold"
        itemButtonLabel.fontSize = 22
        itemButtonLabel.fontColor = .white
        itemButtonLabel.verticalAlignmentMode = .center
        itemButtonLabel.horizontalAlignmentMode = .center
        itemButton.addChild(itemButtonLabel)

        hudLayer.addChild(leftButton)
        hudLayer.addChild(rightButton)
        hudLayer.addChild(itemButton)
        hudLayer.zPosition = 1000
    }

    private func makeControlButton(text: String, fill: UIColor) -> SKShapeNode {
        let btn = SKShapeNode(circleOfRadius: 55)
        btn.fillColor = fill
        btn.strokeColor = UIColor(white: 1, alpha: 0.7)
        btn.lineWidth = 4
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 44
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        btn.addChild(label)
        return btn
    }

    private func layoutHUD() {
        // hudLayer counter-scales the camera zoom so controls stay a fixed on-screen size.
        let s = cam.xScale
        hudLayer.setScale(s)
        let halfW = size.width / 2
        let halfH = size.height / 2
        let margin: CGFloat = 90
        leftButton.position = CGPoint(x: -halfW + margin, y: -halfH + margin)
        rightButton.position = CGPoint(x: -halfW + margin + 140, y: -halfH + margin)
        itemButton.position = CGPoint(x: halfW - margin - 10, y: -halfH + margin + 10)
        let hidden = (phase != .racing) || player.finished
        hudLayer.isHidden = hidden
    }

    // MARK: - Race lifecycle

    func resetRace() {
        phase = .menu
        raceTime = 0
        finishCounter = 0
        hazards.forEach { $0.removeFromParent() }
        hazards.removeAll()
        projectiles.forEach { $0.removeFromParent() }
        projectiles.removeAll()
        for i in 0..<itemBoxes.count {
            itemBoxes[i].respawn = 0
            itemBoxes[i].node.isHidden = false
        }

        let start = track.centerline[0]
        let dir = track.direction(at: 0)
        let perp = CGPoint(x: -dir.y, y: dir.x)

        for (i, c) in carts.enumerated() {
            // Two-wide staggered starting grid, placed just behind the line.
            let row = i / 2
            let colSide: CGFloat = (i % 2 == 0) ? -1 : 1
            let backOffset = CGFloat(row) * 130 + 90
            let sideOffset = colSide * 70
            c.position = start - dir * backOffset + perp * sideOffset
            c.heading = dir.angle
            c.zRotation = c.heading
            c.spinVisualRotation = 0
            c.speed = 0
            c.lap = 1
            c.item = .none
            c.spinTimer = 0
            c.boostTimer = 0
            c.aiItemTimer = 0
            c.autopilot = false
            c.finished = false
            c.finishTime = 0
            c.finishOrder = 0
            c.rank = i + 1

            let info = track.nearest(to: c.position)
            let sVal = CGFloat(info.seg) + info.t
            c.currentS = sVal
            c.prevS = sVal
            c.totalS = 0
        }

        cam.position = player.position
        updateGameState()
    }

    func beginCountdown() {
        resetRace()
        phase = .countdown
        countdown = 3.0
        gameState?.phase = .countdown
        gameState?.countdownText = "3"
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        var dt = CGFloat(currentTime - lastUpdate)
        lastUpdate = currentTime
        dt = min(dt, 1.0 / 30.0)

        switch phase {
        case .menu:
            slowlyOrbitCamera(dt)
        case .countdown:
            countdown -= dt
            let shown: String
            if countdown > 2 { shown = "3" }
            else if countdown > 1 { shown = "2" }
            else if countdown > 0 { shown = "1" }
            else { shown = "GO!" }
            gameState?.countdownText = shown
            if countdown <= -0.6 {
                phase = .racing
                gameState?.phase = .racing
                gameState?.countdownText = ""
            }
            followPlayer(dt, instant: true)
        case .racing:
            raceTime += TimeInterval(dt)
            for c in carts { updateCart(c, dt: dt) }
            updateHazards(dt)
            updateProjectiles(dt)
            updateItemBoxes(dt)
            resolveCartCollisions()
            updateRanks()
            followPlayer(dt, instant: false)
            updateGameState()
            if player.finished && phase == .racing {
                finishRace()
            }
        case .finished:
            // Keep the world alive behind the results overlay.
            for c in carts { updateCart(c, dt: dt) }
            updateHazards(dt)
            updateProjectiles(dt)
            resolveCartCollisions()
            followPlayer(dt, instant: false)
        }

        // Camera zoom scales with view width so gameplay is consistent across devices.
        let desiredVisibleWidth: CGFloat = 1500
        if size.width > 0 {
            cam.setScale(desiredVisibleWidth / size.width)
        }
        layoutHUD()
    }

    private func slowlyOrbitCamera(_ dt: CGFloat) {
        let t = CGFloat(raceTime)
        raceTime += TimeInterval(dt)
        let r: CGFloat = 900
        cam.position = CGPoint(x: cos(t * 0.15) * r, y: sin(t * 0.15) * r * 0.6)
    }

    private func followPlayer(_ dt: CGFloat, instant: Bool) {
        if instant {
            cam.position = player.position
        } else {
            let lerp: CGFloat = min(1, dt * 6)
            cam.position = cam.position + (player.position - cam.position) * lerp
        }
    }

    // MARK: - Cart simulation

    private func updateCart(_ c: Cart, dt: CGFloat) {
        // Track parameter & surface.
        let info = track.nearest(to: c.position)
        c.onTrack = info.dist <= track.width / 2
        let newS = CGFloat(info.seg) + info.t
        updateProgress(c, newS: newS)

        // Spin-out handling.
        if c.spinTimer > 0 {
            c.spinTimer -= dt
            c.spinVisualRotation += 20 * dt
            c.speed = max(60, c.speed - 900 * dt)
        } else if c.spinVisualRotation != 0 {
            c.spinVisualRotation = 0
        }

        if c.boostTimer > 0 { c.boostTimer -= dt }

        // Steering input.
        var steer: CGFloat = 0
        let humanDriving = c.isPlayer && !c.autopilot
        if c.spinTimer <= 0 {
            if humanDriving {
                steer = playerSteerInput()
            } else {
                steer = aiSteer(c)
                maybeUseAIItem(c, dt: dt)
            }
        }

        // Speed model.
        var maxSpeed = c.maxSpeedBase
        if !c.onTrack { maxSpeed *= 0.45 }
        if c.boostTimer > 0 { maxSpeed *= 1.6 }
        if c.spinTimer > 0 { maxSpeed = min(maxSpeed, 120) }

        // Mild rubber-banding keeps the pack (and the race) close.
        if !humanDriving && !c.finished {
            if c.rank <= 1 { maxSpeed *= 0.97 }
            else if c.rank >= 4 { maxSpeed *= 1.05 }
        }

        let accel: CGFloat = 780
        if c.speed < maxSpeed {
            c.speed = min(maxSpeed, c.speed + accel * dt)
        } else {
            c.speed = max(maxSpeed, c.speed - 600 * dt)
        }
        if !c.onTrack { c.speed = max(0, c.speed - 260 * dt) } // grass drag

        // Apply steering (only meaningful once moving).
        let turnRate: CGFloat = 2.6
        let speedFactor = min(1, c.speed / 220)
        if c.spinTimer <= 0 {
            c.heading += steer * turnRate * speedFactor * dt
        }
        c.heading = normalizeAngle(c.heading)
        c.zRotation = c.heading

        // Move.
        let vel = CGPoint(x: cos(c.heading), y: sin(c.heading)) * (c.speed * dt)
        c.position = c.position + vel

        // Keep carts near the circuit: if they stray far, nudge them back.
        let after = track.nearest(to: c.position)
        if after.dist > track.width / 2 + 260 {
            let a = track.centerline[after.seg]
            let b = track.centerline[(after.seg + 1) % track.count]
            let proj = a + (b - a) * after.t
            let pull = (proj - c.position).normalized
            c.position = c.position + pull * (300 * dt)
            c.speed *= 0.9
        }
    }

    private func updateProgress(_ c: Cart, newS: CGFloat) {
        let n = CGFloat(track.count)
        var delta = newS - c.prevS
        if delta < -n / 2 { delta += n }       // wrapped forward past the start line
        else if delta > n / 2 { delta -= n }    // small backward step across the wrap
        c.totalS += delta
        c.prevS = newS
        c.currentS = newS
        c.lap = max(1, min(totalLaps, Int(c.totalS / n) + 1))

        if !c.finished && c.totalS >= n * CGFloat(totalLaps) {
            c.finished = true
            c.finishTime = raceTime
            finishCounter += 1
            c.finishOrder = finishCounter
            if !c.isPlayer { c.autopilot = true }
        }
    }

    private func aiSteer(_ c: Cart) -> CGFloat {
        let n = track.count
        let baseIdx = Int(c.currentS)
        let aimIdx = (baseIdx + 3) % n
        let dir = track.direction(at: aimIdx)
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let target = track.centerline[aimIdx] + perp * c.lineOffset
        let desired = (target - c.position).angle
        let diff = normalizeAngle(desired - c.heading)
        return max(-1, min(1, diff * 2.4))
    }

    private func maybeUseAIItem(_ c: Cart, dt: CGFloat) {
        guard c.item != .none else { return }
        c.aiItemTimer -= dt
        if c.aiItemTimer <= 0 {
            useItem(c)
        }
    }

    private func resolveCartCollisions() {
        let minDist: CGFloat = 78
        for i in 0..<carts.count {
            for j in (i + 1)..<carts.count {
                let a = carts[i], b = carts[j]
                let delta = b.position - a.position
                let d = delta.length
                if d > 0 && d < minDist {
                    let push = delta.normalized * ((minDist - d) / 2)
                    a.position = a.position - push
                    b.position = b.position + push
                    a.speed *= 0.985
                    b.speed *= 0.985
                }
            }
        }
    }

    private func updateRanks() {
        let sorted = carts.sorted { lhs, rhs in
            if lhs.finished != rhs.finished { return lhs.finished }
            if lhs.finished && rhs.finished { return lhs.finishOrder < rhs.finishOrder }
            return lhs.totalS > rhs.totalS
        }
        for (i, c) in sorted.enumerated() { c.rank = i + 1 }
    }

    // MARK: - Items

    private func updateItemBoxes(_ dt: CGFloat) {
        let pickupRadius: CGFloat = 85
        for i in 0..<itemBoxes.count {
            if itemBoxes[i].respawn > 0 {
                itemBoxes[i].respawn -= dt
                if itemBoxes[i].respawn <= 0 {
                    itemBoxes[i].node.isHidden = false
                }
                continue
            }
            let boxPos = itemBoxes[i].node.position
            for c in carts where c.item == .none && !c.finished {
                if c.position.distance(to: boxPos) < pickupRadius {
                    c.item = ItemKind.random
                    if !c.isPlayer { c.aiItemTimer = CGFloat.random(in: 1.0...3.0) }
                    itemBoxes[i].node.isHidden = true
                    itemBoxes[i].respawn = 5
                    break
                }
            }
        }
    }

    func usePlayerItem() {
        guard phase == .racing, !player.finished else { return }
        useItem(player)
    }

    private func useItem(_ c: Cart) {
        let dir = CGPoint(x: cos(c.heading), y: sin(c.heading))
        switch c.item {
        case .none:
            return
        case .boost:
            c.boostTimer = 1.6
            c.speed = max(c.speed, c.maxSpeedBase * 1.2)
        case .banana:
            let h = Hazard()
            h.owner = c
            h.position = c.position - dir * 80
            h.zPosition = 5
            let splat = SKShapeNode(circleOfRadius: 26)
            splat.fillColor = UIColor(white: 1, alpha: 0.9)
            splat.strokeColor = UIColor(white: 0.8, alpha: 1)
            splat.lineWidth = 2
            h.addChild(splat)
            for _ in 0..<4 {
                let drop = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...8))
                drop.position = CGPoint(x: CGFloat.random(in: -28...28), y: CGFloat.random(in: -28...28))
                drop.fillColor = UIColor(white: 1, alpha: 0.85)
                drop.strokeColor = .clear
                h.addChild(drop)
            }
            worldNode.addChild(h)
            hazards.append(h)
        case .can:
            let p = Projectile()
            p.owner = c
            p.position = c.position + dir * 80
            p.velocity = dir * (c.speed + 950)
            p.zPosition = 6
            let can = SKShapeNode(rectOf: CGSize(width: 26, height: 20), cornerRadius: 4)
            can.fillColor = UIColor(red: 0.75, green: 0.55, blue: 0.2, alpha: 1)
            can.strokeColor = UIColor(white: 0.2, alpha: 1)
            can.lineWidth = 2
            p.addChild(can)
            worldNode.addChild(p)
            projectiles.append(p)
        }
        c.item = .none
    }

    private func updateHazards(_ dt: CGFloat) {
        let hitRadius: CGFloat = 46
        var survivors: [Hazard] = []
        for h in hazards {
            h.life -= dt
            h.ownerImmunity -= dt
            var hit = false
            for c in carts where c.spinTimer <= 0 && !c.finished {
                if c === h.owner && h.ownerImmunity > 0 { continue }
                if c.position.distance(to: h.position) < hitRadius {
                    spinOut(c)
                    hit = true
                    break
                }
            }
            if hit || h.life <= 0 {
                h.removeFromParent()
            } else {
                survivors.append(h)
            }
        }
        hazards = survivors
    }

    private func updateProjectiles(_ dt: CGFloat) {
        let hitRadius: CGFloat = 40
        var survivors: [Projectile] = []
        for p in projectiles {
            p.life -= dt
            p.position = p.position + p.velocity * dt
            p.zRotation += 12 * dt
            var hit = false
            for c in carts where c.spinTimer <= 0 && !c.finished {
                if c === p.owner { continue }
                if c.position.distance(to: p.position) < hitRadius {
                    spinOut(c)
                    hit = true
                    break
                }
            }
            if hit || p.life <= 0 {
                p.removeFromParent()
            } else {
                survivors.append(p)
            }
        }
        projectiles = survivors
    }

    private func spinOut(_ c: Cart) {
        guard c.spinTimer <= 0 else { return }
        c.spinTimer = 1.4
        c.speed *= 0.25
    }

    // MARK: - HUD state / results

    private func updateGameState() {
        guard let gs = gameState else { return }
        gs.lap = player.lap
        gs.totalLaps = totalLaps
        gs.positionText = "\(player.rank)/\(carts.count)"
        gs.itemName = player.item.display
        gs.speed = Int(player.speed / 6)
        gs.raceTime = raceTime
    }

    private func finishRace() {
        phase = .finished
        player.autopilot = true
        let ordered = carts.sorted { lhs, rhs in
            if lhs.finished != rhs.finished { return lhs.finished }
            if lhs.finished && rhs.finished { return lhs.finishOrder < rhs.finishOrder }
            return lhs.totalS > rhs.totalS
        }
        let names = ordered.map { $0.displayName }
        DispatchQueue.main.async { [weak self] in
            guard let gs = self?.gameState else { return }
            gs.results = names
            gs.phase = .finished
        }
    }

    // MARK: - Touch handling

    private func playerSteerInput() -> CGFloat {
        let left = touchControl.values.contains("steerLeft")
        let right = touchControl.values.contains("steerRight")
        return (right ? 1 : 0) - (left ? 1 : 0)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .racing, !player.finished else { return }
        for t in touches {
            let loc = t.location(in: self)
            for node in nodes(at: loc) {
                if let name = node.name, name == "steerLeft" || name == "steerRight" || name == "itemBtn" {
                    touchControl[ObjectIdentifier(t)] = name
                    if name == "itemBtn" { usePlayerItem() }
                    highlight(named: name, pressed: true)
                    break
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for t in touches {
            if let name = touchControl[ObjectIdentifier(t)] {
                highlight(named: name, pressed: false)
            }
            touchControl[ObjectIdentifier(t)] = nil
        }
    }

    private func highlight(named: String, pressed: Bool) {
        let node: SKShapeNode?
        switch named {
        case "steerLeft": node = leftButton
        case "steerRight": node = rightButton
        case "itemBtn": node = itemButton
        default: node = nil
        }
        node?.alpha = pressed ? 0.7 : 1.0
    }
}
