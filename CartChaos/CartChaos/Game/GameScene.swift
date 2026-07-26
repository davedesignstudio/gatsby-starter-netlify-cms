import SpriteKit

final class GameScene: SKScene {
    weak var gameState: GameState?

    private var playerCart: CartNode!
    private var aiCarts: [CartNode] = []
    private var aiDrivers: [AIDriver] = []
    private let itemSystem = ItemSystem()

    private var steerInput: CGFloat = 0
    private var isDriftHeld = false
    private var raceTimer: TimeInterval = 0
    private var playerCheckpoint = 0
    private var countdownTimer: TimeInterval = 0
    private var isCountingDown = true
    private var finishOrder: [(CartNode, TimeInterval)] = []
    private var cameraNode = SKCameraNode()

    private let aiCharacters: [CharacterType] = [.bagLadyBetty, .couponCarl, .canCollectorClyde]

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        physicsWorld.gravity = .zero
        itemSystem.scene = self

        _ = TrackBuilder.buildTrack(in: self)
        setupCarts()
        setupCamera()

        if gameState?.phase == .countdown {
            startCountdown()
        }
    }

  private func setupCarts() {
    let character = gameState?.selectedCharacter ?? .rustyRon
    let positions = TrackBuilder.startPositions
    let headings = TrackBuilder.startHeadings

    playerCart = CartNode(character: character, isPlayer: true)
    playerCart.position = positions[0]
    playerCart.heading = headings[0]
    addChild(playerCart)

    for (i, aiChar) in aiCharacters.enumerated() {
      let cart = CartNode(character: aiChar, isPlayer: false)
      cart.position = positions[i + 1]
      cart.heading = headings[i + 1]
      addChild(cart)
      aiCarts.append(cart)
      aiDrivers.append(AIDriver(cart: cart, skill: 0.55 + CGFloat(i) * 0.1))
    }
  }

  private func setupCamera() {
    camera = cameraNode
    addChild(cameraNode)
    cameraNode.position = playerCart.position
  }

  private func startCountdown() {
    isCountingDown = true
    countdownTimer = 0
    gameState?.countdownValue = 3

    let label = SKLabelNode(text: "3")
    label.fontName = "AvenirNext-Heavy"
    label.fontSize = 72
    label.fontColor = .white
    label.position = .zero
    label.zPosition = 100
    label.name = "countdownLabel"
    cameraNode.addChild(label)
  }

  func setSteerInput(_ value: CGFloat) {
    steerInput = value
  }

  func setDriftHeld(_ held: Bool) {
    isDriftHeld = held
  }

  func usePlayerItem() {
    guard let item = playerCart.heldItem else { return }
    let nearestAI = aiCarts.min(by: {
      hypot($0.position.x - playerCart.position.x, $0.position.y - playerCart.position.y) <
      hypot($1.position.x - playerCart.position.x, $1.position.y - playerCart.position.y)
    })
    itemSystem.useItem(item, from: playerCart, target: nearestAI)
    playerCart.heldItem = nil
    gameState?.heldItem = nil
  }

  override func update(_ currentTime: TimeInterval) {
    let delta = 1.0 / 60.0

    if isCountingDown {
      updateCountdown(delta: delta)
      return
    }

    guard gameState?.phase == .racing else { return }

    raceTimer += delta
    gameState?.raceTime = raceTimer

    playerCart.update(
      deltaTime: delta,
      steerInput: steerInput,
      isDriftHeld: isDriftHeld,
      trackBounds: TrackBuilder.trackBounds()
    )

    updateCheckpoints()
    updateItemBoxes()
    updateBoostPads()
    updateAI(delta: delta)
    updateHazards()
    updatePositions()
    updateCamera()
    checkRaceFinish()

    gameState?.boostMeter = playerCart.driftCharge
  }

    private func updateCountdown(delta: TimeInterval) {
        countdownTimer += delta
        let label = cameraNode.childNode(withName: "countdownLabel") as? SKLabelNode

        if countdownTimer < 1 {
            label?.text = "3"
            gameState?.countdownValue = 3
        } else if countdownTimer < 2 {
            label?.text = "2"
            gameState?.countdownValue = 2
        } else if countdownTimer < 3 {
            label?.text = "1"
            gameState?.countdownValue = 1
        } else if countdownTimer < 3.5 {
            label?.text = "GO!"
            label?.fontColor = .green
            if gameState?.raceStarted == false {
                gameState?.beginRacing()
            }
        } else {
            label?.removeFromParent()
            isCountingDown = false
        }
    }

  private func updateCheckpoints() {
    let checkpoints = TrackBuilder.checkpoints
    let cp = checkpoints[playerCheckpoint]
    let dist = hypot(playerCart.position.x - cp.position.x, playerCart.position.y - cp.position.y)

    if dist < cp.radius {
      playerCheckpoint = (playerCheckpoint + 1) % checkpoints.count
      if playerCheckpoint == 0 {
        playerCart.lapCount += 1
        gameState?.currentLap = min(playerCart.lapCount + 1, (gameState?.totalLaps ?? 3) + 1)
        showLapNotification()
      }
    }
  }

  private func showLapNotification() {
    let lap = playerCart.lapCount
    let total = gameState?.totalLaps ?? 3
    guard lap <= total else { return }

    let label = SKLabelNode(text: "LAP \(lap)/\(total)")
    label.fontName = "AvenirNext-Heavy"
    label.fontSize = 28
    label.fontColor = .yellow
    label.position = CGPoint(x: 0, y: 50)
    label.zPosition = 100
    cameraNode.addChild(label)
    label.run(.sequence([.wait(forDuration: 1.5), .fadeOut(withDuration: 0.5), .removeFromParent()]))
  }

  private func updateItemBoxes() {
    enumerateChildNodes(withName: "itemBox") { [weak self] node, _ in
      guard let self else { return }
      let dist = hypot(self.playerCart.position.x - node.position.x, self.playerCart.position.y - node.position.y)
      if dist < 30 {
        if self.itemSystem.collectItemBox(at: node, for: self.playerCart) {
          self.gameState?.heldItem = self.playerCart.heldItem
        }
      }
    }

    for cart in aiCarts {
      enumerateChildNodes(withName: "itemBox") { [weak self] node, _ in
        guard let self else { return }
        let dist = hypot(cart.position.x - node.position.x, cart.position.y - node.position.y)
        if dist < 30 {
          _ = self.itemSystem.collectItemBox(at: node, for: cart)
        }
      }
    }
  }

  private func updateBoostPads() {
    enumerateChildNodes(withName: "boostPad_*") { [weak self] node, _ in
      guard let self else { return }
      let dist = hypot(self.playerCart.position.x - node.position.x, self.playerCart.position.y - node.position.y)
      if dist < 35 {
        self.playerCart.applyBoost(duration: 1.0)
      }
    }
  }

  private func updateAI(delta: TimeInterval) {
    let hazards = children.filter { $0.name == "bananaPeel" || $0.name == "milkPuddle" }
    let allCarts = [playerCart] + aiCarts

    for (i, driver) in aiDrivers.enumerated() {
      driver.update(
        deltaTime: delta,
        checkpoints: TrackBuilder.checkpoints,
        otherCarts: allCarts,
        hazards: hazards
      )

      let cart = aiCarts[i]
      if cart.heldItem != nil && Bool.random() && Double.random(in: 0...1) < 0.003 {
        let target = allCarts.filter { $0 !== cart }.randomElement()
        itemSystem.useItem(cart.heldItem!, from: cart, target: target)
        cart.heldItem = nil
      }
    }
  }

  private func updateHazards() {
    let hazards = children.filter { $0.name == "bananaPeel" || $0.name == "milkPuddle" }
    itemSystem.checkHazardCollisions(for: playerCart, hazards: hazards)
    for cart in aiCarts {
      itemSystem.checkHazardCollisions(for: cart, hazards: hazards)
    }
  }

    private func updatePositions() {
        let allCarts = [playerCart] + aiCarts
        playerCart.lastCheckpoint = playerCheckpoint

        let sorted = allCarts.filter { !$0.finished }.sorted { a, b in
            let aProgress = CGFloat(a.lapCount) * 100 + CGFloat(a.lastCheckpoint)
            let bProgress = CGFloat(b.lapCount) * 100 + CGFloat(b.lastCheckpoint)
            return aProgress > bProgress
        }

        if let idx = sorted.firstIndex(where: { $0 === playerCart }) {
            gameState?.playerPosition = idx + 1
        }

        for (i, cart) in aiCarts.enumerated() {
            cart.lastCheckpoint = aiDrivers[i].currentCheckpoint
        }
    }

  private func updateCamera() {
    let target = playerCart.position
    cameraNode.position = CGPoint(
      x: cameraNode.position.x + (target.x - cameraNode.position.x) * 0.08,
      y: cameraNode.position.y + (target.y - cameraNode.position.y) * 0.08
    )
  }

  private func checkRaceFinish() {
    let totalLaps = gameState?.totalLaps ?? 3

    for cart in [playerCart] + aiCarts where !cart.finished && cart.lapCount >= totalLaps {
      cart.finished = true
      cart.finishTime = raceTimer
      finishOrder.append((cart, raceTimer))
    }

    let allFinished = ([playerCart] + aiCarts).allSatisfy(\.finished)
    if allFinished {
      let standings = finishOrder.enumerated().map { i, entry in
        RacerStanding(
          name: entry.0.character.rawValue,
          position: i + 1,
          finishTime: entry.1,
          isPlayer: entry.0.isPlayer
        )
      }
      gameState?.finishRace(standings: standings)
    }
  }
}
