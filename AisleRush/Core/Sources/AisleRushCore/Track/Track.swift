import Foundation

/// Where a point sits relative to the course.
public struct TrackProjection: Sendable {
    /// Arc length along the centreline, metres from the start line.
    public var distance: Double
    /// Signed offset from the centreline; positive is to the left of travel.
    public var lateral: Double
    public var closestPoint: Vector2
    public var tangent: Vector2
    /// Index of the centreline sample the projection landed on.
    public var sampleIndex: Int
}

/// A `TrackDefinition` baked into the uniformly sampled form the simulation
/// queries every tick: Catmull-Rom smoothed, resampled at a fixed spacing so
/// arc length maps straight onto an array index.
public final class Track: @unchecked Sendable {
    public let definition: TrackDefinition
    public let centerline: [Vector2]
    public let halfWidths: [Double]
    public let tangents: [Vector2]
    /// Signed curvature per sample, 1/m. Positive turns left.
    public let curvatures: [Double]
    /// Lateral offset of the suggested racing line, metres.
    public let racingLineOffsets: [Double]
    /// Comfortable cornering speed per sample, m/s.
    public let speedLimits: [Double]
    public let sampleSpacing: Double
    public let length: Double

    public let itemBoxes: [ItemBox]
    public let props: [PlacedProp]
    public let boostZones: [BoostZone]

    /// Ordered gates a cart must pass to bank a lap.
    public let checkpointCount: Int

    public struct ItemBox: Sendable {
        public var position: Vector2
        public var radius: Double = 1.5
    }

    public struct PlacedProp: Sendable {
        public var kind: StaticProp.Kind
        public var position: Vector2
        public var angle: Double
        public var radius: Double
        public var isSolid: Bool
    }

    public struct BoostZone: Sendable {
        public var position: Vector2
        public var angle: Double
        public var length: Double
        public var width: Double
    }

    public init(definition: TrackDefinition, sampleSpacing targetSpacing: Double = 1.0) {
        self.definition = definition

        let fine = Track.smoothClosedPath(definition.controlPoints, subdivisions: 16)
        let resampled = Track.resampleUniformly(fine, targetSpacing: targetSpacing)
        centerline = resampled.points
        halfWidths = resampled.halfWidths
        sampleSpacing = resampled.spacing
        length = resampled.spacing * Double(resampled.points.count)

        let count = centerline.count
        var tangentBuffer = [Vector2](repeating: .zero, count: count)
        for i in 0..<count {
            let next = centerline[(i + 1) % count]
            let prev = centerline[(i - 1 + count) % count]
            tangentBuffer[i] = (next - prev).normalized
        }
        tangents = tangentBuffer

        var curvatureBuffer = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let ahead = tangentBuffer[(i + 1) % count].angle
            let behind = tangentBuffer[(i - 1 + count) % count].angle
            curvatureBuffer[i] = Angle.delta(from: behind, to: ahead) / (2 * resampled.spacing)
        }
        curvatureBuffer = Track.smoothWrapped(curvatureBuffer, radius: max(2, Int(3 / resampled.spacing)))
        curvatures = curvatureBuffer

        // Cut the corner in proportion to how sharp it is, then smooth hard so
        // the AI is not asked to swerve between neighbouring samples.
        var offsets = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let k = curvatureBuffer[i]
            let maxCut = halfWidths[i] * 0.55
            offsets[i] = clamp(k * 120, -1, 1) * maxCut
        }
        offsets = Track.smoothWrapped(offsets, radius: max(4, Int(10 / resampled.spacing)))

        // Steer the racing line around anything solid. Doing it here means
        // every driver inherits the avoidance instead of discovering the
        // pallet with its front wheels.
        let approach = max(4, Int(16 / resampled.spacing))
        let departure = max(2, Int(7 / resampled.spacing))
        for prop in definition.props where prop.isSolid {
            let center = Track.index(forProgress: prop.progress, count: count)
            let clearance = prop.radius + 2.4
            let half = halfWidths[center]
            let roomLeft = half - (prop.lateralOffset + clearance)
            let roomRight = (prop.lateralOffset - clearance) + half
            let passLeft = roomLeft > roomRight
            let gate = passLeft ? prop.lateralOffset + clearance : prop.lateralOffset - clearance

            for step in -approach...departure {
                let i = ((center + step) % count + count) % count
                let reach = Double(step < 0 ? approach : departure)
                let falloff = 1 - Double(abs(step)) / (reach + 1)
                let limit = halfWidths[i] * 0.86
                let bounded = clamp(gate, -limit, limit)
                let target = passLeft ? max(offsets[i], bounded) : min(offsets[i], bounded)
                offsets[i] += (target - offsets[i]) * falloff
            }
        }
        offsets = Track.smoothWrapped(offsets, radius: max(2, Int(4 / resampled.spacing)))
        for i in 0..<count {
            offsets[i] = clamp(offsets[i], -halfWidths[i] * 0.9, halfWidths[i] * 0.9)
        }
        racingLineOffsets = offsets

        // v = sqrt(a_lat / |k|), with a floor so straights are unrestricted.
        let lateralGrip = 26.0
        var limits = [Double](repeating: 90, count: count)
        for i in 0..<count {
            let k = abs(curvatureBuffer[i])
            limits[i] = k < 1e-4 ? 90 : min(90, (lateralGrip / k).squareRoot())
        }
        // A corner limits the approach to it, so sweep the limit backwards.
        let braking = 9.0
        for _ in 0..<3 {
            for step in 0..<count {
                let i = count - 1 - step
                let ahead = limits[(i + 1) % count]
                let reachable = (ahead * ahead + 2 * braking * resampled.spacing).squareRoot()
                limits[i] = min(limits[i], reachable)
            }
        }
        speedLimits = limits

        let line = resampled.points
        var boxes: [ItemBox] = []
        for row in definition.itemBoxRows {
            let index = Track.index(forProgress: row.progress, count: count)
            let base = line[index]
            let normal = tangentBuffer[index].perpendicular
            for offset in row.lateralOffsets {
                boxes.append(ItemBox(position: base + normal * offset))
            }
        }
        itemBoxes = boxes

        props = definition.props.map { prop in
            let index = Track.index(forProgress: prop.progress, count: count)
            let normal = tangentBuffer[index].perpendicular
            return PlacedProp(
                kind: prop.kind,
                position: line[index] + normal * prop.lateralOffset,
                angle: tangentBuffer[index].angle,
                radius: prop.radius,
                isSolid: prop.isSolid
            )
        }

        boostZones = definition.boostStrips.map { strip in
            let index = Track.index(forProgress: strip.progress, count: count)
            let normal = tangentBuffer[index].perpendicular
            return BoostZone(
                position: line[index] + normal * strip.lateralOffset,
                angle: tangentBuffer[index].angle,
                length: strip.length,
                width: strip.width
            )
        }

        checkpointCount = max(8, Int(length / 40))
    }

    // MARK: - Sampling

    public var sampleCount: Int { centerline.count }

    private static func index(forProgress progress: Double, count: Int) -> Int {
        let wrapped = progress - progress.rounded(.down)
        return min(count - 1, Int(wrapped * Double(count)))
    }

    /// Wraps a distance into 0..<length.
    public func wrap(_ distance: Double) -> Double {
        var d = distance.truncatingRemainder(dividingBy: length)
        if d < 0 { d += length }
        return d
    }

    /// Shortest signed distance from `a` to `b` around the loop.
    public func signedGap(from a: Double, to b: Double) -> Double {
        var d = wrap(b) - wrap(a)
        if d > length / 2 { d -= length }
        if d < -length / 2 { d += length }
        return d
    }

    public func sampleIndex(atDistance distance: Double) -> Int {
        let d = wrap(distance)
        return min(sampleCount - 1, Int(d / sampleSpacing))
    }

    public func point(atDistance distance: Double) -> Vector2 {
        interpolate(distance) { self.centerline[$0] }
    }

    public func tangent(atDistance distance: Double) -> Vector2 {
        let i = sampleIndex(atDistance: distance)
        return tangents[i]
    }

    public func halfWidth(atDistance distance: Double) -> Double {
        interpolateScalar(distance) { self.halfWidths[$0] }
    }

    public func curvature(atDistance distance: Double) -> Double {
        interpolateScalar(distance) { self.curvatures[$0] }
    }

    public func speedLimit(atDistance distance: Double) -> Double {
        interpolateScalar(distance) { self.speedLimits[$0] }
    }

    /// Lateral offset of the racing line from the centreline.
    public func racingLineOffset(atDistance distance: Double) -> Double {
        interpolateScalar(distance) { self.racingLineOffsets[$0] }
    }

    /// A point on the suggested racing line, optionally nudged sideways.
    public func racingLinePoint(atDistance distance: Double, extraOffset: Double = 0) -> Vector2 {
        let offset = interpolateScalar(distance) { self.racingLineOffsets[$0] } + extraOffset
        let base = point(atDistance: distance)
        let normal = tangent(atDistance: distance).perpendicular
        return base + normal * offset
    }

    /// World position for a distance/lateral pair.
    public func position(distance: Double, lateral: Double) -> Vector2 {
        point(atDistance: distance) + tangent(atDistance: distance).perpendicular * lateral
    }

    private func interpolate(_ distance: Double, _ get: (Int) -> Vector2) -> Vector2 {
        let d = wrap(distance)
        let raw = d / sampleSpacing
        let i = min(sampleCount - 1, Int(raw))
        let t = raw - Double(i)
        return Vector2.lerp(get(i), get((i + 1) % sampleCount), t)
    }

    private func interpolateScalar(_ distance: Double, _ get: (Int) -> Double) -> Double {
        let d = wrap(distance)
        let raw = d / sampleSpacing
        let i = min(sampleCount - 1, Int(raw))
        let t = raw - Double(i)
        let a = get(i), b = get((i + 1) % sampleCount)
        return a + (b - a) * t
    }

    // MARK: - Projection

    /// Finds where `point` sits on the course. Passing the previous result as
    /// `hint` turns the search into a short local scan.
    public func project(_ point: Vector2, hint: Int? = nil) -> TrackProjection {
        let count = sampleCount
        if let hint, count > 64 {
            let window = 40
            if let local = search(point, from: hint - window, through: hint + window) {
                // Reject the local answer if it looks like the cart teleported
                // (respawn, or a hint from a different part of the lap).
                if abs(local.lateral) < halfWidths[local.sampleIndex] + definition.shoulderWidth + 25 {
                    return local
                }
            }
        }
        return search(point, from: 0, through: count - 1) ?? TrackProjection(
            distance: 0,
            lateral: 0,
            closestPoint: centerline[0],
            tangent: tangents[0],
            sampleIndex: 0
        )
    }

    private func search(_ point: Vector2, from start: Int, through end: Int) -> TrackProjection? {
        let count = sampleCount
        var best: TrackProjection?
        var bestDistanceSquared = Double.infinity
        var index = start
        while index <= end {
            let i = ((index % count) + count) % count
            let a = centerline[i]
            let b = centerline[(i + 1) % count]
            let segment = b - a
            let lengthSquared = segment.lengthSquared
            guard lengthSquared > 1e-12 else { index += 1; continue }
            let t = clamp((point - a).dot(segment) / lengthSquared, 0, 1)
            let closest = a + segment * t
            let distanceSquared = (point - closest).lengthSquared
            if distanceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                let direction = segment.normalized
                best = TrackProjection(
                    distance: wrap(Double(i) * sampleSpacing + t * sampleSpacing),
                    lateral: (point - closest).dot(direction.perpendicular),
                    closestPoint: closest,
                    tangent: direction,
                    sampleIndex: i
                )
            }
            index += 1
        }
        return best
    }

    // MARK: - Surfaces

    public func surface(atDistance distance: Double, lateral: Double) -> Surface {
        let half = halfWidth(atDistance: distance)
        let absolute = abs(lateral)

        for zone in boostZones {
            let local = (position(distance: distance, lateral: lateral) - zone.position).rotated(by: -zone.angle)
            if abs(local.x) <= zone.length / 2, abs(local.y) <= zone.width / 2 {
                return .boostStrip
            }
        }

        if absolute <= half {
            let progress = wrap(distance) / length
            let band = lateral / max(half, 0.001)
            for patch in definition.surfacePatches where patch.lateralBand.contains(band) {
                if patch.progress.contains(progress) { return patch.surface }
                // Patches are allowed to wrap past the start line.
                if patch.progress.upperBound > 1, patch.progress.contains(progress + 1) { return patch.surface }
            }
            return .linoleum
        }
        return .scuffed
    }

    /// Absolute lateral distance at which the shelving starts.
    public func wallDistance(atDistance distance: Double) -> Double {
        halfWidth(atDistance: distance) + definition.shoulderWidth
    }

    // MARK: - Grid

    /// Staggered starting slots behind the line, two carts per row.
    public func startingSlot(_ index: Int, of total: Int) -> (position: Vector2, heading: Double) {
        let row = index / 2
        let side = index % 2 == 0 ? -1.0 : 1.0
        let back = -(6.0 + Double(row) * 5.0)
        let distance = wrap(back)
        let half = halfWidth(atDistance: distance)
        let lateral = side * min(half * 0.45, 3.0)
        let heading = tangent(atDistance: distance).angle
        _ = total
        return (position(distance: distance, lateral: lateral), heading)
    }

    // MARK: - Path building

    /// Closed Catmull-Rom through the control points.
    private static func smoothClosedPath(
        _ controls: [TrackControlPoint],
        subdivisions: Int
    ) -> [(point: Vector2, halfWidth: Double)] {
        let n = controls.count
        precondition(n >= 4, "A course needs at least four control points")
        var output: [(Vector2, Double)] = []
        output.reserveCapacity(n * subdivisions)
        for i in 0..<n {
            let p0 = controls[(i - 1 + n) % n]
            let p1 = controls[i]
            let p2 = controls[(i + 1) % n]
            let p3 = controls[(i + 2) % n]
            for step in 0..<subdivisions {
                let t = Double(step) / Double(subdivisions)
                output.append((
                    catmullRom(p0.position, p1.position, p2.position, p3.position, t),
                    catmullRomScalar(p0.halfWidth, p1.halfWidth, p2.halfWidth, p3.halfWidth, t)
                ))
            }
        }
        return output
    }

    private static func catmullRom(_ p0: Vector2, _ p1: Vector2, _ p2: Vector2, _ p3: Vector2, _ t: Double) -> Vector2 {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * ((2 * p1)
            + (-p0 + p2) * t
            + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }

    private static func catmullRomScalar(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, _ t: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * ((2 * p1)
            + (-p0 + p2) * t
            + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }

    private static func resampleUniformly(
        _ path: [(point: Vector2, halfWidth: Double)],
        targetSpacing: Double
    ) -> (points: [Vector2], halfWidths: [Double], spacing: Double) {
        let n = path.count
        var cumulative = [Double](repeating: 0, count: n + 1)
        for i in 0..<n {
            let next = path[(i + 1) % n]
            cumulative[i + 1] = cumulative[i] + path[i].point.distance(to: next.point)
        }
        let total = cumulative[n]
        let count = max(16, Int((total / targetSpacing).rounded()))
        let spacing = total / Double(count)

        var points: [Vector2] = []
        var widths: [Double] = []
        points.reserveCapacity(count)
        widths.reserveCapacity(count)

        var segment = 0
        for i in 0..<count {
            let target = Double(i) * spacing
            while segment < n - 1, cumulative[segment + 1] < target { segment += 1 }
            let segmentLength = cumulative[segment + 1] - cumulative[segment]
            let t = segmentLength > 1e-9 ? (target - cumulative[segment]) / segmentLength : 0
            let a = path[segment]
            let b = path[(segment + 1) % n]
            points.append(Vector2.lerp(a.point, b.point, t))
            widths.append(a.halfWidth + (b.halfWidth - a.halfWidth) * t)
        }
        return (points, widths, spacing)
    }

    private static func smoothWrapped(_ values: [Double], radius: Int) -> [Double] {
        guard radius > 0, values.count > radius * 2 else { return values }
        let n = values.count
        var output = [Double](repeating: 0, count: n)
        let window = Double(radius * 2 + 1)
        for i in 0..<n {
            var sum = 0.0
            for offset in -radius...radius {
                sum += values[((i + offset) % n + n) % n]
            }
            output[i] = sum / window
        }
        return output
    }
}
