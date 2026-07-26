import SpriteKit
import UIKit

/// Native SpriteKit port of Cart Rush — top-down supermarket kart race.
final class RaceScene: SKScene {
    private var player: CartNode!
    private var rivals: [CartNode] = []
    private var path: [CGPoint] = []
    private var shelves: [SKNode] = []
    private var pickups: [SKNode] = []
    private var hazards: [HazardNode] = []
    private var projectiles: [ProjectileNode] = []

    private var steer: CGFloat = 0
    private var gas = false
    private var touchSteer: UITouch?
    private var touchGas: UITouch?

    private var raceTime: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var playerItem: ItemKind?
    private var finishPlace = 0
    private var finished = false

    private(set) var hudText = "LAP 1/3 · 1st"

    private let lapsRequired = 3
    private let roadHalf: CGFloat = 95

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.18, blue: 0.12, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        physicsWorld.gravity = .zero

        buildTrack()
        spawnField()
        camera = SKCameraNode()
        addChild(camera!)
        camera?.position = player.position
    }

    private func buildTrack() {
        path = [
            CGPoint(x: -800, y: -400), CGPoint(x: -400, y: -450), CGPoint(x: 0, y: -480),
            CGPoint(x: 400, y: -420), CGPoint(x: 750, y: -280), CGPoint(x: 950, y: -50),
            CGPoint(x: 1000, y: 250), CGPoint(x: 880, y: 520), CGPoint(x: 600, y: 680),
            CGPoint(x: 250, y: 740), CGPoint(x: -100, y: 720), CGPoint(x: -400, y: 620),
            CGPoint(x: -620, y: 440), CGPoint(x: -740, y: 180), CGPoint(x: -780, y: -100),
            CGPoint(x: -760, y: -300)
        ]

        let road = SKShapeNode()
        let roadPath = CGMutablePath()
        roadPath.move(to: path[0])
        for p in path.dropFirst() { roadPath.addLine(to: p) }
        roadPath.closeSubpath()
        road.path = roadPath
        road.strokeColor = SKColor(red: 0.29, green: 0.39, blue: 0.31, alpha: 1)
        road.lineWidth = roadHalf * 2
        road.lineCap = .round
        road.lineJoin = .round
        road.zPosition = 1
        addChild(road)

        let dashes = SKShapeNode(path: roadPath)
        dashes.strokeColor = SKColor(red: 0.94, green: 0.78, blue: 0.27, alpha: 0.35)
        dashes.lineWidth = 4
        dashes.zPosition = 2
        addChild(dashes)

        let shelfRects: [(CGRect, String)] = [
            (CGRect(x: -200, y: 40, width: 420, height: 90), "CEREAL"),
            (CGRect(x: -200, y: -200, width: 420, height: 90), "SOUP"),
            (CGRect(x: 350, y: 40, width: 280, height: 90), "CHIPS"),
            (CGRect(x: 350, y: -200, width: 280, height: 90), "SODA"),
            (CGRect(x: -520, y: -120, width: 90, height: 380), "FROZEN"),
            (CGRect(x: 650, y: -120, width: 90, height: 380), "DAIRY")
        ]

        for (rect, label) in shelfRects {
            let node = SKShapeNode(rect: rect, cornerRadius: 4)
            node.fillColor = SKColor(red: 0.42, green: 0.29, blue: 0.20, alpha: 1)
            node.strokeColor = SKColor(white: 0, alpha: 0.35)
            node.zPosition = 5
            node.physicsBody = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.midX, y: rect.midY))
            node.physicsBody?.isDynamic = false
            addChild(node)
            shelves.append(node)

            let text = SKLabelNode(text: label)
            text.fontName = "AvenirNext-Bold"
            text.fontSize = 12
            text.fontColor = SKColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 0.75)
            text.position = CGPoint(x: rect.midX, y: rect.midY - 5)
            text.zPosition = 6
            addChild(text)
        }

        let spawnPoints = [
            CGPoint(x: 0, y: -480), CGPoint(x: 950, y: -50), CGPoint(x: 600, y: 680),
            CGPoint(x: -620, y: 440), CGPoint(x: 250, y: 740), CGPoint(x: 880, y: 520)
        ]
        for p in spawnPoints {
            let box = SKShapeNode(circleOfRadius: 16)
            box.fillColor = SKColor(red: 1, green: 0.42, blue: 0.17, alpha: 0.85)
            box.strokeColor = .clear
            box.position = p
            box.zPosition = 4
            box.name = "pickup"
            addChild(box)
            pickups.append(box)
        }
    }

    private func spawnField() {
        let start = path[0]
        let angle = atan2(path[1].y - path[0].y, path[1].x - path[0].x)

        player = CartNode(name: "You", color: SKColor(red: 1, green: 0.42, blue: 0.17, alpha: 1), isPlayer: true)
        player.position = start
        player.zRotation = angle
        player.zPosition = 10
        addChild(player)

        let roster: [(String, SKColor)] = [
            ("Squeaky", SKColor(red: 0.94, green: 0.78, blue: 0.27, alpha: 1)),
            ("Dent", SKColor(red: 0.31, green: 0.63, blue: 0.85, alpha: 1)),
            ("Wobbles", SKColor(red: 0.36, green: 0.75, blue: 0.48, alpha: 1))
        ]

        for (i, entry) in roster.enumerated() {
            let cart = CartNode(name: entry.0, color: entry.1, isPlayer: false)
            let offset = CGPoint(x: cos(angle + .pi) * CGFloat(i + 1) * 55, y: sin(angle + .pi) * CGFloat(i + 1) * 55)
            cart.position = CGPoint(x: start.x + offset.x, y: start.y + offset.y)
            cart.zRotation = angle
            cart.zPosition = 10
            addChild(cart)
            rivals.append(cart)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            let loc = touch.location(in: view)
            if loc.x < view.bounds.midX {
                touchSteer = touch
                updateSteer(touch, in: view)
            } else if loc.y < view.bounds.midY {
                // top-right-ish: use item
                usePlayerItem()
            } else {
                touchGas = touch
                gas = true
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touchSteer, touches.contains(touchSteer) else { return }
        updateSteer(touchSteer, in: view)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touchSteer, touches.contains(touchSteer) {
            self.touchSteer = nil
            steer = 0
        }
        if let touchGas, touches.contains(touchGas) {
            self.touchGas = nil
            gas = false
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateSteer(_ touch: UITouch, in view: SKView) {
        let loc = touch.location(in: view)
        let dx = loc.x - view.bounds.width * 0.25
        steer = max(-1, min(1, dx / 80))
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdate == 0 {
            dt = 1 / 60
        } else {
            dt = CGFloat(min(0.033, currentTime - lastUpdate))
        }
        lastUpdate = currentTime
        raceTime += currentTime == 0 ? 0 : TimeInterval(dt)

        tickCart(player, dt: dt, steer: steer, gas: gas)
        for rival in rivals {
            aiTick(rival, dt: dt)
        }

        resolveCartCollisions()
        updatePickups()
        updateHazards(dt: dt)
        updateProjectiles(dt: dt)

        camera?.position = player.position
        refreshHUD()
    }

    private func tickCart(_ cart: CartNode, dt: CGFloat, steer: CGFloat, gas: Bool) {
        if cart.spinTimer > 0 {
            cart.spinTimer -= dt
            cart.zRotation += 10 * dt
            cart.speed *= 0.92
        } else {
            let maxSpeed: CGFloat = 265 * (cart.boostTimer > 0 ? 1.45 : 1) * (cart.slowTimer > 0 ? 0.55 : 1)
            if gas { cart.speed += 340 * dt }
            else { cart.speed -= 90 * dt }
            cart.speed = max(0, min(maxSpeed, cart.speed))
            let turn = CGFloat(2.55) * (cart.speed > 20 ? 1 : 0.35)
            cart.zRotation += steer * turn * dt
        }

        cart.boostTimer = max(0, cart.boostTimer - dt)
        cart.slowTimer = max(0, cart.slowTimer - dt)
        cart.shieldTimer = max(0, cart.shieldTimer - dt)
        cart.invuln = max(0, cart.invuln - dt)

        cart.position.x += cos(cart.zRotation) * cart.speed * dt
        cart.position.y += sin(cart.zRotation) * cart.speed * dt

        // Soft shelf push-out
        for shelf in shelves {
            guard let body = shelf as? SKShapeNode, let path = body.path else { continue }
            let rect = path.boundingBox
            let closest = CGPoint(
                x: min(max(cart.position.x, rect.minX), rect.maxX),
                y: min(max(cart.position.y, rect.minY), rect.maxY)
            )
            let dx = cart.position.x - closest.x
            let dy = cart.position.y - closest.y
            let dist = hypot(dx, dy)
            if dist < 22 {
                let nx = dx / max(dist, 0.001)
                let ny = dy / max(dist, 0.001)
                cart.position.x += nx * (22 - dist)
                cart.position.y += ny * (22 - dist)
                cart.speed *= 0.75
            }
        }

        let progress = pathProgress(for: cart.position)
        if cart.lastProgress > 0.85 && progress < 0.15 {
            cart.lap += 1
        }
        cart.lastProgress = cart.progress
        cart.progress = progress

        if cart.isPlayer && cart.lap >= lapsRequired && !finished {
            finished = true
            finishPlace = currentPlace(for: player)
            hudText = "FINISHED · \(ordinal(finishPlace))"
        }
    }

    private func aiTick(_ cart: CartNode, dt: CGFloat) {
        let look = pathProgress(for: cart.position)
        let target = pointOnPath((look + 0.04).truncatingRemainder(dividingBy: 1))
        let desired = atan2(target.y - cart.position.y, target.x - cart.position.x)
        var diff = desired - cart.zRotation
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let s = max(-1, min(1, diff * 1.8))
        tickCart(cart, dt: dt, steer: s, gas: cart.spinTimer <= 0)

        if cart.item != nil, CGFloat.random(in: 0...1) < dt * 0.6 {
            fireItem(from: cart)
        }
    }

    private func resolveCartCollisions() {
        let all = [player] + rivals
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                let a = all[i]
                let b = all[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = hypot(dx, dy)
                if dist < 40 && dist > 0.001 {
                    let nx = dx / dist
                    let ny = dy / dist
                    let push = (40 - dist) / 2
                    a.position.x -= nx * push
                    a.position.y -= ny * push
                    b.position.x += nx * push
                    b.position.y += ny * push
                }
            }
        }
    }

    private func updatePickups() {
        for box in pickups where !box.isHidden {
            for cart in [player] + rivals {
                if cart.item != nil { continue }
                if hypot(cart.position.x - box.position.x, cart.position.y - box.position.y) < 30 {
                    let item = ItemKind.random(place: currentPlace(for: cart))
                    cart.item = item
                    if cart.isPlayer { playerItem = item }
                    box.isHidden = true
                    run(SKAction.sequence([
                        .wait(forDuration: 4.5),
                        .run { box.isHidden = false }
                    ]))
                }
            }
        }
    }

    private func usePlayerItem() {
        guard let item = player.item else { return }
        player.item = nil
        playerItem = nil
        apply(item, from: player)
    }

    private func fireItem(from cart: CartNode) {
        guard let item = cart.item else { return }
        cart.item = nil
        apply(item, from: cart)
    }

    private func apply(_ item: ItemKind, from cart: CartNode) {
        switch item {
        case .boost:
            cart.boostTimer = 1.35
        case .coupon:
            cart.shieldTimer = 3.5
        case .banana, .milk:
            let back = CGPoint(
                x: cart.position.x - cos(cart.zRotation) * 48,
                y: cart.position.y - sin(cart.zRotation) * 48
            )
            let hazard = HazardNode(kind: item == .banana ? .banana : .milk, owner: cart)
            hazard.position = back
            hazard.zPosition = 3
            addChild(hazard)
            hazards.append(hazard)
        case .can:
            let shot = ProjectileNode(owner: cart)
            shot.position = CGPoint(
                x: cart.position.x + cos(cart.zRotation) * 40,
                y: cart.position.y + sin(cart.zRotation) * 40
            )
            shot.velocity = CGVector(dx: cos(cart.zRotation) * 520, dy: sin(cart.zRotation) * 520)
            shot.zPosition = 8
            addChild(shot)
            projectiles.append(shot)
        }
    }

    private func updateHazards(dt: CGFloat) {
        hazards.removeAll { hazard in
            hazard.life -= dt
            if hazard.life <= 0 {
                hazard.removeFromParent()
                return true
            }
            for cart in [player] + rivals {
                if cart === hazard.owner || cart.invuln > 0 || cart.shieldTimer > 0 { continue }
                if hypot(cart.position.x - hazard.position.x, cart.position.y - hazard.position.y) < hazard.radius + 18 {
                    if hazard.kind == .banana {
                        cart.spinTimer = 1.1
                        cart.invuln = 1.3
                        hazard.removeFromParent()
                        return true
                    } else {
                        cart.slowTimer = 1.6
                        cart.invuln = 0.8
                    }
                }
            }
            return false
        }
    }

    private func updateProjectiles(dt: CGFloat) {
        projectiles.removeAll { shot in
            shot.life -= dt
            shot.position.x += shot.velocity.dx * dt
            shot.position.y += shot.velocity.dy * dt
            var dead = shot.life <= 0
            for cart in [player] + rivals {
                if cart === shot.owner || cart.invuln > 0 { continue }
                if hypot(cart.position.x - shot.position.x, cart.position.y - shot.position.y) < 28 {
                    if cart.shieldTimer > 0 {
                        cart.shieldTimer = 0
                    } else {
                        cart.spinTimer = 0.9
                        cart.speed *= 0.4
                        cart.invuln = 1.2
                    }
                    dead = true
                    break
                }
            }
            if dead { shot.removeFromParent() }
            return dead
        }
    }

    private func refreshHUD() {
        guard !finished else { return }
        let place = currentPlace(for: player)
        let lap = min(player.lap + 1, lapsRequired)
        let item = playerItem.map { " · \($0.label)" } ?? ""
        hudText = "LAP \(lap)/\(lapsRequired) · \(ordinal(place))\(item)"
    }

    private func currentPlace(for cart: CartNode) -> Int {
        let all = [player] + rivals
        let ranked = all.sorted { ($0.lap + $0.progress) > ($1.lap + $1.progress) }
        return (ranked.firstIndex(of: cart) ?? 0) + 1
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private func pathLength() -> CGFloat {
        var len: CGFloat = 0
        for i in 0..<path.count {
            let a = path[i]
            let b = path[(i + 1) % path.count]
            len += hypot(b.x - a.x, b.y - a.y)
        }
        return len
    }

    private func pathProgress(for point: CGPoint) -> CGFloat {
        var best: CGFloat = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        var accum: CGFloat = 0
        let total = pathLength()
        for i in 0..<path.count {
            let a = path[i]
            let b = path[(i + 1) % path.count]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let seg = hypot(dx, dy)
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / max(seg * seg, 0.001)))
            let px = a.x + dx * t
            let py = a.y + dy * t
            let dist = hypot(point.x - px, point.y - py)
            if dist < bestDist {
                bestDist = dist
                best = (accum + seg * t) / total
            }
            accum += seg
        }
        return best
    }

    private func pointOnPath(_ progress: CGFloat) -> CGPoint {
        var target = ((progress.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1) * pathLength()
        for i in 0..<path.count {
            let a = path[i]
            let b = path[(i + 1) % path.count]
            let seg = hypot(b.x - a.x, b.y - a.y)
            if target <= seg {
                let t = target / max(seg, 0.001)
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            target -= seg
        }
        return path[0]
    }
}

final class CartNode: SKNode {
    let cartName: String
    let isPlayer: Bool
    var speed: CGFloat = 0
    var lap = 0
    var progress: CGFloat = 0
    var lastProgress: CGFloat = 0
    var item: ItemKind?
    var spinTimer: CGFloat = 0
    var boostTimer: CGFloat = 0
    var slowTimer: CGFloat = 0
    var shieldTimer: CGFloat = 0
    var invuln: CGFloat = 0

    init(name: String, color: SKColor, isPlayer: Bool) {
        self.cartName = name
        self.isPlayer = isPlayer
        super.init()
        let body = SKShapeNode(rectOf: CGSize(width: 48, height: 32), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = SKColor(white: 0, alpha: 0.35)
        body.lineWidth = 2
        addChild(body)

        let label = SKLabelNode(text: isPlayer ? "YOU" : name)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = isPlayer ? SKColor(red: 1, green: 0.42, blue: 0.17, alpha: 1) : .white
        label.position = CGPoint(x: 0, y: 28)
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

enum ItemKind: CaseIterable {
    case banana, boost, can, coupon, milk

    var label: String {
        switch self {
        case .banana: return "BANANA"
        case .boost: return "SODA"
        case .can: return "SOUP"
        case .coupon: return "COUPON"
        case .milk: return "SPILL"
        }
    }

    static func random(place: Int) -> ItemKind {
        var pool = ItemKind.allCases
        if place >= 3 { pool += [.boost, .boost, .can] }
        if place == 1 { pool += [.banana, .milk] }
        return pool.randomElement() ?? .boost
    }
}

final class HazardNode: SKShapeNode {
    enum Kind { case banana, milk }
    let kind: Kind
    weak var owner: CartNode?
    var life: CGFloat
    var radius: CGFloat

    init(kind: Kind, owner: CartNode) {
        self.kind = kind
        self.owner = owner
        self.life = kind == .milk ? 12 : 18
        self.radius = kind == .milk ? 34 : 18
        super.init()
        if kind == .banana {
            path = CGPath(ellipseIn: CGRect(x: -14, y: -7, width: 28, height: 14), transform: nil)
            fillColor = SKColor(red: 0.94, green: 0.78, blue: 0.27, alpha: 1)
        } else {
            path = CGPath(ellipseIn: CGRect(x: -34, y: -24, width: 68, height: 48), transform: nil)
            fillColor = SKColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 0.55)
        }
        strokeColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ProjectileNode: SKShapeNode {
    weak var owner: CartNode?
    var velocity = CGVector.zero
    var life: CGFloat = 2.2

    init(owner: CartNode) {
        self.owner = owner
        super.init()
        path = CGPath(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24), transform: nil)
        fillColor = SKColor(red: 0.77, green: 0.36, blue: 0.23, alpha: 1)
        strokeColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
