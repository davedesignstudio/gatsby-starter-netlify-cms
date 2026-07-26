import SpriteKit

struct Checkpoint {
    let index: Int
    let position: CGPoint
    let radius: CGFloat
}

struct TrackData {
    let trackNode: SKNode
    let walls: [SKNode]
    let pathPoints: [CGPoint]
    let checkpoints: [Checkpoint]
    let itemBoxSpawns: [CGPoint]
    let startPositions: [CGPoint]
    let startRotation: CGFloat
    let worldSize: CGSize
}

enum TrackBuilder {
    /// Builds a supermarket loop: produce → aisle → freezer → checkout → back.
    static func buildMegaMart() -> TrackData {
        let world = CGSize(width: 2200, height: 1600)
        let root = SKNode()
        root.name = "track"

        // Floor
        let floor = SKSpriteNode(color: GameTheme.aisleFloor, size: world)
        floor.position = CGPoint(x: world.width / 2, y: world.height / 2)
        floor.zPosition = -100
        root.addChild(floor)

        // Checker / tile pattern
        let tileSize: CGFloat = 64
        var flip = false
        for x in stride(from: 0, to: world.width, by: tileSize) {
            flip.toggle()
            var rowFlip = flip
            for y in stride(from: 0, to: world.height, by: tileSize) {
                rowFlip.toggle()
                if rowFlip {
                    let tile = SKSpriteNode(color: GameTheme.aisleTile, size: CGSize(width: tileSize, height: tileSize))
                    tile.position = CGPoint(x: x + tileSize / 2, y: y + tileSize / 2)
                    tile.zPosition = -99
                    tile.alpha = 0.55
                    root.addChild(tile)
                }
            }
        }

        // Center island shelves (inner walls of the loop)
        var walls: [SKNode] = []

        func addShelf(rect: CGRect, color: UIColor, label: String? = nil) {
            let node = SKShapeNode(rectOf: rect.size, cornerRadius: 4)
            node.fillColor = color
            node.strokeColor = color.darker(by: 0.2)
            node.lineWidth = 2
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            node.zPosition = 5

            let body = SKPhysicsBody(rectangleOf: rect.size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            body.friction = 0.3
            node.physicsBody = body
            root.addChild(node)
            walls.append(node)

            // Shelf face stripe
            let stripe = SKShapeNode(rectOf: CGSize(width: rect.width - 8, height: 8), cornerRadius: 2)
            stripe.fillColor = UIColor(white: 1, alpha: 0.15)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: 0, y: rect.height / 2 - 12)
            node.addChild(stripe)

            if let label {
                let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
                t.text = label
                t.fontSize = 14
                t.fontColor = UIColor(white: 1, alpha: 0.55)
                t.verticalAlignmentMode = .center
                t.horizontalAlignmentMode = .center
                t.zRotation = rect.width > rect.height ? 0 : -.pi / 2
                node.addChild(t)
            }
        }

        // Outer boundary walls
        let margin: CGFloat = 40
        let outerRects = [
            CGRect(x: 0, y: 0, width: world.width, height: margin),
            CGRect(x: 0, y: world.height - margin, width: world.width, height: margin),
            CGRect(x: 0, y: 0, width: margin, height: world.height),
            CGRect(x: world.width - margin, y: 0, width: margin, height: world.height)
        ]
        for r in outerRects {
            addShelf(rect: r, color: GameTheme.shelfBrown)
        }

        // Inner supermarket shelves forming a racing loop
        // Center block
        addShelf(rect: CGRect(x: 520, y: 420, width: 1160, height: 160), color: GameTheme.shelfFace, label: "CEREAL")
        addShelf(rect: CGRect(x: 520, y: 1020, width: 1160, height: 160), color: GameTheme.produceGreen, label: "PRODUCE")
        addShelf(rect: CGRect(x: 520, y: 620, width: 180, height: 360), color: GameTheme.freezerBlue, label: "FROZEN")
        addShelf(rect: CGRect(x: 1500, y: 620, width: 180, height: 360), color: GameTheme.shelfFace, label: "SNACKS")

        // Extra endcaps / obstacles
        addShelf(rect: CGRect(x: 900, y: 720, width: 120, height: 120), color: GameTheme.accentOrange, label: "SALE")
        addShelf(rect: CGRect(x: 1180, y: 720, width: 120, height: 120), color: GameTheme.checkoutYellow.darker(by: 0.15), label: "DEAL")

        // Corner displays
        addShelf(rect: CGRect(x: 180, y: 180, width: 140, height: 100), color: GameTheme.produceGreen, label: "FRUIT")
        addShelf(rect: CGRect(x: 1880, y: 180, width: 140, height: 100), color: GameTheme.freezerBlue, label: "ICE")
        addShelf(rect: CGRect(x: 180, y: 1320, width: 140, height: 100), color: GameTheme.shelfFace, label: "SOAP")
        addShelf(rect: CGRect(x: 1880, y: 1320, width: 140, height: 100), color: GameTheme.accentOrange, label: "TOYS")

        // Yellow checkout strip (visual finish line area)
        let checkout = SKShapeNode(rectOf: CGSize(width: 200, height: 16), cornerRadius: 2)
        checkout.fillColor = GameTheme.checkoutYellow
        checkout.strokeColor = .clear
        checkout.position = CGPoint(x: 300, y: 300)
        checkout.zPosition = -50
        root.addChild(checkout)
        let finishLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        finishLabel.text = "CHECKOUT →"
        finishLabel.fontSize = 16
        finishLabel.fontColor = GameTheme.ink
        finishLabel.position = CGPoint(x: 300, y: 320)
        finishLabel.zPosition = -49
        root.addChild(finishLabel)

        // Racing line waypoints (clockwise loop starting near checkout / bottom-left)
        let path: [CGPoint] = [
            CGPoint(x: 300, y: 280),
            CGPoint(x: 700, y: 220),
            CGPoint(x: 1100, y: 220),
            CGPoint(x: 1500, y: 220),
            CGPoint(x: 1900, y: 280),
            CGPoint(x: 1980, y: 500),
            CGPoint(x: 1980, y: 800),
            CGPoint(x: 1980, y: 1100),
            CGPoint(x: 1900, y: 1350),
            CGPoint(x: 1500, y: 1420),
            CGPoint(x: 1100, y: 1420),
            CGPoint(x: 700, y: 1420),
            CGPoint(x: 300, y: 1350),
            CGPoint(x: 220, y: 1100),
            CGPoint(x: 220, y: 800),
            CGPoint(x: 220, y: 500),
            CGPoint(x: 300, y: 280)
        ]

        var checkpoints: [Checkpoint] = []
        for (i, p) in path.enumerated() {
            checkpoints.append(Checkpoint(index: i, position: p, radius: 90))
            let marker = SKShapeNode(circleOfRadius: 6)
            marker.fillColor = UIColor(white: 1, alpha: 0.08)
            marker.strokeColor = .clear
            marker.position = p
            marker.zPosition = -80
            root.addChild(marker)
        }

        let itemSpawns: [CGPoint] = [
            CGPoint(x: 900, y: 300),
            CGPoint(x: 1600, y: 300),
            CGPoint(x: 1900, y: 800),
            CGPoint(x: 1600, y: 1300),
            CGPoint(x: 900, y: 1300),
            CGPoint(x: 320, y: 800),
            CGPoint(x: 1100, y: 560),
            CGPoint(x: 1100, y: 980)
        ]

        // Grid start positions behind start line
        let starts: [CGPoint] = [
            CGPoint(x: 280, y: 360),
            CGPoint(x: 340, y: 420),
            CGPoint(x: 280, y: 480),
            CGPoint(x: 340, y: 540)
        ]

        // Decorative aisle signs
        for (text, pos) in [("AISLE 1", CGPoint(x: 700, y: 800)), ("AISLE 4", CGPoint(x: 1400, y: 800))] {
            let sign = SKLabelNode(fontNamed: "AvenirNext-Bold")
            sign.text = text
            sign.fontSize = 22
            sign.fontColor = UIColor(white: 0.2, alpha: 0.12)
            sign.position = pos
            sign.zPosition = -90
            root.addChild(sign)
        }

        return TrackData(
            trackNode: root,
            walls: walls,
            pathPoints: path,
            checkpoints: checkpoints,
            itemBoxSpawns: itemSpawns,
            startPositions: starts,
            startRotation: .pi / 2, // facing +X along bottom aisle
            worldSize: world
        )
    }
}
