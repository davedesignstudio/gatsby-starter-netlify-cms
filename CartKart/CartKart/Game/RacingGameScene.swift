import SpriteKit

final class RacingGameScene: SKScene, CartDelegate {
    weak var gameState: GameState?

    private let trackIndex: Int
    private var trackDefinition: TrackDefinition!
    private var carts: [ShoppingCart] = []
    private var playerCart: ShoppingCart?
    private var countdownValue = 3
    private var raceStarted = false
    private var raceStartTime: TimeInterval = 0
    private var finishedCount = 0
    private var standings: [Standing] = []

    private var leftTouch: UITouch?
    private var rightTouch: UITouch?
    private var leftOrigin: CGPoint = .zero
    private var rightOrigin: CGPoint = .zero
    private var itemUsePending = false

    init(size: CGSize, trackIndex: Int) {
        self.trackIndex = trackIndex
        super.init(size: size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        physicsWorld.contactDelegate = self

        trackDefinition = TrackBuilder.definition(for: trackIndex, sceneSize: size)
        TrackBuilder.build(in: self, definition: trackDefinition)
        spawnCarts()
        startCountdown()
    }

    private func spawnCarts() {
        let racers: [(String, SKColor, CartStats)] = [
            ("You", .systemBlue, .player),
            ("Cart Carl", .systemRed, .aiFast),
            ("Bag Lady Barb", .systemPurple, .aiTechnical),
            ("Dumpster Dan", .systemOrange, .aiBalanced)
        ]

        for (index, racer) in racers.enumerated() {
            let position = trackDefinition.startPositions[index]
            let angle = trackDefinition.startAngles[index]
            let cart = ShoppingCart(
                id: "cart_\(index)",
                name: racer.0,
                isPlayer: index == 0,
                position: position,
                angle: angle,
                color: racer.1,
                stats: racer.2
            )
            cart.delegate = self
            cart.configureCheckpoints(trackDefinition.checkpoints)
            addChild(cart)
            carts.append(cart)

            if index == 0 {
                playerCart = cart
            }
        }
    }

    private func startCountdown() {
        gameState?.phase = .countdown
        gameState?.countdownText = "\(countdownValue)"

        run(.sequence([
            .wait(forDuration: 1),
            .run { [weak self] in self?.tickCountdown() }
        ]))
    }

    private func tickCountdown() {
        countdownValue -= 1
        if countdownValue > 0 {
            gameState?.countdownText = "\(countdownValue)"
            run(.sequence([
                .wait(forDuration: 1),
                .run { [weak self] in self?.tickCountdown() }
            ]))
        } else if countdownValue == 0 {
            gameState?.countdownText = "GO!"
            run(.sequence([
                .wait(forDuration: 0.6),
                .run { [weak self] in self?.beginRace() }
            ]))
        }
    }

    private func beginRace() {
        raceStarted = true
        raceStartTime = CACurrentMediaTime()
        gameState?.phase = .racing
        carts.forEach { $0.beginRace() }
    }

    override func update(_ currentTime: TimeInterval) {
        guard raceStarted else { return }

        let delta = 1.0 / 60.0

        for cart in carts where !cart.raceFinished {
            if cart.isPlayer {
                cart.checkCheckpointProximity()
            } else {
                cart.updateAI(deltaTime: delta, opponents: carts)
            }
            cart.update(deltaTime: delta)
        }

        updateHUD()
        updateCamera()
        updatePositions()
    }

    private func updateHUD() {
        guard let playerCart, let gameState else { return }
        Task { @MainActor in
            gameState.playerLap = playerCart.lap
            gameState.playerSpeed = playerCart.speed * 0.45
            gameState.heldItem = playerCart.heldItem
            gameState.playerPosition = currentPosition(for: playerCart)
        }
    }

    private func updateCamera() {
        guard let playerCart else { return }
        let cameraNode = childNode(withName: "camera") ?? {
            let node = SKNode()
            node.name = "camera"
            addChild(node)
            return node
        }()

        let target = playerCart.position
        cameraNode.position = CGPoint(
            x: cameraNode.position.x * 0.85 + target.x * 0.15,
            y: cameraNode.position.y * 0.85 + target.y * 0.15
        )

        enumerateChildNodes(withName: "//cart") { node, _ in
            guard node !== playerCart else { return }
            node.alpha = 1
        }
    }

    private func updatePositions() {
        let sorted = carts.sorted { $0.progressScore > $1.progressScore }
        if let playerCart {
            Task { @MainActor in
                gameState?.playerPosition = (sorted.firstIndex(where: { $0.cartID == playerCart.cartID }) ?? 0) + 1
            }
        }
    }

    private func currentPosition(for cart: ShoppingCart) -> Int {
        let sorted = carts.sorted { $0.progressScore > $1.progressScore }
        return (sorted.firstIndex(where: { $0.cartID == cart.cartID }) ?? 0) + 1
    }

    // MARK: - Touch Controls

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if location.x < size.width / 2 {
                leftTouch = touch
                leftOrigin = location
            } else {
                if rightTouch == nil, playerCart?.heldItem != nil {
                    itemUsePending = true
                }
                rightTouch = touch
                rightOrigin = location
            }
        }
        updatePlayerInput()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updatePlayerInput()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == leftTouch { leftTouch = nil }
            if touch == rightTouch { rightTouch = nil }
        }
        updatePlayerInput()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updatePlayerInput() {
        guard let playerCart, raceStarted else { return }

        var steering: CGFloat = 0
        var throttle: CGFloat = 0

        if let leftTouch {
            let location = leftTouch.location(in: self)
            let dx = location.x - leftOrigin.x
            steering = max(-1, min(1, dx / 60))
        }

        if let rightTouch {
            let location = rightTouch.location(in: self)
            let dy = rightOrigin.y - location.y
            throttle = max(-0.6, min(1, dy / 80))
        }

        playerCart.setPlayerInput(steering: steering, throttle: throttle)

        if itemUsePending, playerCart.heldItem != nil {
            itemUsePending = false
            let opponents = carts.filter { !$0.isPlayer && !$0.raceFinished }
            let nearest = opponents.min { a, b in
                hypot(a.position.x - playerCart.position.x, a.position.y - playerCart.position.y) <
                hypot(b.position.x - playerCart.position.x, b.position.y - playerCart.position.y)
            }
            playerCart.useHeldItem(toward: nearest)
        }
    }

    // MARK: - CartDelegate

    func cartDidCompleteLap(_ cart: ShoppingCart) {
        if cart.isPlayer {
            Task { @MainActor in
                gameState?.playerLap = cart.lap
            }
        }
    }

    func cartDidFinishRace(_ cart: ShoppingCart) {
        finishedCount += 1
        standings.append(Standing(
            rank: finishedCount,
            name: cart.displayName,
            isPlayer: cart.isPlayer
        ))

        if cart.isPlayer || finishedCount == carts.count {
            endRaceIfNeeded()
        }
    }

    func cartDidCollectItem(_ cart: ShoppingCart, item: RaceItem) {
        if cart.isPlayer {
            Task { @MainActor in
                gameState?.heldItem = item
            }
        }
    }

    private func endRaceIfNeeded() {
        guard let playerCart, let gameState else { return }

        let remaining = carts.filter { !$0.raceFinished }.sorted { $0.progressScore > $1.progressScore }
        for cart in remaining {
            finishedCount += 1
            standings.append(Standing(
                rank: finishedCount,
                name: cart.displayName,
                isPlayer: cart.isPlayer
            ))
        }

        let position = standings.firstIndex(where: { $0.isPlayer }).map { $0 + 1 } ?? carts.count

        Task { @MainActor in
            gameState.finishRace(
                position: position,
                standings: standings.sorted { $0.rank < $1.rank },
                bestLap: playerCart.bestLapTime
            )
        }
    }
}

extension RacingGameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]

        if let cartBody = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.cart }),
           let otherBody = bodies.first(where: { $0 !== cartBody }) {
            handleCartContact(cartNode: cartBody.node, otherNode: otherBody.node, otherCategory: otherBody.categoryBitMask)
        }
    }

    private func handleCartContact(cartNode: SKNode?, otherNode: SKNode?, otherCategory: UInt32) {
        guard let cartNode = cartNode as? ShoppingCart else { return }

        switch otherCategory {
        case PhysicsCategory.itemBox:
            if let itemBox = otherNode as? ItemBoxNode {
                let item = itemBox.collect()
                cartNode.collectItem(item)
            }
        case PhysicsCategory.projectile:
            if let projectile = otherNode as? ProjectileNode {
                _ = cartNode.hitByProjectile(projectile)
            }
        case PhysicsCategory.hazard:
            cartNode.applySlip(duration: 0.8)
        case PhysicsCategory.boostPad:
            cartNode.applyBoost()
        default:
            break
        }
    }
}
