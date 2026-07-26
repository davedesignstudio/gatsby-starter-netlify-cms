import SpriteKit

struct Checkpoint {
    let position: CGPoint
    let radius: CGFloat
}

final class TrackBuilder {
    let worldSize = CGSize(width: 2400, height: 1800)

    /// Centerline waypoints of MegaMart aisle loop (clockwise-ish).
    let centerline: [CGPoint] = [
        CGPoint(x: 400, y: 350),
        CGPoint(x: 900, y: 280),
        CGPoint(x: 1400, y: 320),
        CGPoint(x: 1900, y: 400),
        CGPoint(x: 2100, y: 700),
        CGPoint(x: 2050, y: 1100),
        CGPoint(x: 1800, y: 1400),
        CGPoint(x: 1300, y: 1550),
        CGPoint(x: 800, y: 1500),
        CGPoint(x: 400, y: 1300),
        CGPoint(x: 280, y: 900),
        CGPoint(x: 320, y: 550)
    ]

    let trackHalfWidth: CGFloat = 95

    func build(into parent: SKNode) -> (checkpoints: [Checkpoint], startPositions: [CGPoint], startHeading: CGFloat) {
        drawFloor(into: parent)
        drawAisles(into: parent)
        drawTrack(into: parent)
        drawDecor(into: parent)

        let checkpoints = centerline.enumerated().map { idx, p in
            Checkpoint(position: p, radius: 110)
        }

        let start = centerline[0]
        let next = centerline[1]
        let heading = atan2(next.y - start.y, next.x - start.x)
        let nx = cos(heading + .pi / 2)
        let ny = sin(heading + .pi / 2)

        var starts: [CGPoint] = []
        for i in 0..<RaceConfig.racerCount {
            let lane = (i % 2 == 0 ? -1.0 : 1.0) * 28
            let row = CGFloat(i / 2) * -55
            starts.append(CGPoint(
                x: start.x + nx * lane + cos(heading) * row,
                y: start.y + ny * lane + sin(heading) * row
            ))
        }

        return (checkpoints, starts, heading)
    }

    private func drawFloor(into parent: SKNode) {
        let floor = SKSpriteNode(color: UIColor(red: 0.92, green: 0.90, blue: 0.84, alpha: 1), size: worldSize)
        floor.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        floor.zPosition = -20
        parent.addChild(floor)

        // Tile grid
        let tile: CGFloat = 80
        for x in stride(from: 0, through: worldSize.width, by: tile) {
            let v = SKShapeNode(rectOf: CGSize(width: 1, height: worldSize.height))
            v.fillColor = UIColor(white: 0.8, alpha: 0.25)
            v.strokeColor = .clear
            v.position = CGPoint(x: x, y: worldSize.height / 2)
            v.zPosition = -19
            parent.addChild(v)
        }
        for y in stride(from: 0, through: worldSize.height, by: tile) {
            let h = SKShapeNode(rectOf: CGSize(width: worldSize.width, height: 1))
            h.fillColor = UIColor(white: 0.8, alpha: 0.25)
            h.strokeColor = .clear
            h.position = CGPoint(x: worldSize.width / 2, y: y)
            h.zPosition = -19
            parent.addChild(h)
        }
    }

    private func drawTrack(into parent: SKNode) {
        let path = CGMutablePath()
        guard let first = centerline.first else { return }
        path.move(to: first)
        for p in centerline.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()

        let asphalt = SKShapeNode(path: path.cgPath.copy(strokingWithWidth: trackHalfWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 2))
        asphalt.fillColor = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        asphalt.strokeColor = .clear
        asphalt.zPosition = -10
        parent.addChild(asphalt)

        let lane = SKShapeNode(path: path)
        lane.strokeColor = UIColor(white: 1, alpha: 0.35)
        lane.lineWidth = 3
        lane.lineDashPattern = [18, 14]
        lane.zPosition = -9
        parent.addChild(lane)

        // Yellow edge lines
        let edge = SKShapeNode(path: path.cgPath.copy(strokingWithWidth: trackHalfWidth * 2 - 8, lineCap: .round, lineJoin: .round, miterLimit: 2))
        edge.fillColor = .clear
        edge.strokeColor = UIColor(red: 0.95, green: 0.8, blue: 0.15, alpha: 0.7)
        edge.lineWidth = 4
        edge.zPosition = -8
        parent.addChild(edge)
    }

    private func drawAisles(into parent: SKNode) {
        // Shelf blocks outside the track — visual supermarket clutter
        let shelves: [(CGRect, UIColor)] = [
            (CGRect(x: 700, y: 700, width: 280, height: 70), UIColor(red: 0.75, green: 0.25, blue: 0.25, alpha: 1)),
            (CGRect(x: 1100, y: 750, width: 260, height: 70), UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1)),
            (CGRect(x: 900, y: 1050, width: 300, height: 70), UIColor(red: 0.30, green: 0.60, blue: 0.35, alpha: 1)),
            (CGRect(x: 1500, y: 900, width: 80, height: 240), UIColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1)),
            (CGRect(x: 550, y: 950, width: 80, height: 200), UIColor(red: 0.55, green: 0.30, blue: 0.65, alpha: 1)),
            (CGRect(x: 1700, y: 600, width: 200, height: 60), UIColor(red: 0.20, green: 0.55, blue: 0.55, alpha: 1))
        ]

        for (rect, color) in shelves {
            let shelf = SKShapeNode(rect: rect, cornerRadius: 6)
            shelf.fillColor = color
            shelf.strokeColor = UIColor(white: 0.2, alpha: 0.4)
            shelf.lineWidth = 2
            shelf.zPosition = -5
            parent.addChild(shelf)

            // Product dots
            for i in 0..<6 {
                let item = SKShapeNode(circleOfRadius: 6)
                item.fillColor = UIColor(
                    hue: CGFloat(i) / 6,
                    saturation: 0.55,
                    brightness: 0.9,
                    alpha: 1
                )
                item.strokeColor = .clear
                item.position = CGPoint(
                    x: rect.midX - rect.width / 3 + CGFloat(i % 3) * (rect.width / 3.5),
                    y: rect.midY - 10 + CGFloat(i / 3) * 18
                )
                item.zPosition = -4
                parent.addChild(item)
            }
        }
    }

    private func drawDecor(into parent: SKNode) {
        let labels = [
            ("PRODUCE", CGPoint(x: 600, y: 500)),
            ("FROZEN", CGPoint(x: 1700, y: 500)),
            ("CEREAL", CGPoint(x: 1200, y: 1200)),
            ("CHECKOUT", CGPoint(x: 500, y: 1500))
        ]
        for (text, pos) in labels {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = text
            label.fontSize = 28
            label.fontColor = UIColor(white: 0.35, alpha: 0.45)
            label.position = pos
            label.zPosition = -7
            parent.addChild(label)
        }

        // Start / finish banner
        let start = centerline[0]
        let banner = SKShapeNode(rectOf: CGSize(width: 160, height: 18), cornerRadius: 2)
        banner.fillColor = UIColor(white: 0.1, alpha: 1)
        banner.strokeColor = .white
        banner.lineWidth = 2
        banner.position = CGPoint(x: start.x, y: start.y + 70)
        banner.zPosition = 5
        parent.addChild(banner)

        let finish = SKLabelNode(fontNamed: "AvenirNext-Bold")
        finish.text = "FINISH"
        finish.fontSize = 12
        finish.fontColor = .white
        finish.position = banner.position
        finish.verticalAlignmentMode = .center
        finish.zPosition = 6
        parent.addChild(finish)
    }

    func nearestProgress(for point: CGPoint, checkpointIndex: Int) -> CGFloat {
        let n = centerline.count
        let i = checkpointIndex % n
        let a = centerline[i]
        let b = centerline[(i + 1) % n]
        let segLen = hypot(b.x - a.x, b.y - a.y)
        let t = max(0, min(1, ((point.x - a.x) * (b.x - a.x) + (point.y - a.y) * (b.y - a.y)) / max(segLen * segLen, 1)))
        return CGFloat(checkpointIndex) + t
    }

    func isOnTrack(_ point: CGPoint) -> Bool {
        var minDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<centerline.count {
            let a = centerline[i]
            let b = centerline[(i + 1) % centerline.count]
            minDist = min(minDist, distanceToSegment(point, a, b))
        }
        return minDist <= trackHalfWidth + 8
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let apx = p.x - a.x, apy = p.y - a.y
        let ab2 = abx * abx + aby * aby
        let t = max(0, min(1, (apx * abx + apy * aby) / max(ab2, 1)))
        let cx = a.x + abx * t, cy = a.y + aby * t
        return hypot(p.x - cx, p.y - cy)
    }
}
