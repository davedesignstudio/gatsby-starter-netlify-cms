import Foundation

/// Art direction for a course. The renderer uses this to pick floor patterns,
/// shelving colours and which props to scatter along the edges.
public enum TrackTheme: String, Codable, CaseIterable, Sendable {
    case grocery
    case frozenFoods
    case loadingDock

    public var displayName: String {
        switch self {
        case .grocery: return "Main Aisles"
        case .frozenFoods: return "Frozen Foods"
        case .loadingDock: return "Loading Dock"
        }
    }
}

/// One sample of the centreline. Tracks are stored as a dense closed polyline
/// because every query the simulation needs (progress, lateral offset, walls)
/// falls out of simple segment maths.
public struct TrackNode: Equatable, Codable, Sendable {
    public var position: Vector2
    /// Distance from the centreline to the edge of the racing surface.
    public var halfWidth: Double
    public var surface: Surface

    public init(position: Vector2, halfWidth: Double, surface: Surface) {
        self.position = position
        self.halfWidth = halfWidth
        self.surface = surface
    }
}

public struct Obstacle: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case palletStack
        case displayTower
        case wetFloorSign
        case mopBucket
        case produceCrate
        case trafficCone

        /// Soft props get shoved aside; hard ones stop a cart dead.
        public var isSoft: Bool {
            switch self {
            case .wetFloorSign, .trafficCone, .produceCrate: return true
            case .palletStack, .displayTower, .mopBucket: return false
            }
        }

        /// Fraction of speed kept after hitting this.
        public var speedRetention: Double {
            switch self {
            case .wetFloorSign, .trafficCone: return 0.88
            case .produceCrate: return 0.7
            case .mopBucket: return 0.45
            case .displayTower: return 0.4
            case .palletStack: return 0.3
            }
        }

        public var displayName: String {
            switch self {
            case .palletStack: return "Pallet Stack"
            case .displayTower: return "Promo Display"
            case .wetFloorSign: return "Wet Floor Sign"
            case .mopBucket: return "Mop Bucket"
            case .produceCrate: return "Produce Crate"
            case .trafficCone: return "Traffic Cone"
            }
        }
    }

    public var position: Vector2
    public var radius: Double
    public var kind: Kind

    public init(position: Vector2, radius: Double, kind: Kind) {
        self.position = position
        self.radius = radius
        self.kind = kind
    }
}

/// Air-curtain vents and ramp strips that hand out a free boost.
public struct BoostPad: Equatable, Codable, Sendable {
    public var position: Vector2
    public var radius: Double
    public var duration: Double

    public init(position: Vector2, radius: Double = 1.6, duration: Double = 1.1) {
        self.position = position
        self.radius = radius
        self.duration = duration
    }
}

public struct ItemBoxSpawn: Equatable, Codable, Sendable {
    public var position: Vector2
    public var radius: Double
    /// Seconds before a smashed crate comes back.
    public var respawnDelay: Double

    public init(position: Vector2, radius: Double = 1.3, respawnDelay: Double = 4.5) {
        self.position = position
        self.radius = radius
        self.respawnDelay = respawnDelay
    }
}

/// Loose change on the floor. Each one nudges your top speed up a touch.
public struct TokenSpawn: Equatable, Codable, Sendable {
    public var position: Vector2
    public var radius: Double

    public init(position: Vector2, radius: Double = 0.95) {
        self.position = position
        self.radius = radius
    }
}

public struct TrackDefinition: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let theme: TrackTheme
    public let recommendedLaps: Int
    /// Nodes form a closed loop: the last node connects back to the first.
    public let nodes: [TrackNode]
    /// Width of the scruffy run-off outside the racing surface before the wall.
    public let shoulderWidth: Double
    public let obstacles: [Obstacle]
    public let boostPads: [BoostPad]
    public let itemBoxes: [ItemBoxSpawn]
    public let tokens: [TokenSpawn]

    public init(
        id: String,
        name: String,
        subtitle: String,
        theme: TrackTheme,
        recommendedLaps: Int,
        nodes: [TrackNode],
        shoulderWidth: Double,
        obstacles: [Obstacle],
        boostPads: [BoostPad],
        itemBoxes: [ItemBoxSpawn],
        tokens: [TokenSpawn]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.theme = theme
        self.recommendedLaps = recommendedLaps
        self.nodes = nodes
        self.shoulderWidth = shoulderWidth
        self.obstacles = obstacles
        self.boostPads = boostPads
        self.itemBoxes = itemBoxes
        self.tokens = tokens
    }
}

/// A definition plus its precomputed geometry. Build one per race and share it.
public struct Track: Sendable {
    public let definition: TrackDefinition
    public let geometry: TrackGeometry

    public init(definition: TrackDefinition) {
        self.definition = definition
        self.geometry = TrackGeometry(nodes: definition.nodes)
    }

    public var id: String { definition.id }
    public var name: String { definition.name }
    public var length: Double { geometry.totalLength }

    public struct GridSlot: Sendable {
        public let position: Vector2
        public let heading: Double
        /// Metres behind the start line, so the simulation can seed lap progress.
        public let distanceBehindLine: Double
    }

    /// Starting grid: two carts per row, staggered behind the start line.
    public func gridSlot(index: Int) -> GridSlot {
        let row = index / 2
        let side = index % 2 == 0 ? -1.0 : 1.0
        let distanceBack = 7.0 + Double(row) * 6.0
        let distance = geometry.wrap(-distanceBack)
        let centre = geometry.point(at: distance)
        let heading = geometry.tangentAngle(at: distance)
        let lateral = Vector2(angle: heading).perpendicular * (side * 2.8)
        return GridSlot(position: centre + lateral, heading: heading, distanceBehindLine: distanceBack)
    }
}
