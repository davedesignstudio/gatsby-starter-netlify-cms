import SpriteKit

enum StoreTrack {
    static let worldSize = CGSize(width: 2600, height: 3500)

    static let waypoints: [CGPoint] = [
        CGPoint(x: 650, y: 500),
        CGPoint(x: 1_950, y: 500),
        CGPoint(x: 2_220, y: 850),
        CGPoint(x: 2_220, y: 2_650),
        CGPoint(x: 1_950, y: 3_000),
        CGPoint(x: 650, y: 3_000),
        CGPoint(x: 380, y: 2_650),
        CGPoint(x: 380, y: 850)
    ]

    static func build(in world: SKNode) {
        addFloor(to: world)
        addOuterWalls(to: world)
        addCentralAisles(to: world)
        addStartLine(to: world)
        addPickups(to: world)
        addHazards(to: world)
        addBoostPads(to: world)
        addSigns(to: world)
    }

    private static func addFloor(to world: SKNode) {
        let background = SKShapeNode(rectOf: worldSize)
        background.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        background.fillColor = SKColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1)
        background.strokeColor = .clear
        background.zPosition = -20
        world.addChild(background)

        let tileSize: CGFloat = 180
        for row in 0..<20 {
            for column in 0..<15 where (row + column).isMultiple(of: 2) {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(
                    x: CGFloat(column) * tileSize + tileSize / 2,
                    y: CGFloat(row) * tileSize + tileSize / 2
                )
                tile.fillColor = .white.withAlphaComponent(0.025)
                tile.strokeColor = .clear
                tile.zPosition = -19
                world.addChild(tile)
            }
        }

        let route = CGMutablePath()
        route.move(to: waypoints[0])
        for point in waypoints.dropFirst() {
            route.addLine(to: point)
        }
        route.closeSubpath()

        let racingLine = SKShapeNode(path: route)
        racingLine.strokeColor = SKColor(red: 0.97, green: 0.78, blue: 0.22, alpha: 0.1)
        racingLine.lineWidth = 15
        racingLine.lineDashPattern = [30, 34]
        racingLine.zPosition = -10
        world.addChild(racingLine)
    }

    private static func addOuterWalls(to world: SKNode) {
        let outerRect = CGRect(x: 180, y: 250, width: 2_240, height: 3_000)
        let boundary = SKNode()
        boundary.name = "outerWall"
        boundary.physicsBody = SKPhysicsBody(edgeLoopFrom: outerRect)
        boundary.physicsBody?.categoryBitMask = PhysicsCategory.wall
        boundary.physicsBody?.collisionBitMask = PhysicsCategory.cart
        boundary.physicsBody?.friction = 0.4
        world.addChild(boundary)

        addWallStrip(
            to: world,
            position: CGPoint(x: 1_300, y: 230),
            size: CGSize(width: 2_300, height: 38)
        )
        addWallStrip(
            to: world,
            position: CGPoint(x: 1_300, y: 3_270),
            size: CGSize(width: 2_300, height: 38)
        )
        addWallStrip(
            to: world,
            position: CGPoint(x: 160, y: 1_750),
            size: CGSize(width: 38, height: 3_080)
        )
        addWallStrip(
            to: world,
            position: CGPoint(x: 2_440, y: 1_750),
            size: CGSize(width: 38, height: 3_080)
        )
    }

    private static func addCentralAisles(to world: SKNode) {
        let islandRect = CGRect(x: 780, y: 920, width: 1_040, height: 1_660)
        let islandBody = SKNode()
        islandBody.name = "shelves"
        islandBody.physicsBody = SKPhysicsBody(edgeLoopFrom: islandRect)
        islandBody.physicsBody?.categoryBitMask = PhysicsCategory.wall
        islandBody.physicsBody?.collisionBitMask = PhysicsCategory.cart
        islandBody.physicsBody?.friction = 0.5
        world.addChild(islandBody)

        let carpet = SKShapeNode(rect: islandRect, cornerRadius: 28)
        carpet.fillColor = SKColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1)
        carpet.strokeColor = SKColor(red: 0.32, green: 0.36, blue: 0.40, alpha: 1)
        carpet.lineWidth = 18
        carpet.zPosition = 2
        world.addChild(carpet)

        let shelfColors: [SKColor] = [
            SKColor(red: 0.98, green: 0.35, blue: 0.25, alpha: 1),
            SKColor(red: 0.20, green: 0.82, blue: 0.64, alpha: 1),
            SKColor(red: 0.65, green: 0.42, blue: 0.94, alpha: 1),
            SKColor(red: 0.98, green: 0.75, blue: 0.20, alpha: 1)
        ]

        for index in 0..<5 {
            let shelf = SKShapeNode(
                rectOf: CGSize(width: 820, height: 190),
                cornerRadius: 24
            )
            shelf.position = CGPoint(x: 1_300, y: 1_090 + CGFloat(index) * 330)
            shelf.fillColor = SKColor(red: 0.22, green: 0.25, blue: 0.29, alpha: 1)
            shelf.strokeColor = .white.withAlphaComponent(0.15)
            shelf.lineWidth = 8
            shelf.zPosition = 4
            world.addChild(shelf)

            for productIndex in 0..<9 {
                let product = SKShapeNode(
                    rectOf: CGSize(width: 54, height: 90),
                    cornerRadius: 8
                )
                product.position = CGPoint(
                    x: -330 + CGFloat(productIndex) * 82,
                    y: 0
                )
                product.fillColor = shelfColors[(index + productIndex) % shelfColors.count]
                product.strokeColor = .white.withAlphaComponent(0.3)
                product.lineWidth = 3
                shelf.addChild(product)
            }
        }

        for position in [
            CGPoint(x: 565, y: 1_150),
            CGPoint(x: 2_035, y: 1_450),
            CGPoint(x: 565, y: 2_150),
            CGPoint(x: 2_035, y: 2_350)
        ] {
            let display = SKShapeNode(rectOf: CGSize(width: 150, height: 260), cornerRadius: 18)
            display.position = position
            display.fillColor = SKColor(red: 0.23, green: 0.16, blue: 0.11, alpha: 1)
            display.strokeColor = .orange.withAlphaComponent(0.7)
            display.lineWidth = 7
            display.zPosition = 3
            display.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 150, height: 260))
            display.physicsBody?.isDynamic = false
            display.physicsBody?.categoryBitMask = PhysicsCategory.wall
            display.physicsBody?.collisionBitMask = PhysicsCategory.cart
            world.addChild(display)
        }
    }

    private static func addStartLine(to world: SKNode) {
        for index in 0..<8 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 45, height: 52))
            stripe.position = CGPoint(x: 650, y: 318 + CGFloat(index) * 52)
            stripe.fillColor = index.isMultiple(of: 2) ? .white : .black
            stripe.strokeColor = .clear
            stripe.zPosition = 1
            world.addChild(stripe)
        }

        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = "PANTRY RUN • START / FINISH"
        banner.fontSize = 28
        banner.fontColor = .white.withAlphaComponent(0.6)
        banner.position = CGPoint(x: 650, y: 740)
        banner.zRotation = .pi / 2
        banner.zPosition = 2
        world.addChild(banner)
    }

    private static func addPickups(to world: SKNode) {
        let positions = [
            CGPoint(x: 1_100, y: 500),
            CGPoint(x: 1_650, y: 520),
            CGPoint(x: 2_210, y: 1_250),
            CGPoint(x: 2_190, y: 1_900),
            CGPoint(x: 2_210, y: 2_500),
            CGPoint(x: 1_650, y: 3_000),
            CGPoint(x: 1_100, y: 2_980),
            CGPoint(x: 390, y: 2_500),
            CGPoint(x: 410, y: 1_850),
            CGPoint(x: 390, y: 1_150)
        ]

        for position in positions {
            let item = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 10)
            item.name = "pantryItem"
            item.position = position
            item.fillColor = SKColor(red: 1, green: 0.72, blue: 0.16, alpha: 1)
            item.strokeColor = .white
            item.lineWidth = 4
            item.zPosition = 10
            item.physicsBody = SKPhysicsBody(circleOfRadius: 34)
            item.physicsBody?.isDynamic = false
            item.physicsBody?.categoryBitMask = PhysicsCategory.pantryItem
            item.physicsBody?.collisionBitMask = 0
            item.physicsBody?.contactTestBitMask = PhysicsCategory.cart

            let cross = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            cross.text = "+"
            cross.fontSize = 39
            cross.fontColor = .white
            cross.verticalAlignmentMode = .center
            item.addChild(cross)

            item.run(.repeatForever(.sequence([
                .rotate(byAngle: 0.15, duration: 0.55),
                .rotate(byAngle: -0.3, duration: 1.1),
                .rotate(byAngle: 0.15, duration: 0.55)
            ])))
            world.addChild(item)
        }
    }

    private static func addHazards(to world: SKNode) {
        for position in [
            CGPoint(x: 1_860, y: 680),
            CGPoint(x: 2_050, y: 2_160),
            CGPoint(x: 820, y: 2_820),
            CGPoint(x: 545, y: 1_630)
        ] {
            let spill = SKShapeNode(ellipseOf: CGSize(width: 145, height: 90))
            spill.name = "spill"
            spill.position = position
            spill.fillColor = SKColor(red: 0.35, green: 0.80, blue: 0.96, alpha: 0.58)
            spill.strokeColor = .white.withAlphaComponent(0.35)
            spill.lineWidth = 5
            spill.zPosition = 2
            spill.physicsBody = SKPhysicsBody(ellipseOf: CGSize(width: 135, height: 80))
            spill.physicsBody?.isDynamic = false
            spill.physicsBody?.categoryBitMask = PhysicsCategory.spill
            spill.physicsBody?.collisionBitMask = 0
            spill.physicsBody?.contactTestBitMask = PhysicsCategory.cart
            world.addChild(spill)
        }
    }

    private static func addBoostPads(to world: SKNode) {
        for (position, rotation) in [
            (CGPoint(x: 1_350, y: 500), CGFloat.zero),
            (CGPoint(x: 2_220, y: 1_700), CGFloat.pi / 2),
            (CGPoint(x: 1_350, y: 3_000), CGFloat.pi),
            (CGPoint(x: 380, y: 1_700), -CGFloat.pi / 2)
        ] {
            let pad = SKShapeNode(rectOf: CGSize(width: 155, height: 90), cornerRadius: 20)
            pad.name = "boostPad"
            pad.position = position
            pad.zRotation = rotation
            pad.fillColor = SKColor(red: 0.96, green: 0.30, blue: 0.72, alpha: 0.45)
            pad.strokeColor = SKColor(red: 1, green: 0.42, blue: 0.86, alpha: 0.85)
            pad.lineWidth = 8
            pad.zPosition = 3
            pad.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 145, height: 82))
            pad.physicsBody?.isDynamic = false
            pad.physicsBody?.categoryBitMask = PhysicsCategory.boostPad
            pad.physicsBody?.collisionBitMask = 0
            pad.physicsBody?.contactTestBitMask = PhysicsCategory.cart

            let chevrons = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            chevrons.text = "»»"
            chevrons.fontSize = 47
            chevrons.fontColor = .white
            chevrons.verticalAlignmentMode = .center
            pad.addChild(chevrons)
            world.addChild(pad)
        }
    }

    private static func addSigns(to world: SKNode) {
        let signs = [
            ("PRODUCE", CGPoint(x: 1_300, y: 2_760)),
            ("CEREAL", CGPoint(x: 1_300, y: 740)),
            ("FROZEN", CGPoint(x: 2_270, y: 1_750)),
            ("CHECKOUT", CGPoint(x: 320, y: 1_750))
        ]

        for (text, position) in signs {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = text
            label.fontSize = 42
            label.fontColor = .white.withAlphaComponent(0.18)
            label.position = position
            label.zRotation = position.x < 500 || position.x > 2_100 ? .pi / 2 : 0
            label.zPosition = 1
            world.addChild(label)
        }
    }

    private static func addWallStrip(to world: SKNode, position: CGPoint, size: CGSize) {
        let strip = SKShapeNode(rectOf: size, cornerRadius: 10)
        strip.position = position
        strip.fillColor = SKColor(red: 0.98, green: 0.69, blue: 0.14, alpha: 1)
        strip.strokeColor = .white.withAlphaComponent(0.65)
        strip.lineWidth = 5
        strip.zPosition = 8
        world.addChild(strip)
    }
}

private extension SKShapeNode {
    var lineDashPattern: [CGFloat] {
        get { [] }
        set {
            guard let path else { return }
            let dashed = path.copy(
                dashingWithPhase: 0,
                lengths: newValue
            )
            self.path = dashed
        }
    }
}
