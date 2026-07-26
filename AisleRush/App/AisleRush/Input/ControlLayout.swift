import CoreGraphics
import Foundation

/// The on-screen controls a touch can land on.
enum ControlRegion: Hashable {
    case steer
    case drift
    case item
    case brake
    case gas
}

/// Geometry for the control pad, shared by the SwiftUI visuals and the
/// multitouch layer underneath them so the two can never disagree about where
/// a button is.
struct ControlLayout: Equatable {
    var size: CGSize
    var showsGas: Bool

    /// Thumb travel for full steering lock, in points.
    let steerTravel: CGFloat = 78
    let steerHeight: CGFloat = 92
    let driftDiameter: CGFloat = 96
    let itemDiameter: CGFloat = 82
    let pedalDiameter: CGFloat = 64

    private let margin: CGFloat = 26
    private let bottom: CGFloat = 24
    private let gap: CGFloat = 14

    /// The steering strip. Generously tall: thumbs wander.
    var steerRect: CGRect {
        let width = steerTravel * 2 + 96
        return CGRect(
            x: margin - 8,
            y: size.height - bottom - steerHeight - 10,
            width: width,
            height: steerHeight + 20
        )
    }

    var steerCentre: CGPoint {
        CGPoint(x: steerRect.midX, y: steerRect.midY)
    }

    var driftCentre: CGPoint {
        CGPoint(
            x: size.width - margin - driftDiameter / 2,
            y: size.height - bottom - driftDiameter / 2
        )
    }

    var brakeCentre: CGPoint {
        CGPoint(
            x: driftCentre.x,
            y: driftCentre.y - driftDiameter / 2 - gap - pedalDiameter / 2
        )
    }

    var itemCentre: CGPoint {
        CGPoint(
            x: driftCentre.x - driftDiameter / 2 - gap - itemDiameter / 2,
            y: size.height - bottom - itemDiameter / 2
        )
    }

    var gasCentre: CGPoint {
        CGPoint(
            x: itemCentre.x,
            y: itemCentre.y - itemDiameter / 2 - gap - pedalDiameter / 2
        )
    }

    func centre(of region: ControlRegion) -> CGPoint {
        switch region {
        case .steer: return steerCentre
        case .drift: return driftCentre
        case .item: return itemCentre
        case .brake: return brakeCentre
        case .gas: return gasCentre
        }
    }

    func diameter(of region: ControlRegion) -> CGFloat {
        switch region {
        case .steer: return steerRect.width
        case .drift: return driftDiameter
        case .item: return itemDiameter
        case .brake, .gas: return pedalDiameter
        }
    }

    /// Which control a touch landed on. Buttons get a generous margin because
    /// nobody looks at their thumbs mid-corner.
    func region(at point: CGPoint) -> ControlRegion? {
        var candidates: [ControlRegion] = [.drift, .item, .brake]
        if showsGas { candidates.append(.gas) }

        var best: ControlRegion?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for region in candidates {
            let centre = centre(of: region)
            let slop = diameter(of: region) / 2 + 14
            let dx = point.x - centre.x
            let dy = point.y - centre.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= slop, distance < bestDistance {
                best = region
                bestDistance = distance
            }
        }
        if let best { return best }

        // Anything on the left half that missed a button is steering.
        return point.x < size.width * 0.5 ? .steer : nil
    }
}
