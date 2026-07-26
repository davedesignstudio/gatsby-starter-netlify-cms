import SpriteKit

final class AIDriver {
  private let cart: CartNode
  private var targetCheckpoint = 0
  private var steerNoise: CGFloat = 0
  private var reactionTimer: TimeInterval = 0
  private let skill: CGFloat

  init(cart: CartNode, skill: CGFloat = 0.7) {
    self.cart = cart
    self.skill = skill
  }

  func update(deltaTime: TimeInterval, checkpoints: [TrackCheckpoint], otherCarts: [CartNode], hazards: [SKNode]) {
    guard !cart.finished, cart.spinOutTimer <= 0 else { return }

    reactionTimer -= deltaTime
    if reactionTimer <= 0 {
      steerNoise = CGFloat.random(in: -0.3...0.3) * (1 - skill)
      reactionTimer = Double.random(in: 0.3...0.8)
    }

    let target = checkpoints[targetCheckpoint]
    let dx = target.position.x - cart.position.x
    let dy = target.position.y - cart.position.y
    let dist = hypot(dx, dy)

    if dist < target.radius {
      targetCheckpoint = (targetCheckpoint + 1) % checkpoints.count
      if targetCheckpoint == 0 {
        cart.lapCount += 1
      }
    }

    let desiredHeading = atan2(dx, dy)
    var headingDiff = desiredHeading - cart.heading
    while headingDiff > .pi { headingDiff -= 2 * .pi }
    while headingDiff < -.pi { headingDiff += 2 * .pi }

    var steer = headingDiff * 2.5 * skill + steerNoise

    for other in otherCarts where other !== cart {
      let odx = cart.position.x - other.position.x
      let ody = cart.position.y - other.position.y
      let odist = hypot(odx, ody)
      if odist < 50 && odist > 0 {
        steer += (odx / odist) * 0.8
      }
    }

    for hazard in hazards {
      let hdx = cart.position.x - hazard.position.x
      let hdy = cart.position.y - hazard.position.y
      let hdist = hypot(hdx, hdy)
      if hdist < 40 && hdist > 0 {
        steer += (hdx / hdist) * 1.2
      }
    }

    steer = max(-1, min(1, steer))

    let shouldDrift = abs(headingDiff) > 0.5 && cart.currentSpeed > 100
    cart.update(
      deltaTime: deltaTime,
      steerInput: steer,
      isDriftHeld: shouldDrift && Bool.random(),
      trackBounds: TrackBuilder.trackBounds()
    )

    if cart.heldItem != nil && Double.random(in: 0...1) < 0.005 * Double(skill) {
      // AI uses items via callback handled in GameScene
    }
  }

  var currentCheckpoint: Int { targetCheckpoint }
}
