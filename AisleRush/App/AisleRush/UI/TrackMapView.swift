import SwiftUI
import AisleRushCore

/// Baked tracks are not free to build, so keep one of each around.
final class TrackCache {
    static let shared = TrackCache()
    private var tracks: [String: Track] = [:]

    func track(id: String) -> Track {
        if let existing = tracks[id] { return existing }
        let built = Track(definition: Tracks.definition(id: id))
        tracks[id] = built
        return built
    }
}

/// A course outline, used both on the selection screen and as the in-race
/// minimap.
struct TrackMapView: View {
    let track: Track
    var lineWidth: CGFloat = 7
    var lineColor: Color = Theme.ink.opacity(0.18)
    var edgeColor: Color = Theme.ink.opacity(0.35)
    /// Optional dots: position in world space plus a colour.
    var markers: [Marker] = []
    var showStartLine = true

    struct Marker: Identifiable {
        var id: Int
        var position: Vector2
        var color: Color
        var isPlayer: Bool
    }

    var body: some View {
        Canvas { context, size in
            let layout = TrackMapLayout(track: track, in: CGRect(origin: .zero, size: size), inset: lineWidth)

            var path = Path()
            for index in 0...track.sampleCount {
                let point = layout.map(track.centerline[index % track.sampleCount])
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            context.stroke(path, with: .color(edgeColor), style: StrokeStyle(lineWidth: lineWidth + 3, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            if showStartLine {
                let start = layout.map(track.point(atDistance: 0))
                let normal = track.tangent(atDistance: 0).perpendicular
                let dx = CGFloat(normal.x)
                let dy = CGFloat(normal.y)
                let half = (lineWidth + 2) / 2
                var line = Path()
                line.move(to: CGPoint(x: start.x - dx * half, y: start.y + dy * half))
                line.addLine(to: CGPoint(x: start.x + dx * half, y: start.y - dy * half))
                context.stroke(line, with: .color(Theme.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            for marker in markers {
                let point = layout.map(marker.position)
                let radius: CGFloat = marker.isPlayer ? 5 : 3.5
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                if marker.isPlayer {
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)), with: .color(.white))
                }
                context.fill(Path(ellipseIn: rect), with: .color(marker.color))
            }
        }
    }
}

/// Maps world metres into a view rectangle, preserving aspect ratio and
/// flipping y so the map is not upside down.
struct TrackMapLayout {
    private let scale: CGFloat
    private let offset: CGPoint
    private let bounds: CGRect

    init(track: Track, in rect: CGRect, inset: CGFloat) {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        for point in track.centerline {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let margin = track.definition.controlPoints.map(\.halfWidth).max() ?? 8
        bounds = CGRect(
            x: minX - margin,
            y: minY - margin,
            width: (maxX - minX) + margin * 2,
            height: (maxY - minY) + margin * 2
        )
        let usable = rect.insetBy(dx: inset, dy: inset)
        scale = min(usable.width / max(bounds.width, 1), usable.height / max(bounds.height, 1))
        offset = CGPoint(
            x: usable.minX + (usable.width - bounds.width * scale) / 2,
            y: usable.minY + (usable.height - bounds.height * scale) / 2
        )
    }

    func map(_ point: Vector2) -> CGPoint {
        CGPoint(
            x: offset.x + (CGFloat(point.x) - bounds.minX) * scale,
            // Flip: world y grows upwards, view y grows downwards.
            y: offset.y + (bounds.height - (CGFloat(point.y) - bounds.minY)) * scale
        )
    }
}
