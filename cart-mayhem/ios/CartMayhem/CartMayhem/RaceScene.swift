import SpriteKit
import SwiftUI

final class RaceScene: SKScene {
    private let totalLaps = 3
    private let trackWidth: CGFloat = 92

    private let track: [CGPoint] = [
        CGPoint(x: 0, y: -420),
        CGPoint(x: 180, y: -400),
        CGPoint(x: 320, y: -280),
        CGPoint(x: 360, y: -80),
        CGPoint(x: 300, y: 120),
        CGPoint(x: 180, y: 260),
        CGPoint(x: 40, y: 340),
        CGPoint(x: -140, y: 360),
        CGPoint(x: -300, y: 260),
        CGPoint(x: -360, y: 80),
        CGPoint(x: -340, y: -120),
        CGPoint(x: -260, y: -300),
        CGPoint(x: -100, y: -400)
    ]

    private var trackLength: CGFloat = 0
    private var carts: [CartNode] = []
    private var itemBoxes: [ItemBoxNode] = []
    private var hazards: [HazardNode] = []
    private var projectiles: [ProjectileNode] = []
    private var worldNode = SKNode()
    private var raceTime: TimeInterval = 0
    private var countdownTime: TimeInterval = 0

    private(set) var phase: RacePhase = .title
    var selectedRacer = 0
    private var countdownLabel = "3"
    private var playerLap = 0
    private var playerPlaceLabel = "1st"
    private var timeLabel = "0:00.0"
    private var playerItemIcon = "·"
    private var resultTitle = "FINISH!"
    private var standings: [String] = []

    var touchLeft = false
    var touchRight = false
    var touchDrift = false

    var onStateChange: ((RaceSnapshot) -> Void)?

    func setPhase(_ newPhase: RacePhase) {
        phase = newPhase
        publish()
    }

    private func publish() {
        onStateChange?(
            RaceSnapshot(
                phase: phase,
                countdownLabel: countdownLabel,
                playerLap: playerLap,
                playerPlaceLabel: playerPlaceLabel,
                timeLabel: timeLabel,
                playerItemIcon: playerItemIcon,
                resultTitle: resultTitle,
                standings: standings
            )
        )
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.12, blue: 0.09, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(worldNode)
        trackLength = computeTrackLength()
        drawStore()
        isPaused = false
    }

    func openSelect() { setPhase(.select) }
    func openHowTo() { setPhase(.howTo) }

    func startCountdown() {
        rebuildRace()
        countdownTime = 0
        countdownLabel = "3"
        setPhase(.countdown)
    }

    func usePlayerItem() {
        guard let player = carts.first(where: { $0.isPlayer }) else { return }
        useItem(for: player)
        updateHUD()
    }

    private func rebuildRace() {
        carts.forEach { $0.removeFromParent() }
        itemBoxes.forEach { $0.removeFromParent() }
        hazards.forEach { $0.removeFromParent() }
        projectiles.forEach { $0.removeFromParent() }
        carts.removeAll()
        itemBoxes.removeAll()
        hazards.removeAll()
        projectiles.removeAll()
        raceTime = 0

        var order = [selectedRacer]
        for i in 0..<RacerRoster.all.count where i != selectedRacer {
            order.append(i)
        }
        order = Array(order.prefix(4))

        for (idx, racerIndex) in order.enumerated() {
            let cart = CartNode(racer: RacerRoster.all[racerIndex], isPlayer: idx == 0)
            let start = pointOnTrack(trackLength - 40 - CGFloat(idx) * 28)
            let side: CGFloat = idx % 2 == 0 ? -18 : 18
            cart.position = CGPoint(
                x: start.point.x + cos(start.angle + .pi / 2) * side,
                y: start.point.y + sin(start.angle + .pi / 2) * side
            )
            cart.zRotation = start.angle
            cart.progress = trackLength - 40 - CGFloat(idx) * 28
            cart.aiTargetOff = CGFloat.random(in: -30...30)
            worldNode.addChild(cart)
            carts.append(cart)
        }

        let spots: [CGFloat] = [0.12, 0.28, 0.45, 0.62, 0.78, 0.9]
        for (i, s) in spots.enumerated() {
            let p = pointOnTrack(trackLength * s)
            let side: CGFloat = i % 2 == 0 ? 28 : -28
            let box = ItemBoxNode()
            box.position = CGPoint(
                x: p.point.x + cos(p.angle + .pi / 2) * side,
                y: p.point.y + sin(p.angle + .pi / 2) * side
            )
            worldNode.addChild(box)
            itemBoxes.append(box)
        }
        updateHUD()
    }

    private func computeTrackLength() -> CGFloat {
        var len: CGFloat = 0
        for i in 0..<track.count {
            let a = track[i]
            let b = track[(i + 1) % track.count]
            len += hypot(b.x - a.x, b.y - a.y)
        }
        return len
    }

    private func pointOnTrack(_ progress: CGFloat) -> (point: CGPoint, angle: CGFloat) {
        var p = progress.truncatingRemainder(dividingBy: trackLength)
        if p < 0 { p += trackLength }
        var acc: CGFloat = 0
        for i in 0..<track.count {
            let a = track[i]
            let b = track[(i + 1) % track.count]
            let seg = hypot(b.x - a.x, b.y - a.y)
            if acc + seg >= p {
                let t = (p - acc) / max(seg, 0.001)
                let point = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let angle = atan2(b.y - a.y, b.x - a.x)
                return (point, angle)
            }
            acc += seg
        }
        return (track[0], 0)
    }

    private func nearestTrack(_ point: CGPoint) -> (dist: CGFloat, along: CGFloat, closest: CGPoint) {
        var bestDist = CGFloat.greatestFiniteMagnitude
        var bestAlong: CGFloat = 0
        var bestPoint = point
        var alongAcc: CGFloat = 0
        for i in 0..<track.count {
            let a = track[i]
            let b = track[(i + 1) % track.count]
            let abx = b.x - a.x
            let aby = b.y - a.y
            let segLen = hypot(abx, aby)
            let t = max(0, min(1, ((point.x - a.x) * abx + (point.y - a.y) * aby) / max(segLen * segLen, 0.001)))
            let px = a.x + abx * t
            let py = a.y + aby * t
            let d = hypot(point.x - px, point.y - py)
            if d < bestDist {
                bestDist = d
                bestAlong = alongAcc + segLen * t
                bestPoint = CGPoint(x: px, y: py)
            }
            alongAcc += segLen
        }
        return (bestDist, bestAlong, bestPoint)
    }

    private func drawStore() {
        worldNode.removeAllChildren()

        let floor = SKShapeNode(rectOf: CGSize(width: 2400, height: 2400))
        floor.fillColor = SKColor(red: 0.10, green: 0.14, blue: 0.11, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -20
        worldNode.addChild(floor)

        let shelfPath = CGMutablePath()
        shelfPath.move(to: track[0])
        for p in track.dropFirst() { shelfPath.addLine(to: p) }
        shelfPath.closeSubpath()

        let shelves = SKShapeNode(path: shelfPath)
        shelves.strokeColor = SKColor(red: 0.18, green: 0.24, blue: 0.17, alpha: 1)
        shelves.lineWidth = trackWidth + 110
        shelves.lineJoin = .round
        shelves.lineCap = .round
        shelves.zPosition = -10
        worldNode.addChild(shelves)

        let aisle = SKShapeNode(path: shelfPath)
        aisle.strokeColor = SKColor(red: 0.84, green: 0.79, blue: 0.65, alpha: 1)
        aisle.lineWidth = trackWidth
        aisle.lineJoin = .round
        aisle.lineCap = .round
        aisle.zPosition = -8
        worldNode.addChild(aisle)

        let lane = SKShapeNode(path: shelfPath)
        lane.strokeColor = SKColor(white: 1, alpha: 0.28)
        lane.lineWidth = 3
        lane.lineJoin = .round
        if #available(iOS 17.0, *) {
            // dashed via shape approximation — keep solid faint center line
        }
        lane.zPosition = -7
        worldNode.addChild(lane)

        // start/finish checkers
        let start = track[0]
        let next = track[1]
        let ang = atan2(next.y - start.y, next.x - start.x)
        for i in -4..<4 {
            let check = SKSpriteNode(color: i % 2 == 0 ? .black : SKColor(red: 0.95, green: 0.94, blue: 0.89, alpha: 1), size: CGSize(width: 12, height: trackWidth / 8))
            check.position = start
            check.zRotation = ang
            check.position = CGPoint(
                x: start.x + cos(ang + .pi / 2) * (CGFloat(i) + 0.5) * (trackWidth / 8),
                y: start.y + sin(ang + .pi / 2) * (CGFloat(i) + 0.5) * (trackWidth / 8)
            )
            check.zPosition = -6
            worldNode.addChild(check)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = 1.0 / 60.0

        if phase == .countdown {
            countdownTime += dt
            let next = 3 - Int(countdownTime)
            if next > 0 {
                countdownLabel = "\(next)"
            } else if countdownTime < 3.55 {
                countdownLabel = "GO!"
            } else {
                setPhase(.racing)
                return
            }
            publish()
            followPlayer()
            return
        }

        guard phase == .racing else { return }

        raceTime += dt
        for cart in carts {
            updateCart(cart, dt: dt)
        }
        resolveCartCollisions()
        updateProjectiles(dt: dt)
        updateHazards(dt: dt)
        for box in itemBoxes { box.tick(dt: dt) }
        updatePlaces()
        updateHUD()
        followPlayer()
        checkFinish()
    }

    private func followPlayer() {
        guard let player = carts.first(where: { $0.isPlayer }) else { return }
        let target = CGPoint(x: -player.position.x, y: -player.position.y)
        worldNode.position = CGPoint(
            x: worldNode.position.x + (target.x - worldNode.position.x) * 0.12,
            y: worldNode.position.y + (target.y - worldNode.position.y) * 0.12
        )
        let zoom = max(0.85, min(1.2, min(size.width, size.height) / 700))
        worldNode.setScale(zoom)
    }

    private func updateCart(_ cart: CartNode, dt: CGFloat) {
        guard !cart.finished else { return }
        cart.boostTimer = max(0, cart.boostTimer - dt)
        cart.stunTimer = max(0, cart.stunTimer - dt)

        var steer: CGFloat = 0
        var drifting = false
        var throttle: CGFloat = 1

        if cart.isPlayer {
            if touchLeft { steer -= 1 }
            if touchRight { steer += 1 }
            drifting = touchDrift
        } else {
            let look = 70 + cart.speed * 0.25
            let target = pointOnTrack(cart.progress + look)
            let tx = target.point.x + cos(target.angle + .pi / 2) * cart.aiTargetOff
            let ty = target.point.y + sin(target.angle + .pi / 2) * cart.aiTargetOff
            let desired = atan2(ty - cart.position.y, tx - cart.position.x)
            var diff = desired - cart.zRotation
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            steer = max(-1, min(1, diff * 1.8))
            drifting = abs(diff) > 0.55 && cart.speed > 90
            if let item = cart.item, cart.place > 1 || Int.random(in: 0...120) == 0 {
                if item == .boost || cart.place > 1 { useItem(for: cart) }
            }
            if cart.stunTimer > 0 { throttle = 0.2 }
        }

        let maxSpeed = cart.maxSpeed * (cart.boostTimer > 0 ? 1.45 : 1) * (cart.stunTimer > 0 ? 0.35 : 1)
        let turnMul: CGFloat = drifting ? 1.55 : 1
        let grip: CGFloat = drifting ? 0.92 : 0.98

        if cart.stunTimer <= 0 {
            cart.zRotation += steer * cart.turnRate * turnMul * (0.55 + 0.45 * (cart.speed / cart.maxSpeed)) * dt
            cart.speed += cart.accel * throttle * dt
            if drifting && cart.speed > 60 {
                cart.speed -= 35 * dt
                cart.driftTimer += dt
            } else {
                if cart.driftTimer > 0.55 {
                    cart.boostTimer = max(cart.boostTimer, 0.55)
                }
                cart.driftTimer = 0
            }
        } else {
            cart.zRotation += sin(raceTime * 20) * 0.8 * dt
            cart.speed *= max(0, 1 - 1.5 * dt)
        }

        cart.speed = max(0, min(maxSpeed, cart.speed))
        let tx = cos(cart.zRotation) * cart.speed
        let ty = sin(cart.zRotation) * cart.speed
        cart.vx = cart.vx * (1 - grip) + tx * grip
        cart.vy = cart.vy * (1 - grip) + ty * grip
        cart.position = CGPoint(x: cart.position.x + cart.vx * dt, y: cart.position.y + cart.vy * dt)

        let np = nearestTrack(cart.position)
        let half = trackWidth * 0.5
        if np.dist > half {
            let sx = (cart.position.x - np.closest.x) / max(np.dist, 0.001)
            let sy = (cart.position.y - np.closest.y) / max(np.dist, 0.001)
            let push = np.dist - half
            cart.position = CGPoint(x: cart.position.x - sx * push, y: cart.position.y - sy * push)
            cart.vx *= 0.55
            cart.vy *= 0.55
            cart.speed *= 0.7
        }

        if np.along > trackLength * 0.45 && np.along < trackLength * 0.9 {
            cart.armedForLap = true
        }
        if let last = cart.lastAlong, cart.armedForLap {
            if last > trackLength * 0.85 && np.along < trackLength * 0.15 {
                cart.lap += 1
                cart.armedForLap = false
                if cart.lap >= totalLaps {
                    cart.finished = true
                    cart.finishTime = raceTime
                    cart.speed *= 0.3
                }
            }
        }
        cart.lastAlong = np.along
        cart.progress = np.along

        for box in itemBoxes where box.cooldown <= 0 {
            if hypot(cart.position.x - box.position.x, cart.position.y - box.position.y) < 28, cart.item == nil {
                cart.item = PowerUp.allCases.randomElement()
                box.cooldown = 3.5
            }
        }

        for (idx, h) in hazards.enumerated().reversed() {
            if h.owner === cart && h.life > 17 { continue }
            if hypot(cart.position.x - h.position.x, cart.position.y - h.position.y) < 22 {
                hit(cart, kind: h.kind)
                h.removeFromParent()
                hazards.remove(at: idx)
            }
        }

        cart.refreshVisual()
    }

    private func useItem(for cart: CartNode) {
        guard let item = cart.item else { return }
        cart.item = nil
        switch item {
        case .boost:
            cart.boostTimer = 1.35
        case .banana:
            let h = HazardNode(kind: .banana, owner: cart)
            h.position = CGPoint(
                x: cart.position.x + cos(cart.zRotation + .pi) * 36,
                y: cart.position.y + sin(cart.zRotation + .pi) * 36
            )
            worldNode.addChild(h)
            hazards.append(h)
        case .soup:
            let p = ProjectileNode(owner: cart)
            p.position = CGPoint(
                x: cart.position.x + cos(cart.zRotation) * 28,
                y: cart.position.y + sin(cart.zRotation) * 28
            )
            p.vx = cos(cart.zRotation) * 340
            p.vy = sin(cart.zRotation) * 340
            worldNode.addChild(p)
            projectiles.append(p)
        case .gum:
            let h = HazardNode(kind: .gum, owner: cart)
            h.position = CGPoint(
                x: cart.position.x + cos(cart.zRotation + .pi) * 40,
                y: cart.position.y + sin(cart.zRotation + .pi) * 40
            )
            worldNode.addChild(h)
            hazards.append(h)
        }
    }

    private func hit(_ cart: CartNode, kind: HazardKind) {
        cart.stunTimer = kind == .gum ? 0.7 : 1.1
        cart.speed *= kind == .gum ? 0.35 : 0.2
    }

    private func updateProjectiles(dt: CGFloat) {
        for (idx, p) in projectiles.enumerated().reversed() {
            p.position = CGPoint(x: p.position.x + p.vx * dt, y: p.position.y + p.vy * dt)
            p.life -= dt
            let np = nearestTrack(p.position)
            var remove = p.life <= 0 || np.dist > trackWidth * 0.55
            if !remove {
                for cart in carts where cart !== p.owner {
                    if hypot(cart.position.x - p.position.x, cart.position.y - p.position.y) < 24 {
                        hit(cart, kind: .banana)
                        remove = true
                        break
                    }
                }
            }
            if remove {
                p.removeFromParent()
                projectiles.remove(at: idx)
            }
        }
    }

    private func updateHazards(dt: CGFloat) {
        for (idx, h) in hazards.enumerated().reversed() {
            h.life -= dt
            if h.life <= 0 {
                h.removeFromParent()
                hazards.remove(at: idx)
            }
        }
    }

    private func resolveCartCollisions() {
        for i in 0..<carts.count {
            for j in (i + 1)..<carts.count {
                let a = carts[i]
                let b = carts[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let d = hypot(dx, dy)
                if d < 34 && d > 0.01 {
                    let nx = dx / d
                    let ny = dy / d
                    let overlap = 34 - d
                    a.position = CGPoint(x: a.position.x - nx * overlap * 0.5, y: a.position.y - ny * overlap * 0.5)
                    b.position = CGPoint(x: b.position.x + nx * overlap * 0.5, y: b.position.y + ny * overlap * 0.5)
                    a.speed *= 0.92
                    b.speed *= 0.92
                }
            }
        }
    }

    private func updatePlaces() {
        let ranked = carts.sorted { a, b in
            if a.finished != b.finished { return a.finished && !b.finished }
            if a.finished && b.finished { return a.finishTime < b.finishTime }
            return a.lap * trackLength + a.progress > b.lap * trackLength + b.progress
        }
        for (i, c) in ranked.enumerated() { c.place = i + 1 }
    }

    private func updateHUD() {
        guard let player = carts.first(where: { $0.isPlayer }) else { return }
        playerLap = player.lap
        playerPlaceLabel = ordinal(player.place)
        timeLabel = formatTime(raceTime)
        playerItemIcon = player.item?.icon ?? "·"
        publish()
    }

    private func checkFinish() {
        guard let player = carts.first(where: { $0.isPlayer }), player.finished else { return }
        for c in carts where !c.finished {
            c.finished = true
            c.finishTime = raceTime + Double(c.place) * 0.05
        }
        updatePlaces()
        resultTitle = player.place == 1 ? "AISLE CHAMP!" : player.place == 2 ? "SOLID HAUL" : "CART WIPED"
        playerPlaceLabel = ordinal(player.place)
        timeLabel = formatTime(player.finishTime)
        standings = carts.sorted { $0.place < $1.place }.map {
            "\(ordinal($0.place)) \($0.racerName)\($0.isPlayer ? " (YOU)" : "")  \(formatTime($0.finishTime))"
        }
        setPhase(.results)
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let d = Int((t.truncatingRemainder(dividingBy: 1)) * 10)
        return "\(m):\(String(format: "%02d", s)).\(d)"
    }
}

final class CartNode: SKNode {
    let isPlayer: Bool
    let racerName: String
    var speed: CGFloat = 0
    var maxSpeed: CGFloat
    var accel: CGFloat
    var turnRate: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var lap = 0
    var progress: CGFloat = 0
    var lastAlong: CGFloat?
    var finished = false
    var finishTime: TimeInterval = 0
    var place = 1
    var item: PowerUp?
    var boostTimer: CGFloat = 0
    var stunTimer: CGFloat = 0
    var driftTimer: CGFloat = 0
    var aiTargetOff: CGFloat = 0
    var armedForLap = false
    private let body: SKShapeNode
    private let flame: SKShapeNode

    init(racer: RacerDef, isPlayer: Bool) {
        self.isPlayer = isPlayer
        self.racerName = racer.name
        self.maxSpeed = 210 * racer.speed
        self.accel = 160 * racer.accel
        self.turnRate = 2.8 * racer.handling

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -16, y: -12))
        path.addLine(to: CGPoint(x: 14, y: -11))
        path.addLine(to: CGPoint(x: 18, y: 11))
        path.addLine(to: CGPoint(x: -16, y: 12))
        path.closeSubpath()
        body = SKShapeNode(path: path)
        body.fillColor = UIColor(racer.color)
        body.strokeColor = UIColor(racer.accent)
        body.lineWidth = 2

        flame = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -18, y: -6))
            p.addLine(to: CGPoint(x: -30, y: 0))
            p.addLine(to: CGPoint(x: -18, y: 6))
            p.closeSubpath()
            return p
        }())
        flame.fillColor = SKColor(red: 0.78, green: 0.96, blue: 0.26, alpha: 0.8)
        flame.strokeColor = .clear
        flame.isHidden = true

        super.init()
        addChild(body)
        addChild(flame)
        zPosition = 10

        let label = SKLabelNode(text: isPlayer ? "YOU" : racer.name.split(separator: " ").last.map(String.init) ?? "")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = isPlayer ? SKColor(red: 0.78, green: 0.96, blue: 0.26, alpha: 1) : .white
        label.position = CGPoint(x: 0, y: 22)
        label.zPosition = 11
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func refreshVisual() {
        flame.isHidden = boostTimer <= 0
    }
}

enum HazardKind { case banana, gum }

final class HazardNode: SKShapeNode {
    let kind: HazardKind
    weak var owner: CartNode?
    var life: CGFloat = 16

    init(kind: HazardKind, owner: CartNode) {
        self.kind = kind
        self.owner = owner
        super.init()
        path = CGPath(ellipseIn: CGRect(x: -11, y: -7, width: 22, height: 14), transform: nil)
        fillColor = kind == .banana ? SKColor(red: 1, green: 0.9, blue: 0.4, alpha: 1) : SKColor(red: 1, green: 0.56, blue: 0.67, alpha: 1)
        strokeColor = .clear
        zPosition = 5
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

final class ProjectileNode: SKShapeNode {
    weak var owner: CartNode?
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var life: CGFloat = 1.6

    init(owner: CartNode) {
        self.owner = owner
        super.init()
        path = CGPath(rect: CGRect(x: -8, y: -6, width: 16, height: 12), transform: nil)
        fillColor = SKColor(red: 0.90, green: 0.44, blue: 0.32, alpha: 1)
        zPosition = 6
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

final class ItemBoxNode: SKNode {
    var cooldown: CGFloat = 0
    private let box: SKShapeNode

    override init() {
        box = SKShapeNode(rectOf: CGSize(width: 24, height: 24), cornerRadius: 3)
        box.fillColor = SKColor(red: 0.78, green: 0.96, blue: 0.26, alpha: 1)
        box.strokeColor = .black
        super.init()
        addChild(box)
        let q = SKLabelNode(text: "?")
        q.fontName = "AvenirNext-Heavy"
        q.fontSize = 14
        q.fontColor = .black
        q.verticalAlignmentMode = .center
        addChild(q)
        zPosition = 4
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func tick(dt: CGFloat) {
        cooldown = max(0, cooldown - dt)
        alpha = cooldown > 0 ? 0.25 : 1
        box.zRotation += dt * 1.5
    }
}

private extension UIColor {
    convenience init(_ color: Color) {
        let ui = UIColor(color)
        self.init(cgColor: ui.cgColor)
    }
}
