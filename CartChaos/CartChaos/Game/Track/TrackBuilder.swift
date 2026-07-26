import SpriteKit

struct TrackWaypoint {
    let position: CGPoint
    let width: CGFloat
}

final class TrackBuilder {
    static let tileSize: CGFloat = 64

    /// Store-shaped oval track with aisle corners and checkout straight.
    static func waypoints(for size: CGSize) -> [TrackWaypoint] {
        let cx = size.width / 2
        let cy = size.height / 2
        let rx = size.width * 0.34
        let ry = size.height * 0.30
        let trackWidth: CGFloat = 110

        let points: [CGPoint] = [
            CGPoint(x: cx, y: cy + ry),           // top checkout lane
            CGPoint(x: cx + rx * 0.55, y: cy + ry * 0.75),
            CGPoint(x: cx + rx, y: cy),           // right frozen aisle
            CGPoint(x: cx + rx * 0.55, y: cy - ry * 0.75),
            CGPoint(x: cx, y: cy - ry),           // bottom produce
            CGPoint(x: cx - rx * 0.55, y: cy - ry * 0.75),
            CGPoint(x: cx - rx, y: cy),           // left dairy aisle
            CGPoint(x: cx - rx * 0.55, y: cy + ry * 0.75)
        ]

        return points.map { TrackWaypoint(position: $0, width: trackWidth) }
    }

    static func build(in scene: SKScene, size: CGSize) -> SKNode {
        let trackNode = SKNode()
        trackNode.name = "track"
        trackNode.zPosition = -10

        addFloorTiles(to: trackNode, size: size)
        addAisles(to: trackNode, size: size)
        addTrackSurface(to: trackNode, size: size)
        addCheckoutDecor(to: trackNode, size: size)
        addStartLine(to: trackNode, size: size)

        scene.addChild(trackNode)
        return trackNode
    }

    private static func addFloorTiles(to parent: SKNode, size: CGSize) {
        let cols = Int(ceil(size.width / tileSize))
        let rows = Int(ceil(size.height / tileSize))

        for row in 0..<rows {
            for col in 0..<cols {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2))
                tile.position = CGPoint(
                    x: CGFloat(col) * tileSize + tileSize / 2,
                    y: CGFloat(row) * tileSize + tileSize / 2
                )
                let checker = (row + col) % 2 == 0
                tile.fillColor = checker
                    ? SKColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1)
                    : SKColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1)
                tile.strokeColor = .clear
                tile.zPosition = -20
                parent.addChild(tile)
            }
        }
    }

    private static func addAisles(to parent: SKNode, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2

        let shelfSpecs: [(CGPoint, CGSize)] = [
            (CGPoint(x: cx - 120, y: cy + 180), CGSize(width: 50, height: 140)),
            (CGPoint(x: cx + 120, y: cy + 180), CGSize(width: 50, height: 140)),
            (CGPoint(x: cx - 120, y: cy - 180), CGSize(width: 50, height: 140)),
            (CGPoint(x: cx + 120, y: cy - 180), CGSize(width: 50, height: 140)),
            (CGPoint(x: cx, y: cy + 260), CGSize(width: 200, height: 40)),
            (CGPoint(x: cx, y: cy - 260), CGSize(width: 200, height: 40))
        ]

        for (pos, shelfSize) in shelfSpecs {
            let shelf = SKShapeNode(rectOf: shelfSize, cornerRadius: 4)
            shelf.position = pos
            shelf.fillColor = SKColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)
            shelf.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 1)
            shelf.lineWidth = 2
            shelf.zPosition = -5
            parent.addChild(shelf)

            addShelfProducts(on: shelf, size: shelfSize)
        }
    }

    private static func addShelfProducts(on shelf: SKShapeNode, size: CGSize) {
        let colors: [SKColor] = [
            SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
            SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1),
            SKColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),
            SKColor(red: 0.95, green: 0.8, blue: 0.1, alpha: 1)
        ]

        let rows = max(2, Int(size.height / 28))
        let cols = max(2, Int(size.width / 22))

        for r in 0..<rows {
            for c in 0..<cols {
                let box = SKShapeNode(rectOf: CGSize(width: 14, height: 18), cornerRadius: 2)
                box.position = CGPoint(
                    x: -size.width / 2 + 14 + CGFloat(c) * (size.width - 28) / CGFloat(max(cols - 1, 1)),
                    y: -size.height / 2 + 16 + CGFloat(r) * (size.height - 32) / CGFloat(max(rows - 1, 1))
                )
                box.fillColor = colors[(r + c) % colors.count]
                box.strokeColor = .clear
                box.zPosition = 1
                shelf.addChild(box)
            }
        }
    }

    private static func addTrackSurface(to parent: SKNode, size: CGSize) {
        let wps = waypoints(for: size)
        guard wps.count >= 2 else { return }

        for i in 0..<wps.count {
            let current = wps[i]
            let next = wps[(i + 1) % wps.count]

            let segment = SKShapeNode(rectOf: CGSize(
                width: distance(from: current.position, to: next.position),
                height: current.width
            ))
            segment.position = midpoint(current.position, next.position)
            segment.zRotation = atan2(
                next.position.y - current.position.y,
                next.position.x - current.position.x
            )
            segment.fillColor = SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
            segment.strokeColor = SKColor(white: 0.35, alpha: 1)
            segment.lineWidth = 3
            segment.zPosition = -8
            parent.addChild(segment)

            addLaneMarkings(on: segment)
        }

        for wp in wps {
            let corner = SKShapeNode(circleOfRadius: wp.width / 2)
            corner.position = wp.position
            corner.fillColor = SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
            corner.strokeColor = SKColor(white: 0.35, alpha: 1)
            corner.lineWidth = 3
            corner.zPosition = -8
            parent.addChild(corner)
        }
    }

    private static func addLaneMarkings(on segment: SKShapeNode) {
        let dash = SKShapeNode(rectOf: CGSize(width: 18, height: 4), cornerRadius: 1)
        dash.fillColor = SKColor(white: 0.95, alpha: 0.7)
        dash.strokeColor = .clear
        dash.zPosition = 1
        segment.addChild(dash)
    }

    private static func addCheckoutDecor(to parent: SKNode, size: CGSize) {
        let cx = size.width / 2
        let topY = size.height / 2 + size.height * 0.30

        let sign = SKLabelNode(fontNamed: "AvenirNext-Bold")
        sign.text = "CHECKOUT"
        sign.fontSize = 18
        sign.fontColor = SKColor(red: 0.15, green: 0.45, blue: 0.2, alpha: 1)
        sign.position = CGPoint(x: cx, y: topY + 30)
        sign.zPosition = 5
        parent.addChild(sign)

        for offset in [-80.0, 0.0, 80.0] {
            let lane = SKShapeNode(rectOf: CGSize(width: 60, height: 12), cornerRadius: 2)
            lane.position = CGPoint(x: cx + offset, y: topY + 10)
            lane.fillColor = SKColor(red: 0.2, green: 0.65, blue: 0.3, alpha: 1)
            lane.strokeColor = .clear
            lane.zPosition = 4
            parent.addChild(lane)
        }
    }

    private static func addStartLine(to parent: SKNode, size: CGSize) {
        let cx = size.width / 2
        let startY = size.height / 2 + size.height * 0.30 - 40

        let line = SKShapeNode(rectOf: CGSize(width: 100, height: 8))
        line.position = CGPoint(x: cx, y: startY)
        line.fillColor = .white
        line.strokeColor = .black
        line.lineWidth = 1
        line.zPosition = 3
        parent.addChild(line)

        for i in 0..<5 {
            let checker = SKShapeNode(rectOf: CGSize(width: 10, height: 8))
            checker.position = CGPoint(x: -40 + CGFloat(i) * 20, y: 0)
            checker.fillColor = i % 2 == 0 ? .black : .white
            checker.strokeColor = .clear
            line.addChild(checker)
        }
    }

    static func startPosition(for size: CGSize, lane: Int) -> (position: CGPoint, angle: CGFloat) {
        let cx = size.width / 2
        let startY = size.height / 2 + size.height * 0.30 - 55
        let laneOffset = CGFloat(lane - 1) * 28
        return (CGPoint(x: cx + laneOffset, y: startY), -.pi / 2)
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
