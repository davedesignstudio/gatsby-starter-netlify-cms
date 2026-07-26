import Foundation

/// Declarative placement of course furniture, expressed in fractions of a lap
/// so features can be positioned before the spline has been resampled.
public struct FeaturePlan: Sendable {
    public struct Spot: Sendable {
        public var arc: Double
        public var lane: Double
        public var radius: Double

        public init(arc: Double, lane: Double = 0, radius: Double = 46) {
            self.arc = arc
            self.lane = lane
            self.radius = radius
        }
    }

    public struct Row: Sendable {
        public var arc: Double
        public var count: Int
        /// Total spread across the lane, in half-width units.
        public var spread: Double

        public init(arc: Double, count: Int = 5, spread: Double = 1.3) {
            self.arc = arc
            self.count = count
            self.spread = spread
        }
    }

    public struct Prop: Sendable {
        public var arc: Double
        public var lane: Double
        public var radius: Double
        public var style: TrackObstacle.Style
        public var isBreakable: Bool

        public init(
            arc: Double,
            lane: Double,
            radius: Double = 48,
            style: TrackObstacle.Style = .pallet,
            isBreakable: Bool = false
        ) {
            self.arc = arc
            self.lane = lane
            self.radius = radius
            self.style = style
            self.isBreakable = isBreakable
        }
    }

    public var boostPads: [Spot] = []
    public var itemBoxRows: [Row] = []
    public var puddles: [Spot] = []
    public var props: [Prop] = []

    public init(
        boostPads: [Spot] = [],
        itemBoxRows: [Row] = [],
        puddles: [Spot] = [],
        props: [Prop] = []
    ) {
        self.boostPads = boostPads
        self.itemBoxRows = itemBoxRows
        self.puddles = puddles
        self.props = props
    }
}

public extension Track {
    /// World position at a fraction of a lap, offset sideways in half-width units.
    func point(atArcFraction fraction: Double, lane: Double) -> Vec2 {
        let index = sampleIndex(atArcLength: wrapArcLength(fraction * trackLength))
        let sample = self.sample(at: index)
        return sample.position + sample.tangent.perpendicular * (lane * sample.halfWidth)
    }

    /// Builds the final course by laying out a `FeaturePlan` on a bare spline.
    static func assembled(
        id: String,
        name: String,
        subtitle: String,
        theme: TrackTheme,
        lapCount: Int,
        controlPoints: [TrackControlPoint],
        shoulderWidth: Double,
        plan: FeaturePlan
    ) -> Track {
        // Pass one gives us geometry to hang the furniture off.
        let bare = Track(
            id: id,
            name: name,
            subtitle: subtitle,
            theme: theme,
            lapCount: lapCount,
            controlPoints: controlPoints,
            shoulderWidth: shoulderWidth
        )

        let boostPads = plan.boostPads.map {
            TrackFeature(bare.point(atArcFraction: $0.arc, lane: $0.lane), radius: $0.radius)
        }
        let puddles = plan.puddles.map {
            TrackFeature(bare.point(atArcFraction: $0.arc, lane: $0.lane), radius: $0.radius)
        }
        var itemBoxes: [TrackFeature] = []
        for row in plan.itemBoxRows {
            for i in 0..<row.count {
                let t = row.count == 1 ? 0.5 : Double(i) / Double(row.count - 1)
                let lane = (t - 0.5) * row.spread
                itemBoxes.append(TrackFeature(bare.point(atArcFraction: row.arc, lane: lane), radius: 34))
            }
        }
        let obstacles = plan.props.map {
            TrackObstacle(
                bare.point(atArcFraction: $0.arc, lane: $0.lane),
                radius: $0.radius,
                style: $0.style,
                isBreakable: $0.isBreakable
            )
        }

        return Track(
            id: id,
            name: name,
            subtitle: subtitle,
            theme: theme,
            lapCount: lapCount,
            controlPoints: controlPoints,
            shoulderWidth: shoulderWidth,
            boostPads: boostPads,
            itemBoxes: itemBoxes,
            puddles: puddles,
            obstacles: obstacles
        )
    }
}

/// The four courses that make up the Trolley Cup.
public enum TrackLibrary {
    public static var all: [Track] { [producePlaza, frozenFoods, bulkWarehouse, checkoutChaos] }

    public static func track(id: String) -> Track {
        all.first { $0.id == id } ?? producePlaza
    }

    /// Wide, forgiving opener. Fruit everywhere, gentle sweepers.
    public static let producePlaza = Track.assembled(
        id: "produce-plaza",
        name: "Produce Plaza",
        subtitle: "Aisle 1 – Fruit & Veg",
        theme: TrackTheme(
            floor: .init(0.93, 0.92, 0.88),
            rough: .init(0.72, 0.78, 0.58),
            shelf: .init(0.28, 0.55, 0.35),
            accent: .init(0.98, 0.62, 0.18),
            tagline: "Mind the misting sprinklers."
        ),
        lapCount: 3,
        controlPoints: [
            TrackControlPoint(0, -900, halfWidth: 235),
            TrackControlPoint(700, -910, halfWidth: 230),
            TrackControlPoint(1200, -820, halfWidth: 215),
            TrackControlPoint(1430, -500, halfWidth: 200),
            TrackControlPoint(1360, -150, halfWidth: 190),
            TrackControlPoint(1520, 220, halfWidth: 205),
            TrackControlPoint(1390, 620, halfWidth: 220),
            TrackControlPoint(1000, 890, halfWidth: 230),
            TrackControlPoint(400, 940, halfWidth: 235),
            TrackControlPoint(-300, 880, halfWidth: 225),
            TrackControlPoint(-900, 760, halfWidth: 205),
            TrackControlPoint(-1310, 400, halfWidth: 190),
            TrackControlPoint(-1420, 0, halfWidth: 200),
            TrackControlPoint(-1260, -450, halfWidth: 215),
            TrackControlPoint(-900, -820, halfWidth: 225),
            TrackControlPoint(-400, -940, halfWidth: 235)
        ],
        shoulderWidth: 95,
        plan: FeaturePlan(
            boostPads: [
                .init(arc: 0.10, lane: 0.0, radius: 52),
                .init(arc: 0.44, lane: -0.35, radius: 52),
                .init(arc: 0.78, lane: 0.30, radius: 52)
            ],
            itemBoxRows: [
                .init(arc: 0.06, count: 5, spread: 1.25),
                .init(arc: 0.34, count: 5, spread: 1.15),
                .init(arc: 0.62, count: 5, spread: 1.25),
                .init(arc: 0.88, count: 4, spread: 1.0)
            ],
            puddles: [
                .init(arc: 0.25, lane: 0.45, radius: 105)
            ],
            props: [
                .init(arc: 0.18, lane: -0.55, radius: 52, style: .canPyramid),
                .init(arc: 0.53, lane: 0.5, radius: 46, style: .cardboardBin, isBreakable: true),
                .init(arc: 0.54, lane: 0.72, radius: 46, style: .cardboardBin, isBreakable: true),
                .init(arc: 0.70, lane: -0.62, radius: 55, style: .pallet),
                .init(arc: 0.93, lane: 0.4, radius: 40, style: .wetFloorSign, isBreakable: true)
            ]
        )
    )

    /// Long straights, no grip. Bring a coat.
    public static let frozenFoods = Track.assembled(
        id: "frozen-foods",
        name: "Frozen Foods Freeway",
        subtitle: "Aisle 7 – Keep the doors shut",
        theme: TrackTheme(
            floor: .init(0.86, 0.92, 0.97),
            rough: .init(0.70, 0.80, 0.88),
            shelf: .init(0.34, 0.52, 0.70),
            accent: .init(0.28, 0.78, 0.95),
            tagline: "Meltwater on the racing line."
        ),
        lapCount: 3,
        controlPoints: [
            TrackControlPoint(0, -1050, halfWidth: 200),
            TrackControlPoint(900, -1080, halfWidth: 195),
            TrackControlPoint(1600, -980, halfWidth: 180),
            TrackControlPoint(1850, -600, halfWidth: 165),
            TrackControlPoint(1600, -280, halfWidth: 160),
            TrackControlPoint(1100, -240, halfWidth: 170),
            TrackControlPoint(700, -60, halfWidth: 175),
            TrackControlPoint(760, 380, halfWidth: 185),
            TrackControlPoint(1200, 640, halfWidth: 190),
            TrackControlPoint(1150, 1000, halfWidth: 175),
            TrackControlPoint(650, 1140, halfWidth: 180),
            TrackControlPoint(0, 1080, halfWidth: 200),
            TrackControlPoint(-700, 980, halfWidth: 195),
            TrackControlPoint(-1250, 700, halfWidth: 180),
            TrackControlPoint(-1450, 250, halfWidth: 175),
            TrackControlPoint(-1500, -250, halfWidth: 180),
            TrackControlPoint(-1300, -700, halfWidth: 190),
            TrackControlPoint(-750, -1000, halfWidth: 200)
        ],
        shoulderWidth: 80,
        plan: FeaturePlan(
            boostPads: [
                .init(arc: 0.05, lane: 0.2, radius: 50),
                .init(arc: 0.30, lane: -0.4, radius: 50),
                .init(arc: 0.66, lane: 0.0, radius: 50),
                .init(arc: 0.85, lane: -0.25, radius: 50)
            ],
            itemBoxRows: [
                .init(arc: 0.12, count: 5, spread: 1.2),
                .init(arc: 0.40, count: 4, spread: 1.0),
                .init(arc: 0.58, count: 5, spread: 1.2),
                .init(arc: 0.80, count: 5, spread: 1.15)
            ],
            puddles: [
                .init(arc: 0.19, lane: -0.2, radius: 130),
                .init(arc: 0.35, lane: 0.35, radius: 110),
                .init(arc: 0.52, lane: 0.0, radius: 140),
                .init(arc: 0.72, lane: -0.45, radius: 120),
                .init(arc: 0.91, lane: 0.3, radius: 115)
            ],
            props: [
                .init(arc: 0.24, lane: 0.6, radius: 58, style: .freezer),
                .init(arc: 0.47, lane: -0.6, radius: 58, style: .freezer),
                .init(arc: 0.63, lane: 0.55, radius: 44, style: .wetFloorSign, isBreakable: true),
                .init(arc: 0.76, lane: 0.0, radius: 40, style: .cardboardBin, isBreakable: true)
            ]
        )
    )

    /// Big, fast and cluttered with pallets. Four laps of forklift dodging.
    public static let bulkWarehouse = Track.assembled(
        id: "bulk-warehouse",
        name: "Bulk Warehouse Rally",
        subtitle: "Back of house – Staff only",
        theme: TrackTheme(
            floor: .init(0.62, 0.62, 0.64),
            rough: .init(0.48, 0.44, 0.40),
            shelf: .init(0.85, 0.55, 0.15),
            accent: .init(0.98, 0.82, 0.20),
            tagline: "Watch for the pallet stacks."
        ),
        lapCount: 4,
        controlPoints: [
            TrackControlPoint(0, -1300, halfWidth: 215),
            TrackControlPoint(800, -1350, halfWidth: 205),
            TrackControlPoint(1500, -1200, halfWidth: 195),
            TrackControlPoint(1900, -800, halfWidth: 185),
            TrackControlPoint(1750, -350, halfWidth: 175),
            TrackControlPoint(1250, -200, halfWidth: 170),
            TrackControlPoint(900, 100, halfWidth: 180),
            TrackControlPoint(1150, 500, halfWidth: 190),
            TrackControlPoint(1700, 700, halfWidth: 195),
            TrackControlPoint(1850, 1150, halfWidth: 185),
            TrackControlPoint(1350, 1450, halfWidth: 190),
            TrackControlPoint(700, 1400, halfWidth: 200),
            TrackControlPoint(100, 1250, halfWidth: 210),
            TrackControlPoint(-600, 1300, halfWidth: 205),
            TrackControlPoint(-1300, 1050, halfWidth: 195),
            TrackControlPoint(-1750, 600, halfWidth: 185),
            TrackControlPoint(-1850, 100, halfWidth: 190),
            TrackControlPoint(-1700, -450, halfWidth: 200),
            TrackControlPoint(-1350, -950, halfWidth: 205),
            TrackControlPoint(-750, -1250, halfWidth: 215)
        ],
        shoulderWidth: 110,
        plan: FeaturePlan(
            boostPads: [
                .init(arc: 0.08, lane: -0.3, radius: 54),
                .init(arc: 0.28, lane: 0.35, radius: 54),
                .init(arc: 0.55, lane: 0.0, radius: 54),
                .init(arc: 0.74, lane: -0.4, radius: 54),
                .init(arc: 0.92, lane: 0.25, radius: 54)
            ],
            itemBoxRows: [
                .init(arc: 0.10, count: 6, spread: 1.3),
                .init(arc: 0.32, count: 5, spread: 1.1),
                .init(arc: 0.50, count: 6, spread: 1.3),
                .init(arc: 0.68, count: 5, spread: 1.15),
                .init(arc: 0.86, count: 6, spread: 1.25)
            ],
            puddles: [
                .init(arc: 0.41, lane: -0.3, radius: 120),
                .init(arc: 0.79, lane: 0.35, radius: 110)
            ],
            props: [
                .init(arc: 0.15, lane: 0.5, radius: 62, style: .pallet),
                .init(arc: 0.16, lane: -0.55, radius: 62, style: .pallet),
                .init(arc: 0.36, lane: 0.0, radius: 55, style: .canPyramid),
                .init(arc: 0.46, lane: 0.6, radius: 62, style: .pallet),
                .init(arc: 0.60, lane: -0.5, radius: 48, style: .cardboardBin, isBreakable: true),
                .init(arc: 0.61, lane: -0.25, radius: 48, style: .cardboardBin, isBreakable: true),
                .init(arc: 0.71, lane: 0.45, radius: 62, style: .pallet),
                .init(arc: 0.88, lane: -0.35, radius: 55, style: .canPyramid),
                .init(arc: 0.96, lane: 0.55, radius: 44, style: .wetFloorSign, isBreakable: true)
            ]
        )
    )

    /// Short, tight and mean. Five laps around the tills after closing time.
    public static let checkoutChaos = Track.assembled(
        id: "checkout-chaos",
        name: "Checkout Chaos",
        subtitle: "Front of store – After hours",
        theme: TrackTheme(
            floor: .init(0.24, 0.24, 0.30),
            rough: .init(0.18, 0.17, 0.22),
            shelf: .init(0.55, 0.20, 0.45),
            accent: .init(0.98, 0.30, 0.55),
            tagline: "Nine items or fewer. No exceptions."
        ),
        lapCount: 5,
        controlPoints: [
            TrackControlPoint(0, -620, halfWidth: 165),
            TrackControlPoint(520, -660, halfWidth: 155),
            TrackControlPoint(880, -420, halfWidth: 145),
            TrackControlPoint(830, -80, halfWidth: 140),
            TrackControlPoint(420, 60, halfWidth: 150),
            TrackControlPoint(180, 340, halfWidth: 155),
            TrackControlPoint(400, 660, halfWidth: 150),
            TrackControlPoint(120, 880, halfWidth: 145),
            TrackControlPoint(-400, 840, halfWidth: 155),
            TrackControlPoint(-820, 560, halfWidth: 150),
            TrackControlPoint(-900, 140, halfWidth: 145),
            TrackControlPoint(-780, -280, halfWidth: 155),
            TrackControlPoint(-450, -580, halfWidth: 165)
        ],
        shoulderWidth: 70,
        plan: FeaturePlan(
            boostPads: [
                .init(arc: 0.14, lane: 0.0, radius: 46),
                .init(arc: 0.48, lane: -0.3, radius: 46),
                .init(arc: 0.82, lane: 0.3, radius: 46)
            ],
            itemBoxRows: [
                .init(arc: 0.08, count: 4, spread: 1.0),
                .init(arc: 0.38, count: 4, spread: 1.0),
                .init(arc: 0.66, count: 4, spread: 1.0),
                .init(arc: 0.90, count: 3, spread: 0.8)
            ],
            puddles: [
                .init(arc: 0.29, lane: 0.3, radius: 95),
                .init(arc: 0.60, lane: -0.35, radius: 90)
            ],
            props: [
                .init(arc: 0.22, lane: -0.5, radius: 42, style: .cardboardBin, isBreakable: true),
                .init(arc: 0.44, lane: 0.55, radius: 48, style: .canPyramid),
                .init(arc: 0.72, lane: -0.55, radius: 48, style: .pallet),
                .init(arc: 0.95, lane: 0.35, radius: 38, style: .wetFloorSign, isBreakable: true)
            ]
        )
    )
}
