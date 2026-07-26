import SpriteKit

final class ItemSystem {
  weak var scene: SKScene?

  func useItem(_ item: ItemType, from cart: CartNode, target: CartNode?) {
    guard let scene else { return }

    switch item {
    case .bananaPeel:
      dropBananaPeel(at: offsetBehind(cart), scene: scene)
    case .canMissile:
      fireCanMissile(from: cart, toward: target, scene: scene)
    case .squeakyBoost:
      cart.applyBoost(duration: 2.0)
      playEffect("SQUEAK!", at: cart.position, color: .cyan, scene: scene)
    case .couponShield:
      cart.shieldActive = true
      playEffect("SHIELD!", at: cart.position, color: .green, scene: scene)
    case .spilledMilk:
      dropMilkPuddle(at: offsetBehind(cart), scene: scene)
    }
  }

  func collectItemBox(at node: SKNode, for cart: CartNode) -> Bool {
    guard node.name == "itemBox" || node.parent?.name == "itemBox" else { return false }
    let box = node.name == "itemBox" ? node : node.parent!
    guard !box.isHidden else { return false }

    cart.heldItem = ItemType.random()
    box.isHidden = true

    let respawn = SKAction.sequence([
      .wait(forDuration: 5),
      .run { box.isHidden = false },
    ])
    box.run(respawn)

    flashCollect(at: box.position)
    return true
  }

  func checkHazardCollisions(for cart: CartNode, hazards: [SKNode]) {
    for hazard in hazards {
      let dist = hypot(cart.position.x - hazard.position.x, cart.position.y - hazard.position.y)
      if dist < 25 {
        if hazard.name == "bananaPeel" || hazard.name == "milkPuddle" {
          cart.applySpinOut()
          hazard.removeFromParent()
        }
      }
    }
  }

  // MARK: - Private

  private func offsetBehind(_ cart: CartNode) -> CGPoint {
    let offset: CGFloat = 35
    return CGPoint(
      x: cart.position.x - sin(cart.heading) * offset,
      y: cart.position.y - cos(cart.heading) * offset
    )
  }

  private func dropBananaPeel(at position: CGPoint, scene: SKScene) {
    let peel = SKShapeNode(circleOfRadius: 10)
    peel.fillColor = .yellow
    peel.strokeColor = .orange
    peel.lineWidth = 1
    peel.position = position
    peel.zPosition = 5
    peel.name = "bananaPeel"
    scene.addChild(peel)
  }

  private func dropMilkPuddle(at position: CGPoint, scene: SKScene) {
    let puddle = SKShapeNode(ellipseOf: CGSize(width: 40, height: 30))
    puddle.fillColor = SKColor(white: 0.95, alpha: 0.8)
    puddle.strokeColor = SKColor(white: 0.8, alpha: 1)
    puddle.lineWidth = 1
    puddle.position = position
    puddle.zPosition = 4
    puddle.name = "milkPuddle"
    scene.addChild(puddle)
  }

  private func fireCanMissile(from cart: CartNode, toward target: CartNode?, scene: SKScene) {
    let missile = SKShapeNode(rectOf: CGSize(width: 8, height: 16), cornerRadius: 2)
    missile.fillColor = .orange
    missile.strokeColor = .red
    missile.lineWidth = 1
    missile.position = cart.position
    missile.zPosition = 15
    missile.name = "canMissile"
    scene.addChild(missile)

    let targetPos: CGPoint
    if let target {
      targetPos = target.position
    } else {
      targetPos = CGPoint(
        x: cart.position.x + sin(cart.heading) * 300,
        y: cart.position.y + cos(cart.heading) * 300
      )
    }

    let dist = hypot(targetPos.x - cart.position.x, targetPos.y - cart.position.y)
    let duration = TimeInterval(dist / 400)

    missile.run(.sequence([
      .move(to: targetPos, duration: duration),
      .run { [weak self, weak scene] in
        guard let scene else { return }
        self?.checkMissileHit(at: targetPos, scene: scene, exclude: cart)
        missile.removeFromParent()
      },
    ]))
  }

  private func checkMissileHit(at position: CGPoint, scene: SKScene, exclude: CartNode) {
    scene.enumerateChildNodes(withName: "aiCart") { node, _ in
      guard let cart = node as? CartNode, cart !== exclude else { return }
      let dist = hypot(cart.position.x - position.x, cart.position.y - position.y)
      if dist < 30 { cart.applySpinOut() }
    }
    if let player = scene.childNode(withName: "playerCart") as? CartNode, player !== exclude {
      let dist = hypot(player.position.x - position.x, player.position.y - position.y)
      if dist < 30 { player.applySpinOut() }
    }
  }

  private func playEffect(_ text: String, at position: CGPoint, color: SKColor, scene: SKScene) {
    let label = SKLabelNode(text: text)
    label.fontName = "AvenirNext-Heavy"
    label.fontSize = 16
    label.fontColor = color
    label.position = position
    label.zPosition = 20
    scene.addChild(label)
    label.run(.sequence([
      .group([.moveBy(x: 0, y: 30, duration: 0.8), .fadeOut(withDuration: 0.8)]),
      .removeFromParent(),
    ]))
  }

  private func flashCollect(at position: CGPoint) {
  }
}
