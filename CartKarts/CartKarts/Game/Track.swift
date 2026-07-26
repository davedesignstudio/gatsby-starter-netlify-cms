import SpriteKit

struct Waypoint {
    let position: CGPoint
    let radius: CGFloat
}

/// "Midnight at the MegaMart" — one lap runs counter-clockwise around the
/// store perimeter, weaves an S through the grocery aisles, then slaloms the
/// checkout lanes back to the finish line.
final class Track {
    static let worldSize = CGSize(width: 4200, height: 2600)

    /// Ordered racing line. Carts must pass each waypoint (within its radius)
    /// in sequence, which is also how laps and race positions are scored.
    let waypoints: [Waypoint] = [
        // Bottom straight, heading east.
        Waypoint(position: CGPoint(x: 2400, y: 420), radius: 150),
        Waypoint(position: CGPoint(x: 2800, y: 420), radius: 160),
        Waypoint(position: CGPoint(x: 3200, y: 420), radius: 160),
        Waypoint(position: CGPoint(x: 3560, y: 460), radius: 120),
        // Right corridor, heading north past the dairy wall.
        Waypoint(position: CGPoint(x: 3810, y: 640), radius: 110),
        Waypoint(position: CGPoint(x: 3860, y: 950), radius: 150),
        Waypoint(position: CGPoint(x: 3860, y: 1350), radius: 160),
        Waypoint(position: CGPoint(x: 3860, y: 1750), radius: 150),
        Waypoint(position: CGPoint(x: 3790, y: 2070), radius: 110),
        // Top corridor, heading west.
        Waypoint(position: CGPoint(x: 3520, y: 2220), radius: 120),
        Waypoint(position: CGPoint(x: 3080, y: 2230), radius: 160),
        Waypoint(position: CGPoint(x: 2620, y: 2230), radius: 160),
        Waypoint(position: CGPoint(x: 2160, y: 2230), radius: 160),
        Waypoint(position: CGPoint(x: 1700, y: 2230), radius: 160),
        Waypoint(position: CGPoint(x: 1240, y: 2230), radius: 160),
        Waypoint(position: CGPoint(x: 840, y: 2210), radius: 120),
        // Down the left corridor.
        Waypoint(position: CGPoint(x: 520, y: 2060), radius: 110),
        Waypoint(position: CGPoint(x: 450, y: 1760), radius: 120),
        Waypoint(position: CGPoint(x: 470, y: 1500), radius: 100),
        // East through the upper aisle (between Aisle 1 and Aisle 3 shelving).
        Waypoint(position: CGPoint(x: 900, y: 1500), radius: 120),
        Waypoint(position: CGPoint(x: 1350, y: 1500), radius: 130),
        Waypoint(position: CGPoint(x: 1800, y: 1500), radius: 110),
        // South through the center gap...
        Waypoint(position: CGPoint(x: 2100, y: 1420), radius: 90),
        Waypoint(position: CGPoint(x: 2100, y: 1140), radius: 90),
        // ...then back west through the lower aisle.
        Waypoint(position: CGPoint(x: 1930, y: 1050), radius: 90),
        Waypoint(position: CGPoint(x: 1500, y: 1050), radius: 130),
        Waypoint(position: CGPoint(x: 1060, y: 1050), radius: 130),
        Waypoint(position: CGPoint(x: 640, y: 1040), radius: 110),
        // Short left-corridor hop down to the checkout area.
        Waypoint(position: CGPoint(x: 455, y: 890), radius: 100),
        Waypoint(position: CGPoint(x: 450, y: 640), radius: 110),
        Waypoint(position: CGPoint(x: 640, y: 420), radius: 110),
        // Checkout-lane slalom back to the finish line.
        Waypoint(position: CGPoint(x: 950, y: 300), radius: 80),
        Waypoint(position: CGPoint(x: 1300, y: 330), radius: 80),
        Waypoint(position: CGPoint(x: 1520, y: 480), radius: 80),
        Waypoint(position: CGPoint(x: 1720, y: 440), radius: 70),
        Waypoint(position: CGPoint(x: 1880, y: 290), radius: 80),
    ]

    let itemBoxPositions: [CGPoint] = [
        // Bottom straight.
        CGPoint(x: 2600, y: 260), CGPoint(x: 2600, y: 420), CGPoint(x: 2600, y: 580),
        // Right corridor.
        CGPoint(x: 3580, y: 1500), CGPoint(x: 3740, y: 1500), CGPoint(x: 3900, y: 1500),
        // Top corridor.
        CGPoint(x: 2350, y: 2060), CGPoint(x: 2350, y: 2220), CGPoint(x: 2350, y: 2380),
        // Lower aisle.
        CGPoint(x: 1500, y: 960), CGPoint(x: 1520, y: 1050), CGPoint(x: 1500, y: 1140),
    ]

    let puddlePositions: [CGPoint] = [
        CGPoint(x: 2820, y: 2170),
        CGPoint(x: 1320, y: 1520),
        CGPoint(x: 3920, y: 1050),
    ]

    let startRotation: CGFloat = -.pi / 2 // facing east

    /// Starting grid: two columns just behind the finish line.
    func gridPositions(count: Int) -> [CGPoint] {
        let xs: [CGFloat] = [2200, 2125, 2050]
        let ys: [CGFloat] = [350, 480]
        var slots: [CGPoint] = []
        for x in xs {
            for y in ys {
                slots.append(CGPoint(x: x, y: y))
            }
        }
        return Array(slots.prefix(count))
    }

    // MARK: - Geometry (shared between visuals and physics)

    struct Obstacle {
        let rect: CGRect
        enum Kind { case shelf(String); case checkout; case pallet }
        let kind: Kind
    }

    static let wallThickness: CGFloat = 80

    let obstacles: [Obstacle] = [
        // Gondola shelving, three rows split by the center gap.
        Obstacle(rect: CGRect(x: 800, y: 1650, width: 1150, height: 150), kind: .shelf("AISLE 1 · CEREAL")),
        Obstacle(rect: CGRect(x: 2250, y: 1650, width: 1150, height: 150), kind: .shelf("AISLE 2 · SODA & CHIPS")),
        Obstacle(rect: CGRect(x: 800, y: 1200, width: 1150, height: 150), kind: .shelf("AISLE 3 · CANNED GOODS")),
        Obstacle(rect: CGRect(x: 2250, y: 1200, width: 1150, height: 150), kind: .shelf("AISLE 4 · FROZEN")),
        Obstacle(rect: CGRect(x: 800, y: 750, width: 1150, height: 150), kind: .shelf("AISLE 5 · PET FOOD")),
        Obstacle(rect: CGRect(x: 2250, y: 750, width: 1150, height: 150), kind: .shelf("AISLE 6 · CLEANING")),
        // Checkout counters forming the slalom before the finish line.
        Obstacle(rect: CGRect(x: 1000, y: 400, width: 200, height: 160), kind: .checkout),
        Obstacle(rect: CGRect(x: 1400, y: 180, width: 200, height: 140), kind: .checkout),
        Obstacle(rect: CGRect(x: 1800, y: 450, width: 200, height: 160), kind: .checkout),
        // Pallet stacks parked in the corridors.
        Obstacle(rect: CGRect(x: 200, y: 1260, width: 150, height: 150), kind: .pallet),
        Obstacle(rect: CGRect(x: 200, y: 2280, width: 150, height: 150), kind: .pallet),
        Obstacle(rect: CGRect(x: 3920, y: 160, width: 150, height: 150), kind: .pallet),
    ]

    // MARK: - Build

    func build(into world: SKNode) {
        buildFloor(world)
        buildWalls(world)
        buildStartLine(world)
        buildObstacles(world)
        buildDecals(world)

        for position in puddlePositions {
            world.addChild(PuddleNode(position: position))
            let cone = SKSpriteNode(texture: TextureFactory.wetFloorCone)
            cone.setScale(1.6)
            cone.position = position + CGPoint(x: 70, y: 55)
            cone.zPosition = 6
            world.addChild(cone)
        }

        for position in itemBoxPositions {
            world.addChild(ItemBoxNode(position: position))
        }
    }

    private func buildFloor(_ world: SKNode) {
        let tileSize: CGFloat = 256
        let texture = TextureFactory.floorTile
        let columns = Int(ceil(Track.worldSize.width / tileSize))
        let rows = Int(ceil(Track.worldSize.height / tileSize))
        let floor = SKNode()
        floor.zPosition = -100
        for col in 0..<columns {
            for row in 0..<rows {
                let tile = SKSpriteNode(texture: texture)
                tile.size = CGSize(width: tileSize, height: tileSize)
                tile.anchorPoint = .zero
                tile.position = CGPoint(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize)
                floor.addChild(tile)
            }
        }
        world.addChild(floor)
    }

    private func buildWalls(_ world: SKNode) {
        let thickness = Track.wallThickness
        let w = Track.worldSize.width
        let h = Track.worldSize.height
        let wallRects = [
            CGRect(x: 0, y: 0, width: w, height: thickness),
            CGRect(x: 0, y: h - thickness, width: w, height: thickness),
            CGRect(x: 0, y: 0, width: thickness, height: h),
            CGRect(x: w - thickness, y: 0, width: thickness, height: h),
        ]
        for rect in wallRects {
            world.addChild(staticBox(rect: rect,
                                     color: UIColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1),
                                     texture: nil))
        }
    }

    private func buildStartLine(_ world: SKNode) {
        let size = CGSize(width: 60, height: 670)
        let line = SKSpriteNode(texture: TextureFactory.startLine(size: size))
        line.size = size
        line.position = CGPoint(x: 2280, y: 415)
        line.zPosition = -85
        world.addChild(line)
    }

    private func buildObstacles(_ world: SKNode) {
        var seed: UInt64 = 11
        for obstacle in obstacles {
            let rect = obstacle.rect
            let node: SKSpriteNode
            switch obstacle.kind {
            case .shelf(let label):
                seed += 1
                node = staticBox(rect: rect, color: nil,
                                 texture: TextureFactory.shelf(size: rect.size, seed: seed))
                let text = SKLabelNode(fontNamed: "AvenirNext-Bold")
                text.text = label
                text.fontSize = 40
                text.fontColor = UIColor(white: 1, alpha: 0.92)
                text.verticalAlignmentMode = .center
                text.zPosition = 1
                node.addChild(text)
            case .checkout:
                node = staticBox(rect: rect, color: nil,
                                 texture: TextureFactory.checkoutCounter(size: rect.size))
            case .pallet:
                node = staticBox(rect: rect, color: nil,
                                 texture: TextureFactory.palletStack(size: rect.size))
            }
            world.addChild(node)
        }
    }

    private func staticBox(rect: CGRect, color: UIColor?, texture: SKTexture?) -> SKSpriteNode {
        let node: SKSpriteNode
        if let texture = texture {
            node = SKSpriteNode(texture: texture)
            node.size = rect.size
        } else {
            node = SKSpriteNode(color: color ?? .gray, size: rect.size)
        }
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = 18
        let body = SKPhysicsBody(rectangleOf: rect.size)
        body.isDynamic = false
        body.friction = 0.1
        body.restitution = 0.2
        body.categoryBitMask = PhysicsCategory.wall
        node.physicsBody = body
        return node
    }

    private func buildDecals(_ world: SKNode) {
        func decal(_ text: String, at point: CGPoint, size: CGFloat, rotation: CGFloat = 0,
                   color: UIColor = UIColor(white: 0.55, alpha: 0.55)) {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = text
            label.fontSize = size
            label.fontColor = color
            label.verticalAlignmentMode = .center
            label.position = point
            label.zRotation = rotation
            label.zPosition = -90
            world.addChild(label)
        }

        decal("MEGAMART", at: CGPoint(x: 2100, y: 2440), size: 110,
              color: UIColor(red: 0.85, green: 0.35, blue: 0.30, alpha: 0.65))
        decal("OPEN 25 HRS", at: CGPoint(x: 3300, y: 2440), size: 48)
        decal("CHECKOUT", at: CGPoint(x: 1450, y: 640), size: 56)
        decal("CLEAN-UP ON AISLE 3", at: CGPoint(x: 1320, y: 1610), size: 34,
              color: UIColor(red: 0.75, green: 0.60, blue: 0.20, alpha: 0.7))
        decal("DAIRY", at: CGPoint(x: 3990, y: 1350), size: 52, rotation: -.pi / 2)
        decal("PRODUCE", at: CGPoint(x: 210, y: 1750), size: 52, rotation: .pi / 2)
        decal("NO CART RACING", at: CGPoint(x: 2100, y: 640), size: 40,
              color: UIColor(red: 0.80, green: 0.30, blue: 0.30, alpha: 0.55))
        decal("SALE!", at: CGPoint(x: 620, y: 2330), size: 44,
              color: UIColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 0.6))
    }
}
