import Foundation

/// A deterministic description of how a course should be drawn: the road surface
/// ribbon, the shelving that lines it, the props scattered around the shop floor
/// and the strip lights overhead.
///
/// Keeping this out of the renderer means the dressing can be asserted in tests
/// (nothing overlapping the racing line, nothing left floating in a wall) and
/// stays identical between runs.
public struct TrackArtPlan: Sendable {
    /// One slice across the course, used to build the floor ribbon.
    public struct Slice: Sendable {
        public let centre: Vector2
        public let left: Vector2
        public let right: Vector2
        /// Outer edges including the run-off.
        public let shoulderLeft: Vector2
        public let shoulderRight: Vector2
        public let surface: Surface
        public let distance: Double
    }

    public enum PropKind: String, Sendable, CaseIterable {
        case shelfUnit
        case freezerCabinet
        case palletStack
        case cardboardBox
        case promoSign
        case pottedPlant
        case pillar
        case trolleyBay
        case wheelieBin

        /// Footprint radius in metres, used for spacing and collision-free checks.
        public var radius: Double {
            switch self {
            case .shelfUnit: return 2.6
            case .freezerCabinet: return 2.4
            case .palletStack: return 1.6
            case .cardboardBox: return 0.9
            case .promoSign: return 0.8
            case .pottedPlant: return 0.7
            case .pillar: return 1.1
            case .trolleyBay: return 2.2
            case .wheelieBin: return 1.0
            }
        }
    }

    public struct Prop: Sendable {
        public let kind: PropKind
        public let position: Vector2
        /// Radians; props line up with the aisle they sit beside.
        public let rotation: Double
        public let scale: Double
        public let colorIndex: Int
    }

    public struct Light: Sendable {
        public let position: Vector2
        public let rotation: Double
        public let length: Double
    }

    public struct Marking: Sendable {
        public let position: Vector2
        public let rotation: Double
        public let halfWidth: Double
    }

    /// A stretch of course sharing one floor type, as a run of slice indices.
    ///
    /// Consecutive runs overlap by one slice and the final run wraps back onto the
    /// first, so the filled shapes leave no gap — including across the start line.
    public struct SurfaceRun: Sendable {
        public let surface: Surface
        public let indices: [Int]
    }

    public let trackID: String
    public let theme: TrackTheme
    public let palette: Palette
    public let slices: [Slice]
    public let props: [Prop]
    public let lights: [Light]
    /// Start/finish line plus the chequered strips.
    public let startLine: Marking
    /// Faint lane guides painted down the middle of the aisles.
    public let centreMarkings: [Marking]
    /// World-space bounds of everything, for camera limits and the minimap.
    public let bounds: (min: Vector2, max: Vector2)

    public init(track: Track, seed: UInt64 = 0x5CA7) {
        let geometry = track.geometry
        let definition = track.definition
        trackID = definition.id
        theme = definition.theme
        palette = Palette.palette(for: definition.theme)

        // MARK: Road ribbon

        var slices: [Slice] = []
        slices.reserveCapacity(definition.nodes.count + 1)
        let shoulder = definition.shoulderWidth
        for index in definition.nodes.indices {
            let node = definition.nodes[index]
            let next = definition.nodes[(index + 1) % definition.nodes.count]
            let tangent = (next.position - node.position).normalized
            let normal = tangent.perpendicular
            let distance = geometry.segments[index].startDistance
            slices.append(
                Slice(
                    centre: node.position,
                    left: node.position + normal * node.halfWidth,
                    right: node.position - normal * node.halfWidth,
                    shoulderLeft: node.position + normal * (node.halfWidth + shoulder),
                    shoulderRight: node.position - normal * (node.halfWidth + shoulder),
                    surface: node.surface,
                    distance: distance
                )
            )
        }
        self.slices = slices

        // MARK: Overhead lighting

        var lights: [Light] = []
        var lightDistance = 0.0
        while lightDistance < geometry.totalLength {
            lights.append(
                Light(
                    position: geometry.position(at: lightDistance, lateral: 0),
                    rotation: geometry.tangentAngle(at: lightDistance),
                    length: 6.5
                )
            )
            lightDistance += 16
        }
        self.lights = lights

        // MARK: Painted markings

        startLine = Marking(
            position: geometry.point(at: 0),
            rotation: geometry.tangentAngle(at: 0),
            halfWidth: geometry.halfWidth(at: 0)
        )

        var markings: [Marking] = []
        var markDistance = 4.0
        while markDistance < geometry.totalLength {
            markings.append(
                Marking(
                    position: geometry.position(at: markDistance, lateral: 0),
                    rotation: geometry.tangentAngle(at: markDistance),
                    halfWidth: geometry.halfWidth(at: markDistance)
                )
            )
            markDistance += 8
        }
        centreMarkings = markings

        // MARK: Scenery

        var random = DeterministicRandom(seed: seed)
        var props: [Prop] = []
        let kinds = TrackArtPlan.propKinds(for: definition.theme)

        // Walk both sides of the course dropping scenery just outside the wall.
        for side in [-1.0, 1.0] {
            var distance = random.nextDouble(in: 0...6)
            while distance < geometry.totalLength {
                let kind = kinds[random.weightedIndex(kinds.map(\.weight))].kind
                let halfWidth = geometry.halfWidth(at: distance)
                let lateral = side * (halfWidth + shoulder + kind.radius + random.nextDouble(in: 0.3...2.4))
                let position = geometry.position(at: distance, lateral: lateral)

                // Courses double back on themselves; a prop dropped beside one
                // straight can easily land on another. Only keep the ones that are
                // clear of the road everywhere.
                let location = geometry.location(of: position)
                let clearance = abs(location.lateral) - location.halfWidth - shoulder
                if clearance > kind.radius * 0.5 {
                    props.append(
                        Prop(
                            kind: kind,
                            position: position,
                            rotation: geometry.tangentAngle(at: distance) + random.nextDouble(in: -0.08...0.08),
                            scale: random.nextDouble(in: 0.85...1.2),
                            colorIndex: Int(random.nextDouble(in: 0...4.99))
                        )
                    )
                }
                distance += kind.radius * 2 + random.nextDouble(in: 1.5...7)
            }
        }
        self.props = props

        // MARK: Bounds

        var minPoint = geometry.bounds.min
        var maxPoint = geometry.bounds.max
        for slice in slices {
            for point in [slice.shoulderLeft, slice.shoulderRight] {
                minPoint = Vector2(min(minPoint.x, point.x), min(minPoint.y, point.y))
                maxPoint = Vector2(max(maxPoint.x, point.x), max(maxPoint.y, point.y))
            }
        }
        for prop in props {
            let radius = prop.kind.radius * prop.scale
            minPoint = Vector2(min(minPoint.x, prop.position.x - radius), min(minPoint.y, prop.position.y - radius))
            maxPoint = Vector2(max(maxPoint.x, prop.position.x + radius), max(maxPoint.y, prop.position.y + radius))
        }
        bounds = (minPoint, maxPoint)
    }

    /// Groups the slices into runs of identical floor for the renderer to fill.
    public var surfaceRuns: [SurfaceRun] {
        guard !slices.isEmpty else { return [] }
        let count = slices.count
        var runs: [SurfaceRun] = []
        var startIndex = 0

        for index in 1...count {
            let ended = index == count || slices[index].surface != slices[startIndex].surface
            guard ended else { continue }
            // One slice of overlap, wrapped, so consecutive fills meet.
            let indices = (startIndex...index).map { $0 % count }
            runs.append(SurfaceRun(surface: slices[startIndex].surface, indices: indices))
            startIndex = index
        }
        return runs
    }

    private static func propKinds(for theme: TrackTheme) -> [(kind: PropKind, weight: Double)] {
        switch theme {
        case .grocery:
            return [
                (.shelfUnit, 5),
                (.promoSign, 2),
                (.pottedPlant, 1),
                (.cardboardBox, 2),
                (.trolleyBay, 1),
                (.pillar, 1)
            ]
        case .frozenFoods:
            return [
                (.freezerCabinet, 5),
                (.shelfUnit, 2),
                (.cardboardBox, 1.5),
                (.promoSign, 1),
                (.pillar, 1)
            ]
        case .loadingDock:
            return [
                (.palletStack, 4),
                (.wheelieBin, 2),
                (.cardboardBox, 2),
                (.pillar, 1.5),
                (.trolleyBay, 1)
            ]
        }
    }
}
