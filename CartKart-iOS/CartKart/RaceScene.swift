// RaceScene.swift — SpriteKit MegaMart race
import SpriteKit
import UIKit
import SwiftUI
import Combine

final class RaceScene: SKScene, ObservableObject {
    var steerInput: Float = 0
    var gas: Bool = true
    var braking: Bool = false
    var wantsFire: Bool = false

    @Published private(set) var hudPlace: String = "1st"
    @Published private(set) var hudLap: String = "LAP 1/3"
    @Published private(set) var hudItem: String = ""
    @Published private(set) var countdownText: String = "3"

    private var playerCart: CartDef = CartCatalog.all[0]
    private var onFinished: (([RaceResult]) -> Void)?
    private var racers: [KartNode] = []
    private var player: KartNode?
    private var worldItems = ItemWorld()
    private var countdown: CGFloat = 3.2
    private var raceTime: TimeInterval = 0
    private var finishedOrder: [KartNode] = []
    private var ended = false
    private let totalLaps = 3

    private let tile: CGFloat = 48
    private let mapW = 42
    private let mapH = 32
    private var walls: [[Bool]] = []
    private var waypoints: [CGPoint] = []
    private var trackNode = SKNode()

    func configure(playerCart: CartDef, onFinished: @escaping ([RaceResult]) -> Void) {
        self.playerCart = playerCart
        self.onFinished = onFinished
        removeAllChildren()
        racers.removeAll()
        finishedOrder.removeAll()
        ended = false
        countdown = 3.2
        raceTime = 0
        worldItems = ItemWorld()
        buildTrack()
        spawnRacers()
        if let p = player {
            camera = SKCameraNode()
            addChild(camera!)
            camera!.position = p.position
        }
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.23, blue: 0.16, alpha: 1)
        isUserInteractionEnabled = true
    }

    private func buildTrack() {
        walls = Array(repeating: Array(repeating: false, count: mapW), count: mapH)
        trackNode.removeAllChildren()
        trackNode = SKNode()
        addChild(trackNode)

        for y in 0..<mapH {
            for x in 0..<mapW {
                var wall = x < 2 || y < 2 || x >= mapW - 2 || y >= mapH - 2
                if x >= 12 && x <= 29 && y >= 10 && y <= 21 {
                    let hole = (x >= 14 && x <= 27 && y >= 12 && y <= 19)
                    wall = !hole
                    if (x == 12 || x == 29) && y >= 14 && y <= 17 { wall = false }
                }
                if y == 6 && ((x >= 6 && x <= 18) || (x >= 24 && x <= 35)) { wall = true }
                if y == 25 && ((x >= 6 && x <= 18) || (x >= 24 && x <= 35)) { wall = true }
                walls[y][x] = wall

                let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
                n.position = CGPoint(x: CGFloat(x) * tile + tile / 2, y: CGFloat(y) * tile + tile / 2)
                n.lineWidth = 0
                if wall {
                    n.fillColor = UIColor(red: 0.29, green: 0.20, blue: 0.16, alpha: 1)
                } else {
                    let checker = (x + y) % 2 == 0
                    n.fillColor = checker
                        ? UIColor(red: 0.85, green: 0.79, blue: 0.66, alpha: 1)
                        : UIColor(red: 0.81, green: 0.75, blue: 0.63, alpha: 1)
                }
                trackNode.addChild(n)
            }
        }

        // Start line
        for x in 15...26 {
            let n = SKShapeNode(rectOf: CGSize(width: tile, height: tile))
            n.position = CGPoint(x: CGFloat(x) * tile + tile / 2, y: CGFloat(mapH - 4) * tile + tile / 2)
            n.fillColor = ((x % 2) == 0) ? .black : .white
            n.lineWidth = 0
            n.zPosition = 1
            trackNode.addChild(n)
        }

        // Item crates
        let spots: [(Int, Int)] = [(8, 8), (10, 15), (8, 22), (20, 4), (28, 8), (33, 15), (28, 22), (20, 27)]
        for (x, y) in spots where !walls[y][x] {
            let crate = SKLabelNode(text: "📦")
            crate.fontSize = 22
            crate.position = CGPoint(x: CGFloat(x) * tile + tile / 2, y: CGFloat(y) * tile + tile / 2)
            crate.zPosition = 2
            crate.name = "crate"
            trackNode.addChild(crate)
            worldItems.crates.append(Crate(node: crate, respawn: 0))
        }

        waypoints = [
            CGPoint(x: 20.5 * tile, y: CGFloat(mapH - 3) * tile),
            CGPoint(x: 30 * tile, y: CGFloat(mapH - 3) * tile),
            CGPoint(x: 37 * tile, y: 24 * tile),
            CGPoint(x: 37 * tile, y: 8 * tile),
            CGPoint(x: 20 * tile, y: 4.5 * tile),
            CGPoint(x: 4.5 * tile, y: 8 * tile),
            CGPoint(x: 4.5 * tile, y: 24 * tile),
            CGPoint(x: 10 * tile, y: CGFloat(mapH - 3) * tile),
        ]
    }

    private func spawnRacers() {
        let starts: [CGPoint] = (0..<6).map { i in
            CGPoint(x: 14 * tile - CGFloat(i) * 40, y: CGFloat(mapH - 3) * tile + (i % 2 == 0 ? -20 : 10))
        }
        let player = KartNode(cart: playerCart, isPlayer: true, nameLabel: playerCart.name)
        player.position = starts[0]
        player.zRotation = 0
        addChild(player)
        racers.append(player)
        self.player = player

        let others = CartCatalog.all.filter { $0.id != playerCart.id }.shuffled().prefix(5)
        for (i, cart) in others.enumerated() {
            let k = KartNode(cart: cart, isPlayer: false, nameLabel: cart.name)
            k.position = starts[i + 1]
            addChild(k)
            racers.append(k)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0
        if ended { return }

        if countdown > 0 {
            countdown -= dt
            let n = Int(ceil(Double(countdown)))
            countdownText = countdown <= 0 ? "GO!" : "\(max(n, 1))"
            if countdown <= 0 { countdownText = "GO!" }
            followCamera()
            return
        }
        if countdownText == "GO!" {
            countdownText = ""
        }

        raceTime += TimeInterval(dt)

        for r in racers where !r.finished {
            updateKart(r, dt: dt)
        }
        separate()
        updateItems(dt: dt)
        rank()
        checkFinish()
        followCamera()
        refreshHud()
    }

    private func updateKart(_ r: KartNode, dt: CGFloat) {
        var steer: CGFloat = 0
        var throttle: CGFloat = 0
        var brake = false

        if r.isPlayer {
            steer = CGFloat(steerInput)
            brake = braking
            throttle = gas && !brake ? 1 : 0
            if wantsFire {
                useItem(r)
                wantsFire = false
            }
        } else {
            let wp = waypoints[r.wp % waypoints.count]
            let desired = atan2(wp.y - r.position.y, wp.x - r.position.x)
            var diff = desired - r.zRotation
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            steer = max(-1, min(1, diff * 1.8))
            throttle = r.slip > 0 ? 0.4 : 0.9
            if r.item != nil && Int.random(in: 0..<120) == 0 {
                useItem(r)
            }
        }

        if r.stunned > 0 {
            r.stunned -= dt
            r.speed *= 0.92
        }

        let maxSp = r.cart.maxSpeed * (r.boost > 0 ? 1.55 : 1) * (r.slip > 0 ? 0.45 : 1)
        if brake {
            r.speed *= 0.9
        } else if throttle > 0 && r.stunned <= 0 {
            r.speed += r.cart.accel * throttle * dt * (r.boost > 0 ? 1.4 : 1)
        } else {
            r.speed *= 0.985
        }
        r.speed = max(0, min(maxSp, r.speed))

        let turn = r.cart.turn * (0.45 + 0.55 * (r.speed / max(maxSp, 1))) * dt
        r.zRotation += steer * turn * (r.slip > 0 ? 1.8 : 1)

        if r.boost > 0 { r.boost -= dt }
        if r.slip > 0 { r.slip -= dt }

        let grip = r.cart.grip * (r.slip > 0 ? 0.35 : 1)
        let tvx = cos(r.zRotation) * r.speed
        let tvy = sin(r.zRotation) * r.speed
        r.vx = r.vx * (1 - grip) + tvx * grip
        r.vy = r.vy * (1 - grip) + tvy * grip

        var nx = r.position.x + r.vx * dt
        var ny = r.position.y + r.vy * dt
        if solid(nx, r.position.y) {
            r.vx *= -0.3
            r.speed *= 0.55
            nx = r.position.x
        }
        if solid(r.position.x, ny) {
            r.vy *= -0.3
            r.speed *= 0.55
            ny = r.position.y
        }
        r.position = CGPoint(x: nx, y: ny)

        // Waypoints / laps
        let target = waypoints[r.wp % waypoints.count]
        if hypot(target.x - r.position.x, target.y - r.position.y) < 70 {
            r.wp = (r.wp + 1) % waypoints.count
            if r.wp == 0 { r.lap += 1 }
        }
        let dist = hypot(target.x - r.position.x, target.y - r.position.y)
        r.progress = Double(r.lap * 1000 + r.wp * 10) + Double(1 - min(dist / 400, 1))
    }

    private func solid(_ x: CGFloat, _ y: CGFloat) -> Bool {
        let tx = Int(x / tile)
        let ty = Int(y / tile)
        if tx < 0 || ty < 0 || tx >= mapW || ty >= mapH { return true }
        return walls[ty][tx]
    }

    private func separate() {
        for i in 0..<racers.count {
            for j in (i + 1)..<racers.count {
                let a = racers[i]
                let b = racers[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let d = hypot(dx, dy)
                let minD: CGFloat = 34
                if d > 0 && d < minD {
                    let push = (minD - d) / 2
                    let nx = dx / d
                    let ny = dy / d
                    a.position.x -= nx * push
                    a.position.y -= ny * push
                    b.position.x += nx * push
                    b.position.y += ny * push
                    a.speed *= 0.85
                    b.speed *= 0.85
                }
            }
        }
    }

    private func updateItems(dt: CGFloat) {
        for crate in worldItems.crates {
            if !crate.alive {
                crate.respawn -= dt
                if crate.respawn <= 0 {
                    crate.alive = true
                    crate.node.isHidden = false
                }
                continue
            }
            for r in racers where r.item == nil && !r.finished {
                if hypot(r.position.x - crate.node.position.x, r.position.y - crate.node.position.y) < 24 {
                    crate.alive = false
                    crate.respawn = 6
                    crate.node.isHidden = true
                    r.item = ItemKind.allCases.randomElement()
                }
            }
        }

        worldItems.hazards = worldItems.hazards.filter { h in
            h.life -= dt
            for r in racers where r !== h.owner && !r.finished {
                if hypot(r.position.x - h.node.position.x, r.position.y - h.node.position.y) < h.radius {
                    if h.kind == .banana || h.kind == .milk {
                        r.slip = max(r.slip, h.kind == .milk ? 2.0 : 1.4)
                        r.speed *= 0.5
                        if h.kind == .banana { h.life = 0 }
                    }
                }
            }
            if h.life <= 0 { h.node.removeFromParent() }
            return h.life > 0
        }

        worldItems.projectiles = worldItems.projectiles.filter { p in
            p.life -= dt
            p.node.position.x += cos(p.angle) * p.speed * dt
            p.node.position.y += sin(p.angle) * p.speed * dt
            var hit = false
            if solid(p.node.position.x, p.node.position.y) { hit = true }
            for r in racers where r !== p.owner && !r.finished {
                if hypot(r.position.x - p.node.position.x, r.position.y - p.node.position.y) < 22 {
                    r.stunned = max(r.stunned, 1.1)
                    r.speed *= 0.3
                    hit = true
                }
            }
            if hit || p.life <= 0 { p.node.removeFromParent() }
            return !hit && p.life > 0
        }
    }

    private func useItem(_ r: KartNode) {
        guard let item = r.item else { return }
        r.item = nil
        switch item {
        case .soda:
            r.boost = 1.6
            r.speed = max(r.speed, r.cart.maxSpeed * 1.2)
        case .banana, .milk:
            let node = SKLabelNode(text: item == .banana ? "🍌" : "🥛")
            node.fontSize = item == .banana ? 22 : 18
            node.position = CGPoint(
                x: r.position.x - cos(r.zRotation) * 28,
                y: r.position.y - sin(r.zRotation) * 28
            )
            node.zPosition = 5
            addChild(node)
            worldItems.hazards.append(Hazard(kind: item, node: node, radius: item == .milk ? 36 : 16, life: item == .milk ? 8 : 12, owner: r))
        case .can:
            let node = SKLabelNode(text: "🥫")
            node.fontSize = 18
            node.position = CGPoint(
                x: r.position.x + cos(r.zRotation) * 24,
                y: r.position.y + sin(r.zRotation) * 24
            )
            node.zPosition = 6
            addChild(node)
            worldItems.projectiles.append(Projectile(node: node, angle: r.zRotation, speed: 420, life: 1.4, owner: r))
        case .bag:
            for o in racers where o !== r && !o.finished {
                if hypot(o.position.x - r.position.x, o.position.y - r.position.y) < 110 {
                    o.stunned = max(o.stunned, 0.9)
                    o.speed *= 0.4
                }
            }
        }
    }

    private func rank() {
        let live = racers.sorted { a, b in
            if a.finished && b.finished { return a.finishPlace < b.finishPlace }
            if a.finished { return true }
            if b.finished { return false }
            return a.progress > b.progress
        }
        for (i, r) in live.enumerated() where !r.finished {
            r.place = i + 1
        }
    }

    private func checkFinish() {
        for r in racers where !r.finished {
            if r.lap >= totalLaps {
                r.finished = true
                r.finishPlace = finishedOrder.count + 1
                r.finishTime = raceTime
                finishedOrder.append(r)
            }
        }
        guard let player, player.finished, !ended else { return }
        if racers.allSatisfy(\.finished) || raceTime - player.finishTime > 4 {
            let rest = racers.filter { !$0.finished }.sorted { $0.progress > $1.progress }
            for r in rest {
                r.finished = true
                r.finishPlace = finishedOrder.count + 1
                r.finishTime = raceTime
                finishedOrder.append(r)
            }
            ended = true
            let results = finishedOrder.map {
                RaceResult(place: $0.finishPlace, name: $0.cartName, isPlayer: $0.isPlayer, time: $0.finishTime)
            }
            onFinished?(results)
        }
    }

    private func followCamera() {
        guard let player, let camera else { return }
        let lead: CGFloat = 80
        let tx = player.position.x + cos(player.zRotation) * lead
        let ty = player.position.y + sin(player.zRotation) * lead
        camera.position.x += (tx - camera.position.x) * 0.12
        camera.position.y += (ty - camera.position.y) * 0.12
    }

    private func refreshHud() {
        guard let player else { return }
        let place = player.finished ? player.finishPlace : player.place
        let suffix: String
        switch place {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        let nextPlace = "\(place)\(suffix)"
        let lap = min(totalLaps, max(1, player.lap + 1))
        let nextLap = "LAP \(player.finished ? totalLaps : min(lap, totalLaps))/\(totalLaps)"
        let nextItem = player.item?.icon ?? ""
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hudPlace != nextPlace { self.hudPlace = nextPlace }
            if self.hudLap != nextLap { self.hudLap = nextLap }
            if self.hudItem != nextItem { self.hudItem = nextItem }
        }
    }
}

// MARK: - Supporting types

final class KartNode: SKNode {
    let cart: CartDef
    let isPlayer: Bool
    let cartName: String
    var speed: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var lap = 0
    var wp = 0
    var progress: Double = 0
    var place = 1
    var item: ItemKind?
    var stunned: CGFloat = 0
    var boost: CGFloat = 0
    var slip: CGFloat = 0
    var finished = false
    var finishPlace = 0
    var finishTime: TimeInterval = 0

    init(cart: CartDef, isPlayer: Bool, nameLabel: String) {
        self.cart = cart
        self.isPlayer = isPlayer
        self.cartName = nameLabel
        super.init()

        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 20), cornerRadius: 3)
        body.fillColor = UIColor(cart.basket)
        body.strokeColor = UIColor(cart.accent)
        body.lineWidth = 2
        addChild(body)

        let bumper = SKShapeNode(rectOf: CGSize(width: 8, height: 16))
        bumper.position = CGPoint(x: 14, y: 0)
        bumper.fillColor = UIColor(cart.color)
        bumper.lineWidth = 0
        addChild(bumper)

        if !isPlayer {
            let label = SKLabelNode(text: nameLabel)
            label.fontSize = 10
            label.fontName = "AvenirNext-Bold"
            label.position = CGPoint(x: 0, y: 22)
            label.fontColor = .white
            addChild(label)
        } else {
            let arrow = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: 28))
                p.addLine(to: CGPoint(x: -6, y: 38))
                p.addLine(to: CGPoint(x: 6, y: 38))
                p.closeSubpath()
                return p
            }())
            arrow.fillColor = UIColor(red: 0.94, green: 0.77, blue: 0.10, alpha: 1)
            arrow.lineWidth = 0
            addChild(arrow)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

final class Crate {
    let node: SKNode
    var alive = true
    var respawn: CGFloat
    init(node: SKNode, respawn: CGFloat) {
        self.node = node
        self.respawn = respawn
    }
}

final class Hazard {
    let kind: ItemKind
    let node: SKNode
    let radius: CGFloat
    var life: CGFloat
    weak var owner: KartNode?
    init(kind: ItemKind, node: SKNode, radius: CGFloat, life: CGFloat, owner: KartNode) {
        self.kind = kind
        self.node = node
        self.radius = radius
        self.life = life
        self.owner = owner
    }
}

final class Projectile {
    let node: SKNode
    var angle: CGFloat
    var speed: CGFloat
    var life: CGFloat
    weak var owner: KartNode?
    init(node: SKNode, angle: CGFloat, speed: CGFloat, life: CGFloat, owner: KartNode) {
        self.node = node
        self.angle = angle
        self.speed = speed
        self.life = life
        self.owner = owner
    }
}

struct ItemWorld {
    var crates: [Crate] = []
    var hazards: [Hazard] = []
    var projectiles: [Projectile] = []
}

extension UIColor {
    convenience init(_ color: Color) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: r, green: g, blue: b, alpha: a)
        #else
        self.init(white: 1, alpha: 1)
        #endif
    }
}
