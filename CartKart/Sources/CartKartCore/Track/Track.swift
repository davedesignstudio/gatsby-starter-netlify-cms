import Foundation

/// What the wheels are rolling over. Supermarket floors are not all equal.
public enum SurfaceKind: String, Sendable, Codable, CaseIterable {
    /// Polished aisle tile. Full grip, full speed.
    case tile
    /// Off the racing lane: rubber matting, spilled cereal, sample stands.
    case rough
    /// Mopped floor or a burst juice carton. Fast but almost no grip.
    case slick
}

/// A single authored point of the racing lane.
public struct TrackControlPoint: Sendable, Codable {
    public var position: Vec2
    /// Distance from the lane centre to the edge of the raceable floor.
    public var halfWidth: Double

    public init(_ position: Vec2, halfWidth: Double) {
        self.position = position
        self.halfWidth = halfWidth
    }

    public init(_ x: Double, _ y: Double, halfWidth: Double) {
        self.init(Vec2(x, y), halfWidth: halfWidth)
    }
}

/// A resampled point on the smoothed centreline.
public struct TrackSample: Sendable {
    public var position: Vec2
    public var halfWidth: Double
    /// Unit tangent pointing in the racing direction.
    public var tangent: Vec2
    /// Distance travelled along the lane to reach this sample.
    public var arcLength: Double
    /// Signed curvature; large magnitude means a tight corner.
    public var curvature: Double
}

/// Where a world position sits relative to the lane.
public struct TrackProjection: Sendable {
    /// Distance along the lane, in `0..<trackLength`.
    public var arcLength: Double
    /// Signed distance from the centreline. Positive is to the left of travel.
    public var lateralOffset: Double
    public var tangent: Vec2
    public var halfWidth: Double
    public var sampleIndex: Int

    /// How far outside the raceable floor the point is (0 when on the lane).
    public var overshoot: Double { max(0, abs(lateralOffset) - halfWidth) }
}

/// A circular feature sprinkled around the course.
public struct TrackFeature: Sendable, Codable {
    public var position: Vec2
    public var radius: Double
    /// Filled in by `Track.init` so the AI can reason about features without
    /// re-projecting them every frame.
    public internal(set) var arcLength: Double = 0
    /// Signed lane offset in half-width units, also precomputed.
    public internal(set) var lane: Double = 0

    public init(_ position: Vec2, radius: Double) {
        self.position = position
        self.radius = radius
    }

    public init(_ x: Double, _ y: Double, radius: Double) {
        self.init(Vec2(x, y), radius: radius)
    }
}

/// A solid thing you should not drive into: pallet stacks, freezer chests, a
/// pyramid of canned peaches.
public struct TrackObstacle: Sendable, Codable {
    public enum Style: String, Sendable, Codable {
        case pallet
        case canPyramid
        case freezer
        case cardboardBin
        case wetFloorSign
    }

    public var position: Vec2
    public var radius: Double
    public var style: Style
    /// Cardboard bins scatter instead of stopping you dead.
    public var isBreakable: Bool

    public init(_ position: Vec2, radius: Double, style: Style, isBreakable: Bool = false) {
        self.position = position
        self.radius = radius
        self.style = style
        self.isBreakable = isBreakable
    }
}

/// A closed-loop supermarket course.
public struct Track: Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    /// Colour/mood hints consumed by the renderer.
    public let theme: TrackTheme
    public let lapCount: Int

    /// Smoothed, evenly spaced centreline samples (closed loop).
    public let samples: [TrackSample]
    public let trackLength: Double

    /// Beyond the raceable floor there is `shoulderWidth` of rough ground, then shelving.
    public let shoulderWidth: Double

    public let boostPads: [TrackFeature]
    public let itemBoxes: [TrackFeature]
    public let puddles: [TrackFeature]
    public let obstacles: [TrackObstacle]

    /// Arc length of the finish line. Always 0 for authored tracks.
    public let finishArcLength: Double = 0

    public init(
        id: String,
        name: String,
        subtitle: String,
        theme: TrackTheme,
        lapCount: Int = 3,
        controlPoints: [TrackControlPoint],
        shoulderWidth: Double = 90,
        sampleSpacing: Double = 12,
        boostPads: [TrackFeature] = [],
        itemBoxes: [TrackFeature] = [],
        puddles: [TrackFeature] = [],
        obstacles: [TrackObstacle] = []
    ) {
        precondition(controlPoints.count >= 4, "A closed track needs at least four control points")
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.theme = theme
        self.lapCount = lapCount
        self.shoulderWidth = shoulderWidth
        self.obstacles = obstacles
        self.samples = Track.resample(controlPoints: controlPoints, spacing: sampleSpacing)
        self.trackLength = (samples.last?.arcLength ?? 0)
            + (samples.last?.position.distance(to: samples[0].position) ?? 0)

        // Cache each feature's place on the lane once, up front, so the AI
        // never has to re-project static furniture while racing.
        let samples = self.samples
        let length = self.trackLength
        func locate(_ feature: TrackFeature) -> TrackFeature {
            var located = feature
            let projection = Track.project(
                feature.position,
                samples: samples,
                trackLength: length,
                shoulderWidth: shoulderWidth,
                hint: nil
            )
            located.arcLength = projection.arcLength
            located.lane = projection.lateralOffset / max(projection.halfWidth, 1)
            return located
        }
        self.boostPads = boostPads.map(locate)
        self.itemBoxes = itemBoxes.map(locate)
        self.puddles = puddles.map(locate)
    }

    // MARK: - Geometry

    /// Turns sparse authored points into a smooth, evenly spaced closed loop
    /// using a centripetal-ish Catmull-Rom spline.
    private static func resample(controlPoints: [TrackControlPoint], spacing: Double) -> [TrackSample] {
        let n = controlPoints.count
        var dense: [(position: Vec2, halfWidth: Double)] = []
        // Sub-steps per authored segment; the extra density is thrown away by
        // the arc-length pass below but keeps the spline faithful.
        let steps = 24
        for i in 0..<n {
            let p0 = controlPoints[(i - 1 + n) % n]
            let p1 = controlPoints[i]
            let p2 = controlPoints[(i + 1) % n]
            let p3 = controlPoints[(i + 2) % n]
            for s in 0..<steps {
                let t = Double(s) / Double(steps)
                dense.append((
                    catmullRom(p0.position, p1.position, p2.position, p3.position, t),
                    catmullRomScalar(p0.halfWidth, p1.halfWidth, p2.halfWidth, p3.halfWidth, t)
                ))
            }
        }

        // Walk the dense polyline and emit a point every `spacing` units.
        var evenPositions: [(position: Vec2, halfWidth: Double)] = []
        var carry = 0.0
        for i in 0..<dense.count {
            let a = dense[i]
            let b = dense[(i + 1) % dense.count]
            let segment = a.position.distance(to: b.position)
            guard segment > 1e-9 else { continue }
            var travelled = carry
            while travelled < segment {
                let t = travelled / segment
                evenPositions.append((
                    a.position + (b.position - a.position) * t,
                    lerp(a.halfWidth, b.halfWidth, t)
                ))
                travelled += spacing
            }
            carry = travelled - segment
        }

        // Build samples with tangents, arc length and curvature.
        let count = evenPositions.count
        var samples: [TrackSample] = []
        samples.reserveCapacity(count)
        var arc = 0.0
        for i in 0..<count {
            let previous = evenPositions[(i - 1 + count) % count].position
            let current = evenPositions[i].position
            let next = evenPositions[(i + 1) % count].position
            let tangent = (next - previous).normalized
            let inbound = (current - previous).normalized
            let outbound = (next - current).normalized
            let segmentLength = max(current.distance(to: next), 1e-6)
            let curvature = Angle.delta(from: inbound.angle, to: outbound.angle) / segmentLength
            samples.append(
                TrackSample(
                    position: current,
                    halfWidth: evenPositions[i].halfWidth,
                    tangent: tangent,
                    arcLength: arc,
                    curvature: curvature
                )
            )
            arc += segmentLength
        }
        return samples
    }

    private static func catmullRom(_ p0: Vec2, _ p1: Vec2, _ p2: Vec2, _ p3: Vec2, _ t: Double) -> Vec2 {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            2 * p1
                + (p2 - p0) * t
                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                + (3 * p1 - p0 - 3 * p2 + p3) * t3
        )
    }

    private static func catmullRomScalar(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ t: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
    }

    public func sample(at index: Int) -> TrackSample {
        samples[((index % samples.count) + samples.count) % samples.count]
    }

    /// Index of the centreline sample nearest to `point`.
    ///
    /// `hint` restricts the search to a window around a previously known index,
    /// which is both faster and avoids snapping across a hairpin.
    public func nearestSampleIndex(to point: Vec2, hint: Int? = nil) -> Int {
        Track.nearestSampleIndex(to: point, samples: samples, shoulderWidth: shoulderWidth, hint: hint)
    }

    private static func nearestSampleIndex(
        to point: Vec2,
        samples: [TrackSample],
        shoulderWidth: Double,
        hint: Int?
    ) -> Int {
        let count = samples.count
        if let hint {
            let window = max(12, count / 12)
            var bestIndex = hint
            var bestDistance = Double.greatestFiniteMagnitude
            for offset in -window...window {
                let index = ((hint + offset) % count + count) % count
                let d = samples[index].position.distance(to: point)
                if d < bestDistance {
                    bestDistance = d
                    bestIndex = index
                }
            }
            // Only trust the local answer if we are plausibly near the lane;
            // otherwise fall through to the global search.
            if bestDistance < samples[bestIndex].halfWidth + shoulderWidth + 240 {
                return bestIndex
            }
        }
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, sample) in samples.enumerated() {
            let d = sample.position.distance(to: point)
            if d < bestDistance {
                bestDistance = d
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Projects a world position onto the lane.
    public func project(_ point: Vec2, hint: Int? = nil) -> TrackProjection {
        Track.project(
            point,
            samples: samples,
            trackLength: trackLength,
            shoulderWidth: shoulderWidth,
            hint: hint
        )
    }

    private static func project(
        _ point: Vec2,
        samples: [TrackSample],
        trackLength: Double,
        shoulderWidth: Double,
        hint: Int?
    ) -> TrackProjection {
        let index = nearestSampleIndex(to: point, samples: samples, shoulderWidth: shoulderWidth, hint: hint)
        let count = samples.count
        // Test the segments on both sides of the nearest sample and keep the closer one.
        var best: (index: Int, t: Double, distance: Double) = (index, 0, .greatestFiniteMagnitude)
        for candidate in [((index - 1) + count) % count, index] {
            let a = samples[candidate]
            let b = samples[(candidate + 1) % count]
            let segment = b.position - a.position
            let lengthSquared = max(segment.lengthSquared, 1e-9)
            let t = clamp((point - a.position).dot(segment) / lengthSquared, 0, 1)
            let closest = a.position + segment * t
            let d = closest.distance(to: point)
            if d < best.distance { best = (candidate, t, d) }
        }

        let a = samples[best.index]
        let b = samples[(best.index + 1) % count]
        let segment = b.position - a.position
        let tangent = segment.normalized
        let closest = a.position + segment * best.t
        let offset = point - closest
        let lateral = offset.dot(tangent.perpendicular)
        var arc = a.arcLength + segment.length * best.t
        if arc >= trackLength { arc -= trackLength }

        return TrackProjection(
            arcLength: arc,
            lateralOffset: lateral,
            tangent: tangent,
            halfWidth: lerp(a.halfWidth, b.halfWidth, best.t),
            sampleIndex: best.index
        )
    }

    /// Centreline position `distance` further along the lane from `arcLength`.
    public func position(atArcLength arcLength: Double) -> Vec2 {
        let count = samples.count
        let wrapped = wrapArcLength(arcLength)
        let approximateIndex = Int(wrapped / max(trackLength / Double(count), 1e-6))
        var index = clamp(approximateIndex, 0, count - 1)
        // Nudge to the segment that actually contains `wrapped`.
        while samples[index].arcLength > wrapped && index > 0 { index -= 1 }
        while index + 1 < count && samples[index + 1].arcLength <= wrapped { index += 1 }
        let a = samples[index]
        let b = samples[(index + 1) % count]
        let span = max((b.arcLength > a.arcLength ? b.arcLength : trackLength) - a.arcLength, 1e-6)
        let t = clamp((wrapped - a.arcLength) / span, 0, 1)
        return a.position + (b.position - a.position) * t
    }

    public func halfWidth(atArcLength arcLength: Double) -> Double {
        let index = sampleIndex(atArcLength: arcLength)
        return samples[index].halfWidth
    }

    public func sampleIndex(atArcLength arcLength: Double) -> Int {
        let count = samples.count
        let wrapped = wrapArcLength(arcLength)
        var index = clamp(Int(wrapped / max(trackLength / Double(count), 1e-6)), 0, count - 1)
        while samples[index].arcLength > wrapped && index > 0 { index -= 1 }
        while index + 1 < count && samples[index + 1].arcLength <= wrapped { index += 1 }
        return index
    }

    public func wrapArcLength(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: trackLength)
        if v < 0 { v += trackLength }
        return v
    }

    /// Signed lap-forward distance from `from` to `to`, in `-length/2 ... length/2`.
    public func arcDelta(from: Double, to: Double) -> Double {
        var d = to - from
        while d > trackLength / 2 { d -= trackLength }
        while d < -trackLength / 2 { d += trackLength }
        return d
    }

    /// Surface under a world position (ignores dynamic hazards).
    public func surface(at point: Vec2, hint: Int? = nil) -> SurfaceKind {
        for puddle in puddles where puddle.position.distance(to: point) < puddle.radius {
            return .slick
        }
        let projection = project(point, hint: hint)
        return abs(projection.lateralOffset) <= projection.halfWidth ? .tile : .rough
    }

    /// Starting grid: two-by-two behind the finish line, pole position first.
    public func startingGrid(count: Int) -> [(position: Vec2, heading: Double)] {
        var grid: [(Vec2, Double)] = []
        for slot in 0..<count {
            let row = slot / 2
            let column = slot % 2
            let back = 70.0 + Double(row) * 78.0
            let arc = wrapArcLength(finishArcLength - back)
            let index = sampleIndex(atArcLength: arc)
            let sample = samples[index]
            let lateral = (column == 0 ? -1.0 : 1.0) * min(sample.halfWidth * 0.45, 46)
            let position = sample.position + sample.tangent.perpendicular * lateral
            grid.append((position, sample.tangent.angle))
        }
        return grid
    }
}

/// Renderer-facing palette and dressing for a course.
public struct TrackTheme: Sendable, Codable {
    public struct RGB: Sendable, Codable, Hashable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    public var floor: RGB
    public var rough: RGB
    public var shelf: RGB
    public var accent: RGB
    /// Text shown on the loading card, e.g. "Mind the wet floor".
    public var tagline: String

    public init(floor: RGB, rough: RGB, shelf: RGB, accent: RGB, tagline: String) {
        self.floor = floor
        self.rough = rough
        self.shelf = shelf
        self.accent = accent
        self.tagline = tagline
    }
}
