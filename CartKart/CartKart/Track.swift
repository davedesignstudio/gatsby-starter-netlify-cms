import SpriteKit

/// The supermarket race course.
///
/// The course is a closed loop of centerline waypoints. AI carts follow the
/// waypoints, lap progress is measured against them, and "on track" is simply
/// "close enough to the centerline". All artwork is drawn with SpriteKit
/// primitives so the game ships with zero binary assets.
final class Track {

    /// Ordered centerline of the loop. The last point connects back to the first.
    let centerline: [CGPoint]
    let width: CGFloat

    init() {
        self.width = GameConfig.trackWidth
        // A rounded loop through the store. Clockwise starting near the bottom.
        self.centerline = [
            CGPoint(x: 650,  y: 450),
            CGPoint(x: 1300, y: 360),
            CGPoint(x: 1950, y: 450),
            CGPoint(x: 2220, y: 760),
            CGPoint(x: 2120, y: 1150),
            CGPoint(x: 1780, y: 1400),
            CGPoint(x: 1300, y: 1460),
            CGPoint(x: 820,  y: 1400),
            CGPoint(x: 470,  y: 1150),
            CGPoint(x: 400,  y: 760)
        ]
    }

    var checkpointCount: Int { centerline.count }

    func checkpoint(_ index: Int) -> CGPoint {
        centerline[((index % centerline.count) + centerline.count) % centerline.count]
    }

    // MARK: - Geometry queries

    /// Shortest distance from `p` to the closed centerline polyline.
    func distanceToCenterline(_ p: CGPoint) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        for i in 0..<centerline.count {
            let a = centerline[i]
            let b = centerline[(i + 1) % centerline.count]
            best = min(best, Track.distance(from: p, toSegment: a, b: b))
        }
        return best
    }

    func isOnTrack(_ p: CGPoint) -> Bool {
        distanceToCenterline(p) <= width / 2
    }

    private static func distance(from p: CGPoint, toSegment a: CGPoint, b: CGPoint) -> CGFloat {
        let ab = b - a
        let lengthSq = ab.x * ab.x + ab.y * ab.y
        guard lengthSq > 0 else { return p.distance(to: a) }
        var t = ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSq
        t = clamp(t, 0, 1)
        let projection = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return p.distance(to: projection)
    }

    // MARK: - Starting grid

    struct StartSlot {
        let position: CGPoint
        let heading: CGFloat
    }

    /// A 2x2 grid tucked behind the start/finish line.
    func startingSlots() -> [StartSlot] {
        let start = centerline[0]
        let next = centerline[1]
        let dir = (next - start).normalized
        let heading = atan2(dir.y, dir.x)
        let perp = CGPoint(x: -dir.y, y: dir.x)

        var slots: [StartSlot] = []
        let rowOffsets: [CGFloat] = [-70, -180]
        let colOffsets: [CGFloat] = [-70, 70]
        for row in rowOffsets {
            for col in colOffsets {
                let pos = start + dir * row + perp * col
                slots.append(StartSlot(position: pos, heading: heading))
            }
        }
        return slots
    }

    /// Evenly spaced points along the loop, handy for placing item boxes.
    func itemBoxAnchors() -> [CGPoint] {
        var anchors: [CGPoint] = []
        for i in 0..<centerline.count {
            let a = centerline[i]
            let b = centerline[(i + 1) % centerline.count]
            anchors.append(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
        }
        return anchors
    }

    // MARK: - Rendering

    func buildNode() -> SKNode {
        let root = SKNode()

        // Store floor background.
        let floor = SKSpriteNode(color: SKColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1),
                                 size: GameConfig.worldSize)
        floor.position = CGPoint(x: GameConfig.worldSize.width / 2,
                                 y: GameConfig.worldSize.height / 2)
        floor.zPosition = GameConfig.ZPosition.background
        root.addChild(floor)

        // Checkerboard tiles for a polished-linoleum look.
        addFloorTiles(to: root)

        // The polished aisle (the drivable road).
        let roadPath = CGMutablePath()
        roadPath.addLines(between: centerline)
        roadPath.closeSubpath()

        let roadBorder = SKShapeNode(path: roadPath)
        roadBorder.lineWidth = width + 26
        roadBorder.strokeColor = SKColor(red: 0.95, green: 0.82, blue: 0.30, alpha: 1) // caution stripe
        roadBorder.lineCap = .round
        roadBorder.lineJoin = .round
        roadBorder.fillColor = .clear
        roadBorder.zPosition = GameConfig.ZPosition.track
        root.addChild(roadBorder)

        let road = SKShapeNode(path: roadPath)
        road.lineWidth = width
        road.strokeColor = SKColor(red: 0.62, green: 0.64, blue: 0.70, alpha: 1)
        road.lineCap = .round
        road.lineJoin = .round
        road.fillColor = .clear
        road.zPosition = GameConfig.ZPosition.track + 0.1
        root.addChild(road)

        // Dashed centre guide line.
        let dash = SKShapeNode(path: roadPath)
        dash.lineWidth = 6
        dash.strokeColor = SKColor(white: 1, alpha: 0.35)
        dash.lineCap = .round
        dash.lineJoin = .round
        dash.fillColor = .clear
        dash.zPosition = GameConfig.ZPosition.track + 0.2
        if let dashed = dash.path?.copy(dashingWithPhase: 0, lengths: [26, 34]) {
            dash.path = dashed
        }
        root.addChild(dash)

        addStartFinishLine(to: root)
        addInfieldShelves(to: root)

        return root
    }

    private func addFloorTiles(to root: SKNode) {
        let tile: CGFloat = 130
        let cols = Int(GameConfig.worldSize.width / tile) + 1
        let rows = Int(GameConfig.worldSize.height / tile) + 1
        let tiles = SKNode()
        tiles.zPosition = GameConfig.ZPosition.background + 0.1
        for r in 0..<rows {
            for c in 0..<cols where (r + c) % 2 == 0 {
                let square = SKSpriteNode(color: SKColor(white: 1, alpha: 0.03),
                                          size: CGSize(width: tile, height: tile))
                square.position = CGPoint(x: CGFloat(c) * tile + tile / 2,
                                          y: CGFloat(r) * tile + tile / 2)
                tiles.addChild(square)
            }
        }
        root.addChild(tiles)
    }

    private func addStartFinishLine(to root: SKNode) {
        let start = centerline[0]
        let next = centerline[1]
        let dir = (next - start).normalized
        let perp = CGPoint(x: -dir.y, y: dir.x)

        let line = SKNode()
        line.zPosition = GameConfig.ZPosition.trackDecor
        let squares = 8
        let squareSize = width / CGFloat(squares)
        for i in 0..<squares {
            for j in 0..<2 {
                guard (i + j) % 2 == 0 else { continue }
                let offsetAlong = perp * (CGFloat(i) * squareSize - width / 2 + squareSize / 2)
                let offsetDepth = dir * (CGFloat(j) * squareSize - squareSize / 2)
                let sq = SKSpriteNode(color: .white,
                                      size: CGSize(width: squareSize, height: squareSize))
                sq.position = start + offsetAlong + offsetDepth
                sq.zRotation = atan2(dir.y, dir.x)
                line.addChild(sq)
            }
        }
        root.addChild(line)
    }

    /// Decorative grocery shelves inside the loop (visual only).
    private func addInfieldShelves(to root: SKNode) {
        let center = CGPoint(x: GameConfig.worldSize.width / 2,
                             y: GameConfig.worldSize.height / 2)
        let colors = [
            SKColor(red: 0.85, green: 0.35, blue: 0.35, alpha: 1),
            SKColor(red: 0.35, green: 0.65, blue: 0.85, alpha: 1),
            SKColor(red: 0.45, green: 0.75, blue: 0.45, alpha: 1)
        ]
        let layout: [(dx: CGFloat, dy: CGFloat, w: CGFloat, h: CGFloat)] = [
            (-180, 60, 260, 70),
            (170, -40, 260, 70),
            (-30, 180, 70, 200),
            (10, -190, 70, 200)
        ]
        for (i, item) in layout.enumerated() {
            let shelf = SKSpriteNode(color: colors[i % colors.count],
                                     size: CGSize(width: item.w, height: item.h))
            shelf.position = CGPoint(x: center.x + item.dx, y: center.y + item.dy)
            shelf.zPosition = GameConfig.ZPosition.trackDecor
            shelf.alpha = 0.9
            root.addChild(shelf)

            let label = SKLabelNode(text: "SALE")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 22
            label.fontColor = SKColor(white: 1, alpha: 0.7)
            label.verticalAlignmentMode = .center
            label.position = shelf.position
            label.zPosition = GameConfig.ZPosition.trackDecor + 0.1
            root.addChild(label)
        }
    }
}
