import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    weak var game: GameState?

    private let worldSize = CGSize(width: 2600, height: 1800)
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var track: Track!

    private var carts: [Cart] = []
    private var player: Cart { carts[0] }
    private var itemBoxes: [ItemBox] = []
    private var milkSlicks: [MilkSlick] = []
    private var projectiles: [CannedProjectile] = []

    private var lastUpdate: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var countdownRemaining: TimeInterval = 0
    private var finishScheduled = false

    private let aiNames = ["Cart Vader", "Trolley Parton", "Buggy McCart"]

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(world)
        camera = cam
        addChild(cam)

        track = Track(worldSize: worldSize)
        track.build(into: world)

        spawnCarts()
        spawnItemBoxes()

        updateCameraScale()
        cam.position = player.position

        game?.onStartRace = { [weak self] in self?.beginCountdown() }
        game?.onRestart = { [weak self] in self?.beginCountdown() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        updateCameraScale()
    }

    private func spawnCarts() {
        let names = ["You"] + aiNames
        let grid = track.startingGrid(count: 4)
        for i in 0..<4 {
            let cart = Cart(isPlayer: i == 0, name: names[i], colorIndex: i)
            cart.reset(position: grid[i].position, heading: grid[i].heading)
            world.addChild(cart)
            carts.append(cart)
        }
    }

    private func spawnItemBoxes() {
        let n = track.waypoints.count
        let indices = [n / 6, n / 2, (5 * n) / 6]
        for wpi in indices {
            let p = track.waypoints[wpi]
            let dir = track.direction(at: wpi)
            let perp = CGPoint(x: -dir.y, y: dir.x)
            for off in [-95, 0, 95] {
                let box = ItemBox()
                box.position = p + perp * CGFloat(off)
                world.addChild(box)
                itemBoxes.append(box)
            }
        }
    }

    // MARK: - Race flow

    private func beginCountdown() {
        resetPositions()
        countdownRemaining = 3.0
        game?.countdownText = "3"
        game?.phase = .countdown
    }

    private func resetPositions() {
        let grid = track.startingGrid(count: carts.count)
        for (i, c) in carts.enumerated() {
            c.reset(position: grid[i].position, heading: grid[i].heading)
        }
        projectiles.forEach { $0.removeFromParent() }
        projectiles.removeAll()
        milkSlicks.forEach { $0.removeFromParent() }
        milkSlicks.removeAll()
        itemBoxes.forEach { $0.forceActivate() }
        cam.position = player.position
        elapsed = 0
        finishScheduled = false
        game?.results = []
        game?.heldItem = nil
        game?.boostActive = false
        game?.rank = 1
        game?.lap = 1
        game?.speed = 0
    }

    private func finishRace() {
        guard !finishScheduled else { return }
        finishScheduled = true
        let sorted = carts.sorted { $0.progressScore > $1.progressScore }
        var results: [RaceResult] = []
        for (i, c) in sorted.enumerated() {
            results.append(RaceResult(position: i + 1,
                                      name: c.displayName,
                                      isPlayer: c.isPlayer,
                                      time: c.finished ? c.finishTime : elapsed,
                                      finished: c.finished))
        }
        game?.results = results
        if let playerTime = carts.first(where: { $0.isPlayer })?.finishTime {
            if let best = game?.bestTime {
                if playerTime < best { game?.bestTime = playerTime }
            } else {
                game?.bestTime = playerTime
            }
        }
        game?.phase = .finished
        Haptics.notify(.success)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime
        guard !carts.isEmpty, let game else { return }

        switch game.phase {
        case .menu:
            idleCarts()
        case .countdown:
            idleCarts()
            countdownRemaining -= dt
            if countdownRemaining <= 0 {
                game.phase = .racing
                elapsed = 0
                game.countdownText = "GO!"
            } else {
                game.countdownText = "\(Int(ceil(countdownRemaining)))"
            }
        case .racing:
            elapsed += dt
            if elapsed > 0.8 && !game.countdownText.isEmpty { game.countdownText = "" }
            runRacing(dt: dt)
        case .finished:
            idleCarts()
        }

        updateCamera()
        for box in itemBoxes { box.update(dt: dt) }
        cullProjectiles(dt: dt)
        cullSlicks(dt: dt)
    }

    private func idleCarts() {
        for c in carts { c.physicsBody?.velocity = .zero }
    }

    private func runRacing(dt: TimeInterval) {
        guard let game else { return }

        if !player.finished {
            if game.useItemRequested {
                useItem(by: player)
                game.useItemRequested = false
            }
            player.drive(dt: dt,
                         steer: game.steerAxis,
                         accelerate: !game.brakeHeld,
                         brake: game.brakeHeld,
                         drift: game.driftHeld)
        } else {
            player.drive(dt: dt, steer: 0, accelerate: false, brake: false, drift: false)
        }

        for cart in carts where !cart.isPlayer {
            updateAI(cart, dt: dt)
        }

        for cart in carts { updateProgress(cart) }
        updateHUD()
    }

    // MARK: - AI

    private func updateAI(_ cart: Cart, dt: TimeInterval) {
        let n = track.waypoints.count
        let aimIndex = (cart.checkpointsPassed + 2) % n
        let dir = track.direction(at: aimIndex)
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let aim = track.waypoints[aimIndex] + perp * cart.aiLateralOffset
        let desired = (aim - cart.position).angle
        let delta = shortestAngleDelta(from: cart.heading, to: desired)
        let steer = clamp(delta * 2.2, -1, 1)
        let drift = abs(delta) > 0.55 && cart.speed > cart.baseMaxSpeed * 0.5

        cart.drive(dt: dt, steer: steer, accelerate: true, brake: false, drift: drift)

        cart.aiItemCooldown -= dt
        if cart.heldItem != nil && cart.aiItemCooldown <= 0 {
            useItem(by: cart)
            cart.aiItemCooldown = TimeInterval.random(in: 2...5)
        }
    }

    // MARK: - Progress & HUD

    private func updateProgress(_ cart: Cart) {
        let n = track.waypoints.count
        var steps = 0
        while steps < n {
            let next = (cart.checkpointsPassed + 1) % n
            let wp = track.waypoints[next]
            let dir = track.direction(at: next)
            if (cart.position - wp).dot(dir) >= 0 {
                cart.checkpointsPassed += 1
                steps += 1
                if cart.checkpointsPassed % n == 0 {
                    let laps = cart.checkpointsPassed / n
                    if laps >= (game?.totalLaps ?? 3) && !cart.finished {
                        cart.finished = true
                        cart.finishTime = elapsed
                        if cart.isPlayer { finishRace() }
                    }
                }
            } else {
                break
            }
        }

        let next = (cart.checkpointsPassed + 1) % n
        let prev = cart.checkpointsPassed % n
        let a = track.waypoints[prev]
        let b = track.waypoints[next]
        let seg = b - a
        let denom = seg.length * seg.length
        let t = denom > 0 ? clamp((cart.position - a).dot(seg) / denom, 0, 1) : 0
        cart.progressScore = CGFloat(cart.checkpointsPassed) + t
    }

    private func updateHUD() {
        guard let game else { return }
        let n = track.waypoints.count
        let sorted = carts.sorted { $0.progressScore > $1.progressScore }
        if let idx = sorted.firstIndex(where: { $0.isPlayer }) {
            game.rank = idx + 1
        }
        let laps = player.checkpointsPassed / n
        game.lap = min(laps + 1, game.totalLaps)
        game.speed = Int(max(0, player.speed) / 4.5)
        game.raceTime = elapsed
        game.heldItem = player.heldItem
        game.boostActive = player.isBoosting
    }

    // MARK: - Items

    private func useItem(by cart: Cart) {
        guard let item = cart.heldItem else { return }
        cart.heldItem = nil
        let forward = CGPoint(x: cos(cart.heading), y: sin(cart.heading))
        switch item {
        case .turboCola:
            cart.applyBoost(1.8)
        case .spilledMilk:
            let slick = MilkSlick(at: cart.position + forward * -52)
            world.addChild(slick)
            milkSlicks.append(slick)
        case .cannedGoods:
            let can = CannedProjectile(owner: cart,
                                       heading: cart.heading,
                                       launchSpeed: 900,
                                       from: cart.position + forward * 52)
            world.addChild(can)
            projectiles.append(can)
        }
        if cart.isPlayer { Haptics.tap() }
    }

    // MARK: - Cleanup

    private func cullProjectiles(dt: TimeInterval) {
        projectiles.removeAll { p in
            p.life -= dt
            if p.life <= 0 { p.removeFromParent(); return true }
            return p.parent == nil
        }
    }

    private func cullSlicks(dt: TimeInterval) {
        milkSlicks.removeAll { s in
            s.life -= dt
            if s.life <= 0 { s.removeFromParent(); return true }
            return s.parent == nil
        }
    }

    // MARK: - Camera

    private func updateCameraScale() {
        guard size.width > 0 else { return }
        let desiredVisibleWidth: CGFloat = 1500
        cam.setScale(clamp(desiredVisibleWidth / size.width, 1.2, 3.0))
    }

    private func updateCamera() {
        guard !carts.isEmpty else { return }
        let target = player.position
        let lerp: CGFloat = 0.15
        var pos = CGPoint(x: cam.position.x + (target.x - cam.position.x) * lerp,
                          y: cam.position.y + (target.y - cam.position.y) * lerp)
        let halfW = size.width * cam.xScale / 2
        let halfH = size.height * cam.yScale / 2
        pos.x = worldSize.width > halfW * 2 ? clamp(pos.x, halfW, worldSize.width - halfW) : worldSize.width / 2
        pos.y = worldSize.height > halfH * 2 ? clamp(pos.y, halfH, worldSize.height - halfH) : worldSize.height / 2
        cam.position = pos
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        resolveContact(contact.bodyA.node, contact.bodyB.node)
        resolveContact(contact.bodyB.node, contact.bodyA.node)
    }

    private func resolveContact(_ node: SKNode?, _ other: SKNode?) {
        guard let node else { return }
        if let cart = node as? Cart {
            if let box = other as? ItemBox {
                collect(box, by: cart)
            } else if let slick = other as? MilkSlick {
                slickHit(cart, slick)
            } else if let can = other as? CannedProjectile {
                canHit(cart, can)
            } else if isWall(other) {
                cart.bumpWall()
            }
        } else if let can = node as? CannedProjectile, isWall(other) {
            can.removeFromParent()
        }
    }

    private func isWall(_ node: SKNode?) -> Bool {
        node?.physicsBody?.categoryBitMask == PhysicsCategory.wall
    }

    private func collect(_ box: ItemBox, by cart: Cart) {
        guard box.active, cart.heldItem == nil else { return }
        cart.heldItem = ItemType.random()
        box.collect()
        if cart.isPlayer { Haptics.tap(.light) }
    }

    private func slickHit(_ cart: Cart, _ slick: MilkSlick) {
        guard slick.parent != nil else { return }
        cart.spinOut()
        slick.removeFromParent()
        if cart.isPlayer { Haptics.tap(.heavy) }
    }

    private func canHit(_ cart: Cart, _ can: CannedProjectile) {
        guard can.parent != nil, can.owner !== cart else { return }
        cart.spinOut()
        can.removeFromParent()
        if cart.isPlayer { Haptics.tap(.heavy) }
    }
}
