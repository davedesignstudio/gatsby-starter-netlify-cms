import SpriteKit

/// One cart on screen: the body sprite plus the continuous effects that hang off
/// it. Reads its state from `CartState` every frame and owns no logic of its own.
final class CartNode: SKNode {
    let cartID: Int
    private let racer: Racer
    private let metre: CGFloat

    private let body: SKSpriteNode
    private let playerRing: SKSpriteNode?
    private let tyreSmoke: SKEmitterNode
    private let boostFlame: SKEmitterNode
    private let shieldCrates: [SKSpriteNode]
    private let statusGlow: SKSpriteNode

    init(cart: CartState, factory: ArtFactory, metre: CGFloat, effectTarget: SKNode) {
        cartID = cart.id
        racer = cart.racer
        self.metre = metre

        let texture = factory.cartTexture(for: cart.racer)
        body = SKSpriteNode(texture: texture)
        body.size = CGSize(
            width: texture.size().width / ArtFactory.pixelsPerMetre * metre,
            height: texture.size().height / ArtFactory.pixelsPerMetre * metre
        )
        body.zPosition = 2

        if cart.isPlayer {
            let ring = SKSpriteNode(texture: factory.glowTexture())
            ring.size = CGSize(width: metre * 3.4, height: metre * 3.4)
            ring.color = UIColor(cart.racer.primaryColor)
            ring.colorBlendFactor = 1
            ring.alpha = 0.35
            ring.zPosition = -1
            ring.blendMode = .add
            playerRing = ring
        } else {
            playerRing = nil
        }

        // Tyre smoke doubles as the off-road dust cloud.
        tyreSmoke = SKEmitterNode()
        tyreSmoke.particleTexture = factory.smokeTexture()
        tyreSmoke.particleBirthRate = 0
        tyreSmoke.particleLifetime = 0.55
        tyreSmoke.particleLifetimeRange = 0.2
        tyreSmoke.particleSize = CGSize(width: metre * 0.8, height: metre * 0.8)
        tyreSmoke.particleAlpha = 0.45
        tyreSmoke.particleAlphaSpeed = -0.9
        tyreSmoke.particleScale = 0.5
        tyreSmoke.particleScaleRange = 0.2
        tyreSmoke.particleScaleSpeed = 0.7
        tyreSmoke.particleSpeed = metre * 0.9
        tyreSmoke.particleSpeedRange = metre * 0.6
        tyreSmoke.emissionAngleRange = .pi * 2
        tyreSmoke.particleColor = UIColor(white: 0.95, alpha: 1)
        tyreSmoke.particleColorBlendFactor = 1
        tyreSmoke.position = CGPoint(x: -metre * 0.7, y: 0)
        tyreSmoke.zPosition = 1
        // Particles live in the world so they stay put on the floor instead of
        // being dragged along by the cart.
        tyreSmoke.targetNode = effectTarget

        boostFlame = SKEmitterNode()
        boostFlame.particleTexture = factory.sparkTexture()
        boostFlame.particleBirthRate = 0
        boostFlame.particleLifetime = 0.35
        boostFlame.particleSize = CGSize(width: metre * 0.4, height: metre * 0.4)
        boostFlame.particleAlpha = 0.9
        boostFlame.particleAlphaSpeed = -2.4
        boostFlame.particleScale = 0.7
        boostFlame.particleScaleSpeed = -1.0
        boostFlame.particleSpeed = metre * 3.2
        boostFlame.particleSpeedRange = metre * 1.2
        boostFlame.emissionAngle = .pi
        boostFlame.emissionAngleRange = 0.7
        boostFlame.particleColor = UIColor(Palette.boostGlow)
        boostFlame.particleColorBlendFactor = 1
        boostFlame.particleBlendMode = .add
        boostFlame.position = CGPoint(x: -metre * 0.9, y: 0)
        boostFlame.zPosition = 1
        boostFlame.targetNode = effectTarget

        let crateTexture = factory.shieldCrateTexture()
        shieldCrates = (0..<3).map { _ in
            let crate = SKSpriteNode(texture: crateTexture)
            crate.size = CGSize(width: metre * 0.8, height: metre * 0.8)
            crate.zPosition = 3
            crate.isHidden = true
            return crate
        }

        statusGlow = SKSpriteNode(texture: factory.glowTexture())
        statusGlow.size = CGSize(width: metre * 2.6, height: metre * 2.6)
        statusGlow.colorBlendFactor = 1
        statusGlow.blendMode = .add
        statusGlow.alpha = 0
        statusGlow.zPosition = 4

        super.init()

        if let playerRing { addChild(playerRing) }
        addChild(tyreSmoke)
        addChild(boostFlame)
        addChild(body)
        shieldCrates.forEach { addChild($0) }
        addChild(statusGlow)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func update(cart: CartState, tuning: SimulationTuning) {
        position = CGPoint(x: CGFloat(cart.position.x) * metre, y: CGFloat(cart.position.y) * metre)
        zRotation = CGFloat(cart.heading)
        zPosition = cart.isPlayer ? 60 : 50

        // Smoke when the tyres are sliding, dust when off the aisle.
        let slipping = abs(cart.lateralSpeed) > 1.2 || cart.isDrifting
        if cart.isOffRoad {
            tyreSmoke.particleColor = UIColor(RacerColor(hex: 0xB8A177))
            tyreSmoke.particleBirthRate = CGFloat(min(70, 22 + abs(cart.forwardSpeed) * 3))
        } else if slipping, abs(cart.forwardSpeed) > 3 {
            tyreSmoke.particleColor = UIColor(white: 0.95, alpha: 1)
            tyreSmoke.particleBirthRate = CGFloat(min(90, abs(cart.lateralSpeed) * 22 + (cart.isDrifting ? 26 : 0)))
        } else {
            tyreSmoke.particleBirthRate = 0
        }

        boostFlame.particleBirthRate = cart.isBoosting ? 150 : 0

        // Drift charge tints the smoke as the mini-turbo builds, the way a kart
        // racer signals the sparks tier.
        if cart.isDrifting {
            switch cart.miniTurboTier(tuning: tuning) {
            case 0: break
            case 1: tyreSmoke.particleColor = UIColor(RacerColor(hex: 0x6FD6E8))
            case 2: tyreSmoke.particleColor = UIColor(Palette.boostGlow)
            default: tyreSmoke.particleColor = UIColor(RacerColor(hex: 0xEF476F))
            }
        }

        if cart.shieldCharges > 0 {
            for (index, crate) in shieldCrates.enumerated() {
                let active = index < cart.shieldCharges
                crate.isHidden = !active
                guard active else { continue }
                let angle = cart.shieldAngle + Double(index) * 2 * .pi / 3
                // Counter-rotate so the crates do not spin with the cart.
                crate.position = CGPoint(x: CGFloat(cos(angle)) * metre * 1.5, y: CGFloat(sin(angle)) * metre * 1.5)
                crate.zRotation = -zRotation + CGFloat(angle)
            }
        } else {
            shieldCrates.forEach { $0.isHidden = true }
        }

        if cart.spinoutTimer > 0 {
            statusGlow.color = UIColor(Palette.danger)
            statusGlow.alpha = 0.5
        } else if cart.slipTimer > 0 {
            statusGlow.color = UIColor(RacerColor(hex: 0x9FD8F2))
            statusGlow.alpha = 0.4
        } else if cart.stallTimer > 0 {
            statusGlow.color = UIColor(RacerColor(hex: 0x8A8FA6))
            statusGlow.alpha = 0.35
        } else if cart.expressLaneTimer > 0 {
            statusGlow.color = UIColor(Palette.good)
            statusGlow.alpha = 0.55
        } else {
            statusGlow.alpha = max(0, statusGlow.alpha - 0.08)
        }

        playerRing?.alpha = cart.isBoosting ? 0.45 : 0.3
    }
}
