import SpriteKit

struct TrackDefinition {
    let name: String
    let floorColor: SKColor
    let aisleColor: SKColor
    let wallColor: SKColor
    let checkpoints: [CGPoint]
    let itemBoxPositions: [CGPoint]
    let boostPadPositions: [CGPoint]
    let hazardPositions: [CGPoint]
    let startPositions: [CGPoint]
    let startAngles: [CGFloat]
}

enum TrackBuilder {
    static func definition(for index: Int, sceneSize: CGSize) -> TrackDefinition {
        switch index % 3 {
        case 1: return frozenFoodsLoop(size: sceneSize)
        case 2: return checkoutChaos(size: sceneSize)
        default: return aisle7Speedway(size: sceneSize)
        }
    }

    static func build(in scene: SKScene, definition: TrackDefinition) {
        let center = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)

        let floor = SKShapeNode(rectOf: CGSize(width: scene.size.width - 20, height: scene.size.height - 20), cornerRadius: 24)
        floor.position = center
        floor.fillColor = definition.floorColor
        floor.strokeColor = definition.wallColor
        floor.lineWidth = 8
        floor.zPosition = -10
        floor.physicsBody = SKPhysicsBody(edgeLoopFrom: floor.path!)
        floor.physicsBody?.categoryBitMask = PhysicsCategory.wall
        floor.physicsBody?.isDynamic = false
        scene.addChild(floor)

        addAisleStripes(to: scene, definition: definition)
        addShelves(to: scene, definition: definition)
        addFinishBanner(to: scene, at: definition.checkpoints[0])
        addDecorations(to: scene, definition: definition)

        for position in definition.boostPadPositions {
            scene.addChild(makeBoostPad(at: position))
        }

        for position in definition.hazardPositions {
            scene.addChild(makeHazard(at: position))
        }

        for position in definition.itemBoxPositions {
            scene.addChild(ItemBoxNode(position: position))
        }
    }

    private static func aisle7Speedway(size: CGSize) -> TrackDefinition {
        let cx = size.width / 2
        let cy = size.height / 2
        return TrackDefinition(
            name: "Aisle 7 Speedway",
            floorColor: SKColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1),
            aisleColor: SKColor(red: 0.78, green: 0.74, blue: 0.68, alpha: 1),
            wallColor: SKColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1),
            checkpoints: [
                CGPoint(x: cx, y: cy + 180),
                CGPoint(x: cx + 150, y: cy + 60),
                CGPoint(x: cx + 120, y: cy - 120),
                CGPoint(x: cx - 120, y: cy - 120),
                CGPoint(x: cx - 150, y: cy + 60)
            ],
            itemBoxPositions: [
                CGPoint(x: cx, y: cy + 40),
                CGPoint(x: cx + 90, y: cy - 40),
                CGPoint(x: cx - 90, y: cy - 40),
                CGPoint(x: cx, y: cy - 140)
            ],
            boostPadPositions: [
                CGPoint(x: cx + 60, y: cy + 120),
                CGPoint(x: cx - 60, y: cy - 80)
            ],
            hazardPositions: [
                CGPoint(x: cx + 140, y: cy - 20),
                CGPoint(x: cx - 140, y: cy + 20)
            ],
            startPositions: [
                CGPoint(x: cx - 30, y: cy + 150),
                CGPoint(x: cx + 30, y: cy + 150),
                CGPoint(x: cx - 30, y: cy + 110),
                CGPoint(x: cx + 30, y: cy + 110)
            ],
            startAngles: [-CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2]
        )
    }

    private static func frozenFoodsLoop(size: CGSize) -> TrackDefinition {
        let cx = size.width / 2
        let cy = size.height / 2
        return TrackDefinition(
            name: "Frozen Foods Loop",
            floorColor: SKColor(red: 0.75, green: 0.88, blue: 0.95, alpha: 1),
            aisleColor: SKColor(red: 0.55, green: 0.72, blue: 0.88, alpha: 1),
            wallColor: SKColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 1),
            checkpoints: [
                CGPoint(x: cx, y: cy + 200),
                CGPoint(x: cx + 170, y: cy),
                CGPoint(x: cx, y: cy - 200),
                CGPoint(x: cx - 170, y: cy)
            ],
            itemBoxPositions: [
                CGPoint(x: cx + 100, y: cy + 100),
                CGPoint(x: cx - 100, y: cy + 100),
                CGPoint(x: cx + 100, y: cy - 100),
                CGPoint(x: cx - 100, y: cy - 100)
            ],
            boostPadPositions: [
                CGPoint(x: cx, y: cy + 160),
                CGPoint(x: cx, y: cy - 160)
            ],
            hazardPositions: [
                CGPoint(x: cx + 170, y: cy + 80),
                CGPoint(x: cx - 170, y: cy - 80)
            ],
            startPositions: [
                CGPoint(x: cx - 35, y: cy + 170),
                CGPoint(x: cx + 35, y: cy + 170),
                CGPoint(x: cx - 35, y: cy + 130),
                CGPoint(x: cx + 35, y: cy + 130)
            ],
            startAngles: [-CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2]
        )
    }

    private static func checkoutChaos(size: CGSize) -> TrackDefinition {
        let cx = size.width / 2
        let cy = size.height / 2
        return TrackDefinition(
            name: "Checkout Chaos",
            floorColor: SKColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1),
            aisleColor: SKColor(red: 0.85, green: 0.80, blue: 0.70, alpha: 1),
            wallColor: SKColor(red: 0.45, green: 0.30, blue: 0.20, alpha: 1),
            checkpoints: [
                CGPoint(x: cx, y: cy + 170),
                CGPoint(x: cx + 130, y: cy + 90),
                CGPoint(x: cx + 160, y: cy - 40),
                CGPoint(x: cx + 40, y: cy - 150),
                CGPoint(x: cx - 100, y: cy - 90),
                CGPoint(x: cx - 160, y: cy + 50)
            ],
            itemBoxPositions: [
                CGPoint(x: cx, y: cy),
                CGPoint(x: cx + 120, y: cy + 30),
                CGPoint(x: cx - 80, y: cy - 60),
                CGPoint(x: cx + 20, y: cy - 120)
            ],
            boostPadPositions: [
                CGPoint(x: cx - 120, y: cy + 100),
                CGPoint(x: cx + 80, y: cy - 100)
            ],
            hazardPositions: [
                CGPoint(x: cx + 50, y: cy + 80),
                CGPoint(x: cx - 60, y: cy + 10),
                CGPoint(x: cx + 10, y: cy - 70)
            ],
            startPositions: [
                CGPoint(x: cx - 30, y: cy + 140),
                CGPoint(x: cx + 30, y: cy + 140),
                CGPoint(x: cx - 30, y: cy + 100),
                CGPoint(x: cx + 30, y: cy + 100)
            ],
            startAngles: [-CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2, -CGFloat.pi / 2]
        )
    }

    private static func addAisleStripes(to scene: SKScene, definition: TrackDefinition) {
        let stripeCount = 6
        let spacing = scene.size.width / CGFloat(stripeCount + 1)
        for index in 1...stripeCount {
            let stripe = SKShapeNode(rectOf: CGSize(width: 18, height: scene.size.height - 80), cornerRadius: 4)
            stripe.position = CGPoint(x: spacing * CGFloat(index), y: scene.size.height / 2)
            stripe.fillColor = definition.aisleColor
            stripe.strokeColor = .clear
            stripe.alpha = 0.35
            stripe.zPosition = -9
            scene.addChild(stripe)
        }
    }

    private static func addShelves(to scene: SKScene, definition: TrackDefinition) {
        let shelfPositions: [CGPoint] = [
            CGPoint(x: 60, y: scene.size.height - 90),
            CGPoint(x: scene.size.width - 60, y: scene.size.height - 90),
            CGPoint(x: 60, y: 90),
            CGPoint(x: scene.size.width - 60, y: 90)
        ]

        for position in shelfPositions {
            let shelf = SKShapeNode(rectOf: CGSize(width: 70, height: 120), cornerRadius: 6)
            shelf.position = position
            shelf.fillColor = definition.wallColor.withAlphaComponent(0.85)
            shelf.strokeColor = .black
            shelf.lineWidth = 2
            shelf.zPosition = -5

            for row in 0..<3 {
                let product = SKShapeNode(rectOf: CGSize(width: 50, height: 18), cornerRadius: 3)
                product.position = CGPoint(x: 0, y: 30 - CGFloat(row) * 28)
                product.fillColor = [SKColor.red, .green, .blue, .yellow, .orange].randomElement()!
                product.strokeColor = .black
                product.lineWidth = 1
                shelf.addChild(product)
            }

            shelf.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 70, height: 120))
            shelf.physicsBody?.isDynamic = false
            shelf.physicsBody?.categoryBitMask = PhysicsCategory.wall
            scene.addChild(shelf)
        }
    }

    private static func addFinishBanner(to scene: SKScene, at position: CGPoint) {
        let banner = SKShapeNode(rectOf: CGSize(width: 140, height: 24), cornerRadius: 4)
        banner.position = position
        banner.fillColor = .white
        banner.strokeColor = .black
        banner.lineWidth = 2
        banner.zPosition = 1

        let label = SKLabelNode(text: "CHECKOUT")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 14
        label.fontColor = .red
        label.verticalAlignmentMode = .center
        banner.addChild(label)
        scene.addChild(banner)
    }

    private static func addDecorations(to scene: SKScene, definition: TrackDefinition) {
        let sign = SKLabelNode(text: definition.name.uppercased())
        sign.fontName = "AvenirNext-Heavy"
        sign.fontSize = 16
        sign.fontColor = definition.wallColor
        sign.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 36)
        sign.zPosition = 5
        scene.addChild(sign)
    }

    private static func makeBoostPad(at position: CGPoint) -> SKNode {
        let pad = SKShapeNode(rectOf: CGSize(width: 50, height: 24), cornerRadius: 6)
        pad.position = position
        pad.fillColor = SKColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.8)
        pad.strokeColor = .white
        pad.lineWidth = 2
        pad.zPosition = -2
        pad.name = "boostPad"

        let arrows = SKLabelNode(text: "»»»")
        arrows.fontSize = 14
        arrows.fontColor = .white
        arrows.verticalAlignmentMode = .center
        pad.addChild(arrows)

        pad.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 24))
        pad.physicsBody?.isDynamic = false
        pad.physicsBody?.categoryBitMask = PhysicsCategory.boostPad
        pad.physicsBody?.contactTestBitMask = PhysicsCategory.cart
        return pad
    }

    private static func makeHazard(at position: CGPoint) -> SKNode {
        let spill = SKShapeNode(circleOfRadius: 18)
        spill.position = position
        spill.fillColor = SKColor.yellow.withAlphaComponent(0.5)
        spill.strokeColor = .orange
        spill.lineWidth = 2
        spill.zPosition = -1
        spill.name = "hazard"

        spill.physicsBody = SKPhysicsBody(circleOfRadius: 18)
        spill.physicsBody?.isDynamic = false
        spill.physicsBody?.categoryBitMask = PhysicsCategory.hazard
        spill.physicsBody?.contactTestBitMask = PhysicsCategory.cart
        return spill
    }
}
