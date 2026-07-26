import Foundation

/// The built-in courses. Every one of them is a closed loop with no crossings,
/// which is what keeps the lateral projection unambiguous.
public enum Tracks {
    public static let all: [TrackDefinition] = [produceLoop, frozenFoods, clearanceCanyon, closingTime]

    public static func definition(id: String) -> TrackDefinition {
        all.first { $0.id == id } ?? produceLoop
    }

    public static func track(id: String) -> Track {
        Track(definition: definition(id: id))
    }

    // MARK: - Cup 1, Course 1

    public static let produceLoop = TrackDefinition(
        id: "produce-loop",
        name: "Produce Loop",
        subtitle: "Mind the misters",
        laps: 3,
        difficulty: 1,
        controlPoints: [
            TrackControlPoint(-10, 0, halfWidth: 7.5),
            TrackControlPoint(30, -2, halfWidth: 7.5),
            TrackControlPoint(70, -2, halfWidth: 7.5),
            TrackControlPoint(105, 6, halfWidth: 7),
            TrackControlPoint(128, 28, halfWidth: 6.5),
            TrackControlPoint(130, 60, halfWidth: 6.5),
            TrackControlPoint(112, 85, halfWidth: 7),
            TrackControlPoint(80, 96, halfWidth: 7.5),
            TrackControlPoint(46, 96, halfWidth: 7),
            TrackControlPoint(32, 86, halfWidth: 6),
            TrackControlPoint(12, 96, halfWidth: 6),
            TrackControlPoint(-16, 92, halfWidth: 6.5),
            TrackControlPoint(-34, 68, halfWidth: 7),
            TrackControlPoint(-36, 34, halfWidth: 7),
            TrackControlPoint(-28, 10, halfWidth: 7)
        ],
        shoulderWidth: 2.6,
        theme: TrackTheme(
            floorTint: .hex(0xF2EFE6),
            groutTint: .hex(0xD9D3C4),
            shelfTint: .hex(0x3F7A54),
            accentTint: .hex(0xF2A93B),
            ambientTint: .hex(0xFFF6E0)
        ),
        surfacePatches: [
            // The misting system runs on a timer nobody has ever adjusted.
            SurfacePatch(surface: .wet, progress: 0.30...0.37),
            SurfacePatch(surface: .wet, progress: 0.62...0.66, lateralBand: -1.0...0.1),
            SurfacePatch(surface: .cardboard, progress: 0.80...0.86, lateralBand: 0.2...1.0)
        ],
        itemBoxRows: [
            ItemBoxRow(progress: 0.12, lateralOffsets: [-4.5, -1.5, 1.5, 4.5]),
            ItemBoxRow(progress: 0.41, lateralOffsets: [-4, 0, 4]),
            ItemBoxRow(progress: 0.68, lateralOffsets: [-4.5, -1.5, 1.5, 4.5]),
            ItemBoxRow(progress: 0.90, lateralOffsets: [-3, 0, 3])
        ],
        props: [
            StaticProp(kind: .canPyramid, progress: 0.22, lateralOffset: 3.5),
            StaticProp(kind: .wetFloorSign, progress: 0.305, lateralOffset: -2.0),
            StaticProp(kind: .shoppingBasket, progress: 0.47, lateralOffset: -4.2),
            StaticProp(kind: .pallet, progress: 0.55, lateralOffset: 4.6),
            StaticProp(kind: .moppingBucket, progress: 0.73, lateralOffset: 2.4)
        ],
        boostStrips: [
            BoostStrip(progress: 0.06, lateralOffset: 0, length: 8, width: 5),
            BoostStrip(progress: 0.52, lateralOffset: -3, length: 7, width: 4),
            BoostStrip(progress: 0.955, lateralOffset: 2, length: 8, width: 4.5)
        ]
    )

    // MARK: - Cup 1, Course 2

    public static let frozenFoods = TrackDefinition(
        id: "frozen-foods",
        name: "Frozen Foods Freeway",
        subtitle: "Zero grip, zero regrets",
        laps: 3,
        difficulty: 2,
        controlPoints: [
            TrackControlPoint(0, 0, halfWidth: 8),
            TrackControlPoint(60, -4, halfWidth: 8),
            TrackControlPoint(120, -6, halfWidth: 7.5),
            TrackControlPoint(170, 6, halfWidth: 7),
            TrackControlPoint(196, 34, halfWidth: 6.5),
            TrackControlPoint(190, 70, halfWidth: 6.5),
            TrackControlPoint(158, 92, halfWidth: 7),
            TrackControlPoint(110, 96, halfWidth: 7.5),
            TrackControlPoint(60, 92, halfWidth: 7.5),
            TrackControlPoint(18, 78, halfWidth: 7),
            TrackControlPoint(-14, 52, halfWidth: 7),
            TrackControlPoint(-16, 22, halfWidth: 7.5)
        ],
        shoulderWidth: 3.0,
        theme: TrackTheme(
            floorTint: .hex(0xE6F1F8),
            groutTint: .hex(0xC2D8E8),
            shelfTint: .hex(0x2E5C8A),
            accentTint: .hex(0x59D2F2),
            ambientTint: .hex(0xDCEEFF)
        ),
        surfacePatches: [
            SurfacePatch(surface: .ice, progress: 0.20...0.34),
            SurfacePatch(surface: .ice, progress: 0.55...0.63, lateralBand: -0.2...1.0),
            SurfacePatch(surface: .wet, progress: 0.72...0.78),
            SurfacePatch(surface: .ice, progress: 0.86...0.94, lateralBand: -1.0...0.3)
        ],
        itemBoxRows: [
            ItemBoxRow(progress: 0.10, lateralOffsets: [-5, -2, 2, 5]),
            ItemBoxRow(progress: 0.36, lateralOffsets: [-4, 0, 4]),
            ItemBoxRow(progress: 0.52, lateralOffsets: [-5, -2, 2, 5]),
            ItemBoxRow(progress: 0.80, lateralOffsets: [-4, 0, 4])
        ],
        props: [
            StaticProp(kind: .pallet, progress: 0.17, lateralOffset: -5.0),
            StaticProp(kind: .wetFloorSign, progress: 0.205, lateralOffset: 1.5),
            StaticProp(kind: .wetFloorSign, progress: 0.335, lateralOffset: -1.5),
            StaticProp(kind: .canPyramid, progress: 0.44, lateralOffset: 4.0),
            StaticProp(kind: .moppingBucket, progress: 0.70, lateralOffset: -3.0),
            StaticProp(kind: .shoppingBasket, progress: 0.88, lateralOffset: 3.6)
        ],
        boostStrips: [
            BoostStrip(progress: 0.04, lateralOffset: 0, length: 9, width: 5),
            BoostStrip(progress: 0.42, lateralOffset: 3, length: 8, width: 4),
            BoostStrip(progress: 0.66, lateralOffset: -3, length: 8, width: 4),
            BoostStrip(progress: 0.97, lateralOffset: 0, length: 9, width: 5)
        ]
    )

    // MARK: - Cup 2, Course 1

    public static let clearanceCanyon = TrackDefinition(
        id: "clearance-canyon",
        name: "Clearance Canyon",
        subtitle: "Narrow aisles, wide margins",
        laps: 3,
        difficulty: 3,
        controlPoints: [
            TrackControlPoint(0, 0, halfWidth: 6),
            TrackControlPoint(45, 0, halfWidth: 6),
            TrackControlPoint(80, -8, halfWidth: 5.5),
            TrackControlPoint(110, -30, halfWidth: 5.5),
            TrackControlPoint(142, -30, halfWidth: 5.5),
            TrackControlPoint(166, -8, halfWidth: 5.5),
            TrackControlPoint(166, 30, halfWidth: 6),
            TrackControlPoint(140, 52, halfWidth: 6),
            TrackControlPoint(100, 52, halfWidth: 5.5),
            TrackControlPoint(76, 70, halfWidth: 5),
            TrackControlPoint(76, 100, halfWidth: 5.5),
            TrackControlPoint(46, 118, halfWidth: 6),
            TrackControlPoint(6, 112, halfWidth: 6.5),
            TrackControlPoint(-20, 88, halfWidth: 7),
            TrackControlPoint(-24, 50, halfWidth: 7),
            TrackControlPoint(-14, 18, halfWidth: 6.5)
        ],
        shoulderWidth: 2.2,
        theme: TrackTheme(
            floorTint: .hex(0xE9E2D2),
            groutTint: .hex(0xCDC2A9),
            shelfTint: .hex(0x8A5A2B),
            accentTint: .hex(0xE04F2E),
            ambientTint: .hex(0xFFEBC9)
        ),
        surfacePatches: [
            SurfacePatch(surface: .cardboard, progress: 0.14...0.20),
            SurfacePatch(surface: .cardboard, progress: 0.47...0.53, lateralBand: -1.0...0.2),
            SurfacePatch(surface: .wet, progress: 0.66...0.71),
            SurfacePatch(surface: .cardboard, progress: 0.88...0.93, lateralBand: -0.2...1.0)
        ],
        itemBoxRows: [
            ItemBoxRow(progress: 0.09, lateralOffsets: [-3.2, 0, 3.2]),
            ItemBoxRow(progress: 0.33, lateralOffsets: [-3.2, 0, 3.2]),
            ItemBoxRow(progress: 0.58, lateralOffsets: [-3.5, -1, 1, 3.5]),
            ItemBoxRow(progress: 0.79, lateralOffsets: [-3.2, 0, 3.2])
        ],
        props: [
            StaticProp(kind: .pallet, progress: 0.12, lateralOffset: 3.8),
            StaticProp(kind: .canPyramid, progress: 0.26, lateralOffset: -3.2),
            StaticProp(kind: .pallet, progress: 0.40, lateralOffset: -3.9),
            StaticProp(kind: .shoppingBasket, progress: 0.50, lateralOffset: 2.6),
            StaticProp(kind: .moppingBucket, progress: 0.665, lateralOffset: 1.8),
            StaticProp(kind: .canPyramid, progress: 0.72, lateralOffset: -2.8),
            StaticProp(kind: .wetFloorSign, progress: 0.84, lateralOffset: 2.2),
            StaticProp(kind: .pallet, progress: 0.94, lateralOffset: 4.2)
        ],
        boostStrips: [
            BoostStrip(progress: 0.03, lateralOffset: 0, length: 7, width: 4),
            BoostStrip(progress: 0.30, lateralOffset: -2, length: 6, width: 3.5),
            BoostStrip(progress: 0.62, lateralOffset: 2, length: 6, width: 3.5),
            BoostStrip(progress: 0.90, lateralOffset: -2, length: 6, width: 3.5)
        ]
    )

    // MARK: - Cup 2, Course 2

    public static let closingTime = TrackDefinition(
        id: "closing-time",
        name: "Closing Time Parkway",
        subtitle: "Cart return, but faster",
        laps: 3,
        difficulty: 2,
        controlPoints: [
            TrackControlPoint(0, 0, halfWidth: 9),
            TrackControlPoint(80, 0, halfWidth: 9),
            TrackControlPoint(160, 0, halfWidth: 9),
            TrackControlPoint(215, 20, halfWidth: 8),
            TrackControlPoint(240, 60, halfWidth: 8),
            TrackControlPoint(225, 105, halfWidth: 8),
            TrackControlPoint(170, 128, halfWidth: 8.5),
            TrackControlPoint(95, 130, halfWidth: 9),
            TrackControlPoint(30, 120, halfWidth: 8.5),
            TrackControlPoint(-25, 95, halfWidth: 8),
            TrackControlPoint(-45, 55, halfWidth: 8),
            TrackControlPoint(-30, 18, halfWidth: 8.5)
        ],
        shoulderWidth: 3.4,
        theme: TrackTheme(
            floorTint: .hex(0x3A3F47),
            groutTint: .hex(0x2B2F36),
            shelfTint: .hex(0x1E232B),
            accentTint: .hex(0xF2C94C),
            ambientTint: .hex(0x2A3346)
        ),
        surfacePatches: [
            SurfacePatch(surface: .wet, progress: 0.24...0.31),
            SurfacePatch(surface: .scuffed, progress: 0.50...0.55, lateralBand: 0.4...1.0),
            SurfacePatch(surface: .wet, progress: 0.76...0.82, lateralBand: -1.0...0.0)
        ],
        itemBoxRows: [
            ItemBoxRow(progress: 0.08, lateralOffsets: [-6, -3, 0, 3, 6]),
            ItemBoxRow(progress: 0.34, lateralOffsets: [-5, -2, 2, 5]),
            ItemBoxRow(progress: 0.60, lateralOffsets: [-6, -3, 0, 3, 6]),
            ItemBoxRow(progress: 0.86, lateralOffsets: [-5, -2, 2, 5])
        ],
        props: [
            StaticProp(kind: .shoppingBasket, progress: 0.16, lateralOffset: -5.5),
            StaticProp(kind: .pallet, progress: 0.28, lateralOffset: 5.5),
            StaticProp(kind: .canPyramid, progress: 0.45, lateralOffset: -4.5),
            StaticProp(kind: .wetFloorSign, progress: 0.63, lateralOffset: 3.0),
            StaticProp(kind: .moppingBucket, progress: 0.78, lateralOffset: -3.2),
            StaticProp(kind: .shoppingBasket, progress: 0.92, lateralOffset: 4.8)
        ],
        boostStrips: [
            BoostStrip(progress: 0.02, lateralOffset: 0, length: 10, width: 6),
            BoostStrip(progress: 0.20, lateralOffset: -4, length: 9, width: 4.5),
            BoostStrip(progress: 0.55, lateralOffset: 4, length: 9, width: 4.5),
            BoostStrip(progress: 0.88, lateralOffset: 0, length: 10, width: 5)
        ]
    )
}

/// A championship: a fixed running order of courses.
public struct Cup: Sendable, Identifiable {
    public var id: String
    public var name: String
    public var blurb: String
    public var trackIDs: [String]

    public var tracks: [TrackDefinition] { trackIDs.map { Tracks.definition(id: $0) } }
}

public enum Cups {
    public static let all: [Cup] = [
        Cup(
            id: "weekly-shop",
            name: "Weekly Shop Cup",
            blurb: "Two courses. One list. No dignity.",
            trackIDs: ["produce-loop", "frozen-foods"]
        ),
        Cup(
            id: "closing-time",
            name: "Closing Time Cup",
            blurb: "The lights are off. The carts are not.",
            trackIDs: ["clearance-canyon", "closing-time"]
        ),
        Cup(
            id: "store-championship",
            name: "Store Championship",
            blurb: "Every aisle, back to back.",
            trackIDs: ["produce-loop", "frozen-foods", "clearance-canyon", "closing-time"]
        )
    ]

    public static func cup(id: String) -> Cup {
        all.first { $0.id == id } ?? all[0]
    }
}
