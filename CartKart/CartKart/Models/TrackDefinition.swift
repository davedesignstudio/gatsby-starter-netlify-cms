import CoreGraphics
import SpriteKit

struct TrackDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let emoji: String
    let floorColor: SKColor
    let islandColor: SKColor
    let shelfColor: SKColor
    let decorColors: [SKColor]
    let islandLabel: String
    let shelfLabels: [String]
    let outerRect: CGRect
    let innerRect: CGRect
    let checkpoints: [CGPoint]
    let itemBoxPositions: [CGPoint]
    let shelfObstacles: [CGRect]
    let startGrid: [(CGPoint, CGFloat)]
    let isDarkStore: Bool

    var startPosition: CGPoint { startGrid[0].0 }

    func isOnTrack(_ point: CGPoint) -> Bool {
        guard outerRect.contains(point) else { return false }
        if innerRect.contains(point) { return false }
        for shelf in shelfObstacles where shelf.contains(point) {
            return false
        }
        return true
    }

    func nearestTrackPoint(from point: CGPoint) -> CGPoint {
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

extension TrackDefinition {
    static let grocery = TrackDefinition(
        id: "grocery",
        name: "Grocery Gauntlet",
        subtitle: "Classic aisle loop",
        emoji: "🛒",
        floorColor: SKColor(red: 0.78, green: 0.75, blue: 0.7, alpha: 1),
        islandColor: SKColor(red: 0.65, green: 0.62, blue: 0.58, alpha: 1),
        shelfColor: SKColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1),
        decorColors: [
            SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),
            SKColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 1),
            SKColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1),
            SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1)
        ],
        islandLabel: "DAIRY",
        shelfLabels: ["CEREAL", "SOUP", "CHIPS", "PASTA", "COOKIES", "JUICE"],
        outerRect: CGRect(x: -640, y: -480, width: 1280, height: 960),
        innerRect: CGRect(x: -280, y: -180, width: 560, height: 360),
        checkpoints: [
            CGPoint(x: 0, y: -360),
            CGPoint(x: 560, y: 0),
            CGPoint(x: 0, y: 360),
            CGPoint(x: -560, y: 0)
        ],
        itemBoxPositions: [
            CGPoint(x: -520, y: -200),
            CGPoint(x: 520, y: -200),
            CGPoint(x: 520, y: 200),
            CGPoint(x: -520, y: 200),
            CGPoint(x: 0, y: 0),
            CGPoint(x: -200, y: 320),
            CGPoint(x: 200, y: -320)
        ],
        shelfObstacles: [
            CGRect(x: -600, y: 60, width: 180, height: 80),
            CGRect(x: 420, y: 60, width: 180, height: 80),
            CGRect(x: -600, y: -140, width: 180, height: 80),
            CGRect(x: 420, y: -140, width: 180, height: 80),
            CGRect(x: -120, y: 240, width: 240, height: 60),
            CGRect(x: -120, y: -300, width: 240, height: 60)
        ],
        startGrid: [
            (CGPoint(x: -40, y: -360), .pi / 2),
            (CGPoint(x: 40, y: -360), .pi / 2),
            (CGPoint(x: -40, y: -400), .pi / 2),
            (CGPoint(x: 40, y: -400), .pi / 2)
        ],
        isDarkStore: false
    )

    static let frozen = TrackDefinition(
        id: "frozen",
        name: "Frozen Fury",
        subtitle: "Icy freezer maze",
        emoji: "🧊",
        floorColor: SKColor(red: 0.72, green: 0.85, blue: 0.95, alpha: 1),
        islandColor: SKColor(red: 0.55, green: 0.72, blue: 0.88, alpha: 1),
        shelfColor: SKColor(red: 0.35, green: 0.55, blue: 0.75, alpha: 1),
        decorColors: [
            SKColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1),
            SKColor(red: 0.4, green: 0.65, blue: 0.9, alpha: 1),
            SKColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1),
            SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1)
        ],
        islandLabel: "ICE CREAM",
        shelfLabels: ["PIZZA", "WAFFLES", "BERRIES", "FISH", "VEGGIES", "DESSERT"],
        outerRect: CGRect(x: -700, y: -500, width: 1400, height: 1000),
        innerRect: CGRect(x: -220, y: -140, width: 440, height: 280),
        checkpoints: [
            CGPoint(x: 0, y: -380),
            CGPoint(x: 600, y: 40),
            CGPoint(x: -80, y: 380),
            CGPoint(x: -600, y: -40)
        ],
        itemBoxPositions: [
            CGPoint(x: -560, y: -220),
            CGPoint(x: 560, y: -220),
            CGPoint(x: 560, y: 220),
            CGPoint(x: -560, y: 220),
            CGPoint(x: 200, y: 0),
            CGPoint(x: -200, y: 0),
            CGPoint(x: 0, y: 300)
        ],
        shelfObstacles: [
            CGRect(x: -640, y: 120, width: 200, height: 70),
            CGRect(x: 440, y: 120, width: 200, height: 70),
            CGRect(x: -640, y: -190, width: 200, height: 70),
            CGRect(x: 440, y: -190, width: 200, height: 70),
            CGRect(x: -80, y: 260, width: 260, height: 55),
            CGRect(x: -80, y: -315, width: 260, height: 55)
        ],
        startGrid: [
            (CGPoint(x: -50, y: -380), .pi / 2),
            (CGPoint(x: 50, y: -380), .pi / 2),
            (CGPoint(x: -50, y: -420), .pi / 2),
            (CGPoint(x: 50, y: -420), .pi / 2)
        ],
        isDarkStore: false
    )

    static let produce = TrackDefinition(
        id: "produce",
        name: "Produce Pit",
        subtitle: "Wet floor sprint",
        emoji: "🥬",
        floorColor: SKColor(red: 0.7, green: 0.82, blue: 0.65, alpha: 1),
        islandColor: SKColor(red: 0.55, green: 0.7, blue: 0.48, alpha: 1),
        shelfColor: SKColor(red: 0.35, green: 0.55, blue: 0.28, alpha: 1),
        decorColors: [
            SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1),
            SKColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1),
            SKColor(red: 0.4, green: 0.8, blue: 0.35, alpha: 1),
            SKColor(red: 0.95, green: 0.5, blue: 0.6, alpha: 1)
        ],
        islandLabel: "ORGANIC",
        shelfLabels: ["APPLES", "BANANAS", "KALE", "TOMATO", "GRAPES", "CARROT"],
        outerRect: CGRect(x: -600, y: -520, width: 1200, height: 1040),
        innerRect: CGRect(x: -200, y: -220, width: 400, height: 440),
        checkpoints: [
            CGPoint(x: 0, y: -400),
            CGPoint(x: 480, y: -120),
            CGPoint(x: 0, y: 400),
            CGPoint(x: -480, y: 120)
        ],
        itemBoxPositions: [
            CGPoint(x: -460, y: -260),
            CGPoint(x: 460, y: -260),
            CGPoint(x: 460, y: 260),
            CGPoint(x: -460, y: 260),
            CGPoint(x: 0, y: -40),
            CGPoint(x: 280, y: 180),
            CGPoint(x: -280, y: -180)
        ],
        shelfObstacles: [
            CGRect(x: -520, y: 80, width: 150, height: 90),
            CGRect(x: 370, y: 80, width: 150, height: 90),
            CGRect(x: -520, y: -170, width: 150, height: 90),
            CGRect(x: 370, y: -170, width: 150, height: 90),
            CGRect(x: -60, y: 300, width: 200, height: 70),
            CGRect(x: -60, y: -370, width: 200, height: 70)
        ],
        startGrid: [
            (CGPoint(x: -35, y: -400), .pi / 2),
            (CGPoint(x: 35, y: -400), .pi / 2),
            (CGPoint(x: -35, y: -440), .pi / 2),
            (CGPoint(x: 35, y: -440), .pi / 2)
        ],
        isDarkStore: false
    )

    static let bakery = TrackDefinition(
        id: "bakery",
        name: "Bakery Blitz",
        subtitle: "Flour-dusted sprint",
        emoji: "🥐",
        floorColor: SKColor(red: 0.88, green: 0.82, blue: 0.72, alpha: 1),
        islandColor: SKColor(red: 0.78, green: 0.68, blue: 0.52, alpha: 1),
        shelfColor: SKColor(red: 0.62, green: 0.42, blue: 0.28, alpha: 1),
        decorColors: [
            SKColor(red: 0.95, green: 0.75, blue: 0.45, alpha: 1),
            SKColor(red: 0.85, green: 0.55, blue: 0.3, alpha: 1),
            SKColor(red: 0.7, green: 0.45, blue: 0.25, alpha: 1),
            SKColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1)
        ],
        islandLabel: "OVEN",
        shelfLabels: ["BREAD", "BAGELS", "MUFFIN", "DONUT", "ROLLS", "CAKE"],
        outerRect: CGRect(x: -620, y: -460, width: 1240, height: 920),
        innerRect: CGRect(x: -240, y: -160, width: 480, height: 320),
        checkpoints: [
            CGPoint(x: 0, y: -340),
            CGPoint(x: 500, y: 80),
            CGPoint(x: 0, y: 340),
            CGPoint(x: -500, y: -80)
        ],
        itemBoxPositions: [
            CGPoint(x: -480, y: -180),
            CGPoint(x: 480, y: -180),
            CGPoint(x: 480, y: 180),
            CGPoint(x: -480, y: 180),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 250, y: 280),
            CGPoint(x: -250, y: -280)
        ],
        shelfObstacles: [
            CGRect(x: -560, y: 80, width: 160, height: 75),
            CGRect(x: 400, y: 80, width: 160, height: 75),
            CGRect(x: -560, y: -155, width: 160, height: 75),
            CGRect(x: 400, y: -155, width: 160, height: 75),
            CGRect(x: -100, y: 250, width: 200, height: 55),
            CGRect(x: -100, y: -280, width: 200, height: 55)
        ],
        startGrid: [
            (CGPoint(x: -40, y: -340), .pi / 2),
            (CGPoint(x: 40, y: -340), .pi / 2),
            (CGPoint(x: -40, y: -380), .pi / 2),
            (CGPoint(x: 40, y: -380), .pi / 2)
        ],
        isDarkStore: false
    )

    static let liquor = TrackDefinition(
        id: "liquor",
        name: "Liquor Lane",
        subtitle: "Bottle-lined bends",
        emoji: "🍷",
        floorColor: SKColor(red: 0.55, green: 0.48, blue: 0.42, alpha: 1),
        islandColor: SKColor(red: 0.42, green: 0.32, blue: 0.28, alpha: 1),
        shelfColor: SKColor(red: 0.35, green: 0.22, blue: 0.18, alpha: 1),
        decorColors: [
            SKColor(red: 0.6, green: 0.15, blue: 0.2, alpha: 1),
            SKColor(red: 0.45, green: 0.25, blue: 0.35, alpha: 1),
            SKColor(red: 0.75, green: 0.55, blue: 0.2, alpha: 1),
            SKColor(red: 0.3, green: 0.2, blue: 0.15, alpha: 1)
        ],
        islandLabel: "VINTAGE",
        shelfLabels: ["WINE", "BEER", "VODKA", "WHISKY", "GIN", "CIDER"],
        outerRect: CGRect(x: -660, y: -490, width: 1320, height: 980),
        innerRect: CGRect(x: -300, y: -200, width: 600, height: 400),
        checkpoints: [
            CGPoint(x: 0, y: -370),
            CGPoint(x: 580, y: 0),
            CGPoint(x: 0, y: 370),
            CGPoint(x: -580, y: 0)
        ],
        itemBoxPositions: [
            CGPoint(x: -540, y: -210),
            CGPoint(x: 540, y: -210),
            CGPoint(x: 540, y: 210),
            CGPoint(x: -540, y: 210),
            CGPoint(x: 0, y: 0),
            CGPoint(x: -220, y: 300),
            CGPoint(x: 220, y: -300)
        ],
        shelfObstacles: [
            CGRect(x: -620, y: 70, width: 170, height: 85),
            CGRect(x: 450, y: 70, width: 170, height: 85),
            CGRect(x: -620, y: -155, width: 170, height: 85),
            CGRect(x: 450, y: -155, width: 170, height: 85),
            CGRect(x: -130, y: 260, width: 260, height: 60),
            CGRect(x: -130, y: -320, width: 260, height: 60)
        ],
        startGrid: [
            (CGPoint(x: -45, y: -370), .pi / 2),
            (CGPoint(x: 45, y: -370), .pi / 2),
            (CGPoint(x: -45, y: -410), .pi / 2),
            (CGPoint(x: 45, y: -410), .pi / 2)
        ],
        isDarkStore: false
    )

    static let midnight = TrackDefinition(
        id: "midnight",
        name: "Midnight Shift",
        subtitle: "Dark store dash",
        emoji: "🌙",
        floorColor: SKColor(red: 0.18, green: 0.2, blue: 0.25, alpha: 1),
        islandColor: SKColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1),
        shelfColor: SKColor(red: 0.25, green: 0.28, blue: 0.35, alpha: 1),
        decorColors: [
            SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1),
            SKColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1),
            SKColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1),
            SKColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1)
        ],
        islandLabel: "CLOSED",
        shelfLabels: ["SNACKS", "SODA", "RAMEN", "CANDY", "CHIPS", "ENERGY"],
        outerRect: CGRect(x: -640, y: -480, width: 1280, height: 960),
        innerRect: CGRect(x: -260, y: -170, width: 520, height: 340),
        checkpoints: [
            CGPoint(x: 0, y: -360),
            CGPoint(x: 550, y: 50),
            CGPoint(x: 0, y: 360),
            CGPoint(x: -550, y: -50)
        ],
        itemBoxPositions: [
            CGPoint(x: -500, y: -200),
            CGPoint(x: 500, y: -200),
            CGPoint(x: 500, y: 200),
            CGPoint(x: -500, y: 200),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 180, y: 300),
            CGPoint(x: -180, y: -300)
        ],
        shelfObstacles: [
            CGRect(x: -580, y: 65, width: 175, height: 80),
            CGRect(x: 405, y: 65, width: 175, height: 80),
            CGRect(x: -580, y: -145, width: 175, height: 80),
            CGRect(x: 405, y: -145, width: 175, height: 80),
            CGRect(x: -110, y: 235, width: 220, height: 58),
            CGRect(x: -110, y: -295, width: 220, height: 58)
        ],
        startGrid: [
            (CGPoint(x: -40, y: -360), .pi / 2),
            (CGPoint(x: 40, y: -360), .pi / 2),
            (CGPoint(x: -40, y: -400), .pi / 2),
            (CGPoint(x: 40, y: -400), .pi / 2)
        ],
        isDarkStore: true
    )

    static let all: [TrackDefinition] = [.grocery, .frozen, .produce, .bakery, .liquor, .midnight]
}

// Backward-compatible alias used by existing code paths.
typealias TrackLayout = TrackDefinition
