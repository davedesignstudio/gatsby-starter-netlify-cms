import SpriteKit

/// Draws the race and pumps the simulation. The scene owns no game rules: it
/// feeds input in, steps the simulation, and mirrors the result into nodes.
final class RaceScene: SKScene {
    /// Scene points per simulation metre.
    static let metre: CGFloat = 20
    /// How much of the shop is visible across the screen, in metres.
    private let visibleWidthMetres: CGFloat = 46

    let simulation: RaceSimulation
    var settings: ControlSettings
    /// Polled at the top of every frame. The coordinator installs a closure that
    /// blends the on-screen controls with tilt and any connected game pad.
    var inputSource: (() -> RawControlState)?

    var onEvents: (([RaceEvent]) -> Void)?
    var onFrame: ((RaceSimulation) -> Void)?
    var onComplete: ((RaceResult) -> Void)?

    private let track: Track
    private let plan: TrackArtPlan
    private let factory: ArtFactory
    private let builder: WorldBuilder

    private let worldNode = SKNode()
    private let effectsNode = SKNode()
    private let cameraNode = SKCameraNode()

    private var cartNodes: [Int: CartNode] = [:]
    private var crateNodes: [Int: SKSpriteNode] = [:]
    private var tokenNodes: [Int: SKSpriteNode] = [:]
    private var hazardNodes: [Int: SKSpriteNode] = [:]
    private var projectileNodes: [Int: SKSpriteNode] = [:]

    private var mapper = ControlMapper()
    private var lastUpdateTime: TimeInterval = 0
    private var hasReportedCompletion = false
    private var cameraRotation: CGFloat = 0

    init(configuration: RaceConfiguration, settings: ControlSettings, size: CGSize) {
        simulation = RaceSimulation(configuration: configuration)
        self.settings = settings
        track = configuration.track
        plan = TrackArtPlan(track: configuration.track)
        factory = ArtFactory(palette: plan.palette)
        builder = WorldBuilder(track: configuration.track, plan: plan, factory: factory, metre: RaceScene.metre)

        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(plan.palette.backdrop)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }

        addChild(worldNode)
        worldNode.addChild(builder.buildFloor())
        worldNode.addChild(builder.buildRacingSurface())
        worldNode.addChild(builder.buildMarkings())
        worldNode.addChild(builder.buildBoostPads())
        worldNode.addChild(builder.buildAisleWalls())
        worldNode.addChild(builder.buildProps())
        worldNode.addChild(builder.buildObstacles())
        worldNode.addChild(builder.buildLighting())

        effectsNode.zPosition = WorldBuilder.Layer.hazards.rawValue
        worldNode.addChild(effectsNode)

        for cart in simulation.carts {
            let node = CartNode(cart: cart, factory: factory, metre: RaceScene.metre, effectTarget: effectsNode)
            node.update(cart: cart, tuning: simulation.tuning)
            worldNode.addChild(node)
            cartNodes[cart.id] = node
        }

        camera = cameraNode
        addChild(cameraNode)
        if let player = simulation.playerCart {
            cameraNode.position = builder.point(player.position)
            cameraRotation = CGFloat(player.heading) - .pi / 2
            cameraNode.zRotation = cameraRotation
        }
        updateCameraScale()
        syncPickups()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateCameraScale()
    }

    private func updateCameraScale() {
        guard size.width > 0 else { return }
        cameraNode.setScale(visibleWidthMetres * RaceScene.metre / size.width)
    }

    // MARK: - Frame

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if lastUpdateTime == 0 {
            delta = 1.0 / 60
        } else {
            delta = min(currentTime - lastUpdateTime, 0.25)
        }
        lastUpdateTime = currentTime

        if let playerID = simulation.playerCartID {
            let raw = inputSource?() ?? RawControlState()
            simulation.setInput(mapper.input(from: raw, settings: settings, delta: delta), forCart: playerID)
        }

        simulation.update(deltaTime: delta)

        syncCarts()
        syncPickups()
        syncHazardsAndProjectiles()
        updateCamera(delta: delta)

        let events = simulation.drainEvents()
        if !events.isEmpty {
            handle(events: events)
            onEvents?(events)
        }
        onFrame?(simulation)

        if simulation.phase == .complete, !hasReportedCompletion {
            hasReportedCompletion = true
            onComplete?(simulation.result())
        }
    }

    private func syncCarts() {
        for cart in simulation.carts {
            cartNodes[cart.id]?.update(cart: cart, tuning: simulation.tuning)
        }
    }

    private func syncPickups() {
        for box in simulation.itemBoxes {
            let node = crateNodes[box.id] ?? makeCrateNode(id: box.id, at: box.position)
            // Smashed crates fade out and pop back when they respawn.
            let visible = box.isAvailable
            node.alpha = visible ? 1 : 0.15
            node.setScale(visible ? 1 : 0.6)
        }
        for token in simulation.tokens {
            let node = tokenNodes[token.id] ?? makeTokenNode(id: token.id, at: token.position)
            node.alpha = token.isAvailable ? 1 : 0
        }
    }

    private func makeCrateNode(id: Int, at position: Vector2) -> SKSpriteNode {
        let texture = factory.itemCrateTexture()
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: 2.4 * RaceScene.metre, height: 2.4 * RaceScene.metre)
        node.position = builder.point(position)
        node.zPosition = WorldBuilder.Layer.pickups.rawValue
        node.run(.repeatForever(.sequence([
            .rotate(byAngle: .pi, duration: 2.4),
            .rotate(byAngle: .pi, duration: 2.4)
        ])))
        worldNode.addChild(node)
        crateNodes[id] = node
        return node
    }

    private func makeTokenNode(id: Int, at position: Vector2) -> SKSpriteNode {
        let node = SKSpriteNode(texture: factory.tokenTexture())
        node.size = CGSize(width: 1.2 * RaceScene.metre, height: 1.2 * RaceScene.metre)
        node.position = builder.point(position)
        node.zPosition = WorldBuilder.Layer.pickups.rawValue
        node.run(.repeatForever(.sequence([
            .scaleX(to: 0.35, duration: 0.7),
            .scaleX(to: 1.0, duration: 0.7)
        ])))
        worldNode.addChild(node)
        tokenNodes[id] = node
        return node
    }

    private func syncHazardsAndProjectiles() {
        var liveHazards: Set<Int> = []
        for hazard in simulation.hazards {
            liveHazards.insert(hazard.id)
            let node: SKSpriteNode
            if let existing = hazardNodes[hazard.id] {
                node = existing
            } else {
                node = SKSpriteNode(texture: factory.greaseTexture())
                node.zPosition = WorldBuilder.Layer.hazards.rawValue
                node.position = builder.point(hazard.position)
                worldNode.addChild(node)
                hazardNodes[hazard.id] = node
            }
            let spread = CGFloat(hazard.kind.radius * 2 * hazard.maturity) * RaceScene.metre
            node.size = CGSize(width: spread, height: spread)
            // Fade out as it dries up.
            node.alpha = CGFloat(min(1, hazard.lifetime / 3))
        }
        for (id, node) in hazardNodes where !liveHazards.contains(id) {
            node.removeFromParent()
            hazardNodes.removeValue(forKey: id)
        }

        var liveProjectiles: Set<Int> = []
        for projectile in simulation.projectiles {
            liveProjectiles.insert(projectile.id)
            let node: SKSpriteNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                node = SKSpriteNode(texture: factory.canTexture())
                node.size = CGSize(width: RaceScene.metre, height: RaceScene.metre)
                node.zPosition = WorldBuilder.Layer.pickups.rawValue + 5
                worldNode.addChild(node)
                projectileNodes[projectile.id] = node
            }
            node.position = builder.point(projectile.position)
            node.zRotation += CGFloat(projectile.spin) * 0.02
        }
        for (id, node) in projectileNodes where !liveProjectiles.contains(id) {
            node.removeFromParent()
            projectileNodes.removeValue(forKey: id)
        }
    }

    // MARK: - Camera

    private func updateCamera(delta: TimeInterval) {
        guard let player = simulation.playerCart else { return }

        // Look ahead of the cart so there is time to react at speed.
        let speedFraction = Scalar.clamp(player.forwardSpeed / player.tuning.topSpeed, 0, 1.4)
        let lookAhead = Scalar.lerp(3.5, 9.0, min(speedFraction, 1))
        let focus = player.position + player.forward * lookAhead
        let target = builder.point(focus)

        let followRate = 9.0
        let factor = CGFloat(1 - exp(-followRate * delta))
        cameraNode.position = CGPoint(
            x: cameraNode.position.x + (target.x - cameraNode.position.x) * factor,
            y: cameraNode.position.y + (target.y - cameraNode.position.y) * factor
        )

        // Rotate the world so the cart always drives up the screen. During a
        // drift, follow the direction of travel rather than the nose, or the view
        // swings about as the cart steps out.
        let referenceAngle = player.isDrifting && player.speed > 2
            ? player.velocity.angle
            : player.heading
        let desired = CGFloat(referenceAngle) - .pi / 2
        let rotationDelta = CGFloat(Scalar.angleDelta(from: Double(cameraRotation), to: Double(desired)))
        cameraRotation += rotationDelta * CGFloat(1 - exp(-6.0 * delta))
        cameraNode.zRotation = cameraRotation

        // Pull back a little at speed for a sense of pace.
        let zoomOut = 1 + 0.12 * min(speedFraction, 1.2) + (player.isBoosting ? 0.05 : 0)
        let baseScale = visibleWidthMetres * RaceScene.metre / max(size.width, 1)
        let currentScale = cameraNode.xScale
        let targetScale = baseScale * zoomOut
        cameraNode.setScale(currentScale + (targetScale - currentScale) * CGFloat(1 - exp(-4.0 * delta)))
    }

    // MARK: - Events

    private func handle(events: [RaceEvent]) {
        let playerID = simulation.playerCartID
        for event in events {
            switch event {
            case .wallScrape(_, let intensity, let position):
                burst(
                    texture: factory.sparkTexture(),
                    at: position,
                    count: Int(4 + intensity * 12),
                    colour: UIColor(Palette.boostGlow),
                    speed: RaceScene.metre * 2.5,
                    blend: .add
                )

            case .cartBump(_, _, let intensity, let position):
                burst(
                    texture: factory.smokeTexture(),
                    at: position,
                    count: Int(3 + intensity * 8),
                    colour: .white,
                    speed: RaceScene.metre * 2
                )

            case .obstacleHit(_, let kind, let position):
                burst(
                    texture: factory.smokeTexture(),
                    at: position,
                    count: kind.isSoft ? 6 : 14,
                    colour: UIColor(RacerColor(hex: 0xC49A6C)),
                    speed: RaceScene.metre * 3
                )

            case .slipped(_, let position):
                burst(
                    texture: factory.splashTexture(),
                    at: position,
                    count: 12,
                    colour: UIColor(RacerColor(hex: 0x9FD8F2)),
                    speed: RaceScene.metre * 2.5
                )

            case .projectileHit(_, let position):
                burst(
                    texture: factory.splashTexture(),
                    at: position,
                    count: 18,
                    colour: UIColor(Palette.danger),
                    speed: RaceScene.metre * 4
                )

            case .shieldBlocked(_, let position):
                burst(
                    texture: factory.sparkTexture(),
                    at: position,
                    count: 16,
                    colour: UIColor(Palette.good),
                    speed: RaceScene.metre * 3,
                    blend: .add
                )

            case .miniTurbo(let cartID, let tier):
                if cartID == playerID {
                    floatText(tier >= 3 ? "SUPER TURBO!" : "MINI-TURBO!", colour: UIColor(Palette.boostGlow))
                }

            case .tokenCollected(let cartID, _):
                if cartID == playerID, let cart = simulation.cart(id: cartID) {
                    burst(
                        texture: factory.tokenTexture(),
                        at: cart.position,
                        count: 4,
                        colour: .white,
                        speed: RaceScene.metre * 1.6
                    )
                }

            case .itemCollected(let cartID, _):
                if cartID == playerID, let cart = simulation.cart(id: cartID) {
                    burst(
                        texture: factory.sparkTexture(),
                        at: cart.position,
                        count: 10,
                        colour: UIColor(RacerColor(hex: 0xFFD166)),
                        speed: RaceScene.metre * 2,
                        blend: .add
                    )
                }

            case .lapCompleted(let cartID, let lap, let lapTime):
                if cartID == playerID {
                    let remaining = simulation.totalLaps - lap
                    let message = remaining == 1 ? "FINAL LAP" : "LAP \(lap) · \(TimeFormatter.lapTime(lapTime))"
                    floatText(message, colour: UIColor(Palette.hudForeground))
                }

            case .rocketStart(let cartID):
                if cartID == playerID { floatText("ROCKET START!", colour: UIColor(Palette.good)) }

            case .floodedEngine(let cartID):
                if cartID == playerID { floatText("FLOODED!", colour: UIColor(Palette.danger)) }

            case .respawned(let cartID):
                if let cart = simulation.cart(id: cartID) {
                    burst(
                        texture: factory.smokeTexture(),
                        at: cart.position,
                        count: 14,
                        colour: .white,
                        speed: RaceScene.metre * 2.5
                    )
                }

            default:
                break
            }
        }
    }

    private func burst(
        texture: SKTexture,
        at world: Vector2,
        count: Int,
        colour: UIColor,
        speed: CGFloat,
        blend: SKBlendMode = .alpha
    ) {
        guard count > 0 else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBirthRate = 900
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.25
        emitter.particleSize = CGSize(width: RaceScene.metre * 0.5, height: RaceScene.metre * 0.5)
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.3
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.6
        emitter.emissionAngleRange = .pi * 2
        emitter.particleColor = colour
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = blend
        emitter.position = builder.point(world)
        emitter.zPosition = WorldBuilder.Layer.pickups.rawValue + 10
        effectsNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
    }

    /// A message that pops up over the player's cart and floats away.
    private func floatText(_ message: String, colour: UIColor) {
        guard let player = simulation.playerCart else { return }
        let label = SKLabelNode(text: message)
        label.fontName = "AvenirNextCondensed-Heavy"
        label.fontSize = 15
        label.fontColor = colour
        label.position = builder.point(player.position + Vector2(0, 2.2))
        label.zPosition = 200
        label.zRotation = cameraRotation
        label.setScale(0.6)
        worldNode.addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: RaceScene.metre * 2.5, duration: 1.1),
                .scale(to: 1.0, duration: 0.25),
                .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.4)])
            ]),
            .removeFromParent()
        ]))
    }
}
