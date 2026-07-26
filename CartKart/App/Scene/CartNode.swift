import CartKartCore
import SpriteKit

/// One cart on screen: the body, its shadow, and the effects that hang off it
/// (drift sparks, boost flames, spin stars, name tag).
final class CartNode: SKNode {
    let kartID: Int
    private let body: SKSpriteNode
    private let shadow: SKSpriteNode
    private let glow: SKShapeNode
    private let nameTag: SKLabelNode
    private var driftSparkTimer: Double = 0
    private var boostPuffTimer: Double = 0

    init(kart: KartState, showNameTag: Bool) {
        self.kartID = kart.id
        body = SKSpriteNode(texture: TextureFactory.cart(for: kart.profile))
        body.size = CGSize(width: 62, height: 42)

        shadow = SKSpriteNode(texture: TextureFactory.shadow)
        shadow.size = CGSize(width: 84, height: 62)
        shadow.alpha = 0.7
        shadow.zPosition = -1

        glow = SKShapeNode(circleOfRadius: 42)
        glow.fillColor = .clear
        glow.strokeColor = .clear
        glow.lineWidth = 5
        glow.zPosition = 1

        nameTag = SKLabelNode(text: kart.profile.name)
        nameTag.fontName = "AvenirNext-Bold"
        nameTag.fontSize = 20
        nameTag.fontColor = .white
        nameTag.position = CGPoint(x: 0, y: 40)
        nameTag.zPosition = 2
        nameTag.alpha = showNameTag ? 0.75 : 0

        super.init()
        zPosition = Layer.cart
        addChild(shadow)
        addChild(glow)
        addChild(body)
        addChild(nameTag)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Copies simulation state onto the sprite and spawns any effects.
    func sync(with kart: KartState, dt: Double, effects: EffectsLayer) {
        position = kart.position.cgPoint
        // Textures are drawn nose-first along +x, so heading maps straight to rotation.
        body.zRotation = kart.visualHeading
        shadow.position = CGPoint(x: -6, y: -8)

        // The camera rotates with the player, so counter-rotate the tag by the
        // same amount to keep it upright on screen.
        if let cameraRotation = (scene as? RaceScene)?.cameraRotation {
            nameTag.zRotation = cameraRotation
        }

        if kart.isInvincible {
            // Bulk Buy: flashing rainbow ring.
            glow.strokeColor = SKColor(
                hue: CGFloat((kart.bulkBuyTimer * 1.6).truncatingRemainder(dividingBy: 1)),
                saturation: 0.9,
                brightness: 1,
                alpha: 0.95
            )
            body.setScale(1.1)
        } else if kart.isBoosting {
            glow.strokeColor = SKColor(red: 1, green: 0.72, blue: 0.2, alpha: 0.8)
            body.setScale(1.04)
        } else {
            glow.strokeColor = .clear
            body.setScale(1.0)
        }

        switch kart.disruption {
        case .cloud:
            body.alpha = 0.55
        case .squash:
            // Flattened: squash the sprite rather than swap the texture.
            body.yScale = 0.55
            body.xScale = 1.25
            body.alpha = 1
        default:
            body.alpha = 1
        }

        spawnTrailEffects(for: kart, dt: dt, effects: effects)
    }

    private func spawnTrailEffects(for kart: KartState, dt: Double, effects: EffectsLayer) {
        let rear = kart.position - Vec2.direction(kart.heading) * 26

        if kart.isDrifting, kart.driftTier != .none {
            driftSparkTimer -= dt
            if driftSparkTimer <= 0 {
                driftSparkTimer = 0.045
                effects.addDriftSpark(at: rear, tier: kart.driftTier)
            }
        } else {
            driftSparkTimer = 0
        }

        if kart.isBoosting || kart.isInvincible {
            boostPuffTimer -= dt
            if boostPuffTimer <= 0 {
                boostPuffTimer = 0.05
                effects.addBoostPuff(at: rear, rainbow: kart.isInvincible)
            }
        }
    }
}
