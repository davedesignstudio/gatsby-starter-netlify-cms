import CoreGraphics
import SpriteKit

struct TrackLayout {
    static let tileSize: CGFloat = 64

    // Store aisle loop: outer rectangle with inner shelf islands.
    static let outerRect = CGRect(x: -640, y: -480, width: 1280, height: 960)
    static let innerRect = CGRect(x: -280, y: -180, width: 560, height: 360)

    static let startPosition = CGPoint(x: 0, y: -360)
    static let startAngle: CGFloat = .pi / 2

    static let checkpointAngles: [CGFloat] = [
        .pi / 2,
        0,
        -.pi / 2,
        .pi
    ]

    static let itemBoxPositions: [CGPoint] = [
        CGPoint(x: -520, y: -200),
        CGPoint(x: 520, y: -200),
        CGPoint(x: 520, y: 200),
        CGPoint(x: -520, y: 200),
        CGPoint(x: 0, y: 0),
        CGPoint(x: -200, y: 320),
        CGPoint(x: 200, y: -320)
    ]

    static let shelfObstacles: [CGRect] = [
        CGRect(x: -600, y: 60, width: 180, height: 80),
        CGRect(x: 420, y: 60, width: 180, height: 80),
        CGRect(x: -600, y: -140, width: 180, height: 80),
        CGRect(x: 420, y: -140, width: 180, height: 80),
        CGRect(x: -120, y: 240, width: 240, height: 60),
        CGRect(x: -120, y: -300, width: 240, height: 60)
    ]

    static func isOnTrack(_ point: CGPoint) -> Bool {
        guard outerRect.contains(point) else { return false }
        if innerRect.contains(point) { return false }
        for shelf in shelfObstacles where shelf.contains(point) {
            return false
        }
        return true
    }

    static func nearestTrackPoint(from point: CGPoint) -> CGPoint {
        var clamped = point
        clamped.x = min(max(clamped.x, outerRect.minX + 40), outerRect.maxX - 40)
        clamped.y = min(max(clamped.y, outerRect.minY + 40), outerRect.maxY - 40)

        if innerRect.contains(clamped) {
            let distances: [(CGPoint, CGFloat)] = [
                (CGPoint(x: clamped.x, y: innerRect.maxY + 30), abs(clamped.y - innerRect.maxY)),
                (CGPoint(x: clamped.x, y: innerRect.minY - 30), abs(clamped.y - innerRect.minY)),
                (CGPoint(x: innerRect.maxX + 30, y: clamped.y), abs(clamped.x - innerRect.maxX)),
                (CGPoint(x: innerRect.minX - 30, y: clamped.y), abs(clamped.x - innerRect.minX))
            ]
            if let nearest = distances.min(by: { $0.1 < $1.1 }) {
                clamped = nearest.0
            }
        }

        for shelf in shelfObstacles where shelf.contains(clamped) {
            clamped.y = shelf.maxY + 35
        }

        return clamped
    }
}
