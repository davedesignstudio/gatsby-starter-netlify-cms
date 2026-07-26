import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let playerCart: CartDef
    private let onFinish: ([RaceResult]) -> Void
    private let onQuit: () -> Void

    private var racers: [Racer] = []
    private var player: Racer!
    private var pickups: [Pickup] = []
    private var hazards: [Hazard] = []
    private var projectiles: [Projectile] = []

    private var raceTime: TimeInterval = 0
    private var countdown: TimeInterval = 3.2
    private var state: RaceState = .countdown
    private var finishCount = 0
    private var cameraX: CGFloat = 0

    private let totalLaps = 3
    private let track = TrackData()

    // UI
    private let placeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let timeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let bannerLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let itemButton = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let gasButton = SKShapeNode()
    private let brakeButton = SKShapeNode()
    private let steerBase = SKShapeNode(circleOfRadius: 56)
    private let steerKnob = SKShapeNode(circleOfRadius: 22)
    private let quitButton = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var steerValue: CGFloat = 0
    private var gasHeld = false
    private var brakeHeld = false
    private var steeringTouch: UITouch?
    private var bannerTimer: TimeInterval = 0

    init(size: CGSize, playerCart: CartDef, onFinish: @escaping ([RaceResult]) -> Void, onQuit: @escaping () -> Void) {
        self.playerCart = playerCart
        self.onFinish = onFinish
        self.onQuit = onQuit
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.04, green: 0.12, blue: 0.14, alpha: 1)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        setupRacers()
        seedPickups()
        setupHUD()
    }

    private func setupRacers() {
        player = Racer(cart: playerCart, isPlayer: true, z: 8, x: 0)
        racers = [player]

        var slot = 0
        for cart in CartDef.roster where cart.id != playerCart.id {
            let x: CGFloat = slot % 2 == 0 ? -0.35 : 0.35
            racers.append(Racer(cart: cart, isPlayer: false, z: CGFloat(4 + slot * 3), x: x))
            slot += 1
        }

        let fillers: [(String, UIColor, UIColor, CGFloat)] = [
            ("Squeaky Pete", UIColor(red: 0.48, green: 0.56, blue: 0.23, alpha: 1), UIColor(red: 0.23, green: 0.29, blue: 0.09, alpha: 1), 0.95),
            ("Bent Axle", UIColor(red: 0.54, green: 0.29, blue: 0.42, alpha: 1), UIColor(red: 0.29, green: 0.13, blue: 0.22, alpha: 1), 1.03),
            ("Milk Crate", UIColor(red: 0.29, green: 0.42, blue: 0.67, alpha: 1), UIColor(red: 0.13, green: 0.19, blue: 0.31, alpha: 1), 0.98),
        ]
        for (i, f) in fillers.enumerated() {
            let def = CartDef(id: "f\(i)", name: f.0, blurb: "", color: Color(uiColor: f.1), accent: Color(uiColor: f.2), speed: f.3, accel: 1, handling: 1)
            racers.append(Racer(cart: def, isPlayer: false, z: CGFloat(2 + i * 2), x: CGFloat(i - 1) * 0.28))
        }
    }

    private func seedPickups() {
        pickups = (0..<18).map { i in
            Pickup(
                z: track.length * CGFloat(i + 1) / 19,
                x: [-0.45, 0, 0.45][i % 3],
                type: ItemType.allCases[i % ItemType.allCases.count]
            )
        }
    }

    private func setupHUD() {
        for label in [placeLabel, lapLabel, timeLabel] {
            label.fontSize = 16
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            addChild(label)
        }
        placeLabel.position = CGPoint(x: size.width * 0.2, y: size.height - 36)
        lapLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 36)
        timeLabel.position = CGPoint(x: size.width * 0.8, y: size.height - 36)

        countdownLabel.fontSize = 96
        countdownLabel.fontColor = UIColor(red: 0.94, green: 0.70, blue: 0.16, alpha: 1)
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        addChild(countdownLabel)

        bannerLabel.fontSize = 18
        bannerLabel.fontColor = UIColor(red: 0.94, green: 0.70, blue: 0.16, alpha: 1)
        bannerLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        bannerLabel.alpha = 0
        addChild(bannerLabel)

        steerBase.fillColor = UIColor(white: 0.1, alpha: 0.4)
        steerBase.strokeColor = UIColor(white: 0.8, alpha: 0.4)
        steerBase.lineWidth = 2
        steerBase.position = CGPoint(x: 90, y: 90)
        steerBase.zPosition = 50
        addChild(steerBase)

        steerKnob.fillColor = UIColor(red: 0.77, green: 0.83, blue: 0.85, alpha: 1)
        steerKnob.strokeColor = UIColor(white: 0.4, alpha: 1)
        steerKnob.lineWidth = 2
        steerKnob.position = .zero
        steerBase.addChild(steerKnob)

        func pedal(_ node: SKShapeNode, color: UIColor, label: String, x: CGFloat, y: CGFloat) {
            node.path = CGPath(roundedRect: CGRect(x: -40, y: -24, width: 80, height: 48), cornerWidth: 8, cornerHeight: 8, transform: nil)
            node.fillColor = color
            node.strokeColor = .clear
            node.position = CGPoint(x: x, y: y)
            node.zPosition = 50
            let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            t.text = label
            t.fontSize = 14
            t.verticalAlignmentMode = .center
            t.fontColor = .white
            node.addChild(t)
            addChild(node)
        }
        pedal(gasButton, color: UIColor(red: 0.25, green: 0.56, blue: 0.30, alpha: 1), label: "GAS", x: size.width - 70, y: 70)
        pedal(brakeButton, color: UIColor(red: 0.35, green: 0.40, blue: 0.44, alpha: 1), label: "BRAKE", x: size.width - 70, y: 130)

        itemButton.text = "ITEM"
        itemButton.fontSize = 14
        itemButton.fontColor = .white
        itemButton.verticalAlignmentMode = .center
        itemButton.horizontalAlignmentMode = .center
        itemButton.position = CGPoint(x: size.width - 70, y: 190)
        itemButton.zPosition = 50
        let itemBg = SKShapeNode(rectOf: CGSize(width: 80, height: 48), cornerRadius: 8)
        itemBg.fillColor = UIColor(red: 0.12, green: 0.65, blue: 0.63, alpha: 1)
        itemBg.strokeColor = .clear
        itemBg.zPosition = -1
        itemButton.addChild(itemBg)
        addChild(itemButton)

        quitButton.text = "QUIT"
        quitButton.fontSize = 14
        quitButton.fontColor = .white
        quitButton.position = CGPoint(x: size.width - 40, y: size.height - 36)
        quitButton.zPosition = 50
        addChild(quitButton)
    }

    override func update(_ currentTime: TimeInterval) {
        // dt via lastUpdate pattern
        enum Hold { static var last: TimeInterval = 0 }
        if Hold.last == 0 { Hold.last = currentTime }
        let dt = min(0.05, currentTime - Hold.last)
        Hold.last = currentTime

        if state == .finished { return }

        if bannerTimer > 0 {
            bannerTimer -= dt
            if bannerTimer <= 0 { bannerLabel.alpha = 0 }
        }

        if state == .countdown {
            countdown -= dt
            countdownLabel.text = countdown > 0 ? "\(Int(ceil(countdown)))" : "GO"
            if countdown <= 0 {
                state = .racing
                countdownLabel.text = ""
                flash("GO!")
            }
            updateAI(dt * 0.2)
            for r in racers where !r.isPlayer { applyPhysics(r, dt: dt * 0.2) }
            updateHUD()
            return
        }

        raceTime += dt
        updateAI(dt)
        player.steer = steerValue
        player.gas = gasHeld
        player.brake = brakeHeld
        for r in racers { applyPhysics(r, dt: dt) }
        resolveCollisions()
        updatePickups()
        updateHazards(dt)
        updateProjectiles(dt)
        cameraX += (player.x - cameraX) * min(1, dt * 6)
        updateHUD()

        if player.finished {
            let allDone = racers.allSatisfy(\.finished)
            if allDone || raceTime > (player.finishTime ?? 0) + 4 {
                state = .finished
                onFinish(results())
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // keep basic layout if rotated
    }

    // MARK: - Physics / AI

    private func applyPhysics(_ r: Racer, dt: TimeInterval) {
        if r.stunned > 0 {
            r.stunned -= dt
            r.speed *= max(0, 1 - dt * 1.8)
        }
        if r.shield > 0 { r.shield -= dt }
        if r.boost > 0 { r.boost -= dt }

        let sample = track.sample(r.z)
        let curveForce = sample.curve * 0.0009 * (r.speed / max(1, r.maxSpeed))

        if !r.finished {
            // Arcade feel: keep rolling; gas boosts, brake cuts speed.
            let autoDrive = r.isPlayer ? !r.brake : r.gas
            if r.gas || autoDrive { r.speed += r.accel * (r.gas ? 1 : 0.72) * CGFloat(dt) }
            if r.brake { r.speed -= r.accel * 1.5 * CGFloat(dt) }
            if !r.gas && !autoDrive && !r.brake { r.speed -= 35 * CGFloat(dt) }
        } else {
            r.speed += (r.maxSpeed * 0.35 - r.speed) * CGFloat(dt) * 2
        }

        var cap = r.maxSpeed
        if r.boost > 0 { cap *= 1.35 }
        r.speed = max(0, min(cap, r.speed))
        if abs(r.x) > 0.92 { r.speed *= max(0, 1 - CGFloat(dt) * 1.4) }

        r.x += r.steer * r.handling * (0.35 + r.speed / r.maxSpeed) * CGFloat(dt)
        r.x -= curveForce * r.speed * CGFloat(dt)
        r.x = max(-1.35, min(1.35, r.x))
        r.z += r.speed * CGFloat(dt) / 20

        if r.z >= track.length {
            r.z -= track.length
            if !r.finished && state == .racing {
                r.lap += 1
                if r.isPlayer { flash("LAP \(min(r.lap + 1, totalLaps))") }
                if r.lap >= totalLaps {
                    r.finished = true
                    finishCount += 1
                    r.finishOrder = finishCount
                    r.finishTime = raceTime
                    if r.isPlayer { flash("FINISHED \(RaceResult(place: r.finishOrder, name: r.name, isPlayer: true, finished: true, time: raceTime).placeSuffix)!") }
                }
            }
        }
        r.progress = CGFloat(r.lap) * track.length + r.z
    }

    private func updateAI(_ dt: TimeInterval) {
        for r in racers where !r.isPlayer && !r.finished {
            r.aiPhase += dt
            r.gas = true
            let target = sin(r.aiPhase * 0.7) * 0.35
            r.steer = max(-1, min(1, (target - r.x) * 2.2))
            let delta = player.progress - r.progress
            if delta > 40 { r.speed = min(r.speed + 40 * CGFloat(dt), r.maxSpeed * 1.15) }
            if delta < -55 { r.speed *= max(0, 1 - CGFloat(dt) * 0.35) }
            if let item = r.item, Double.random(in: 0...1) < dt * 0.55 {
                useItem(r)
                _ = item
            }
        }
    }

    private func updatePickups() {
        for i in pickups.indices {
            guard pickups[i].alive else { continue }
            for r in racers where !r.finished && r.item == nil {
                if near(r.z, r.x, pickups[i].z, pickups[i].x, zWindow: 5, xWindow: 0.22) {
                    pickups[i].alive = false
                    pickups[i].respawn = 6
                    r.item = pickups[i].type
                    if r.isPlayer { flash("Got \(pickups[i].type.label)!") }
                }
            }
        }
        for i in pickups.indices where !pickups[i].alive {
            pickups[i].respawn -= 1.0 / 60.0
            if pickups[i].respawn <= 0 { pickups[i].alive = true }
        }
    }

    private func updateHazards(_ dt: TimeInterval) {
        hazards = hazards.filter { h in
            var hazard = h
            hazard.life -= dt
            guard hazard.life > 0 else { return false }
            for r in racers {
                if r.stunned > 0 { continue }
                if near(r.z, r.x, hazard.z, hazard.x, zWindow: 4, xWindow: 0.18) {
                    if r.shield > 0 {
                        r.shield = 0
                        if r.isPlayer { flash("Shield saved you!") }
                    } else {
                        r.stunned = 1.1
                        r.speed *= 0.35
                        if r.isPlayer { flash("Slipped on a peel!") }
                    }
                    return false
                }
            }
            return true
        }
    }

    private func updateProjectiles(_ dt: TimeInterval) {
        projectiles = projectiles.compactMap { p in
            var bolt = p
            bolt.life -= dt
            bolt.z += bolt.speed * CGFloat(dt) / 20
            if bolt.z >= track.length { bolt.z -= track.length }
            guard bolt.life > 0 else { return nil }
            for r in racers where r !== bolt.owner && !r.finished {
                if near(r.z, r.x, bolt.z, bolt.x, zWindow: 8, xWindow: 0.28) {
                    if r.shield > 0 {
                        r.shield = 0
                    } else {
                        r.stunned = 1.3
                        r.speed *= 0.25
                        if r.isPlayer { flash("ZAPPED!") }
                        else if bolt.owner.isPlayer { flash("Hit \(r.name)!") }
                    }
                    return nil
                }
            }
            return bolt
        }
    }

    private func resolveCollisions() {
        for i in 0..<racers.count {
            for j in (i + 1)..<racers.count {
                let a = racers[i]
                let b = racers[j]
                if near(a.z, a.x, b.z, b.x, zWindow: 3.2, xWindow: 0.16) {
                    let push: CGFloat = 0.04
                    if a.x < b.x { a.x -= push; b.x += push } else { a.x += push; b.x -= push }
                    let avg = (a.speed + b.speed) * 0.5
                    a.speed = a.speed * 0.6 + avg * 0.4 * 0.92
                    b.speed = b.speed * 0.6 + avg * 0.4 * 0.92
                }
            }
        }
    }

    private func near(_ z1: CGFloat, _ x1: CGFloat, _ z2: CGFloat, _ x2: CGFloat, zWindow: CGFloat, xWindow: CGFloat) -> Bool {
        var dz = abs(z1 - z2)
        dz = min(dz, track.length - dz)
        return dz < zWindow && abs(x1 - x2) < xWindow
    }

    private func useItem(_ r: Racer) {
        guard let item = r.item, r.stunned <= 0, !r.finished else { return }
        r.item = nil
        switch item {
        case .soda:
            r.boost = max(r.boost, 1.6)
            flash("\(r.name): SODA BOOST!")
        case .coupon:
            r.shield = max(r.shield, 3.5)
            flash("\(r.name): COUPON SHIELD!")
        case .banana:
            hazards.append(Hazard(z: r.z - 4, x: r.x, life: 18))
            flash("\(r.name) dropped a peel")
        case .pricegun:
            projectiles.append(Projectile(owner: r, z: r.z + 6, x: r.x, speed: 420, life: 2.2))
            flash("\(r.name): PRICE GUN!")
        }
    }

    private func flash(_ text: String) {
        bannerLabel.text = text
        bannerLabel.alpha = 1
        bannerTimer = 1.6
    }

    private func standings() -> [Racer] {
        racers.sorted { a, b in
            if a.finished || b.finished {
                if a.finished && b.finished { return a.finishOrder < b.finishOrder }
                return a.finished
            }
            return a.progress > b.progress
        }
    }

    private func results() -> [RaceResult] {
        standings().enumerated().map { idx, r in
            RaceResult(
                place: r.finished ? r.finishOrder : idx + 1,
                name: r.name,
                isPlayer: r.isPlayer,
                finished: r.finished,
                time: r.finishTime ?? raceTime
            )
        }
    }

    private func updateHUD() {
        let list = standings()
        let place = (list.firstIndex(where: { $0 === player }) ?? 0) + 1
        placeLabel.text = RaceResult(place: place, name: "", isPlayer: true, finished: false, time: 0).placeSuffix
        lapLabel.text = "LAP \(min(player.lap + 1, totalLaps))/\(totalLaps)"
        timeLabel.text = String(format: "%.1fs", raceTime)
        itemButton.text = player.item?.label ?? "ITEM"
    }

    // MARK: - Draw

    override func didFinishUpdate() {
        // Custom draw in a single SKShapeNode rebuilt each frame is heavy;
        // use an overlay node with CoreGraphics texture instead.
        renderFrame()
    }

    private var roadNode: SKSpriteNode?

    private func renderFrame() {
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 10, h > 10 else { return }

        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Ceiling
        let colors = [UIColor(red: 0.09, green: 0.20, blue: 0.24, alpha: 1).cgColor,
                      UIColor(red: 0.11, green: 0.16, blue: 0.19, alpha: 1).cgColor,
                      UIColor(red: 0.14, green: 0.11, blue: 0.09, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }

        drawRoad(ctx: ctx)
        drawSprites(ctx: ctx)
        drawPlayerCart(ctx: ctx)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let image else { return }

        let tex = SKTexture(image: image)
        if let roadNode {
            roadNode.texture = tex
            roadNode.size = size
            roadNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        } else {
            let node = SKSpriteNode(texture: tex, size: size)
            node.position = CGPoint(x: size.width / 2, y: size.height / 2)
            node.zPosition = -10
            addChild(node)
            roadNode = node
        }
    }

    private func drawRoad(ctx: CGContext) {
        let drawDist = 160
        let roadWidth: CGFloat = 2200
        let camHeight: CGFloat = 1000
        let camDepth: CGFloat = 0.84
        var curveAccum: CGFloat = 0
        var prevY = size.height
        var prevX = size.width / 2
        var prevW = roadWidth

        ctx.setFillColor(UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: size.height * 0.52, width: size.width, height: size.height * 0.48))

        for n in stride(from: drawDist, through: 0, by: -1) {
            let z = player.z + CGFloat(n)
            let seg = track.sample(z)
            let scale = camDepth / (CGFloat(n) + camDepth)
            let y = size.height * 0.55 + camHeight * scale * 0.42
            let x = size.width / 2 - cameraX * roadWidth * scale * 0.42 + curveAccum
            let w = roadWidth * scale * 0.42
            curveAccum += seg.curve * CGFloat(n) * 0.018

            if n < drawDist {
                let stripe = Int(z) % 2 == 0
                let theme = seg.theme

                ctx.setFillColor((stripe ? theme.wall : theme.shelf).cgColor)
                ctx.fill(CGRect(x: 0, y: y, width: max(0, x - w * 1.15), height: max(0.5, prevY - y)))
                ctx.fill(CGRect(x: x + w * 1.15, y: y, width: max(0, size.width - (x + w * 1.15)), height: max(0.5, prevY - y)))

                ctx.setFillColor((stripe ? theme.road : theme.roadAlt).cgColor)
                fillRoadPoly(ctx, prevX, prevY, prevW, x, y, w)
                ctx.setFillColor(theme.edge.cgColor)
                fillRoadPoly(ctx, prevX, prevY, prevW, x, y, w * 1.02)
                ctx.setFillColor((stripe ? theme.road : theme.roadAlt).cgColor)
                fillRoadPoly(ctx, prevX, prevY, prevW * 0.94, x, y, w * 0.94)

                if Int(z) % 3 == 0 {
                    ctx.setFillColor(UIColor(white: 1, alpha: 0.3).cgColor)
                    fillRoadPoly(ctx, prevX, prevY, prevW * 0.03, x, y, w * 0.03)
                }
            }
            prevY = y; prevX = x; prevW = w
        }
    }

    private func fillRoadPoly(_ ctx: CGContext, _ x1: CGFloat, _ y1: CGFloat, _ w1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ w2: CGFloat) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x1 - w1, y: y1))
        ctx.addLine(to: CGPoint(x: x1 + w1, y: y1))
        ctx.addLine(to: CGPoint(x: x2 + w2, y: y2))
        ctx.addLine(to: CGPoint(x: x2 - w2, y: y2))
        ctx.closePath()
        ctx.fillPath()
    }

    private func drawSprites(ctx: CGContext) {
        let drawDist: CGFloat = 160
        var sprites: [(CGFloat, () -> Void)] = []

        for p in pickups where p.alive {
            var dz = p.z - player.z
            if dz < 0 { dz += track.length }
            if dz > 0 && dz < drawDist {
                sprites.append((dz, { [self] in self.drawDiamond(ctx, dz: dz, x: p.x, color: .systemTeal) }))
            }
        }
        for h in hazards {
            var dz = h.z - player.z
            if dz < 0 { dz += track.length }
            if dz > 0 && dz < drawDist {
                sprites.append((dz, { [self] in self.drawOval(ctx, dz: dz, x: h.x, color: .systemYellow) }))
            }
        }
        for r in racers where !r.isPlayer {
            var dz = r.z - player.z
            if dz < -track.length / 2 { dz += track.length }
            if dz > track.length / 2 { dz -= track.length }
            if dz > 1 && dz < drawDist {
                sprites.append((dz, { [self] in self.drawCart(ctx, dz: dz, racer: r) }))
            }
        }
        sprites.sort { $0.0 > $1.0 }
        sprites.forEach { $0.1() }
    }

    private func project(dz: CGFloat, x: CGFloat) -> (CGPoint, CGFloat) {
        let camDepth: CGFloat = 0.84
        let roadWidth: CGFloat = 2200
        let camHeight: CGFloat = 1000
        let scale = camDepth / (dz + camDepth)
        let curve = track.curveAhead(player.z, look: max(2, Int(dz))) * dz * 0.55
        let px = size.width / 2 + (x - cameraX) * roadWidth * scale * 0.42 + curve
        let py = size.height * 0.55 + camHeight * scale * 0.42
        return (CGPoint(x: px, y: py), scale)
    }

    private func drawDiamond(_ ctx: CGContext, dz: CGFloat, x: CGFloat, color: UIColor) {
        let (p, scale) = project(dz: dz, x: x)
        let s = max(6, 48 * scale * 28)
        ctx.setFillColor(color.cgColor)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: p.x, y: p.y - s))
        ctx.addLine(to: CGPoint(x: p.x + s * 0.4, y: p.y - s * 0.5))
        ctx.addLine(to: CGPoint(x: p.x, y: p.y))
        ctx.addLine(to: CGPoint(x: p.x - s * 0.4, y: p.y - s * 0.5))
        ctx.closePath()
        ctx.fillPath()
    }

    private func drawOval(_ ctx: CGContext, dz: CGFloat, x: CGFloat, color: UIColor) {
        let (p, scale) = project(dz: dz, x: x)
        let s = max(5, 36 * scale * 28)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - s * 0.45, y: p.y - s * 0.25, width: s * 0.9, height: s * 0.35))
    }

    private func drawCart(ctx: CGContext, dz: CGFloat, racer: Racer) {
        let (p, scale) = project(dz: dz, x: racer.x)
        let s = max(8, 55 * scale * 28)
        let uiColor = UIColor(racer.cart.color)
        ctx.setFillColor(uiColor.cgColor)
        let rect = CGRect(x: p.x - s * 0.35, y: p.y - s * 0.55, width: s * 0.7, height: s * 0.4)
        ctx.fill(rect)
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - s * 0.3, y: p.y - s * 0.08, width: s * 0.16, height: s * 0.16))
        ctx.fillEllipse(in: CGRect(x: p.x + s * 0.14, y: p.y - s * 0.08, width: s * 0.16, height: s * 0.16))
    }

    private func drawPlayerCart(ctx: CGContext) {
        // UIGraphics origin is top-left; bottom of screen ≈ size.height
        let x = size.width / 2 + player.steer * 18
        let y = size.height * 0.82
        let s: CGFloat = 70
        let uiColor = UIColor(player.cart.color)
        ctx.setFillColor(UIColor(white: 0, alpha: 0.3).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - s * 0.55, y: y + s * 0.25, width: s * 1.1, height: s * 0.25))
        ctx.setFillColor(uiColor.cgColor)
        ctx.fill(CGRect(x: x - s * 0.35, y: y - s * 0.15, width: s * 0.7, height: s * 0.4))
        ctx.setStrokeColor(UIColor(player.cart.accent).cgColor)
        ctx.setLineWidth(3)
        ctx.stroke(CGRect(x: x - s * 0.35, y: y - s * 0.15, width: s * 0.7, height: s * 0.4))
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fillEllipse(in: CGRect(x: x - s * 0.3, y: y + s * 0.22, width: s * 0.18, height: s * 0.18))
        ctx.fillEllipse(in: CGRect(x: x + s * 0.12, y: y + s * 0.22, width: s * 0.18, height: s * 0.18))
        if player.shield > 0 {
            ctx.setStrokeColor(UIColor(red: 0.94, green: 0.70, blue: 0.16, alpha: 0.7).cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: x - s * 0.5, y: y - s * 0.25, width: s, height: s * 0.7))
        }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            if quitButton.contains(p) { onQuit(); return }
            if itemButton.contains(p) || itemButton.parent == nil && abs(p.x - itemButton.position.x) < 50 && abs(p.y - itemButton.position.y) < 30 {
                useItem(player); continue
            }
            // item hit test with background
            if abs(p.x - itemButton.position.x) < 50 && abs(p.y - itemButton.position.y) < 30 {
                useItem(player); continue
            }
            if gasButton.contains(p) { gasHeld = true; continue }
            if brakeButton.contains(p) { brakeHeld = true; continue }
            if hypot(p.x - steerBase.position.x, p.y - steerBase.position.y) < 70 {
                steeringTouch = t
                updateSteer(p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            if t === steeringTouch { updateSteer(p) }
            if gasButton.contains(p) { gasHeld = true }
            if brakeButton.contains(p) { brakeHeld = true }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if t === steeringTouch {
                steeringTouch = nil
                steerValue = 0
                steerKnob.position = .zero
            }
            let p = t.location(in: self)
            if gasButton.contains(p) { gasHeld = false }
            if brakeButton.contains(p) { brakeHeld = false }
        }
        // release pedals if no fingers remain on them
        if touches.isEmpty { gasHeld = false; brakeHeld = false }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateSteer(_ p: CGPoint) {
        let dx = max(-40, min(40, p.x - steerBase.position.x))
        let dy = max(-40, min(40, p.y - steerBase.position.y))
        steerKnob.position = CGPoint(x: dx, y: dy)
        steerValue = dx / 40
    }
}

// MARK: - Supporting types

enum RaceState { case countdown, racing, finished }

final class Racer {
    let cart: CartDef
    let isPlayer: Bool
    let name: String
    var z: CGFloat
    var x: CGFloat
    var speed: CGFloat = 0
    var maxSpeed: CGFloat
    var accel: CGFloat
    var handling: CGFloat
    var steer: CGFloat = 0
    var gas = false
    var brake = false
    var lap = 0
    var finished = false
    var finishOrder = 0
    var finishTime: TimeInterval?
    var item: ItemType?
    var shield: TimeInterval = 0
    var boost: TimeInterval = 0
    var stunned: TimeInterval = 0
    var aiPhase: TimeInterval
    var progress: CGFloat = 0

    init(cart: CartDef, isPlayer: Bool, z: CGFloat, x: CGFloat) {
        self.cart = cart
        self.isPlayer = isPlayer
        self.name = cart.name
        self.z = z
        self.x = x
        self.maxSpeed = 280 * cart.speed
        self.accel = 140 * cart.accel
        self.handling = 2.6 * cart.handling
        self.aiPhase = TimeInterval.random(in: 0...(Double.pi * 2))
    }
}

struct Pickup {
    var z: CGFloat
    var x: CGFloat
    var type: ItemType
    var alive = true
    var respawn: TimeInterval = 0
}

struct Hazard {
    var z: CGFloat
    var x: CGFloat
    var life: TimeInterval
}

struct Projectile {
    var owner: Racer
    var z: CGFloat
    var x: CGFloat
    var speed: CGFloat
    var life: TimeInterval
}

struct TrackTheme {
    let road: UIColor
    let roadAlt: UIColor
    let edge: UIColor
    let wall: UIColor
    let shelf: UIColor
}

struct TrackData {
    struct Seg { let len: CGFloat; let curve: CGFloat; let theme: String }
    private let segs: [Seg] = [
        .init(len: 40, curve: 0, theme: "entrance"),
        .init(len: 35, curve: 0, theme: "aisle"),
        .init(len: 45, curve: -2.4, theme: "produce"),
        .init(len: 30, curve: -3.2, theme: "produce"),
        .init(len: 40, curve: 0, theme: "dairy"),
        .init(len: 50, curve: 2.8, theme: "freezer"),
        .init(len: 35, curve: 3.0, theme: "freezer"),
        .init(len: 40, curve: 0, theme: "aisle"),
        .init(len: 45, curve: -1.8, theme: "checkout"),
        .init(len: 35, curve: 2.2, theme: "checkout"),
        .init(len: 50, curve: 0, theme: "aisle"),
        .init(len: 40, curve: -2.6, theme: "bakery"),
        .init(len: 45, curve: 2.5, theme: "bakery"),
        .init(len: 55, curve: 0, theme: "entrance"),
    ]
    private(set) var length: CGFloat = 0
    private var cumulative: [(Seg, CGFloat, CGFloat)] = []

    private let themes: [String: TrackTheme] = [
        "entrance": TrackTheme(road: UIColor(white: 0.25, alpha: 1), roadAlt: UIColor(white: 0.28, alpha: 1), edge: UIColor(red: 0.94, green: 0.70, blue: 0.16, alpha: 1), wall: UIColor(red: 0.42, green: 0.31, blue: 0.23, alpha: 1), shelf: UIColor(red: 0.54, green: 0.42, blue: 0.29, alpha: 1)),
        "aisle": TrackTheme(road: UIColor(white: 0.26, alpha: 1), roadAlt: UIColor(white: 0.29, alpha: 1), edge: UIColor(red: 0.89, green: 0.23, blue: 0.18, alpha: 1), wall: UIColor(red: 0.18, green: 0.44, blue: 0.47, alpha: 1), shelf: UIColor(red: 0.12, green: 0.31, blue: 0.34, alpha: 1)),
        "produce": TrackTheme(road: UIColor(red: 0.23, green: 0.27, blue: 0.22, alpha: 1), roadAlt: UIColor(red: 0.26, green: 0.30, blue: 0.24, alpha: 1), edge: UIColor(red: 0.25, green: 0.56, blue: 0.31, alpha: 1), wall: UIColor(red: 0.31, green: 0.56, blue: 0.24, alpha: 1), shelf: UIColor(red: 0.24, green: 0.44, blue: 0.19, alpha: 1)),
        "dairy": TrackTheme(road: UIColor(white: 0.27, alpha: 1), roadAlt: UIColor(white: 0.30, alpha: 1), edge: UIColor(red: 0.77, green: 0.83, blue: 0.85, alpha: 1), wall: UIColor(red: 0.56, green: 0.64, blue: 0.68, alpha: 1), shelf: UIColor(red: 0.44, green: 0.52, blue: 0.55, alpha: 1)),
        "freezer": TrackTheme(road: UIColor(red: 0.20, green: 0.27, blue: 0.29, alpha: 1), roadAlt: UIColor(red: 0.23, green: 0.30, blue: 0.32, alpha: 1), edge: UIColor(red: 0.43, green: 0.77, blue: 0.78, alpha: 1), wall: UIColor(red: 0.31, green: 0.50, blue: 0.54, alpha: 1), shelf: UIColor(red: 0.23, green: 0.38, blue: 0.41, alpha: 1)),
        "checkout": TrackTheme(road: UIColor(red: 0.25, green: 0.23, blue: 0.21, alpha: 1), roadAlt: UIColor(red: 0.28, green: 0.25, blue: 0.23, alpha: 1), edge: UIColor(red: 0.94, green: 0.70, blue: 0.16, alpha: 1), wall: UIColor(red: 0.54, green: 0.23, blue: 0.20, alpha: 1), shelf: UIColor(red: 0.42, green: 0.16, blue: 0.14, alpha: 1)),
        "bakery": TrackTheme(road: UIColor(red: 0.27, green: 0.25, blue: 0.21, alpha: 1), roadAlt: UIColor(red: 0.30, green: 0.27, blue: 0.23, alpha: 1), edge: UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: 1), wall: UIColor(red: 0.54, green: 0.42, blue: 0.23, alpha: 1), shelf: UIColor(red: 0.42, green: 0.31, blue: 0.19, alpha: 1)),
    ]

    init() {
        var total: CGFloat = 0
        cumulative = segs.map { s in
            let start = total
            total += s.len
            return (s, start, total)
        }
        length = total
    }

    func sample(_ z: CGFloat) -> (curve: CGFloat, theme: TrackTheme) {
        let pos = ((z.truncatingRemainder(dividingBy: length)) + length).truncatingRemainder(dividingBy: length)
        for (s, start, end) in cumulative {
            if pos >= start && pos < end {
                return (s.curve, themes[s.theme] ?? themes["aisle"]!)
            }
        }
        return (0, themes["aisle"]!)
    }

    func curveAhead(_ z: CGFloat, look: Int) -> CGFloat {
        var sum: CGFloat = 0
        for i in 0..<look { sum += sample(z + CGFloat(i)).curve }
        return sum / CGFloat(max(1, look))
    }
}

extension UIColor {
    convenience init(_ color: Color) {
        let ui = UIColor(color)
        self.init(cgColor: ui.cgColor)
    }
}
