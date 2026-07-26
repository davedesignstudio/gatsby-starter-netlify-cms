import SpriteKit

final class GameScene: SKScene {
    var onHUD: ((HUDState) -> Void)?
    var onRaceFinished: ((String, [RaceResult]) -> Void)?

    private var path: [CGPoint] = []
    private var trackWidth: CGFloat = 150
    private var shelves: [SKNode] = []
    private var karts: [KartNode] = []
    private var hazards: [HazardNode] = []
    private var projectiles: [ProjectileNode] = []
    private var itemBoxes: [ItemBoxNode] = []
    private var boostPads: [CGPoint] = []

    private var steer: CGFloat = 0
    private var gas = false
    private var brake = false
    private var countdown: CGFloat = 3.0
    private var racing = false
    private var raceTime: CGFloat = 0
    private var finishedAnnounced = false
    private let laps = 3
    private var cameraNode = SKCameraNode()
    private var floorNode = SKNode()

    func setSteer(_ value: CGFloat) { steer = value }
    func setGas(_ value: Bool) { gas = value }
    func setBrake(_ value: Bool) { brake = value }

    func usePlayerItem() {
        guard let player = karts.first(where: { $0.isPlayer }) else { return }
        fireItem(for: player)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.11, green: 0.14, blue: 0.17, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(cameraNode)
        camera = cameraNode
        buildTrackGeometry()
    }

    func startRace(playerBuild: CartBuild) {
        removeAllChildren()
        addChild(cameraNode)
        camera = cameraNode
        karts.removeAll()
        hazards.removeAll()
        projectiles.removeAll()
        itemBoxes.removeAll()
        shelves.removeAll()
        countdown = 3.0
        racing = false
        raceTime = 0
        finishedAnnounced = false
        gas = true

        buildTrackGeometry()

        var builds = [playerBuild]
        for b in CartBuild.all where b.id != playerBuild.id {
            builds.append(b)
        }
        while builds.count < 5 {
            builds.append(CartBuild.all[builds.count % CartBuild.all.count])
        }

        for (i, build) in builds.prefix(5).enumerated() {
            let kart = KartNode(build: build, isPlayer: i == 0)
            placeOnGrid(kart, lane: i)
            karts.append(kart)
            addChild(kart)
        }

        cameraNode.position = karts[0].position
        pushHUD()
    }

    private func buildTrackGeometry() {
        floorNode = SKNode()
        addChild(floorNode)

        path = []
        let n = 120
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n) * .pi * 2
            var x = cos(t) * 780
            var y = sin(t) * 480
            if sin(t * 2) > 0.2 { x *= 0.78 }
            if cos(t * 3) > 0.35 { y *= 0.72 }
            if t > 0.2 && t < 0.8 { x += sin(t * 8) * 40 }
            if t > 3.4 && t < 4.2 { y += cos(t * 6) * 35 }
            path.append(CGPoint(x: x, y: y))
        }

        // Linoleum ribbon
        let road = SKShapeNode()
        let roadPath = CGMutablePath()
        for i in 0..<path.count {
            let p = path[i]
            let prev = path[(i - 1 + path.count) % path.count]
            let next = path[(i + 1) % path.count]
            let ang = atan2(next.y - prev.y, next.x - prev.x)
            let nx = cos(ang + .pi / 2) * trackWidth
            let ny = sin(ang + .pi / 2) * trackWidth
            if i == 0 { roadPath.move(to: CGPoint(x: p.x + nx, y: p.y + ny)) }
            else { roadPath.addLine(to: CGPoint(x: p.x + nx, y: p.y + ny)) }
        }
        for i in stride(from: path.count - 1, through: 0, by: -1) {
            let p = path[i]
            let prev = path[(i - 1 + path.count) % path.count]
            let next = path[(i + 1) % path.count]
            let ang = atan2(next.y - prev.y, next.x - prev.x)
            let nx = cos(ang + .pi / 2) * trackWidth
            let ny = sin(ang + .pi / 2) * trackWidth
            roadPath.addLine(to: CGPoint(x: p.x - nx, y: p.y - ny))
        }
        roadPath.closeSubpath()
        road.path = roadPath
        road.fillColor = SKColor(red: 0.84, green: 0.78, blue: 0.64, alpha: 1)
        road.strokeColor = .clear
        road.zPosition = -10
        floorNode.addChild(road)

        let center = SKShapeNode()
        let dash = CGMutablePath()
        dash.move(to: path[0])
        for p in path.dropFirst() { dash.addLine(to: p) }
        dash.closeSubpath()
        center.path = dash
        center.strokeColor = SKColor.white.withAlphaComponent(0.35)
        center.lineWidth = 3
        center.zPosition = -9
        floorNode.addChild(center)

        // Shelves
        func shelf(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, color: SKColor) {
            let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 4)
            node.position = CGPoint(x: x, y: y)
            node.fillColor = color
            node.strokeColor = color.withAlphaComponent(0.6)
            node.zPosition = -5
            floorNode.addChild(node)
            shelves.append(node)
        }
        for i in -3...3 where i != 0 {
            shelf(CGFloat(i) * 220, -180, 48, 280, color: SKColor(red: 0.18, green: 0.44, blue: 0.31, alpha: 1))
            shelf(CGFloat(i) * 220, 220, 48, 260, color: SKColor(red: 0.18, green: 0.44, blue: 0.31, alpha: 1))
        }
        shelf(-700, -420, 260, 50, color: SKColor(red: 0.30, green: 0.43, blue: 0.51, alpha: 1))
        shelf(420, -420, 320, 50, color: SKColor(red: 0.30, green: 0.43, blue: 0.51, alpha: 1))
        shelf(-520, 420, 300, 50, color: SKColor(red: 0.42, green: 0.56, blue: 0.24, alpha: 1))
        shelf(480, 420, 280, 50, color: SKColor(red: 0.42, green: 0.56, blue: 0.24, alpha: 1))
        shelf(-860, 0, 50, 220, color: SKColor(red: 0.54, green: 0.42, blue: 0.24, alpha: 1))
        shelf(860, 40, 50, 200, color: SKColor(red: 0.54, green: 0.42, blue: 0.24, alpha: 1))

        boostPads = [CGPoint(x: 0, y: -480), CGPoint(x: 720, y: 0), CGPoint(x: -200, y: 460)]
        for pad in boostPads {
            let n = SKShapeNode(circleOfRadius: 50)
            n.position = pad
            n.fillColor = SKColor.yellow.withAlphaComponent(0.28)
            n.strokeColor = .yellow
            n.lineWidth = 3
            n.zPosition = -8
            floorNode.addChild(n)
            let label = SKLabelNode(text: ">>")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 20
            label.fontColor = .yellow
            label.verticalAlignmentMode = .center
            n.addChild(label)
        }

        let boxPts: [CGPoint] = [
            CGPoint(x: -500, y: -300), CGPoint(x: 300, y: -250), CGPoint(x: 600, y: 180),
            CGPoint(x: -650, y: 250), CGPoint(x: 100, y: 380), CGPoint(x: -100, y: -100),
        ]
        for p in boxPts {
            let box = ItemBoxNode()
            box.position = p
            itemBoxes.append(box)
            floorNode.addChild(box)
        }

        // Finish checker
        let s0 = path[0]
        let s1 = path[1]
        let ang = atan2(s1.y - s0.y, s1.x - s0.x)
        let finish = SKNode()
        finish.position = s0
        finish.zRotation = ang
        for i in -5..<5 {
            for j in 0..<2 {
                let cell = SKShapeNode(rectOf: CGSize(width: 16, height: 18))
                cell.position = CGPoint(x: CGFloat(j) * 16 - 8, y: CGFloat(i) * 18)
                cell.fillColor = ((i + j) % 2 == 0) ? .black : SKColor(white: 0.95, alpha: 1)
                cell.strokeColor = .clear
                finish.addChild(cell)
            }
        }
        finish.zPosition = -7
        floorNode.addChild(finish)
    }

    private func placeOnGrid(_ kart: KartNode, lane: Int) {
        let start = path[0]
        let next = path[1]
        let ang = atan2(next.y - start.y, next.x - start.x)
        let nx = cos(ang + .pi / 2)
        let ny = sin(ang + .pi / 2)
        let back = CGFloat(40 + lane * 55)
        kart.position = CGPoint(
            x: start.x - cos(ang) * back + nx * CGFloat(lane - 2) * 28,
            y: start.y - sin(ang) * back + ny * CGFloat(lane - 2) * 28
        )
        kart.zRotation = ang
        kart.pathIndex = 0
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        guard !karts.isEmpty else { return }

        if countdown > 0 {
            countdown -= dt
            let n = Int(ceil(countdown))
            var hud = HUDState()
            hud.countdown = countdown > 0 ? (n > 0 ? "\(n)" : "GO!") : nil
            if let p = karts.first(where: { $0.isPlayer }) {
                hud.place = place(of: p)
                hud.lap = min(p.lap + 1, laps)
                hud.speed = max(0, Int(p.speed * 0.28))
                hud.itemEmoji = p.item?.emoji ?? "—"
            }
            onHUD?(hud)
            if countdown <= 0 {
                racing = true
            }
            followCamera(dt)
            return
        }

        guard racing else { return }
        raceTime += dt

        for kart in karts {
            updateKart(kart, dt: dt)
        }
        resolveKartCollisions()
        updateProjectiles(dt)
        for box in itemBoxes { box.tick(dt) }
        hazards = hazards.filter { node in
            node.life -= dt
            if node.life <= 0 { node.removeFromParent(); return false }
            return true
        }

        followCamera(dt)
        pushHUD()
        checkFinish()
    }

    private func followCamera(_ dt: CGFloat) {
        guard let player = karts.first(where: { $0.isPlayer }) else { return }
        let t = min(1, 6 * dt)
        cameraNode.position.x += (player.position.x - cameraNode.position.x) * t
        cameraNode.position.y += (player.position.y - cameraNode.position.y) * t
    }

    private func nearestPath(_ point: CGPoint) -> (index: Int, dist: CGFloat, onTrack: Bool) {
        var best = 0
        var bestD = CGFloat.greatestFiniteMagnitude
        for (i, p) in path.enumerated() {
            let d = hypot(p.x - point.x, p.y - point.y)
            if d < bestD { bestD = d; best = i }
        }
        return (best, bestD, bestD < trackWidth * 0.95)
    }

    private func progress(of kart: KartNode) -> CGFloat {
        CGFloat(kart.lap * path.count + kart.pathIndex) + kart.pathFrac
    }

    private func place(of kart: KartNode) -> Int {
        let ordered = karts.sorted { a, b in
            if a.finished && b.finished { return a.finishTime < b.finishTime }
            if a.finished { return true }
            if b.finished { return false }
            return progress(of: a) > progress(of: b)
        }
        return (ordered.firstIndex(where: { $0 === kart }) ?? 0) + 1
    }

    private func updateKart(_ kart: KartNode, dt: CGFloat) {
        if kart.finished {
            kart.speed *= 1 - 2 * dt
            kart.position.x += cos(kart.zRotation) * kart.speed * dt
            kart.position.y += sin(kart.zRotation) * kart.speed * dt
            return
        }

        kart.stun = max(0, kart.stun - dt)
        kart.boost = max(0, kart.boost - dt)
        kart.slip = max(0, kart.slip - dt)
        kart.invuln = max(0, kart.invuln - dt)

        var turn: CGFloat = 0
        var doGas = false
        var doBrake = false

        if kart.stun > 0 {
            kart.zRotation += dt * 8
            kart.speed *= 1 - 1.5 * dt
        } else if kart.isPlayer {
            turn = steer
            doGas = gas
            doBrake = brake
        } else {
            let ai = aiControls(for: kart)
            turn = ai.turn
            doGas = ai.gas
            doBrake = ai.brake
            if kart.item != nil, CGFloat.random(in: 0...1) < dt * 0.35 {
                fireItem(for: kart)
            }
        }

        if kart.stun <= 0 {
            let steerAmt = turn * kart.build.turn * (0.35 + 0.65 * min(1, kart.speed / 160)) * (kart.slip > 0 ? 1.8 : 1)
            kart.zRotation += steerAmt * dt
            var top = kart.build.topSpeed * (kart.boost > 0 ? 1.35 : 1) * (kart.slip > 0 ? 0.7 : 1)
            if doGas { kart.speed += kart.build.accel * dt * (kart.boost > 0 ? 1.4 : 1) }
            if doBrake { kart.speed -= (kart.build.accel * 1.4 + kart.speed * 1.2) * dt }
            if !doGas && !doBrake { kart.speed -= 70 * dt }

            let info = nearestPath(kart.position)
            if !info.onTrack {
                kart.speed *= 1 - 1.8 * dt
                top *= 0.55
            }
            kart.speed = max(-90, min(top, kart.speed))

            let tvx = cos(kart.zRotation) * kart.speed
            let tvy = sin(kart.zRotation) * kart.speed
            var grip = kart.build.grip * (kart.slip > 0 ? 0.25 : 1)
            if abs(turn) > 0.5 && kart.speed > 180 { grip *= 0.7 }
            kart.vx += (tvx - kart.vx) * min(1, grip * 4 * dt)
            kart.vy += (tvy - kart.vy) * min(1, grip * 4 * dt)
        }

        kart.position.x += kart.vx * dt
        kart.position.y += kart.vy * dt
        resolveShelves(kart)
        updateProgress(kart)

        for pad in boostPads {
            if hypot(kart.position.x - pad.x, kart.position.y - pad.y) < 55 {
                kart.boost = max(kart.boost, 0.85)
            }
        }

        for box in itemBoxes where box.ready && kart.item == nil {
            if hypot(kart.position.x - box.position.x, kart.position.y - box.position.y) < 34 {
                kart.item = PowerUp.allCases.randomElement()
                box.collect()
            }
        }

        for h in hazards where kart.invuln <= 0 {
            let rad: CGFloat = h.kind == .soap ? 48 : 22
            if hypot(kart.position.x - h.position.x, kart.position.y - h.position.y) < rad + 16 {
                if h.kind == .banana {
                    kart.stun = 1.1
                    kart.invuln = 1.4
                    h.life = 0
                } else if h.kind == .soap {
                    kart.slip = max(kart.slip, 1.5)
                }
            }
        }

        kart.refreshVisual()
    }

    private func aiControls(for kart: KartNode) -> (turn: CGFloat, gas: Bool, brake: Bool) {
        let target = path[kart.aiTarget % path.count]
        let desired = atan2(target.y - kart.position.y, target.x - kart.position.x)
        var diff = desired - kart.zRotation
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let turn = max(-1, min(1, diff * 2.2))
        if hypot(target.x - kart.position.x, target.y - kart.position.y) < 90 {
            kart.aiTarget = (kart.aiTarget + 3) % path.count
        }
        guard let player = karts.first(where: { $0.isPlayer }) else {
            return (turn, true, abs(diff) > 1.3)
        }
        let gap = progress(of: player) - progress(of: kart)
        var throttle = true
        if gap < -12 { throttle = CGFloat.random(in: 0...1) > 0.25 }
        if abs(diff) > 0.9 { /* still gas but slower via turn */ }
        return (turn, throttle, abs(diff) > 1.3 && kart.speed > 120)
    }

    private func updateProgress(_ kart: KartNode) {
        let prev = kart.pathIndex
        let info = nearestPath(kart.position)
        kart.pathIndex = info.index
        let a = path[info.index]
        let b = path[(info.index + 1) % path.count]
        let seg = hypot(b.x - a.x, b.y - a.y)
        guard seg > 0 else { return }
        let along = ((kart.position.x - a.x) * (b.x - a.x) + (kart.position.y - a.y) * (b.y - a.y)) / (seg * seg)
        kart.pathFrac = max(0, min(0.999, along))
        if prev > path.count * 4 / 5 && info.index < path.count / 6 {
            if !kart.finished {
                kart.lap += 1
                if kart.lap >= laps {
                    kart.finished = true
                    kart.finishTime = raceTime
                    kart.speed *= 0.4
                }
            }
        }
    }

    private func resolveShelves(_ kart: KartNode) {
        let r: CGFloat = 22
        for shelf in shelves {
            let hw = shelf.frame.width / 2
            let hh = shelf.frame.height / 2
            let hx = max(shelf.position.x - hw, min(kart.position.x, shelf.position.x + hw))
            let hy = max(shelf.position.y - hh, min(kart.position.y, shelf.position.y + hh))
            var dx = kart.position.x - hx
            var dy = kart.position.y - hy
            var d = hypot(dx, dy)
            if d >= r || d < 0.001 { continue }
            let push = (r - d) / d
            kart.position.x += dx * push
            kart.position.y += dy * push
            dx /= d; dy /= d
            let dot = kart.vx * dx + kart.vy * dy
            if dot < 0 {
                kart.vx -= dx * dot * 1.4
                kart.vy -= dy * dot * 1.4
            }
            kart.speed *= 0.55
        }
    }

    private func resolveKartCollisions() {
        for i in 0..<karts.count {
            for j in (i + 1)..<karts.count {
                let a = karts[i]
                let b = karts[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let d = hypot(dx, dy)
                if d >= 40 || d < 0.01 { continue }
                let nx = dx / d
                let ny = dy / d
                let overlap = 40 - d
                a.position.x -= nx * overlap * 0.5
                a.position.y -= ny * overlap * 0.5
                b.position.x += nx * overlap * 0.5
                b.position.y += ny * overlap * 0.5
                let impact = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
                if impact > 0 {
                    a.vx -= nx * impact * 0.7
                    a.vy -= ny * impact * 0.7
                    b.vx += nx * impact * 0.7
                    b.vy += ny * impact * 0.7
                }
            }
        }
    }

    private func fireItem(for kart: KartNode) {
        guard let item = kart.item, kart.stun <= 0 else { return }
        kart.item = nil
        switch item {
        case .soda:
            kart.boost = max(kart.boost, 1.4)
        case .banana:
            let h = HazardNode(kind: .banana)
            h.position = CGPoint(
                x: kart.position.x - cos(kart.zRotation) * 40,
                y: kart.position.y - sin(kart.zRotation) * 40
            )
            hazards.append(h)
            addChild(h)
        case .soap:
            let h = HazardNode(kind: .soap)
            h.position = CGPoint(
                x: kart.position.x - cos(kart.zRotation) * 50,
                y: kart.position.y - sin(kart.zRotation) * 50
            )
            hazards.append(h)
            addChild(h)
        case .can:
            let p = ProjectileNode()
            p.position = CGPoint(
                x: kart.position.x + cos(kart.zRotation) * 30,
                y: kart.position.y + sin(kart.zRotation) * 30
            )
            p.vx = cos(kart.zRotation) * 520
            p.vy = sin(kart.zRotation) * 520
            p.owner = kart
            projectiles.append(p)
            addChild(p)
        }
    }

    private func updateProjectiles(_ dt: CGFloat) {
        projectiles = projectiles.filter { p in
            p.position.x += p.vx * dt
            p.position.y += p.vy * dt
            p.life -= dt
            var hit = p.life <= 0
            for shelf in shelves {
                let hw = shelf.frame.width / 2
                let hh = shelf.frame.height / 2
                if abs(p.position.x - shelf.position.x) < hw && abs(p.position.y - shelf.position.y) < hh {
                    hit = true
                }
            }
            for k in karts where k !== p.owner && k.invuln <= 0 && !k.finished {
                if hypot(k.position.x - p.position.x, k.position.y - p.position.y) < 28 {
                    k.stun = 0.9
                    k.invuln = 1.2
                    k.speed *= 0.4
                    hit = true
                }
            }
            if hit { p.removeFromParent() }
            return !hit
        }
    }

    private func pushHUD() {
        guard let player = karts.first(where: { $0.isPlayer }) else { return }
        var hud = HUDState()
        hud.place = place(of: player)
        hud.lap = min(player.lap + 1, laps)
        hud.speed = max(0, Int(player.speed * 0.28))
        hud.itemEmoji = player.item?.emoji ?? "—"
        if countdown > 0 {
            let n = Int(ceil(countdown))
            hud.countdown = n > 0 ? "\(n)" : "GO!"
        }
        onHUD?(hud)
    }

    private func checkFinish() {
        guard !finishedAnnounced, let player = karts.first(where: { $0.isPlayer }), player.finished else { return }
        let allDone = karts.allSatisfy(\.finished)
        if allDone || raceTime - player.finishTime > 4 {
            finishedAnnounced = true
            racing = false
            let ordered = karts.sorted { a, b in
                if a.finished && b.finished { return a.finishTime < b.finishTime }
                if a.finished { return true }
                if b.finished { return false }
                return progress(of: a) > progress(of: b)
            }
            let p = place(of: player)
            let title: String
            switch p {
            case 1: title = "Aisle Champion!"
            case 2: title = "Silver Cart!"
            case 3: title = "Bronze Basket!"
            default: title = "Back to the lot"
            }
            let rows = ordered.enumerated().map { i, k in
                RaceResult(place: i + 1, name: k.build.name, isPlayer: k.isPlayer)
            }
            onRaceFinished?(title, rows)
        }
    }
}

// MARK: - Nodes

final class KartNode: SKNode {
    let build: CartBuild
    let isPlayer: Bool
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var speed: CGFloat = 0
    var lap = 0
    var pathIndex = 0
    var pathFrac: CGFloat = 0
    var finished = false
    var finishTime: CGFloat = 0
    var item: PowerUp?
    var stun: CGFloat = 0
    var boost: CGFloat = 0
    var slip: CGFloat = 0
    var invuln: CGFloat = 0
    var aiTarget = 8

    private let body: SKShapeNode
    private let label: SKLabelNode

    init(build: CartBuild, isPlayer: Bool) {
        self.build = build
        self.isPlayer = isPlayer
        body = SKShapeNode(rectOf: CGSize(width: 34, height: 26), cornerRadius: 4)
        label = SKLabelNode(text: isPlayer ? "YOU" : build.name)
        super.init()
        body.fillColor = build.color
        body.strokeColor = build.accent
        body.lineWidth = 2
        addChild(body)
        let handle = SKShapeNode(rectOf: CGSize(width: 4, height: 22))
        handle.position = CGPoint(x: -20, y: 0)
        handle.fillColor = SKColor(white: 0.85, alpha: 1)
        handle.strokeColor = .clear
        addChild(handle)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = isPlayer ? .yellow : .white
        label.position = CGPoint(x: 0, y: 28)
        label.verticalAlignmentMode = .center
        addChild(label)
        zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func refreshVisual() {
        body.fillColor = boost > 0 ? build.color.withAlphaComponent(1) : build.color
        alpha = stun > 0 ? 0.75 : 1
    }
}

final class ItemBoxNode: SKNode {
    private(set) var ready = true
    private var cooldown: CGFloat = 0
    private let shape = SKShapeNode(rectOf: CGSize(width: 36, height: 36), cornerRadius: 8)
    private let mark = SKLabelNode(text: "?")

    override init() {
        super.init()
        shape.fillColor = SKColor(red: 0.12, green: 0.24, blue: 0.17, alpha: 1)
        shape.strokeColor = .yellow
        shape.lineWidth = 3
        addChild(shape)
        mark.fontName = "AvenirNext-Heavy"
        mark.fontSize = 20
        mark.fontColor = .yellow
        mark.verticalAlignmentMode = .center
        addChild(mark)
        zPosition = -6
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func collect() {
        ready = false
        cooldown = 4.5
        alpha = 0.25
    }

    func tick(_ dt: CGFloat) {
        if !ready {
            cooldown -= dt
            if cooldown <= 0 {
                ready = true
                alpha = 1
            }
        }
        mark.position.y = sin(CACurrentMediaTime() * 4 + Double(position.x)) * 3
    }
}

final class HazardNode: SKNode {
    enum Kind { case banana, soap }
    let kind: Kind
    var life: CGFloat

    init(kind: Kind) {
        self.kind = kind
        self.life = kind == .soap ? 14 : 18
        super.init()
        let label = SKLabelNode(text: kind == .banana ? "🍌" : "🧼")
        label.fontSize = kind == .banana ? 28 : 22
        label.verticalAlignmentMode = .center
        addChild(label)
        if kind == .soap {
            let puddle = SKShapeNode(circleOfRadius: 48)
            puddle.fillColor = SKColor.cyan.withAlphaComponent(0.28)
            puddle.strokeColor = .clear
            puddle.zPosition = -1
            addChild(puddle)
        }
        zPosition = 5
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

final class ProjectileNode: SKNode {
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var life: CGFloat = 1.6
    weak var owner: KartNode?

    override init() {
        super.init()
        let label = SKLabelNode(text: "🥫")
        label.fontSize = 22
        label.verticalAlignmentMode = .center
        addChild(label)
        zPosition = 8
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}
