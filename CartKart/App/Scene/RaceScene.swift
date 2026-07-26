import CartKartCore
import SpriteKit

/// Renders a race and pumps the simulation.
///
/// The scene owns no game rules at all: it reads `RaceEngine` state, draws it,
/// and feeds player input back in. That split is what lets the whole racing
/// model be tested without a screen.
final class RaceScene: SKScene {
    let engine: RaceEngine
    private let controls: ControlState
    private let hud: RaceHUDModel
    private let controlScheme: Storage.ControlScheme
    /// Attract mode: the menus run a race in the background with nobody driving.
    private let isDemo: Bool

    /// Called once when the race is over, on the main thread.
    var onRaceComplete: (([RaceResult], [Double], Double?) -> Void)?

    private let worldNode = SKNode()
    private let effects = EffectsLayer()
    private var cartNodes: [Int: CartNode] = [:]
    private var itemBoxNodes: [Int: SKNode] = [:]
    private var hazardNodes: [Int: SKNode] = [:]
    private var projectileNodes: [Int: SKNode] = [:]
    private var obstacleNodes: [SKNode] = []

    private var lastUpdate: TimeInterval = 0
    private var hudClock: Double = 0
    private var minimap: RaceHUDModel.MinimapProjection
    private var hasReportedCompletion = false
    private(set) var cameraRotation: CGFloat = 0

    init(
        size: CGSize,
        engine: RaceEngine,
        controls: ControlState,
        hud: RaceHUDModel,
        controlScheme: Storage.ControlScheme,
        isDemo: Bool = false
    ) {
        self.engine = engine
        self.controls = controls
        self.hud = hud
        self.controlScheme = controlScheme
        self.isDemo = isDemo
        self.minimap = RaceHUDModel.MinimapProjection(track: engine.track)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = engine.track.theme.shelf.shaded(0.28)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }
        addChild(worldNode)
        worldNode.addChild(TrackRenderer.buildWorld(for: engine.track))
        worldNode.addChild(effects)

        for obstacle in engine.obstacles {
            let node = TrackRenderer.obstacleNode(obstacle, theme: engine.track.theme)
            obstacleNodes.append(node)
            worldNode.addChild(node)
        }
        // Time trials have no items, so there is nothing to smash.
        if engine.configuration.mode != .timeTrial {
            for box in engine.itemBoxes {
                let node = TrackRenderer.itemBoxNode(box)
                itemBoxNodes[box.id] = node
                worldNode.addChild(node)
            }
        }
        for kart in engine.karts {
            let node = CartNode(kart: kart, showNameTag: !isDemo && !kart.isPlayerControlled)
            cartNodes[kart.id] = node
            worldNode.addChild(node)
        }

        let camera = SKCameraNode()
        addChild(camera)
        self.camera = camera
        camera.setScale(1.6)
        if let focus = focusKart {
            camera.position = focus.position.cgPoint
            cameraRotation = CGFloat(focus.heading - .pi / 2)
            camera.zRotation = cameraRotation
        }

        hud.minimapOutline = engine.track.samples.enumerated()
            .compactMap { index, sample in
                // One point every few samples is plenty for a thumbnail.
                index % 3 == 0 ? minimap.map(sample.position) : nil
            }
        pushHUD(force: true)
    }

    /// The cart the camera follows: the player, or the leader in attract mode.
    private var focusKart: KartState? {
        if let playerID = engine.playerKartID, !isDemo {
            return engine.karts.first { $0.id == playerID }
        }
        return engine.standings.first
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let delta: Double
        if lastUpdate == 0 {
            delta = 1.0 / 60
        } else {
            delta = min(currentTime - lastUpdate, 0.1)
        }
        lastUpdate = currentTime

        guard !hud.isPaused else { return }

        let input: RaceInput
        if isDemo, let playerID = engine.playerKartID {
            input = engine.autopilotInput(for: playerID)
        } else if isDemo {
            input = .idle
        } else {
            input = controls.makeInput(scheme: controlScheme)
        }
        engine.advance(deltaTime: delta, playerInput: input)

        handle(events: engine.drainEvents())
        syncCarts(dt: delta)
        syncItemBoxes()
        syncHazards()
        syncProjectiles()
        updateCamera(dt: delta)

        hudClock += delta
        if hudClock >= 1.0 / 15 {
            hudClock = 0
            pushHUD()
        }

        if engine.isComplete && !hasReportedCompletion {
            hasReportedCompletion = true
            pushHUD(force: true)
            let player = engine.karts.first { $0.isPlayerControlled }
            onRaceComplete?(engine.results, player?.lapTimes ?? [], player?.finishTime)
        }
    }

    // MARK: - Syncing

    private func syncCarts(dt: Double) {
        for kart in engine.karts {
            cartNodes[kart.id]?.sync(with: kart, dt: dt, effects: effects)
        }
    }

    private func syncItemBoxes() {
        for box in engine.itemBoxes {
            guard let node = itemBoxNodes[box.id] else { continue }
            let shouldShow = box.isAvailable
            if node.isHidden == shouldShow {
                node.isHidden = !shouldShow
                if shouldShow {
                    node.setScale(0.2)
                    node.run(.scale(to: 1, duration: 0.25))
                }
            }
        }
    }

    private func syncHazards() {
        var live = Set<Int>()
        for hazard in engine.hazards {
            live.insert(hazard.id)
            let node = hazardNodes[hazard.id] ?? makeHazardNode(hazard)
            node.position = hazard.position.cgPoint
            // Everything on the floor fades out as it is cleaned up.
            node.alpha = hazard.remainingLife < 1.5 ? CGFloat(hazard.remainingLife / 1.5) : 1
        }
        for (id, node) in hazardNodes where !live.contains(id) {
            hazardNodes.removeValue(forKey: id)
            node.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
    }

    private func makeHazardNode(_ hazard: DroppedHazard) -> SKNode {
        let sprite = SKSpriteNode(texture: TextureFactory.hazard(hazard.kind))
        sprite.size = CGSize(width: hazard.radius * 2.2, height: hazard.radius * 2.2)
        sprite.zPosition = Layer.hazard
        sprite.setScale(0.3)
        sprite.run(.scale(to: 1, duration: 0.18))
        if hazard.kind == .flourCloud {
            sprite.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.9),
                .scale(to: 0.95, duration: 0.9)
            ])))
        }
        hazardNodes[hazard.id] = sprite
        worldNode.addChild(sprite)
        return sprite
    }

    private func syncProjectiles() {
        var live = Set<Int>()
        for projectile in engine.projectiles {
            live.insert(projectile.id)
            let node: SKNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                let sprite = SKSpriteNode(texture: TextureFactory.projectile(projectile.kind))
                sprite.size = CGSize(width: projectile.radius * 2.4, height: projectile.radius * 2.4)
                sprite.zPosition = Layer.projectile
                sprite.run(.repeatForever(.rotate(byAngle: projectile.kind == .runawayMelon ? -.pi * 2 : .pi * 2, duration: 0.4)))
                projectileNodes[projectile.id] = sprite
                worldNode.addChild(sprite)
                node = sprite
            }
            node.position = projectile.position.cgPoint
        }
        for (id, node) in projectileNodes where !live.contains(id) {
            projectileNodes.removeValue(forKey: id)
            effects.addBurst(at: node.position.vec2, color: "white", scale: 1.2)
            node.removeFromParent()
        }
    }

    private func updateCamera(dt: Double) {
        guard let camera, let kart = focusKart else { return }
        // Look slightly ahead of the cart so you can see what you are about to hit.
        let lead = kart.velocity * 0.16
        let target = kart.position + lead
        let follow = 1 - exp(-9 * dt)
        camera.position = CGPoint(
            x: camera.position.x + (CGFloat(target.x) - camera.position.x) * follow,
            y: camera.position.y + (CGFloat(target.y) - camera.position.y) * follow
        )

        // Rotate so the cart always drives up the screen.
        let desired = kart.heading - .pi / 2
        let smoothed = Angle.rotate(Double(cameraRotation), towards: desired, maxStep: 6 * dt)
        cameraRotation = CGFloat(smoothed)
        camera.zRotation = cameraRotation

        // Pull back a little at speed for a sense of pace.
        let speedFraction = clamp(kart.speed / max(kart.physics.topSpeed, 1), 0, 1.4)
        let targetScale = 1.45 + speedFraction * 0.32
        let current = camera.xScale
        camera.setScale(current + (targetScale - current) * CGFloat(1 - exp(-3 * dt)))
    }

    // MARK: - Events

    private func handle(events: [RaceEvent]) {
        let playerID = isDemo ? nil : engine.playerKartID
        for event in events {
            if !isDemo {
                Feedback.shared.react(to: event, playerKartID: playerID)
            }
            switch event {
            case .countdownTick(let value):
                hud.snapshot.countdown = "\(value)"
            case .go:
                hud.snapshot.countdown = "GO!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak hud] in
                    hud?.snapshot.countdown = nil
                }
            case .rocketStart(let id):
                if let kart = kart(id), !isDemo {
                    effects.addFloatingText("ROCKET START!", at: kart.position, color: .orange)
                }
            case .miniTurbo(let id, let tier):
                if let kart = kart(id) {
                    effects.addBurst(at: kart.position, color: tier == .rumble ? "purple" : "orange")
                    if id == playerID {
                        effects.addFloatingText(tier.label, at: kart.position, color: .white)
                    }
                }
            case .boostPad(let id):
                if let kart = kart(id) { effects.addBurst(at: kart.position, color: "blue", scale: 0.8) }
            case .itemBoxCollected(_, let boxID):
                if let node = itemBoxNodes[boxID] {
                    effects.addBurst(at: node.position.vec2, color: "white", scale: 0.9)
                }
            case .kartHit(let id, let disruption, _):
                if let kart = kart(id) {
                    effects.addBurst(at: kart.position, color: disruption == .squash ? "grey" : "white", scale: disruption == .squash ? 1.8 : 1)
                    if !disruption.allowsControl {
                        effects.addSpinStars(at: kart.position, duration: 1.2)
                    }
                }
            case .kartBumped(let id, _, let impact) where impact > 200:
                if let kart = kart(id) { effects.addBurst(at: kart.position, color: "white", scale: 0.6) }
            case .rescued(let id):
                if let kart = kart(id) {
                    effects.addBurst(at: kart.position, color: "blue", scale: 1.2)
                    if id == playerID {
                        hud.showBanner("STAFF ASSISTANCE", duration: 1.4)
                    }
                }
            case .obstacleSmashed(let position, _):
                effects.addBurst(at: position, color: "grey", scale: 1.4)
                removeObstacleNode(near: position)
            case .lapCompleted(let id, let lap, _) where id == playerID:
                if lap < engine.lapCount {
                    hud.showBanner("LAP \(lap + 1)")
                }
            case .finalLap(let id) where id == playerID:
                hud.showBanner("FINAL LAP!", duration: 2.0)
            case .wrongWay(let id, let active) where id == playerID:
                hud.snapshot.isWrongWay = active
            case .finished(let id, let place, _) where id == playerID:
                hud.showBanner("FINISHED \(TimeFormat.ordinal(place))", duration: 2.5)
            default:
                break
            }
        }
    }

    private func kart(_ id: Int) -> KartState? {
        engine.karts.first { $0.id == id }
    }

    private func removeObstacleNode(near position: Vec2) {
        let target = position.cgPoint
        guard let index = obstacleNodes.firstIndex(where: { node in
            hypot(node.position.x - target.x, node.position.y - target.y) < 12
        }) else { return }
        let node = obstacleNodes.remove(at: index)
        node.run(.sequence([
            .group([.scale(to: 1.4, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
    }

    // MARK: - HUD

    private func pushHUD(force: Bool = false) {
        guard !isDemo else { return }
        guard let player = engine.karts.first(where: { $0.isPlayerControlled }) else { return }

        var snapshot = hud.snapshot
        snapshot.lap = min(player.lapsCompleted + 1, engine.lapCount)
        snapshot.totalLaps = engine.lapCount
        snapshot.position = player.racePosition
        snapshot.racerCount = engine.karts.count
        snapshot.item = player.item?.kind ?? player.pendingItem
        snapshot.itemCharges = player.item?.charges ?? 0
        snapshot.isItemSpinning = player.itemRouletteTimer > 0
        snapshot.speedFraction = clamp(player.speed / max(player.physics.topSpeed, 1), 0, 1.35)
        snapshot.raceTime = max(0, engine.elapsed)
        snapshot.currentLapTime = max(0, engine.elapsed - player.currentLapStart)
        snapshot.lastLapTime = player.lapTimes.last
        snapshot.bestLapTime = player.lapTimes.min()
        snapshot.driftTier = player.driftTier
        snapshot.isBoosting = player.isBoosting
        snapshot.isFinalLap = player.lapsCompleted == engine.lapCount - 1
        snapshot.hasFinished = player.isFinished
        if snapshot != hud.snapshot || force {
            hud.snapshot = snapshot
        }

        hud.minimapDots = engine.karts.map { kart in
            RaceHUDModel.MinimapDot(
                id: kart.id,
                point: minimap.map(kart.position),
                color: kart.profile.bodyColor,
                isPlayer: kart.isPlayerControlled
            )
        }
        hud.standings = engine.standings.prefix(8).map { kart in
            RaceHUDModel.Standing(
                id: kart.id,
                place: kart.racePosition,
                name: kart.profile.name,
                emblem: kart.profile.emblem,
                isPlayer: kart.isPlayerControlled
            )
        }
    }
}
