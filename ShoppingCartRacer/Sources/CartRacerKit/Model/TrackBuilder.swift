import Foundation

/// Authoring helpers. Courses are written as a handful of control points and
/// resampled into the dense centreline the simulation wants, so a track author
/// never has to type out hundreds of coordinates.
public enum TrackBuilder {
    public struct ControlPoint: Sendable {
        public var position: Vector2
        public var halfWidth: Double
        public var surface: Surface

        public init(position: Vector2, halfWidth: Double, surface: Surface) {
            self.position = position
            self.halfWidth = halfWidth
            self.surface = surface
        }
    }

    /// Resamples a closed loop of control points through a Catmull-Rom spline.
    ///
    /// - Parameter resolution: target spacing between output nodes, in metres.
    public static func centreline(from controlPoints: [ControlPoint], resolution: Double = 1.6) -> [TrackNode] {
        precondition(controlPoints.count >= 4, "Catmull-Rom needs at least four control points")
        let count = controlPoints.count
        var nodes: [TrackNode] = []
        nodes.reserveCapacity(count * 6)

        for index in 0..<count {
            let p0 = controlPoints[(index - 1 + count) % count].position
            let c1 = controlPoints[index]
            let c2 = controlPoints[(index + 1) % count]
            let p3 = controlPoints[(index + 2) % count].position

            let approximateLength = c1.position.distance(to: c2.position)
            let steps = max(2, Int((approximateLength / resolution).rounded(.up)))
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let position = catmullRom(p0, c1.position, c2.position, p3, t)
                nodes.append(
                    TrackNode(
                        position: position,
                        halfWidth: Scalar.lerp(c1.halfWidth, c2.halfWidth, t),
                        // Surface changes at control points rather than blending,
                        // which is what makes spill patches read as distinct.
                        surface: c1.surface
                    )
                )
            }
        }

        return dedupe(nodes)
    }

    private static func catmullRom(_ p0: Vector2, _ p1: Vector2, _ p2: Vector2, _ p3: Vector2, _ t: Double) -> Vector2 {
        let t2 = t * t
        let t3 = t2 * t
        let a = p1 * 2.0
        let b = p2 - p0
        let c = p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3
        let d = -p0 + p1 * 3.0 - p2 * 3.0 + p3
        return (a + b * t + c * t2 + d * t3) * 0.5
    }

    private static func dedupe(_ nodes: [TrackNode]) -> [TrackNode] {
        var result: [TrackNode] = []
        result.reserveCapacity(nodes.count)
        for node in nodes {
            if let last = result.last, last.position.distance(to: node.position) < 0.05 { continue }
            result.append(node)
        }
        // The loop closes, so the final node must not sit on top of the first.
        if let first = result.first, let last = result.last,
           result.count > 3, first.position.distance(to: last.position) < 0.05 {
            result.removeLast()
        }
        return result
    }

    /// Sketches a loop with a pen that walks straights and arcs. Good for the
    /// boxy, aisle-shaped courses inside the store.
    public struct Pen {
        public private(set) var points: [ControlPoint] = []
        public var halfWidth: Double
        public var surface: Surface

        public init(halfWidth: Double, surface: Surface) {
            self.halfWidth = halfWidth
            self.surface = surface
        }

        public mutating func add(_ position: Vector2) {
            points.append(ControlPoint(position: position, halfWidth: halfWidth, surface: surface))
        }

        /// Straight run, excluding the end point so the next command owns it.
        public mutating func line(from start: Vector2, to end: Vector2, spacing: Double = 14) {
            let distance = start.distance(to: end)
            let steps = max(1, Int((distance / spacing).rounded()))
            for step in 0..<steps {
                add(Vector2.lerp(start, end, Double(step) / Double(steps)))
            }
        }

        /// Circular arc; angles in radians, swept from `startAngle` to `endAngle`.
        public mutating func arc(
            centre: Vector2,
            radius: Double,
            startAngle: Double,
            endAngle: Double,
            spacing: Double = 10
        ) {
            let sweep = endAngle - startAngle
            let arcLength = abs(sweep) * radius
            let steps = max(2, Int((arcLength / spacing).rounded(.up)))
            for step in 0..<steps {
                let angle = startAngle + sweep * Double(step) / Double(steps)
                add(centre + Vector2(angle: angle, length: radius))
            }
        }
    }

    /// Builds an organic closed loop from a polar radius function. Because the
    /// radius stays positive the result can never cross itself, which keeps the
    /// centreline projection unambiguous.
    ///
    /// - Parameters:
    ///   - harmonics: `(k, amplitude, phase)` terms added to the base radius.
    ///   - aspect: horizontal stretch; an affine scale, so still no crossings.
    ///   - describe: per-angle width and surface, given normalised progress.
    public static func polarLoop(
        baseRadius: Double,
        harmonics: [(k: Int, amplitude: Double, phase: Double)],
        aspect: Double = 1.0,
        samples: Int = 48,
        centre: Vector2 = .zero,
        describe: (Double) -> (halfWidth: Double, surface: Surface)
    ) -> [ControlPoint] {
        precondition(samples >= 8, "Too few samples for a smooth loop")
        var points: [ControlPoint] = []
        points.reserveCapacity(samples)
        for index in 0..<samples {
            let progress = Double(index) / Double(samples)
            let theta = progress * 2 * .pi
            var radius = baseRadius
            for harmonic in harmonics {
                radius += harmonic.amplitude * cos(Double(harmonic.k) * theta + harmonic.phase)
            }
            precondition(radius > 1, "Polar loop radius collapsed at progress \(progress)")
            let description = describe(progress)
            let position = centre + Vector2(cos(theta) * radius * aspect, sin(theta) * radius)
            points.append(
                ControlPoint(position: position, halfWidth: description.halfWidth, surface: description.surface)
            )
        }
        return points
    }
}

/// Places course features relative to the centreline, because "35% of the way
/// round, three metres left" is far easier to author than raw world coordinates.
public struct TrackDresser {
    private let geometry: TrackGeometry

    public init(geometry: TrackGeometry) {
        self.geometry = geometry
    }

    public func position(progress: Double, lateral: Double) -> Vector2 {
        geometry.position(progress: progress, lateral: lateral)
    }

    /// A row of item crates spread across the track at one point on the lap.
    public func itemRow(progress: Double, lateralOffsets: [Double]) -> [ItemBoxSpawn] {
        lateralOffsets.map { ItemBoxSpawn(position: position(progress: progress, lateral: $0)) }
    }

    /// A line of tokens running along the track, hugging one side.
    public func tokenTrail(
        from startProgress: Double,
        to endProgress: Double,
        count: Int,
        lateral: Double,
        lateralEnd: Double? = nil
    ) -> [TokenSpawn] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let t = count == 1 ? 0 : Double(index) / Double(count - 1)
            let progress = Scalar.lerp(startProgress, endProgress, t)
            let offset = Scalar.lerp(lateral, lateralEnd ?? lateral, t)
            return TokenSpawn(position: position(progress: progress, lateral: offset))
        }
    }

    public func obstacle(progress: Double, lateral: Double, kind: Obstacle.Kind, radius: Double = 1.1) -> Obstacle {
        Obstacle(position: position(progress: progress, lateral: lateral), radius: radius, kind: kind)
    }

    /// A chicane of props that forces a line change.
    public func obstacleCluster(
        progress: Double,
        lateralOffsets: [Double],
        kind: Obstacle.Kind,
        spacing: Double = 0.012,
        radius: Double = 1.1
    ) -> [Obstacle] {
        lateralOffsets.enumerated().map { index, lateral in
            obstacle(
                progress: progress + Double(index) * spacing,
                lateral: lateral,
                kind: kind,
                radius: radius
            )
        }
    }

    public func boostPad(progress: Double, lateral: Double, duration: Double = 1.1) -> BoostPad {
        BoostPad(position: position(progress: progress, lateral: lateral), duration: duration)
    }

    /// Side-by-side pads so the boost is hard to miss.
    public func boostStrip(progress: Double, lateralOffsets: [Double], duration: Double = 1.1) -> [BoostPad] {
        lateralOffsets.map { boostPad(progress: progress, lateral: $0, duration: duration) }
    }
}
