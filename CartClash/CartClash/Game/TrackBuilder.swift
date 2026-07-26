import SpriteKit
import UIKit

struct TrackData {
    let size: CGSize
    let startPositions: [CGPoint]
    let startRotation: CGFloat
    let checkpoints: [CGPoint]
    let walls: [CGRect]
    let shelves: [CGRect]
    let itemPads: [CGPoint]
    let floorColor: UIColor
    let aisleColor: UIColor
}

enum TrackBuilder {
    static func megaMart() -> TrackData {
        let w: CGFloat = 2200
        let h: CGFloat = 1600
        let margin: CGFloat = 80

        // Outer walls
        var walls: [CGRect] = [
            CGRect(x: 0, y: 0, width: w, height: margin),
            CGRect(x: 0, y: h - margin, width: w, height: margin),
            CGRect(x: 0, y: 0, width: margin, height: h),
            CGRect(x: w - margin, y: 0, width: margin, height: h)
        ]

        // Aisle shelves (inner obstacles creating a looping course)
        let shelves: [CGRect] = [
            // Left block of aisles
            CGRect(x: 280, y: 280, width: 70, height: 420),
            CGRect(x: 280, y: 900, width: 70, height: 420),
            CGRect(x: 480, y: 280, width: 70, height: 420),
            CGRect(x: 480, y: 900, width: 70, height: 420),
            // Center island
            CGRect(x: 780, y: 500, width: 640, height: 120),
            CGRect(x: 780, y: 980, width: 640, height: 120),
            CGRect(x: 980, y: 620, width: 120, height: 360),
            // Right aisles
            CGRect(x: 1650, y: 280, width: 70, height: 420),
            CGRect(x: 1650, y: 900, width: 70, height: 420),
            CGRect(x: 1850, y: 280, width: 70, height: 420),
            CGRect(x: 1850, y: 900, width: 70, height: 420),
            // Checkout counters near start
            CGRect(x: 700, y: 160, width: 180, height: 50),
            CGRect(x: 960, y: 160, width: 180, height: 50),
            CGRect(x: 1220, y: 160, width: 180, height: 50)
        ]
        walls.append(contentsOf: shelves)

        // Checkpoint ring around the store (clockwise from bottom start)
        let checkpoints: [CGPoint] = [
            CGPoint(x: 1100, y: 220),  // start / finish
            CGPoint(x: 1900, y: 220),
            CGPoint(x: 2000, y: 500),
            CGPoint(x: 2000, y: 1100),
            CGPoint(x: 1900, y: 1400),
            CGPoint(x: 1100, y: 1450),
            CGPoint(x: 300, y: 1400),
            CGPoint(x: 180, y: 1100),
            CGPoint(x: 180, y: 500),
            CGPoint(x: 300, y: 220),
            CGPoint(x: 700, y: 220)
        ]

        let itemPads: [CGPoint] = [
            CGPoint(x: 600, y: 400),
            CGPoint(x: 1500, y: 400),
            CGPoint(x: 1100, y: 750),
            CGPoint(x: 600, y: 1200),
            CGPoint(x: 1500, y: 1200),
            CGPoint(x: 200, y: 800),
            CGPoint(x: 2000, y: 800),
            CGPoint(x: 1100, y: 1350)
        ]

        let startPositions: [CGPoint] = [
            CGPoint(x: 1040, y: 260),
            CGPoint(x: 1120, y: 260),
            CGPoint(x: 1040, y: 320),
            CGPoint(x: 1120, y: 320)
        ]

        return TrackData(
            size: CGSize(width: w, height: h),
            startPositions: startPositions,
            startRotation: 0, // facing up initially; course goes right then around — actually start faces east-ish
            checkpoints: checkpoints,
            walls: walls,
            shelves: shelves,
            itemPads: itemPads,
            floorColor: UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1),
            aisleColor: UIColor(red: 0.86, green: 0.84, blue: 0.78, alpha: 1)
        )
    }

    static func buildWorld(in scene: SKNode, track: TrackData) -> SKNode {
        let world = SKNode()
        world.name = "world"
        scene.addChild(world)

        let floor = SKShapeNode(rectOf: track.size)
        floor.fillColor = track.floorColor
        floor.strokeColor = .clear
        floor.position = CGPoint(x: track.size.width / 2, y: track.size.height / 2)
        floor.zPosition = 0
        world.addChild(floor)

        // Tile pattern
        let tile: CGFloat = 80
        var x: CGFloat = 0
        while x < track.size.width {
            var y: CGFloat = 0
            while y < track.size.height {
                if Int((x + y) / tile) % 2 == 0 {
                    let t = SKShapeNode(rect: CGRect(x: x, y: y, width: tile, height: tile))
                    t.fillColor = UIColor(white: 1, alpha: 0.04)
                    t.strokeColor = .clear
                    t.zPosition = 0.5
                    world.addChild(t)
                }
                y += tile
            }
            x += tile
        }

        // Lane paint near start
        let finish = SKShapeNode(rectOf: CGSize(width: 160, height: 18))
        finish.fillColor = UIColor(white: 0.1, alpha: 0.85)
        finish.strokeColor = .white
        finish.lineWidth = 2
        finish.position = track.checkpoints[0]
        finish.zPosition = 2
        world.addChild(finish)

        let finishLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        finishLabel.text = "CHECKOUT"
        finishLabel.fontSize = 14
        finishLabel.fontColor = .white
        finishLabel.verticalAlignmentMode = .center
        finishLabel.position = CGPoint(x: track.checkpoints[0].x, y: track.checkpoints[0].y + 28)
        finishLabel.zPosition = 3
        world.addChild(finishLabel)

        // Shelves as colorful grocery units
        let shelfColors: [UIColor] = [
            UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1),
            UIColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1),
            UIColor(red: 0.25, green: 0.70, blue: 0.35, alpha: 1),
            UIColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1),
            UIColor(red: 0.55, green: 0.35, blue: 0.75, alpha: 1)
        ]

        for (idx, rect) in track.shelves.enumerated() {
            let shelf = SKShapeNode(rectOf: rect.size, cornerRadius: 4)
            shelf.fillColor = shelfColors[idx % shelfColors.count]
            shelf.strokeColor = UIColor(white: 0.15, alpha: 1)
            shelf.lineWidth = 2
            shelf.position = CGPoint(x: rect.midX, y: rect.midY)
            shelf.zPosition = 5
            world.addChild(shelf)

            // Product dots
            let cols = max(1, Int(rect.width / 22))
            let rows = max(1, Int(rect.height / 22))
            for r in 0..<rows {
                for c in 0..<cols {
                    let dot = SKShapeNode(circleOfRadius: 3)
                    dot.fillColor = UIColor(white: 1, alpha: 0.35)
                    dot.strokeColor = .clear
                    let ox = -rect.width / 2 + 12 + CGFloat(c) * (rect.width - 16) / CGFloat(max(cols - 1, 1))
                    let oy = -rect.height / 2 + 12 + CGFloat(r) * (rect.height - 16) / CGFloat(max(rows - 1, 1))
                    dot.position = CGPoint(x: rect.midX + ox, y: rect.midY + oy)
                    dot.zPosition = 6
                    world.addChild(dot)
                }
            }
        }

        // Physics walls
        for rect in track.walls {
            let wall = SKNode()
            wall.position = CGPoint(x: rect.midX, y: rect.midY)
            wall.physicsBody = SKPhysicsBody(rectangleOf: rect.size)
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody?.friction = 0.3
            wall.physicsBody?.restitution = 0.05
            world.addChild(wall)

            // Visual for outer walls only (not shelves, already drawn)
            if !track.shelves.contains(where: { $0.equalTo(rect) }) {
                let vis = SKShapeNode(rectOf: rect.size)
                vis.fillColor = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
                vis.strokeColor = UIColor(white: 0.2, alpha: 1)
                vis.lineWidth = 1
                vis.zPosition = 4
                wall.addChild(vis)
            }
        }

        // Checkpoint sensors
        for (i, point) in track.checkpoints.enumerated() {
            let cp = SKNode()
            cp.name = "checkpoint-\(i)"
            cp.position = point
            cp.physicsBody = SKPhysicsBody(circleOfRadius: 55)
            cp.physicsBody?.isDynamic = false
            cp.physicsBody?.categoryBitMask = PhysicsCategory.checkpoint
            cp.physicsBody?.collisionBitMask = 0
            cp.physicsBody?.contactTestBitMask = PhysicsCategory.cart
            world.addChild(cp)

            if i > 0 {
                let marker = SKShapeNode(circleOfRadius: 8)
                marker.fillColor = UIColor(white: 1, alpha: 0.25)
                marker.strokeColor = UIColor(white: 1, alpha: 0.5)
                marker.zPosition = 2
                cp.addChild(marker)
            }
        }

        // Decor signs
        addSign(to: world, text: "PRODUCE", at: CGPoint(x: 380, y: 1500), color: UIColor(red: 0.3, green: 0.7, blue: 0.35, alpha: 1))
        addSign(to: world, text: "CANNED GOODS", at: CGPoint(x: 1100, y: 1500), color: UIColor(red: 0.85, green: 0.4, blue: 0.2, alpha: 1))
        addSign(to: world, text: "DAIRY", at: CGPoint(x: 1800, y: 1500), color: UIColor(red: 0.3, green: 0.55, blue: 0.9, alpha: 1))
        addSign(to: world, text: "MEGA MART", at: CGPoint(x: 1100, y: 80), color: UIColor(red: 0.9, green: 0.2, blue: 0.25, alpha: 1))

        return world
    }

    private static func addSign(to world: SKNode, text: String, at point: CGPoint, color: UIColor) {
        let bg = SKShapeNode(rectOf: CGSize(width: CGFloat(text.count) * 11 + 24, height: 28), cornerRadius: 4)
        bg.fillColor = color
        bg.strokeColor = UIColor(white: 0.1, alpha: 1)
        bg.lineWidth = 1.5
        bg.position = point
        bg.zPosition = 7
        world.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = 8
        world.addChild(label)
    }
}

private extension CGRect {
    func equalTo(_ other: CGRect) -> Bool {
        abs(origin.x - other.origin.x) < 0.5 &&
        abs(origin.y - other.origin.y) < 0.5 &&
        abs(size.width - other.size.width) < 0.5 &&
        abs(size.height - other.size.height) < 0.5
    }
}
