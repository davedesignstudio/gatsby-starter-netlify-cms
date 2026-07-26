import SpriteKit

struct TrackCheckpoint {
    let index: Int
    let position: CGPoint
    let radius: CGFloat
}

final class TrackBuilder {
    static let trackWidth: CGFloat = 180
    static let innerRect = CGRect(x: -200, y: -280, width: 400, height: 560)
    static let outerRect = CGRect(x: -290, y: -370, width: 580, height: 740)

    static func buildTrack(in scene: SKScene) -> SKNode {
        let trackNode = SKNode()
        trackNode.name = "track"

        let floor = SKShapeNode(rect: outerRect, cornerRadius: 40)
        floor.fillColor = SKColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = 0
        trackNode.addChild(floor)

        drawTilePattern(on: floor, rect: outerRect)

        let innerCutout = SKShapeNode(rect: innerRect, cornerRadius: 30)
        innerCutout.fillColor = SKColor(red: 0.55, green: 0.52, blue: 0.48, alpha: 1)
        innerCutout.strokeColor = .clear
        innerCutout.zPosition = 1
        trackNode.addChild(innerCutout)

        addStoreDecorations(to: trackNode)
        addAisles(to: trackNode)
        addShelves(to: trackNode)
        addCheckpoints(to: trackNode)
        addItemBoxes(to: trackNode)
        addBoostPads(to: trackNode)
        addStartLine(to: trackNode)

        scene.addChild(trackNode)
        return trackNode
    }

    static var checkpoints: [TrackCheckpoint] {
        [
            TrackCheckpoint(index: 0, position: CGPoint(x: 0, y: -320), radius: 60),
            TrackCheckpoint(index: 1, position: CGPoint(x: 250, y: -200), radius: 60),
            TrackCheckpoint(index: 2, position: CGPoint(x: 250, y: 100), radius: 60),
            TrackCheckpoint(index: 3, position: CGPoint(x: 0, y: 280), radius: 60),
            TrackCheckpoint(index: 4, position: CGPoint(x: -250, y: 100), radius: 60),
            TrackCheckpoint(index: 5, position: CGPoint(x: -250, y: -200), radius: 60),
        ]
    }

    static var startPositions: [CGPoint] {
        [
            CGPoint(x: -30, y: -310),
            CGPoint(x: 30, y: -310),
            CGPoint(x: -30, y: -340),
            CGPoint(x: 30, y: -340),
        ]
    }

    static var startHeadings: [CGFloat] {
        Array(repeating: 0, count: 4)
    }

    static func isOnTrack(_ point: CGPoint) -> Bool {
        outerRect.contains(point) && !innerRect.contains(point)
    }

    static func trackBounds() -> CGRect {
        CGRect(
            x: outerRect.minX + 30,
            y: outerRect.minY + 30,
            width: outerRect.width - 60,
            height: outerRect.height - 60
        )
    }

    // MARK: - Private

    private static func drawTilePattern(on node: SKShapeNode, rect: CGRect) {
        let tileSize: CGFloat = 40
        let cols = Int(rect.width / tileSize)
        let rows = Int(rect.height / tileSize)
        for row in 0..<rows {
            for col in 0..<cols {
                if (row + col) % 2 == 0 { continue }
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2))
                tile.fillColor = SKColor(white: 0.9, alpha: 0.3)
                tile.strokeColor = .clear
                tile.position = CGPoint(
                    x: rect.minX + CGFloat(col) * tileSize + tileSize / 2,
                    y: rect.minY + CGFloat(row) * tileSize + tileSize / 2
                )
                tile.zPosition = 0.1
                node.addChild(tile)
            }
        }
    }

    private static func addStoreDecorations(to track: SKNode) {
        let sign = SKLabelNode(text: "SUPER SAVE MART")
        sign.fontName = "AvenirNext-Heavy"
        sign.fontSize = 22
        sign.fontColor = SKColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        sign.position = CGPoint(x: 0, y: 0)
        sign.zPosition = 2
        track.addChild(sign)

        let subSign = SKLabelNode(text: "Everyday Low Prices!")
        subSign.fontName = "AvenirNext-Medium"
        subSign.fontSize = 12
        subSign.fontColor = .darkGray
        subSign.position = CGPoint(x: 0, y: -20)
        subSign.zPosition = 2
        track.addChild(subSign)
    }

    private static func addAisles(to track: SKNode) {
        let aisleColors: [SKColor] = [
            SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.15),
            SKColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 0.15),
            SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.15),
        ]
        let labels = ["PRODUCE", "DAIRY", "CEREAL"]
        for (i, label) in labels.enumerated() {
            let aisle = SKShapeNode(rectOf: CGSize(width: 60, height: 120), cornerRadius: 4)
            aisle.fillColor = aisleColors[i]
            aisle.strokeColor = aisleColors[i].withAlphaComponent(0.5)
            aisle.lineWidth = 1
            aisle.position = CGPoint(x: CGFloat(i - 1) * 80, y: 60)
            aisle.zPosition = 1.5
            track.addChild(aisle)

            let text = SKLabelNode(text: label)
            text.fontName = "AvenirNext-Bold"
            text.fontSize = 9
            text.fontColor = .darkGray
            text.verticalAlignmentMode = .center
            text.zPosition = 1.6
            text.position = aisle.position
            track.addChild(text)
        }
    }

    private static func addShelves(to track: SKNode) {
        let shelfPositions: [(CGPoint, CGFloat)] = [
            (CGPoint(x: -270, y: -100), 0),
            (CGPoint(x: 270, y: -100), 0),
            (CGPoint(x: -270, y: 200), 0),
            (CGPoint(x: 270, y: 200), 0),
            (CGPoint(x: 0, y: 350), .pi / 2),
            (CGPoint(x: 0, y: -360), .pi / 2),
        ]

        for (pos, rotation) in shelfPositions {
            let shelf = createShelf()
            shelf.position = pos
            shelf.zRotation = rotation
            shelf.zPosition = 5
            shelf.name = "shelf"
            shelf.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 80))
            shelf.physicsBody?.isDynamic = false
            shelf.physicsBody?.categoryBitMask = PhysicsCategory.wall
            shelf.physicsBody?.collisionBitMask = PhysicsCategory.cart
            track.addChild(shelf)
        }
    }

    private static func createShelf() -> SKNode {
        let shelf = SKNode()
        for i in 0..<4 {
            let row = SKShapeNode(rectOf: CGSize(width: 18, height: 14), cornerRadius: 2)
            row.fillColor = SKColor(red: 0.6, green: 0.45, blue: 0.3, alpha: 1)
            row.strokeColor = .black
            row.lineWidth = 0.5
            row.position = CGPoint(x: 0, y: CGFloat(i) * 18 - 27)

            let product = SKShapeNode(rectOf: CGSize(width: 12, height: 8), cornerRadius: 1)
            product.fillColor = [SKColor.red, .blue, .green, .orange, .purple].randomElement()!
            product.strokeColor = .clear
            product.position = CGPoint(x: CGFloat.random(in: -4...4), y: 3)
            row.addChild(product)
            shelf.addChild(row)
        }
        return shelf
    }

    private static func addCheckpoints(to track: SKNode) {
        for cp in checkpoints {
            let marker = SKShapeNode(circleOfRadius: 4)
            marker.fillColor = SKColor(white: 1, alpha: 0.15)
            marker.strokeColor = .clear
            marker.position = cp.position
            marker.zPosition = 1
            marker.name = "checkpoint_\(cp.index)"
            track.addChild(marker)
        }
    }

    private static func addItemBoxes(to track: SKNode) {
        let positions = [
            CGPoint(x: 200, y: -50),
            CGPoint(x: -200, y: -50),
            CGPoint(x: 200, y: 200),
            CGPoint(x: -200, y: 200),
            CGPoint(x: 0, y: -200),
            CGPoint(x: 0, y: 250),
        ]
        for (i, pos) in positions.enumerated() {
            let box = createItemBox()
            box.position = pos
            box.name = "itemBox_\(i)"
            box.zPosition = 3
            track.addChild(box)
        }
    }

    static func createItemBox() -> SKNode {
        let box = SKShapeNode(rectOf: CGSize(width: 30, height: 30), cornerRadius: 4)
        box.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        box.strokeColor = .orange
        box.lineWidth = 2
        box.name = "itemBox"

        let qLabel = SKLabelNode(text: "?")
        qLabel.fontName = "AvenirNext-Heavy"
        qLabel.fontSize = 18
        qLabel.fontColor = .orange
        qLabel.verticalAlignmentMode = .center
        qLabel.name = "itemBox"
        box.addChild(qLabel)

        let spin = SKAction.repeatForever(.rotate(byAngle: .pi * 2, duration: 3))
        box.run(spin)

        let pulse = SKAction.repeatForever(.sequence([
            .scale(to: 1.1, duration: 0.5),
            .scale(to: 1.0, duration: 0.5),
        ]))
        box.run(pulse)

        return box
    }

    private static func addBoostPads(to track: SKNode) {
        let positions = [
            CGPoint(x: 150, y: -280),
            CGPoint(x: -150, y: 280),
            CGPoint(x: 280, y: 0),
            CGPoint(x: -280, y: 0),
        ]
        for (i, pos) in positions.enumerated() {
            let pad = SKShapeNode(rectOf: CGSize(width: 50, height: 20), cornerRadius: 3)
            pad.fillColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.7)
            pad.strokeColor = .cyan
            pad.lineWidth = 1
            pad.position = pos
            pad.zPosition = 2
            pad.name = "boostPad_\(i)"
            pad.zRotation = i < 2 ? 0 : .pi / 2
            track.addChild(pad)

            let arrow = SKLabelNode(text: "»»")
            arrow.fontSize = 14
            arrow.fontColor = .white
            arrow.verticalAlignmentMode = .center
            pad.addChild(arrow)
        }
    }

    private static func addStartLine(to track: SKNode) {
        let line = SKShapeNode(rectOf: CGSize(width: 80, height: 6))
        line.fillColor = .white
        line.strokeColor = .black
        line.lineWidth = 1
        line.position = CGPoint(x: 0, y: -295)
        line.zPosition = 4

        for i in 0..<8 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 9, height: 6))
            stripe.fillColor = i % 2 == 0 ? .white : .black
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: CGFloat(i - 4) * 10 + 5, y: 0)
            line.addChild(stripe)
        }
        track.addChild(line)
    }
}

struct PhysicsCategory {
    static let cart: UInt32 = 0x1 << 0
    static let wall: UInt32 = 0x1 << 1
    static let item: UInt32 = 0x1 << 2
    static let projectile: UInt32 = 0x1 << 3
}
