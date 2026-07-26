import CartKartCore
import SpriteKit

/// Short-lived visual flourishes: sparks, puffs, bursts and floating text.
///
/// These are plain sprites driven by `SKAction` rather than emitters, so there
/// is no particle configuration to keep in sync and everything is tinted from
/// the same palette as the rest of the game.
final class EffectsLayer: SKNode {
    private let sparkTextures: [String: SKTexture]

    override init() {
        sparkTextures = [
            "white": TextureFactory.spark(named: "white", color: .white),
            "blue": TextureFactory.spark(named: "blue", color: SKColor(red: 0.4, green: 0.75, blue: 1, alpha: 1)),
            "orange": TextureFactory.spark(named: "orange", color: SKColor(red: 1, green: 0.62, blue: 0.15, alpha: 1)),
            "purple": TextureFactory.spark(named: "purple", color: SKColor(red: 0.75, green: 0.4, blue: 1, alpha: 1)),
            "grey": TextureFactory.spark(named: "grey", color: SKColor(white: 0.85, alpha: 1))
        ]
        super.init()
        zPosition = Layer.effect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func spark(_ name: String) -> SKTexture {
        sparkTextures[name] ?? sparkTextures["white"]!
    }

    func addDriftSpark(at position: Vec2, tier: DriftTier) {
        let name: String
        switch tier {
        case .none: return
        case .squeak: name = "blue"
        case .rattle: name = "orange"
        case .rumble: name = "purple"
        }
        let node = SKSpriteNode(texture: spark(name))
        node.position = position.cgPoint
        node.size = CGSize(width: 26, height: 26)
        node.blendMode = .add
        addChild(node)
        node.run(.sequence([
            .group([
                .scale(to: 0.2, duration: 0.28),
                .fadeOut(withDuration: 0.28),
                .move(by: CGVector(dx: .random(in: -18...18), dy: .random(in: -18...18)), duration: 0.28)
            ]),
            .removeFromParent()
        ]))
    }

    func addBoostPuff(at position: Vec2, rainbow: Bool) {
        let node = SKSpriteNode(texture: spark(rainbow ? "white" : "orange"))
        node.position = position.cgPoint
        node.size = CGSize(width: 34, height: 34)
        node.blendMode = .add
        if rainbow {
            node.color = SKColor(hue: .random(in: 0...1), saturation: 0.85, brightness: 1, alpha: 1)
            node.colorBlendFactor = 0.8
        }
        addChild(node)
        node.run(.sequence([
            .group([.scale(to: 1.7, duration: 0.32), .fadeOut(withDuration: 0.32)]),
            .removeFromParent()
        ]))
    }

    /// Ring of sparks for collisions, smashed props and melon impacts.
    func addBurst(at position: Vec2, color: String = "white", scale: CGFloat = 1) {
        for index in 0..<10 {
            let angle = Double(index) / 10 * 2 * .pi
            let node = SKSpriteNode(texture: spark(color))
            node.position = position.cgPoint
            node.size = CGSize(width: 30 * scale, height: 30 * scale)
            node.blendMode = .add
            addChild(node)
            let travel = 70.0 * Double(scale)
            node.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(angle) * travel, dy: sin(angle) * travel), duration: 0.36),
                    .fadeOut(withDuration: 0.36),
                    .scale(to: 0.3, duration: 0.36)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// Stars orbiting a spun-out cart.
    func addSpinStars(at position: Vec2, duration: Double) {
        let container = SKNode()
        container.position = position.cgPoint
        container.zPosition = Layer.effect
        addChild(container)
        for index in 0..<3 {
            let star = SKLabelNode(text: "✳️")
            star.fontSize = 22
            star.position = CGPoint(x: cos(Double(index) * 2.1) * 34, y: sin(Double(index) * 2.1) * 34)
            container.addChild(star)
        }
        container.run(.sequence([
            .group([
                .repeat(.rotate(byAngle: .pi * 2, duration: 0.5), count: Int(duration / 0.5) + 1),
                .sequence([.wait(forDuration: duration * 0.7), .fadeOut(withDuration: duration * 0.3)])
            ]),
            .removeFromParent()
        ]))
    }

    /// Floating text such as "RUMBLE!" or "FINAL LAP".
    func addFloatingText(_ text: String, at position: Vec2, color: SKColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 30
        label.fontColor = color
        label.position = position.cgPoint
        label.zPosition = Layer.effect + 1
        if let rotation = (scene as? RaceScene)?.cameraRotation {
            label.zRotation = -rotation
        }
        addChild(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: 70, duration: 0.85),
                .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.4)])
            ]),
            .removeFromParent()
        ]))
    }
}
