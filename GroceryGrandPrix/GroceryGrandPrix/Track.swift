import SpriteKit

/// Builds the supermarket race track: a rounded-rectangle "aisle" loop with an
/// island of shelves in the middle, bounded by walls, plus waypoints used for
/// AI navigation and lap tracking.
struct Track {
    let worldSize: CGSize
    let outerRect: CGRect
    let centerRect: CGRect
    let innerRect: CGRect
    let outerRadius: CGFloat
    let centerRadius: CGFloat
    let innerRadius: CGFloat
    let roadWidth: CGFloat
    let waypoints: [CGPoint]

    init(worldSize: CGSize) {
        self.worldSize = worldSize
        let margin: CGFloat = 150
        let road: CGFloat = 300
        self.roadWidth = road
        self.outerRect = CGRect(x: margin, y: margin,
                                width: worldSize.width - margin * 2,
                                height: worldSize.height - margin * 2)
        self.centerRect = outerRect.insetBy(dx: road / 2, dy: road / 2)
        self.innerRect = outerRect.insetBy(dx: road, dy: road)
        self.outerRadius = 340
        self.centerRadius = 340 - road / 2
        self.innerRadius = max(40, 340 - road)

        // Build a uniform waypoint loop along the centreline, then rotate it so
        // that index 0 sits at the middle of the bottom straight (the start line).
        let raw = Track.loopPoints(rect: centerRect, radius: centerRadius, arcSteps: 10)
        var wp = Track.resample(raw, count: 72)
        let startTarget = CGPoint(x: centerRect.midX, y: centerRect.minY)
        if let startIdx = wp.indices.min(by: { wp[$0].distance(to: startTarget) < wp[$1].distance(to: startTarget) }) {
            wp = Array(wp[startIdx...] + wp[..<startIdx])
        }
        self.waypoints = wp
    }

    var startPosition: CGPoint { waypoints[0] }

    var startHeading: CGFloat {
        (waypoints[1] - waypoints[0]).angle
    }

    /// Direction (unit vector) of travel at a given waypoint index.
    func direction(at index: Int) -> CGPoint {
        let n = waypoints.count
        let a = waypoints[(index - 1 + n) % n]
        let b = waypoints[index]
        return (b - a).normalized
    }

    /// Positions/headings for the starting grid, staggered behind the line.
    func startingGrid(count: Int) -> [(position: CGPoint, heading: CGFloat)] {
        let heading = startHeading
        let dir = CGPoint(x: cos(heading), y: sin(heading))
        let perp = CGPoint(x: -dir.y, y: dir.x)
        var grid: [(CGPoint, CGFloat)] = []
        for i in 0..<count {
            let row = i / 2
            let col = i % 2
            let back: CGFloat = CGFloat(row + 1) * 78
            let side: CGFloat = (col == 0 ? -1 : 1) * 58
            let pos = startPosition + dir * (-back) + perp * side
            grid.append((pos, heading))
        }
        return grid
    }

    // MARK: - World construction

    func build(into world: SKNode) {
        addFloor(to: world)
        addRoad(to: world)
        addIsland(to: world)
        addWalls(to: world)
        addFinishLine(to: world)
    }

    private func addFloor(to world: SKNode) {
        let floor = SKSpriteNode(color: Palette.floor, size: worldSize)
        floor.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        floor.zPosition = -100
        world.addChild(floor)

        // Subtle tile grid for a supermarket-floor feel.
        let path = CGMutablePath()
        let step: CGFloat = 120
        var x: CGFloat = 0
        while x <= worldSize.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: worldSize.height)); x += step }
        var y: CGFloat = 0
        while y <= worldSize.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: worldSize.width, y: y)); y += step }
        let tiles = SKShapeNode(path: path)
        tiles.strokeColor = Palette.floorTile
        tiles.lineWidth = 2
        tiles.zPosition = -99
        world.addChild(tiles)
    }

    private func addRoad(to world: SKNode) {
        let roadShape = SKShapeNode(path: roundedPath(rect: outerRect, radius: outerRadius))
        roadShape.fillColor = Palette.road
        roadShape.strokeColor = .clear
        roadShape.zPosition = -80
        world.addChild(roadShape)

        // Dashed centre line.
        let center = SKShapeNode(path: roundedPath(rect: centerRect, radius: centerRadius))
        center.fillColor = .clear
        center.strokeColor = Palette.roadLine
        center.lineWidth = 4
        center.lineCap = .round
        center.zPosition = -70
        let dashed = center.path?.copy(dashingWithPhase: 0, lengths: [26, 26])
        if let dashed { center.path = dashed }
        world.addChild(center)
    }

    private func addIsland(to world: SKNode) {
        let island = SKShapeNode(path: roundedPath(rect: innerRect, radius: innerRadius))
        island.fillColor = Palette.floor
        island.strokeColor = .clear
        island.zPosition = -75
        world.addChild(island)

        // Shelves + produce decoration on the island.
        let cols = 4
        let rows = 3
        let pad: CGFloat = 90
        let cellW = (innerRect.width - pad * 2) / CGFloat(cols)
        let cellH = (innerRect.height - pad * 2) / CGFloat(rows)
        let produce = ["🍎", "🥫", "🧻", "🍞", "🥦", "🧀", "🍌", "🥛", "🍊", "🥕", "🍪", "🧃"]
        var idx = 0
        for r in 0..<rows {
            for c in 0..<cols {
                let cx = innerRect.minX + pad + cellW * (CGFloat(c) + 0.5)
                let cy = innerRect.minY + pad + cellH * (CGFloat(r) + 0.5)
                let shelf = SKShapeNode(rectOf: CGSize(width: cellW * 0.7, height: cellH * 0.55), cornerRadius: 8)
                shelf.fillColor = Palette.shelf
                shelf.strokeColor = Palette.shelfTop
                shelf.lineWidth = 3
                shelf.position = CGPoint(x: cx, y: cy)
                shelf.zPosition = -74
                world.addChild(shelf)

                let label = SKLabelNode(text: produce[idx % produce.count])
                label.fontSize = 34
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: cx, y: cy)
                label.zPosition = -73
                world.addChild(label)
                idx += 1
            }
        }
    }

    private func addWalls(to world: SKNode) {
        let outerPath = roundedPath(rect: outerRect, radius: outerRadius)
        let innerPath = roundedPath(rect: innerRect, radius: innerRadius)

        let outerWall = SKShapeNode(path: outerPath)
        outerWall.strokeColor = Palette.wall
        outerWall.lineWidth = 22
        outerWall.fillColor = .clear
        outerWall.zPosition = -60
        outerWall.physicsBody = SKPhysicsBody(edgeLoopFrom: outerPath)
        configureWall(outerWall.physicsBody)
        world.addChild(outerWall)

        let innerWall = SKShapeNode(path: innerPath)
        innerWall.strokeColor = Palette.wall
        innerWall.lineWidth = 18
        innerWall.fillColor = .clear
        innerWall.zPosition = -60
        innerWall.physicsBody = SKPhysicsBody(edgeLoopFrom: innerPath)
        configureWall(innerWall.physicsBody)
        world.addChild(innerWall)
    }

    private func configureWall(_ body: SKPhysicsBody?) {
        guard let body else { return }
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.cart
        body.contactTestBitMask = PhysicsCategory.cart | PhysicsCategory.projectile
        body.restitution = 0.2
        body.friction = 0.4
    }

    private func addFinishLine(to world: SKNode) {
        let container = SKNode()
        container.zPosition = -65
        let x = startPosition.x
        let y0 = outerRect.minY + 11        // inside the outer wall
        let y1 = innerRect.minY - 11        // up to the island edge
        let square: CGFloat = (y1 - y0) / 6
        var i = 0
        var y = y0
        while y < y1 {
            for c in 0..<2 {
                let tile = SKShapeNode(rectOf: CGSize(width: square, height: square))
                tile.fillColor = ((i + c) % 2 == 0) ? .white : .black
                tile.strokeColor = .clear
                tile.position = CGPoint(x: x + (c == 0 ? -square / 2 : square / 2), y: y + square / 2)
                container.addChild(tile)
            }
            y += square
            i += 1
        }
        world.addChild(container)
    }

    // MARK: - Path helpers

    private func roundedPath(rect: CGRect, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// Points around a rounded rectangle, counter-clockwise, starting at the
    /// bottom-right corner region.
    static func loopPoints(rect: CGRect, radius: CGFloat, arcSteps: Int) -> [CGPoint] {
        var pts: [CGPoint] = []
        let r = min(radius, min(rect.width, rect.height) / 2)
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY

        func arc(cx: CGFloat, cy: CGFloat, start: CGFloat, end: CGFloat) {
            for i in 0...arcSteps {
                let t = start + (end - start) * CGFloat(i) / CGFloat(arcSteps)
                pts.append(CGPoint(x: cx + cos(t) * r, y: cy + sin(t) * r))
            }
        }

        arc(cx: maxX - r, cy: minY + r, start: -.pi / 2, end: 0)        // bottom-right
        arc(cx: maxX - r, cy: maxY - r, start: 0, end: .pi / 2)          // top-right
        arc(cx: minX + r, cy: maxY - r, start: .pi / 2, end: .pi)        // top-left
        arc(cx: minX + r, cy: minY + r, start: .pi, end: .pi * 1.5)      // bottom-left
        return pts
    }

    /// Resamples a closed loop of points into `count` evenly spaced points.
    static func resample(_ pts: [CGPoint], count: Int) -> [CGPoint] {
        let n = pts.count
        guard n > 1 else { return pts }
        var lengths: [CGFloat] = []
        var total: CGFloat = 0
        for i in 0..<n {
            let d = pts[i].distance(to: pts[(i + 1) % n])
            lengths.append(d)
            total += d
        }
        guard total > 0 else { return pts }

        var result: [CGPoint] = []
        let step = total / CGFloat(count)
        var segIdx = 0
        var segStart: CGFloat = 0
        var target: CGFloat = 0
        for _ in 0..<count {
            while segIdx < n - 1 && segStart + lengths[segIdx] < target {
                segStart += lengths[segIdx]
                segIdx += 1
            }
            let a = pts[segIdx]
            let b = pts[(segIdx + 1) % n]
            let segLen = lengths[segIdx]
            let f = segLen == 0 ? 0 : (target - segStart) / segLen
            result.append(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
            target += step
        }
        return result
    }
}
