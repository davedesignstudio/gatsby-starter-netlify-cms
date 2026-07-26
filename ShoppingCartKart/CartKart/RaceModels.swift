import SpriteKit

// MARK: - Vector helpers

extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (l: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: l.x * s, y: l.y * s) }

    var length: CGFloat { sqrt(x * x + y * y) }
    var angle: CGFloat { atan2(y, x) }
    var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : .zero
    }
    func distance(to p: CGPoint) -> CGFloat { (self - p).length }
}

/// Normalize an angle to the range (-pi, pi].
func normalizeAngle(_ a: CGFloat) -> CGFloat {
    var x = a
    while x > .pi { x -= 2 * .pi }
    while x < -CGFloat.pi { x += 2 * .pi }
    return x
}

// MARK: - Track

/// A closed-loop race track described by a centerline polyline.
struct Track {
    let centerline: [CGPoint]
    let width: CGFloat

    var count: Int { centerline.count }

    /// Direction (unit vector) at a given centerline vertex, pointing forward around the loop.
    func direction(at index: Int) -> CGPoint {
        let n = centerline.count
        let a = centerline[index]
        let b = centerline[(index + 1) % n]
        return (b - a).normalized
    }

    /// Nearest point on the loop to `p`. Returns distance, the segment index and the
    /// fractional position `t` along that segment, so callers can compute a continuous
    /// track parameter `s = segIndex + t`.
    func nearest(to p: CGPoint) -> (dist: CGFloat, seg: Int, t: CGFloat) {
        var bestDist = CGFloat.greatestFiniteMagnitude
        var bestSeg = 0
        var bestT: CGFloat = 0
        let n = centerline.count
        for i in 0..<n {
            let a = centerline[i]
            let b = centerline[(i + 1) % n]
            let ab = b - a
            let len2 = ab.x * ab.x + ab.y * ab.y
            var t: CGFloat = 0
            if len2 > 0 {
                let ap = p - a
                t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
            }
            let proj = a + ab * t
            let d = proj.distance(to: p)
            if d < bestDist {
                bestDist = d
                bestSeg = i
                bestT = t
            }
        }
        return (bestDist, bestSeg, bestT)
    }

    /// A gently wavy oval circuit that fits inside the store.
    static func store() -> Track {
        var pts: [CGPoint] = []
        let n = 48
        let rx: CGFloat = 1380
        let ry: CGFloat = 860
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let wob = 1 + 0.12 * sin(a * 3) // subtle chicanes without self-intersection
            pts.append(CGPoint(x: cos(a) * rx * wob, y: sin(a) * ry * wob))
        }
        return Track(centerline: pts, width: 300)
    }
}

// MARK: - Items

enum ItemKind {
    case none, boost, banana, can

    var display: String {
        switch self {
        case .none: return "—"
        case .boost: return "Energy Drink"
        case .banana: return "Spilled Milk"
        case .can: return "Canned Beans"
        }
    }

    static var random: ItemKind {
        [.boost, .banana, .can].randomElement()!
    }
}

// MARK: - Cart

/// A racer. The node's `zRotation` tracks heading; visuals live under `spinNode`
/// so a spin-out can rotate the artwork independently of travel direction.
final class Cart: SKNode {
    let isPlayer: Bool
    let displayName: String
    let color: UIColor

    var heading: CGFloat = 0
    var speed: CGFloat = 0
    var maxSpeedBase: CGFloat = 620
    var lineOffset: CGFloat = 0   // AI racing-line lateral bias

    // Progress tracking (continuous track parameter based).
    var currentS: CGFloat = 0
    var prevS: CGFloat = 0
    var totalS: CGFloat = 0
    var onTrack: Bool = true

    var lap: Int = 1
    var item: ItemKind = .none
    var spinTimer: CGFloat = 0
    var boostTimer: CGFloat = 0
    var aiItemTimer: CGFloat = 0
    var autopilot: Bool = false

    var finished: Bool = false
    var finishTime: TimeInterval = 0
    var finishOrder: Int = 0
    var rank: Int = 1

    private let spinNode = SKNode()

    init(isPlayer: Bool, name: String, color: UIColor) {
        self.isPlayer = isPlayer
        self.displayName = name
        self.color = color
        super.init()
        maxSpeedBase = isPlayer ? 640 : CGFloat.random(in: 585...625)
        addChild(spinNode)
        buildVisual()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var spinVisualRotation: CGFloat {
        get { spinNode.zRotation }
        set { spinNode.zRotation = newValue }
    }

    private func buildVisual() {
        // Basket (drawn facing +x, i.e. nose to the right).
        let basket = SKShapeNode(rectOf: CGSize(width: 76, height: 50), cornerRadius: 9)
        basket.fillColor = color
        basket.strokeColor = UIColor(white: 0.15, alpha: 1)
        basket.lineWidth = 3
        spinNode.addChild(basket)

        // Wire-basket grid lines.
        let grid = SKShapeNode()
        let path = CGMutablePath()
        for gx in stride(from: CGFloat(-30), through: 30, by: 15) {
            path.move(to: CGPoint(x: gx, y: -22))
            path.addLine(to: CGPoint(x: gx, y: 22))
        }
        for gy in stride(from: CGFloat(-15), through: 15, by: 15) {
            path.move(to: CGPoint(x: -34, y: gy))
            path.addLine(to: CGPoint(x: 34, y: gy))
        }
        grid.path = path
        grid.strokeColor = UIColor(white: 1, alpha: 0.35)
        grid.lineWidth = 1.5
        spinNode.addChild(grid)

        // Front push-bar (nose).
        let nose = SKShapeNode(rectOf: CGSize(width: 10, height: 44), cornerRadius: 4)
        nose.position = CGPoint(x: 40, y: 0)
        nose.fillColor = UIColor(white: 0.75, alpha: 1)
        nose.strokeColor = UIColor(white: 0.2, alpha: 1)
        nose.lineWidth = 2
        spinNode.addChild(nose)

        // Handle at the back.
        let handle = SKShapeNode(rectOf: CGSize(width: 8, height: 40), cornerRadius: 4)
        handle.position = CGPoint(x: -42, y: 0)
        handle.fillColor = UIColor(white: 0.55, alpha: 1)
        handle.strokeColor = UIColor(white: 0.2, alpha: 1)
        handle.lineWidth = 2
        spinNode.addChild(handle)

        // Wheels.
        for wx in [CGFloat(-26), 26] {
            for wy in [CGFloat(-30), 30] {
                let wheel = SKShapeNode(circleOfRadius: 7)
                wheel.position = CGPoint(x: wx, y: wy)
                wheel.fillColor = UIColor(white: 0.1, alpha: 1)
                wheel.strokeColor = .clear
                spinNode.addChild(wheel)
            }
        }

        // A few groceries poking out of the basket.
        let groceryColors: [UIColor] = [.systemRed, .systemGreen, .systemYellow, .systemOrange, .white]
        for _ in 0..<3 {
            let g = SKShapeNode(circleOfRadius: CGFloat.random(in: 5...8))
            g.position = CGPoint(x: CGFloat.random(in: -22...22), y: CGFloat.random(in: -14...14))
            g.fillColor = groceryColors.randomElement()!
            g.strokeColor = .clear
            g.zPosition = 1
            spinNode.addChild(g)
        }

        if isPlayer {
            let flag = SKShapeNode(circleOfRadius: 12)
            flag.position = CGPoint(x: 0, y: 0)
            flag.fillColor = .white
            flag.strokeColor = color
            flag.lineWidth = 3
            flag.zPosition = 2
            let star = SKLabelNode(text: "★")
            star.fontSize = 16
            star.fontColor = color
            star.verticalAlignmentMode = .center
            star.horizontalAlignmentMode = .center
            flag.addChild(star)
            spinNode.addChild(flag)
        }
    }
}

// MARK: - Hazards & projectiles

final class Hazard: SKNode {
    var life: CGFloat = 12
    weak var owner: Cart?
    var ownerImmunity: CGFloat = 0.6
}

final class Projectile: SKNode {
    var velocity: CGPoint = .zero
    var life: CGFloat = 1.7
    weak var owner: Cart?
}
