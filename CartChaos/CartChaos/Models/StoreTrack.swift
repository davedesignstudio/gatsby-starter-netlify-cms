import SpriteKit
import UIKit

struct TrackSample {
    let progress: CGFloat
    let curvature: CGFloat
    let aisleName: String
    let floorTone: UIColor
}

enum StoreTrack {
    static let lapLength: CGFloat = 1000
    static let totalLaps = 3
    static let trackHalfWidth: CGFloat = 0.92

    private static let samples: [TrackSample] = [
        TrackSample(progress: 0, curvature: 0.0, aisleName: "ENTRANCE", floorTone: UIColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1)),
        TrackSample(progress: 80, curvature: 0.15, aisleName: "PRODUCE", floorTone: UIColor(red: 0.72, green: 0.78, blue: 0.55, alpha: 1)),
        TrackSample(progress: 160, curvature: 0.45, aisleName: "PRODUCE", floorTone: UIColor(red: 0.70, green: 0.76, blue: 0.52, alpha: 1)),
        TrackSample(progress: 240, curvature: -0.1, aisleName: "BAKERY", floorTone: UIColor(red: 0.82, green: 0.70, blue: 0.52, alpha: 1)),
        TrackSample(progress: 320, curvature: -0.55, aisleName: "DAIRY", floorTone: UIColor(red: 0.72, green: 0.78, blue: 0.84, alpha: 1)),
        TrackSample(progress: 400, curvature: -0.2, aisleName: "DAIRY", floorTone: UIColor(red: 0.70, green: 0.76, blue: 0.82, alpha: 1)),
        TrackSample(progress: 480, curvature: 0.35, aisleName: "FROZEN", floorTone: UIColor(red: 0.68, green: 0.80, blue: 0.88, alpha: 1)),
        TrackSample(progress: 560, curvature: 0.6, aisleName: "FROZEN", floorTone: UIColor(red: 0.66, green: 0.78, blue: 0.86, alpha: 1)),
        TrackSample(progress: 640, curvature: 0.1, aisleName: "SNACKS", floorTone: UIColor(red: 0.84, green: 0.68, blue: 0.48, alpha: 1)),
        TrackSample(progress: 720, curvature: -0.4, aisleName: "CEREAL", floorTone: UIColor(red: 0.80, green: 0.72, blue: 0.55, alpha: 1)),
        TrackSample(progress: 800, curvature: -0.15, aisleName: "CHECKOUT", floorTone: UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1)),
        TrackSample(progress: 880, curvature: 0.25, aisleName: "CHECKOUT", floorTone: UIColor(red: 0.74, green: 0.74, blue: 0.77, alpha: 1)),
        TrackSample(progress: 960, curvature: 0.05, aisleName: "EXIT RAMP", floorTone: UIColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1)),
        TrackSample(progress: 1000, curvature: 0.0, aisleName: "ENTRANCE", floorTone: UIColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 1))
    ]

    static func sample(at progress: CGFloat) -> TrackSample {
        let wrapped = progress.truncatingRemainder(dividingBy: lapLength)
        let p = wrapped < 0 ? wrapped + lapLength : wrapped

        for i in 0..<(samples.count - 1) {
            let a = samples[i]
            let b = samples[i + 1]
            if p >= a.progress && p <= b.progress {
                let t = (p - a.progress) / max(0.001, b.progress - a.progress)
                let curvature = a.curvature + (b.curvature - a.curvature) * t
                let aisle = t < 0.5 ? a.aisleName : b.aisleName
                let floor = blend(a.floorTone, b.floorTone, t: t)
                return TrackSample(progress: p, curvature: curvature, aisleName: aisle, floorTone: floor)
            }
        }
        return samples[0]
    }

    static func curvature(at progress: CGFloat) -> CGFloat {
        sample(at: progress).curvature
    }

    private static func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: 1
        )
    }
}

struct Hazard {
    enum Kind { case banana, spill }
    var progress: CGFloat
    var lateral: CGFloat
    var kind: Kind
    var life: TimeInterval = 12
}

struct Projectile {
    var progress: CGFloat
    var lateral: CGFloat
    var ownerId: Int
    var life: TimeInterval = 2.2
}

struct Pickup {
    var progress: CGFloat
    var lateral: CGFloat
    var kind: PowerUpKind
    var collected: Bool = false
    var respawnIn: TimeInterval = 0
}
