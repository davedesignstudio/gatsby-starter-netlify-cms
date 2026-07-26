import Foundation

/// Precomputed centreline maths. Everything the simulation needs to know about
/// where a cart is — lap progress, how far off the racing line it has drifted,
/// which floor it is on — comes from `location(of:)`.
public struct TrackGeometry: Sendable {
    public struct Segment: Sendable {
        public let start: Vector2
        public let end: Vector2
        /// Unit vector from start to end.
        public let direction: Vector2
        public let length: Double
        /// Arc length from the start line to `start`.
        public let startDistance: Double
        public let startHalfWidth: Double
        public let endHalfWidth: Double
        public let surface: Surface
    }

    /// Progress along the loop, plus everything about the cart's relationship to
    /// the centreline at that point.
    public struct Location: Sendable {
        /// Arc length from the start line, in `0..<totalLength`.
        public let distance: Double
        /// Signed offset from the centreline; positive is left of travel.
        public let lateral: Double
        public let centre: Vector2
        public let tangentAngle: Double
        public let halfWidth: Double
        public let surface: Surface
        public let segmentIndex: Int

        /// How far outside the racing surface the cart is (0 when on track).
        public var overhang: Double { max(0, abs(lateral) - halfWidth) }
    }

    public let segments: [Segment]
    public let totalLength: Double
    public let nodes: [TrackNode]
    /// Axis-aligned bounds of the centreline, handy for cameras and minimaps.
    public let bounds: (min: Vector2, max: Vector2)

    public init(nodes: [TrackNode]) {
        precondition(nodes.count >= 3, "A track needs at least three centreline nodes")
        self.nodes = nodes

        var built: [Segment] = []
        built.reserveCapacity(nodes.count)
        var cumulative = 0.0
        var minPoint = nodes[0].position
        var maxPoint = nodes[0].position

        for index in nodes.indices {
            let node = nodes[index]
            let next = nodes[(index + 1) % nodes.count]
            let delta = next.position - node.position
            let length = delta.length
            // Degenerate samples would poison the projection maths.
            precondition(length > 1e-6, "Duplicate centreline nodes at index \(index)")
            built.append(
                Segment(
                    start: node.position,
                    end: next.position,
                    direction: delta / length,
                    length: length,
                    startDistance: cumulative,
                    startHalfWidth: node.halfWidth,
                    endHalfWidth: next.halfWidth,
                    surface: node.surface
                )
            )
            cumulative += length
            minPoint = Vector2(min(minPoint.x, node.position.x), min(minPoint.y, node.position.y))
            maxPoint = Vector2(max(maxPoint.x, node.position.x), max(maxPoint.y, node.position.y))
        }

        segments = built
        totalLength = cumulative
        bounds = (minPoint, maxPoint)
    }

    /// Wraps an arc length into `0..<totalLength`.
    public func wrap(_ distance: Double) -> Double {
        var value = distance.remainder(dividingBy: totalLength)
        if value < 0 { value += totalLength }
        // `remainder` can return exactly totalLength/2 boundaries; guard anyway.
        if value >= totalLength { value -= totalLength }
        return value
    }

    /// Shortest signed distance from `a` to `b` around the loop, in
    /// `-totalLength/2 ... totalLength/2`. Positive means `b` is ahead of `a`.
    public func signedGap(from a: Double, to b: Double) -> Double {
        var delta = wrap(b) - wrap(a)
        if delta > totalLength / 2 { delta -= totalLength }
        if delta < -totalLength / 2 { delta += totalLength }
        return delta
    }

    public func segmentIndex(at distance: Double) -> Int {
        let target = wrap(distance)
        // Binary search over segment start distances.
        var low = 0
        var high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startDistance <= target {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public func point(at distance: Double) -> Vector2 {
        let index = segmentIndex(at: distance)
        let segment = segments[index]
        let along = Scalar.clamp(wrap(distance) - segment.startDistance, 0, segment.length)
        return segment.start + segment.direction * along
    }

    public func tangentAngle(at distance: Double) -> Double {
        segments[segmentIndex(at: distance)].direction.angle
    }

    public func tangent(at distance: Double) -> Vector2 {
        segments[segmentIndex(at: distance)].direction
    }

    public func halfWidth(at distance: Double) -> Double {
        let index = segmentIndex(at: distance)
        let segment = segments[index]
        let t = segment.length > 0 ? Scalar.clamp((wrap(distance) - segment.startDistance) / segment.length, 0, 1) : 0
        return Scalar.lerp(segment.startHalfWidth, segment.endHalfWidth, t)
    }

    public func surface(at distance: Double) -> Surface {
        segments[segmentIndex(at: distance)].surface
    }

    /// A point offset sideways from the centreline; positive `lateral` is left.
    public func position(at distance: Double, lateral: Double) -> Vector2 {
        let index = segmentIndex(at: distance)
        let segment = segments[index]
        let along = Scalar.clamp(wrap(distance) - segment.startDistance, 0, segment.length)
        let centre = segment.start + segment.direction * along
        return centre + segment.direction.perpendicular * lateral
    }

    /// Same as `position(at:lateral:)` but addressed by normalised lap progress,
    /// which is how course features are authored.
    public func position(progress: Double, lateral: Double) -> Vector2 {
        position(at: wrap(progress * totalLength), lateral: lateral)
    }

    /// Signed curvature over a window, in radians per metre. Positive turns left.
    public func curvature(at distance: Double, window: Double = 12) -> Double {
        let ahead = tangentAngle(at: distance + window)
        let behind = tangentAngle(at: distance)
        return Scalar.angleDelta(from: behind, to: ahead) / window
    }

    /// Worst curvature found between `distance` and `distance + range`, used by
    /// the AI to decide how early to lift off.
    public func maxAbsCurvature(at distance: Double, range: Double, step: Double = 4) -> Double {
        var worst = 0.0
        var offset = 0.0
        while offset < range {
            worst = max(worst, abs(curvature(at: distance + offset, window: max(step, 6))))
            offset += step
        }
        return worst
    }

    /// Projects a world point onto the centreline.
    ///
    /// - Parameter hint: the segment index the point was near last frame. The
    ///   search stays local when possible, which keeps the per-cart cost flat
    ///   regardless of how dense the centreline is.
    public func location(of point: Vector2, hint: Int? = nil) -> Location {
        let count = segments.count
        if let hint, count > 24 {
            let window = 10
            let centre = ((hint % count) + count) % count
            var best = centre
            var bestDistance = Double.infinity
            for offset in -window...window {
                let index = ((centre + offset) % count + count) % count
                let distance = distanceSquared(from: point, toSegment: index)
                if distance < bestDistance {
                    bestDistance = distance
                    best = index
                }
            }

            // A local minimum is not necessarily the nearest point on the lap: a
            // stale hint (after a respawn, or an express-lane trip) can settle on
            // the far side of the course. A coarse sweep of the whole loop is
            // cheap and proves the local answer is at least the closest of the
            // samples, which is enough to rule that out.
            let coarseStride = max(1, count / 16)
            var coarseBest = Double.infinity
            for index in stride(from: 0, to: count, by: coarseStride) {
                coarseBest = min(coarseBest, distanceSquared(from: point, toSegment: index))
            }
            if bestDistance <= coarseBest {
                return makeLocation(point: point, segmentIndex: best)
            }
        }

        var best = 0
        var bestDistance = Double.infinity
        for index in segments.indices {
            let distance = distanceSquared(from: point, toSegment: index)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return makeLocation(point: point, segmentIndex: best)
    }

    private func distanceSquared(from point: Vector2, toSegment index: Int) -> Double {
        let segment = segments[index]
        let relative = point - segment.start
        let along = Scalar.clamp(relative.dot(segment.direction), 0, segment.length)
        let closest = segment.start + segment.direction * along
        return (point - closest).lengthSquared
    }

    private func makeLocation(point: Vector2, segmentIndex index: Int) -> Location {
        let segment = segments[index]
        let relative = point - segment.start
        let rawAlong = relative.dot(segment.direction)
        let along = Scalar.clamp(rawAlong, 0, segment.length)
        let centre = segment.start + segment.direction * along
        let lateral = segment.direction.cross(point - segment.start)
        let t = segment.length > 0 ? along / segment.length : 0
        return Location(
            distance: wrap(segment.startDistance + along),
            lateral: lateral,
            centre: centre,
            tangentAngle: segment.direction.angle,
            halfWidth: Scalar.lerp(segment.startHalfWidth, segment.endHalfWidth, t),
            surface: segment.surface,
            segmentIndex: index
        )
    }
}
