import SpriteKit
import UIKit

final class StoreTrack {
    let size: CGSize
    private(set) var walls: [SKNode] = []
    private(set) var checkpoints: [SKNode] = []
    private(set) var itemBoxSpawns: [CGPoint] = []
    private(set) var startPositions: [CGPoint] = []
    private(set) var startHeading: CGFloat = -.pi / 2

    init(size: CGSize) {
        self.size = size
    }

    @discardableResult
    func build(into parent: SKNode) -> SKNode {
        let world = SKNode()
        world.name = "world"
        parent.addChild(world)

        // Floor
        let floor = SKShapeNode(rectOf: size)
        floor.fillColor = UIColor(red: 0.78, green: 0.74, blue: 0.68, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -100
        world.addChild(floor)

        // Tile pattern
        let tileSize: CGFloat = 64
        var x: CGFloat = -size.width / 2
        var col = 0
        while x < size.width / 2 {
            var y: CGFloat = -size.height / 2
            var row = 0
            while y < size.height / 2 {
                if (row + col) % 2 == 0 {
                    let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                    tile.fillColor = UIColor(red: 0.74, green: 0.70, blue: 0.64, alpha: 1)
                    tile.strokeColor = .clear
                    tile.position = CGPoint(x: x + tileSize / 2, y: y + tileSize / 2)
                    tile.zPosition = -99
                    world.addChild(tile)
                }
                y += tileSize
                row += 1
            }
            x += tileSize
            col += 1
        }

        // Outer walls
        let margin: CGFloat = 40
        let trackOuter = CGRect(
            x: -size.width / 2 + margin,
            y: -size.height / 2 + margin,
            width: size.width - margin * 2,
            height: size.height - margin * 2
        )
        addWallRect(trackOuter.insetBy(dx: -20, dy: -20), hole: trackOuter, into: world)

        // Aisle shelves — create a looping supermarket circuit
        let shelfColor = UIColor(red: 0.55, green: 0.42, blue: 0.32, alpha: 1)
        let shelfAccent = UIColor(red: 0.35, green: 0.55, blue: 0.40, alpha: 1)

        // Center island shelves
        addShelf(CGRect(x: -180, y: -80, width: 120, height: 280), color: shelfColor, label: "CEREAL", into: world)
        addShelf(CGRect(x: 60, y: -80, width: 120, height: 280), color: shelfColor, label: "SOUP", into: world)

        // Side aisles
        addShelf(CGRect(x: -520, y: 160, width: 200, height: 70), color: shelfAccent, label: "PRODUCE", into: world)
        addShelf(CGRect(x: 320, y: 160, width: 200, height: 70), color: shelfAccent, label: "DAIRY", into: world)
        addShelf(CGRect(x: -520, y: -230, width: 200, height: 70), color: UIColor(red: 0.40, green: 0.50, blue: 0.65, alpha: 1), label: "FROZEN", into: world)
        addShelf(CGRect(x: 320, y: -230, width: 200, height: 70), color: UIColor(red: 0.65, green: 0.40, blue: 0.35, alpha: 1), label: "SNACKS", into: world)

        // Checkout counters near start/finish (flanking the grid so carts aren't blocked)
        addShelf(CGRect(x: -300, y: -420, width: 100, height: 50), color: UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 1), label: "CHECKOUT", into: world)
        addShelf(CGRect(x: 200, y: -420, width: 100, height: 50), color: UIColor(red: 0.30, green: 0.32, blue: 0.38, alpha: 1), label: "CHECKOUT", into: world)

        // Decorative aisle stripes
        addAisleStripe(from: CGPoint(x: -280, y: -350), to: CGPoint(x: -280, y: 350), into: world)
        addAisleStripe(from: CGPoint(x: 280, y: -350), to: CGPoint(x: 280, y: 350), into: world)
        addAisleStripe(from: CGPoint(x: -450, y: 40), to: CGPoint(x: 450, y: 40), into: world)

        // Checkpoints around the loop (clockwise from bottom)
        let cps: [CGPoint] = [
            CGPoint(x: 0, y: -380),     // 0 start/finish
            CGPoint(x: 400, y: -300),
            CGPoint(x: 480, y: 0),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 0, y: 380),
            CGPoint(x: -400, y: 300),
            CGPoint(x: -480, y: 0),
            CGPoint(x: -400, y: -300)
        ]
        for (i, p) in cps.enumerated() {
            let node = SKNode()
            node.name = "checkpoint_\(i)"
            node.position = p
            node.zPosition = -50
            let body = SKPhysicsBody(circleOfRadius: 70)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.checkpoint
            body.contactTestBitMask = PhysicsCategory.cart
            body.collisionBitMask = 0
            node.physicsBody = body
            world.addChild(node)
            checkpoints.append(node)

            if i == 0 {
                let line = SKShapeNode(rectOf: CGSize(width: 140, height: 10))
                line.fillColor = UIColor(white: 1, alpha: 0.85)
                line.strokeColor = UIColor(white: 0.1, alpha: 1)
                line.lineWidth = 1
                // checker pattern
                for c in 0..<7 {
                    let sq = SKShapeNode(rectOf: CGSize(width: 20, height: 10))
                    sq.fillColor = c % 2 == 0 ? .white : .black
                    sq.strokeColor = .clear
                    sq.position = CGPoint(x: -60 + CGFloat(c) * 20, y: 0)
                    line.addChild(sq)
                }
                line.position = p
                line.zPosition = -40
                world.addChild(line)
            }
        }

        // Item box locations
        itemBoxSpawns = [
            CGPoint(x: 0, y: 200),
            CGPoint(x: 350, y: 0),
            CGPoint(x: 0, y: -200),
            CGPoint(x: -350, y: 0),
            CGPoint(x: 200, y: 320),
            CGPoint(x: -200, y: -320)
        ]

        // Grid start positions just south of the finish line (facing +Y)
        startHeading = .pi / 2
        startPositions = [
            CGPoint(x: -50, y: -440),
            CGPoint(x: 50, y: -470),
            CGPoint(x: -50, y: -410),
            CGPoint(x: 50, y: -455)
        ]

        // Store signage
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = "MEGA MART AISLE CIRCUIT"
        banner.fontSize = 22
        banner.fontColor = UIColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 0.35)
        banner.position = CGPoint(x: 0, y: 0)
        banner.zPosition = -80
        world.addChild(banner)

        return world
    }

    private func addShelf(_ rect: CGRect, color: UIColor, label: String, into world: SKNode) {
        let shelf = SKShapeNode(rectOf: rect.size, cornerRadius: 4)
        shelf.fillColor = color
        shelf.strokeColor = UIColor(white: 0.15, alpha: 1)
        shelf.lineWidth = 2
        shelf.position = CGPoint(x: rect.midX, y: rect.midY)
        shelf.zPosition = 5

        let body = SKPhysicsBody(rectangleOf: rect.size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.friction = 0.2
        body.restitution = 0.1
        shelf.physicsBody = body

        let tag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tag.text = label
        tag.fontSize = 10
        tag.fontColor = UIColor(white: 1, alpha: 0.7)
        tag.verticalAlignmentMode = .center
        shelf.addChild(tag)

        // Product dots
        for _ in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            dot.fillColor = [
                UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1),
                UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1),
                UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1),
                UIColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 1)
            ].randomElement()!
            dot.strokeColor = .clear
            let hw = rect.width / 2 - 10
            let hh = rect.height / 2 - 10
            dot.position = CGPoint(x: CGFloat.random(in: -hw...hw), y: CGFloat.random(in: -hh...hh))
            shelf.addChild(dot)
        }

        world.addChild(shelf)
        walls.append(shelf)
    }

    private func addWallRect(_ outer: CGRect, hole: CGRect, into world: SKNode) {
        // Four border walls around the playable hole
        let thickness: CGFloat = 80
        let segments: [CGRect] = [
            CGRect(x: outer.minX, y: outer.maxY - thickness, width: outer.width, height: thickness), // top
            CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: thickness), // bottom
            CGRect(x: outer.minX, y: outer.minY, width: thickness, height: outer.height), // left
            CGRect(x: outer.maxX - thickness, y: outer.minY, width: thickness, height: outer.height) // right
        ]
        for seg in segments {
            let wall = SKShapeNode(rectOf: seg.size)
            wall.fillColor = UIColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1)
            wall.strokeColor = UIColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1)
            wall.lineWidth = 3
            wall.position = CGPoint(x: seg.midX, y: seg.midY)
            wall.zPosition = 8
            let body = SKPhysicsBody(rectangleOf: seg.size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody = body
            world.addChild(wall)
            walls.append(wall)
        }

        // Soft barrier just inside for bounce feel — skip, shelves handle interior
        _ = hole
    }

    private func addAisleStripe(from: CGPoint, to: CGPoint, into world: SKNode) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let line = SKShapeNode(path: path)
        line.strokeColor = UIColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 0.35)
        line.lineWidth = 4
        line.lineCap = .round
        line.zPosition = -90
        world.addChild(line)
    }
}
