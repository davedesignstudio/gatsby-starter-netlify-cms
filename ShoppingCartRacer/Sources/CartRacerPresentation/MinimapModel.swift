import Foundation

/// Projects the course into a unit square for the corner minimap, keeping the
/// aspect ratio so the shape still reads as the track you are driving.
public struct MinimapModel: Sendable {
    /// Course outline in unit space, ready to stroke.
    public let outline: [Vector2]
    public let startLine: Vector2
    public let scale: Double
    public let offset: Vector2
    /// Inset applied on every side, in unit space.
    public let padding: Double

    public init(track: Track, sampleSpacing: Double = 5, padding: Double = 0.06) {
        let geometry = track.geometry
        self.padding = padding

        var samples: [Vector2] = []
        var distance = 0.0
        while distance < geometry.totalLength {
            samples.append(geometry.point(at: distance))
            distance += sampleSpacing
        }
        if samples.isEmpty { samples = [.zero] }

        var minPoint = samples[0]
        var maxPoint = samples[0]
        for point in samples {
            minPoint = Vector2(min(minPoint.x, point.x), min(minPoint.y, point.y))
            maxPoint = Vector2(max(maxPoint.x, point.x), max(maxPoint.y, point.y))
        }

        let span = maxPoint - minPoint
        let usable = 1 - padding * 2
        // One scale for both axes: squashing the map would misrepresent corners.
        let fit = max(span.x, span.y)
        let mapScale = fit > 1e-6 ? usable / fit : 1

        // Centre whichever axis is the shorter one.
        let scaled = Vector2(span.x * mapScale, span.y * mapScale)
        let mapOffset = Vector2(
            padding + (usable - scaled.x) / 2 - minPoint.x * mapScale,
            padding + (usable - scaled.y) / 2 - minPoint.y * mapScale
        )

        scale = mapScale
        offset = mapOffset
        outline = samples.map { Vector2($0.x * mapScale + mapOffset.x, $0.y * mapScale + mapOffset.y) }
        startLine = Vector2(
            geometry.point(at: 0).x * mapScale + mapOffset.x,
            geometry.point(at: 0).y * mapScale + mapOffset.y
        )
    }

    /// Maps a world position into unit space.
    public func project(_ world: Vector2) -> Vector2 {
        Vector2(world.x * scale + offset.x, world.y * scale + offset.y)
    }

    /// Blips for every cart, player last so it draws on top.
    public func blips(carts: [CartState]) -> [(id: Int, point: Vector2, color: RacerColor, isPlayer: Bool)] {
        carts
            .sorted { !$0.isPlayer && $1.isPlayer }
            .map { (id: $0.id, point: project($0.position), color: $0.racer.primaryColor, isPlayer: $0.isPlayer) }
    }
}
