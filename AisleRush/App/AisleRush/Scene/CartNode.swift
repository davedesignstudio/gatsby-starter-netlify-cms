import SpriteKit
import UIKit
import AisleRushCore

/// One cart on screen: body, shadow, drift sparks, orbiting cans and the
/// little marker that tells you which one is yours.
final class CartNode: SKNode {
    private let body: SKSpriteNode
    private let shadow: SKSpriteNode
    private let sheen: SKSpriteNode
    private let glow: SKSpriteNode
    private let marker: SKSpriteNode?
    private let leftSparks: SKEmitterNode
    private let rightSparks: SKEmitterNode
    private var cans: [SKSpriteNode] = []
    private var lastDriftTier = -1
    private let frameSize: CGSize

    init(cart: Cart, isPlayer: Bool) {
        // Everything is built into locals first: a class initialiser may not
        // read its own stored properties before `super.init()`.
        let scale = TrackNodeBuilder.scale
        let size = CGSize(
            width: CGFloat(cart.setup.frame.size.x) * 2 * scale,
            height: CGFloat(cart.setup.frame.size.y) * 2 * scale
        )
        frameSize = size

        let bodyNode = SKSpriteNode(texture: TextureFactory.cart(for: cart.setup))
        bodyNode.size = size
        body = bodyNode

        let shadowNode = SKSpriteNode(texture: TextureFactory.cartShadow())
        shadowNode.size = CGSize(width: size.width * 1.35, height: size.height * 1.5)
        shadowNode.position = CGPoint(x: -size.width * 0.05, y: -size.height * 0.08)
        shadowNode.zPosition = -1
        shadow = shadowNode

        let sheenNode = SKSpriteNode(texture: TextureFactory.softDot())
        sheenNode.size = CGSize(width: size.width * 1.1, height: size.height * 1.1)
        sheenNode.blendMode = .add
        sheenNode.color = .white
        sheenNode.colorBlendFactor = 1
        sheenNode.alpha = 0
        sheenNode.zPosition = 1
        sheen = sheenNode

        let glowNode = SKSpriteNode(texture: TextureFactory.softDot())
        glowNode.size = CGSize(width: size.width * 2.1, height: size.width * 2.1)
        glowNode.blendMode = .add
        glowNode.color = UIColor(red: 1, green: 0.86, blue: 0.35, alpha: 1)
        glowNode.colorBlendFactor = 1
        glowNode.alpha = 0
        glowNode.zPosition = -0.5
        glow = glowNode

        let left = CartNode.makeSparks()
        let right = CartNode.makeSparks()
        left.position = CGPoint(x: -size.width * 0.42, y: size.height * 0.42)
        right.position = CGPoint(x: -size.width * 0.42, y: -size.height * 0.42)
        leftSparks = left
        rightSparks = right

        if isPlayer {
            let arrow = SKSpriteNode(texture: TextureFactory.softDot())
            arrow.size = CGSize(width: size.width * 0.34, height: size.width * 0.34)
            arrow.color = .white
            arrow.colorBlendFactor = 1
            arrow.blendMode = .add
            arrow.alpha = 0.85
            arrow.position = CGPoint(x: size.width * 0.72, y: 0)
            marker = arrow
        } else {
            marker = nil
        }

        super.init()

        addChild(shadow)
        addChild(glow)
        addChild(body)
        addChild(sheen)
        addChild(leftSparks)
        addChild(rightSparks)
        if let marker {
            addChild(marker)
            marker.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.7),
                .fadeAlpha(to: 0.85, duration: 0.7)
            ])))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CartNode is created in code")
    }

    func sync(with cart: Cart) {
        position = cart.position.point
        zRotation = CGFloat(cart.heading)

        // Sparks should be left on the floor, not carried around by the cart.
        if leftSparks.targetNode == nil, let parent {
            leftSparks.targetNode = parent
            rightSparks.targetNode = parent
        }

        // Lean into the slide.
        let lean = CGFloat(clamp(cart.slipAngle * 0.22, -0.2, 0.2))
        body.zRotation = lean
        body.setScale(1 + abs(lean) * 0.06)

        let tier = cart.drift.isActive ? cart.drift.tier : 0
        if tier != lastDriftTier {
            lastDriftTier = tier
            let color = CartNode.driftColor(tier: tier)
            for emitter in [leftSparks, rightSparks] {
                emitter.particleColor = color
                emitter.particleBirthRate = tier > 0 ? CGFloat(90 + tier * 70) : 0
            }
        }

        glow.alpha = cart.isInvincible ? 0.55 + 0.25 * CGFloat(sin(cart.orbitAngle * 6)) : 0
        if cart.autopilotTimer > 0 { glow.alpha = max(glow.alpha, 0.4) }

        alpha = cart.hasFinished ? 0.55 : 1

        syncCans(count: cart.orbitingCans, angle: cart.orbitAngle)
    }

    func setSurfaceSheen(_ enabled: Bool) {
        let target: CGFloat = enabled ? 0.22 : 0
        if abs(sheen.alpha - target) > 0.02 {
            sheen.removeAllActions()
            sheen.run(.fadeAlpha(to: target, duration: 0.2))
        }
    }

    private func syncCans(count: Int, angle: Double) {
        while cans.count < count {
            let can = SKSpriteNode(texture: TextureFactory.itemIcon(.soupCan))
            can.size = CGSize(width: frameSize.height * 0.42, height: frameSize.height * 0.42)
            can.zPosition = 2
            addChild(can)
            cans.append(can)
        }
        while cans.count > count {
            cans.removeLast().removeFromParent()
        }
        guard !cans.isEmpty else { return }
        let radius = max(frameSize.width, frameSize.height) * 0.75
        for (index, can) in cans.enumerated() {
            let theta = angle + Double(index) * 2 * .pi / Double(cans.count)
            can.position = CGPoint(x: CGFloat(cos(theta)) * radius, y: CGFloat(sin(theta)) * radius)
            can.zRotation = CGFloat(theta)
        }
    }

    static func driftColor(tier: Int) -> UIColor {
        switch tier {
        case 1: return UIColor(red: 0.35, green: 0.72, blue: 1, alpha: 1)
        case 2: return UIColor(red: 1, green: 0.65, blue: 0.2, alpha: 1)
        case 3: return UIColor(red: 0.78, green: 0.4, blue: 1, alpha: 1)
        default: return UIColor(white: 0.9, alpha: 1)
        }
    }

    private static func makeSparks() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = TextureFactory.softDot()
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 0.32
        emitter.particleLifetimeRange = 0.14
        emitter.particleSpeed = 70
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 1.1
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -3
        emitter.particleScale = 0.14
        emitter.particleScaleSpeed = -0.2
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.zPosition = 3
        return emitter
    }
}
