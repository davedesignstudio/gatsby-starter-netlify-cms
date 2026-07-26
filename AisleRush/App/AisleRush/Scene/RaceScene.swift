import SpriteKit
import UIKit
import AisleRushCore

/// Live control state, written by the on-screen pad and read once per
/// simulation step. Deliberately not `@Published`: it changes every frame and
/// SwiftUI does not need to know.
final class RaceInput {
    var steer: Double = 0
    /// Only consulted when auto-accelerate is off, or during the countdown.
    var throttle: Double = 0
    var brake = false
    var drift = false
    var fire = false
    var aimBackward = false

    /// Drops every held control. Used when the pad is taken away mid-touch:
    /// pausing, finishing, or the system cancelling a gesture.
    func releaseAll() {
        steer = 0
        throttle = 0
        brake = false
        drift = false
        fire = false
        aimBackward = false
    }

    func control(autoAccelerate: Bool, duringCountdown: Bool) -> ControlInput {
        // Auto-accelerate must not apply before the lights change: holding the
        // throttle for the whole countdown floods the wheels, and the player
        // has not asked for anything yet.
        let assisted = autoAccelerate && !duringCountdown
        let forward = brake ? -1.0 : (assisted ? 1.0 : throttle)
        return ControlInput(
            steer: steer,
            throttle: forward,
            drift: drift,
            useItem: fire,
            aimBackward: aimBackward
        )
    }
}

/// Everything the HUD needs, refreshed from the simulation a few times a
/// second rather than every frame.
struct HUDSnapshot: Equatable {
    var place = 1
    var fieldSize = 8
    var lap = 1
    var totalLaps = 3
    var raceTime: Double = 0
    var currentLapTime: Double = 0
    var bestLapTime: Double?
    var speedKPH: Int = 0
    var heldItem: ItemKind?
    var itemIsRolling = false
    var driftTier = 0
    var isBoosting = false
    var isWrongWay = false
    var isFinalLap = false
    var countdown: Int?
    var showGo = false
    var mishap: CartMishap = .none
}

final class RaceScene: SKScene {
    private(set) var simulation: RaceSimulation
    private let input: RaceInput
    private let settings: GameSettings
    private weak var session: RaceSession?

    private let worldNode = SKNode()
    private let decalNode = SKNode()
    private let effectNode = SKNode()
    private let cameraNode = SKCameraNode()

    private var cartNodes: [Int: CartNode] = [:]
    private var projectileNodes: [Int: SKSpriteNode] = [:]
    private var dropNodes: [Int: SKSpriteNode] = [:]
    private var crateNodes: [SKSpriteNode] = []
    private var propNodes: [SKSpriteNode] = []
    /// Last applied up/down state, so the fade actions are not restarted on
    /// every frame while they are still running.
    private var crateIsDown: [Bool] = []
    private var propIsDown: [Bool] = []

    private var lastUpdate: TimeInterval?
    private var accumulator: Double = 0
    private var hudClock: Double = 0
    private var goBannerTimer: Double = 0
    private var skidMarks: [SKSpriteNode] = []
    private var cameraAngle: CGFloat = 0
    private var shake: CGFloat = 0

    private let stepSize = 1.0 / 120.0

    init(simulation: RaceSimulation, input: RaceInput, settings: GameSettings, session: RaceSession) {
        self.simulation = simulation
        self.input = input
        self.settings = settings
        self.session = session
        super.init(size: CGSize(width: 1024, height: 768))
        scaleMode = .resizeFill
        backgroundColor = simulation.track.definition.theme.ambientTint.uiColor.adjusted(by: -0.35)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("RaceScene is created in code")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }
        addChild(worldNode)

        let scenery = TrackNodeBuilder.build(track: simulation.track)
        scenery.floor.zPosition = -100
        scenery.markings.zPosition = -90
        scenery.lighting.zPosition = 60
        scenery.fittings.zPosition = 5
        scenery.shelving.zPosition = 40

        worldNode.addChild(scenery.floor)
        worldNode.addChild(scenery.markings)
        decalNode.zPosition = -80
        worldNode.addChild(decalNode)
        worldNode.addChild(scenery.fittings)
        worldNode.addChild(scenery.shelving)
        worldNode.addChild(scenery.lighting)
        effectNode.zPosition = 30
        worldNode.addChild(effectNode)
        crateNodes = scenery.crates
        propNodes = scenery.props
        crateIsDown = [Bool](repeating: false, count: scenery.crates.count)
        propIsDown = [Bool](repeating: false, count: scenery.props.count)

        for cart in simulation.carts {
            let node = CartNode(cart: cart, isPlayer: cart.id == simulation.playerCartID)
            node.zPosition = 10 + CGFloat(cart.id) * 0.01
            worldNode.addChild(node)
            cartNodes[cart.id] = node
            node.sync(with: cart)
        }

        camera = cameraNode
        addChild(cameraNode)
        if let player = simulation.playerCart {
            cameraNode.position = player.position.point
        }
        updateCamera(dt: 0, immediate: true)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        let delta: Double
        if let lastUpdate {
            delta = min(currentTime - lastUpdate, 0.25)
        } else {
            delta = 0
        }
        lastUpdate = currentTime
        guard delta > 0 else { return }

        accumulator += delta
        var steps = 0
        while accumulator >= stepSize, steps < 8 {
            stepSimulation()
            accumulator -= stepSize
            steps += 1
        }
        if steps == 8 { accumulator = 0 }

        syncNodes(dt: delta)
        updateCamera(dt: delta, immediate: false)

        if let player = simulation.playerCart {
            Audio.shared.updateEngineLoop(
                speed: player.speed,
                topSpeed: player.stats.topSpeed,
                boosting: player.boostTimer > 0
            )
        }

        hudClock += delta
        goBannerTimer = max(0, goBannerTimer - delta)
        if hudClock > 0.05 {
            hudClock = 0
            publishHUD()
        }
    }

    private func stepSimulation() {
        if let playerID = simulation.playerCartID {
            var counting = false
            if case .countdown = simulation.phase { counting = true }
            simulation.setInput(
                input.control(autoAccelerate: settings.autoAccelerate, duringCountdown: counting),
                forCart: playerID
            )
        }
        simulation.update(dt: stepSize)
        handle(events: simulation.drainEvents())

        if simulation.isComplete {
            session?.raceDidComplete(results: simulation.results)
        }
    }

    // MARK: - Events

    private func handle(events: [RaceEvent]) {
        let playerID = simulation.playerCartID
        for event in events {
            switch event {
            case .countdownBeep:
                Audio.shared.play(.beep)

            case .go:
                Audio.shared.play(.go)
                goBannerTimer = 1.4

            case .rocketStart(let cartID):
                if cartID == playerID { Haptics.impact(.heavy) }
                burst(at: cartID, color: .systemTeal, count: 26)

            case .burnout(let cartID):
                burst(at: cartID, color: .systemGray, count: 14)

            case .itemBoxCollected(let cartID):
                Audio.shared.play(.pickup, muffled: cartID != playerID)
                if cartID == playerID { Haptics.impact(.light) }

            case .itemAwarded(let cartID, _):
                if cartID == playerID { Haptics.selection() }

            case .itemUsed(let cartID, let kind):
                Audio.shared.play(kind.isInstant ? .powerUp : .throwItem, muffled: cartID != playerID)

            case .projectileFired:
                break

            case .cartHit(let cartID, let kind, _):
                Audio.shared.play(kind == .cleanupCall ? .announce : .splat, muffled: cartID != playerID)
                if cartID == playerID {
                    Haptics.notify(.error)
                    shake = 10
                }
                burst(at: cartID, color: kind == .milkSpill ? .white : .systemOrange, count: 18)

            case .wallImpact(let cartID, let force):
                guard force > 4 else { break }
                Audio.shared.play(.crash, muffled: cartID != playerID)
                if cartID == playerID {
                    Haptics.impact(force > 10 ? .heavy : .medium)
                    shake = min(14, CGFloat(force))
                }
                burst(at: cartID, color: .systemYellow, count: 10)

            case .cartBump(let cartID, let otherID, let force):
                guard force > 6 else { break }
                Audio.shared.play(.bump, muffled: cartID != playerID && otherID != playerID)
                if cartID == playerID || otherID == playerID { Haptics.impact(.medium) }

            case .propScattered(let index):
                Audio.shared.play(.clatter)
                scatterProp(at: index)

            case .miniTurbo(let cartID, let tier):
                Audio.shared.play(.boost, muffled: cartID != playerID)
                if cartID == playerID {
                    Haptics.impact(.medium)
                    shake = CGFloat(3 + tier)
                }
                burst(at: cartID, color: CartNode.driftColor(tier: tier), count: 20)

            case .lapCompleted(let cartID, _, _):
                if cartID == playerID { Audio.shared.play(.lap) }

            case .finalLap(let cartID):
                if cartID == playerID { Audio.shared.play(.finalLap) }

            case .raceFinished(let cartID, let place, _):
                if cartID == playerID {
                    Audio.shared.play(place <= 3 ? .fanfare : .finish)
                    Haptics.notify(.success)
                }

            case .wrongWay:
                break
            }
        }
    }

    // MARK: - Presentation

    private func syncNodes(dt: Double) {
        for cart in simulation.carts {
            guard let node = cartNodes[cart.id] else { continue }
            node.sync(with: cart)
            if cart.surface == .wet || cart.surface == .ice {
                node.setSurfaceSheen(true)
            } else {
                node.setSurfaceSheen(false)
            }
            layDownSkidMarks(for: cart)
        }

        syncProjectiles()
        syncDrops()
        refreshFittings()
        fadeSkidMarks(dt: dt)
    }

    private func syncProjectiles() {
        var live: Set<Int> = []
        for projectile in simulation.projectiles {
            live.insert(projectile.id)
            let node: SKSpriteNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                node = SKSpriteNode(texture: TextureFactory.itemIcon(projectile.kind))
                let side = CGFloat(projectile.radius) * 3.4 * TrackNodeBuilder.scale
                node.size = CGSize(width: side, height: side)
                node.zPosition = 15
                node.run(.repeatForever(.rotate(byAngle: projectile.kind == .rogueMelon ? -6 : 9, duration: 1)))
                worldNode.addChild(node)
                projectileNodes[projectile.id] = node
            }
            node.position = projectile.position.point
        }
        for (id, node) in projectileNodes where !live.contains(id) {
            node.removeFromParent()
            projectileNodes.removeValue(forKey: id)
        }
    }

    private func syncDrops() {
        var live: Set<Int> = []
        for drop in simulation.drops {
            live.insert(drop.id)
            let node: SKSpriteNode
            if let existing = dropNodes[drop.id] {
                node = existing
            } else {
                let texture = drop.kind == .milkSpill
                    ? TextureFactory.spill()
                    : TextureFactory.prop(.wetFloorSign)
                node = SKSpriteNode(texture: texture)
                let side = CGFloat(drop.radius) * 2.6 * TrackNodeBuilder.scale
                node.size = CGSize(width: side, height: side)
                node.zPosition = drop.kind == .milkSpill ? -60 : 8
                node.position = drop.position.point
                node.setScale(0.2)
                node.run(.scale(to: 1, duration: 0.18))
                worldNode.addChild(node)
                dropNodes[drop.id] = node
            }
            node.alpha = drop.life < 3 ? CGFloat(drop.life / 3) : 1
        }
        for (id, node) in dropNodes where !live.contains(id) {
            node.run(.sequence([.scale(to: 1.6, duration: 0.12), .fadeOut(withDuration: 0.12), .removeFromParent()]))
            dropNodes.removeValue(forKey: id)
        }
    }

    /// Crates fade out while they respawn and props lie scattered while they
    /// are on cooldown, so what you see matches what you can hit.
    private func refreshFittings() {
        for index in crateNodes.indices where index < simulation.itemBoxCooldowns.count {
            let node = crateNodes[index]
            let down = simulation.itemBoxCooldowns[index] > 0
            if down != crateIsDown[index] {
                crateIsDown[index] = down
                node.removeAllActions()
                node.run(.fadeAlpha(to: down ? 0.15 : 1, duration: 0.2))
                node.run(.scale(to: down ? 0.6 : 1, duration: 0.2))
            }
            if !down {
                node.zRotation += 0.01
            }
        }

        for index in propNodes.indices where index < simulation.propCooldowns.count {
            let down = simulation.propCooldowns[index] > 0
            guard down != propIsDown[index] else { continue }
            propIsDown[index] = down
            let node = propNodes[index]
            node.removeAllActions()
            node.run(.fadeAlpha(to: down ? 0.35 : 1, duration: down ? 0.12 : 0.3))
            node.run(.scale(to: down ? 0.72 : 1, duration: down ? 0.12 : 0.3))
        }
    }

    private func layDownSkidMarks(for cart: Cart) {
        guard cart.speed > 8, abs(cart.slipAngle) > 0.28 || cart.spinTimer > 0 else { return }
        guard skidMarks.count < 220, Int.random(in: 0..<3) == 0 else { return }
        let mark = SKSpriteNode(texture: TextureFactory.skidMark())
        mark.size = CGSize(width: 0.9 * TrackNodeBuilder.scale, height: 0.34 * TrackNodeBuilder.scale)
        mark.position = cart.position.point
        mark.zRotation = CGFloat(cart.velocity.angle)
        mark.alpha = 0.5
        decalNode.addChild(mark)
        skidMarks.append(mark)
    }

    private func fadeSkidMarks(dt: Double) {
        guard skidMarks.count > 180 else { return }
        let excess = skidMarks.count - 180
        for mark in skidMarks.prefix(excess) {
            mark.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        }
        skidMarks.removeFirst(excess)
    }

    private func burst(at cartID: Int, color: UIColor, count: Int) {
        guard let cart = simulation.cart(withID: cartID) else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureFactory.softDot()
        emitter.position = cart.position.point
        emitter.particleBirthRate = 900
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = 130
        emitter.particleSpeedRange = 90
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2
        emitter.particleScale = 0.22
        emitter.particleScaleSpeed = -0.25
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.targetNode = effectNode
        effectNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func scatterProp(at index: Int) {
        guard index < simulation.track.props.count else { return }
        let prop = simulation.track.props[index]
        burst(at: prop, color: .systemRed, count: 16)
    }

    private func burst(at prop: Track.PlacedProp, color: UIColor, count: Int) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureFactory.softDot()
        emitter.position = prop.position.point
        emitter.particleBirthRate = 800
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.6
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 110
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.2
        emitter.particleScaleSpeed = -0.2
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.targetNode = effectNode
        effectNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func updateCamera(dt: Double, immediate: Bool) {
        guard let player = simulation.playerCart ?? simulation.carts.first else { return }

        // Look ahead of the cart so you can see the corner you are about to
        // mishandle.
        let lead = Vector2.angled(player.heading, length: min(player.speed * 0.42, 11))
        let target = (player.position + lead).point
        if immediate {
            cameraNode.position = target
        } else {
            let t = CGFloat(1 - exp(-9 * dt))
            cameraNode.position = CGPoint(
                x: cameraNode.position.x + (target.x - cameraNode.position.x) * t,
                y: cameraNode.position.y + (target.y - cameraNode.position.y) * t
            )
        }

        if shake > 0.05 {
            shake *= CGFloat(exp(-6 * dt))
            cameraNode.position.x += CGFloat.random(in: -shake...shake)
            cameraNode.position.y += CGFloat.random(in: -shake...shake)
        }

        if settings.rotatingCamera {
            let desired = CGFloat(player.heading) - .pi / 2
            if immediate {
                cameraAngle = desired
            } else {
                let step = CGFloat(Angle.delta(from: Double(cameraAngle), to: Double(desired)))
                cameraAngle += step * CGFloat(1 - exp(-7 * dt))
            }
            cameraNode.zRotation = cameraAngle
        } else {
            cameraNode.zRotation = 0
        }

        // Pull back as speed builds; it reads as going faster than it is.
        let width = max(size.width, 1)
        let metres = 54 + min(player.speed, 34) * 0.55 + (player.boostTimer > 0 ? 6 : 0)
        let desiredScale = CGFloat(metres) * TrackNodeBuilder.scale / width
        let currentScale = cameraNode.xScale
        let blended = immediate ? desiredScale : currentScale + (desiredScale - currentScale) * CGFloat(1 - exp(-3 * dt))
        cameraNode.setScale(blended)
    }

    // MARK: - HUD

    private func publishHUD() {
        guard let session else { return }
        guard let player = simulation.playerCart else { return }

        var snapshot = HUDSnapshot()
        snapshot.place = simulation.place(ofCart: player.id)
        snapshot.fieldSize = simulation.carts.count
        snapshot.lap = min(max(player.lap, 1), simulation.config.laps)
        snapshot.totalLaps = simulation.config.laps
        snapshot.raceTime = max(0, simulation.time)
        snapshot.currentLapTime = max(0, simulation.time - player.lapStartTime)
        snapshot.bestLapTime = player.bestLapTime
        snapshot.speedKPH = Int(player.speed * 3.6)
        snapshot.heldItem = player.heldItem ?? player.pendingItem
        snapshot.itemIsRolling = player.rouletteTimer > 0
        snapshot.driftTier = player.drift.isActive ? player.drift.tier : 0
        snapshot.isBoosting = player.boostTimer > 0
        snapshot.isWrongWay = player.isWrongWay
        snapshot.isFinalLap = player.lap >= simulation.config.laps
        snapshot.showGo = goBannerTimer > 0
        snapshot.mishap = player.mishap
        if case .countdown(let remaining) = simulation.phase {
            snapshot.countdown = max(1, Int(ceil(remaining - 0.4)))
        }

        session.hud = snapshot
    }
}
