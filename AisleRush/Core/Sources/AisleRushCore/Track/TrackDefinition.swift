import Foundation

/// Authored shape of a course. Control points are sparse; `Track` smooths and
/// resamples them into the dense centreline the simulation actually uses.
public struct TrackControlPoint: Sendable {
    public var position: Vector2
    /// Distance from the centreline to the shelving on either side.
    public var halfWidth: Double

    public init(_ x: Double, _ y: Double, halfWidth: Double = 7) {
        position = Vector2(x, y)
        self.halfWidth = halfWidth
    }
}

/// A patch of floor that behaves differently from clean linoleum.
public struct SurfacePatch: Sendable {
    public var surface: Surface
    /// Position along the lap, 0...1.
    public var progress: ClosedRange<Double>
    /// Lateral band it covers, in multiples of the local half width (-1...1).
    public var lateralBand: ClosedRange<Double>

    public init(surface: Surface, progress: ClosedRange<Double>, lateralBand: ClosedRange<Double> = -1...1) {
        self.surface = surface
        self.progress = progress
        self.lateralBand = lateralBand
    }
}

/// A row of item crates spanning the aisle.
public struct ItemBoxRow: Sendable {
    public var progress: Double
    public var lateralOffsets: [Double]

    public init(progress: Double, lateralOffsets: [Double]) {
        self.progress = progress
        self.lateralOffsets = lateralOffsets
    }
}

/// Something permanently parked on the course: a pallet, a wet floor sign, a
/// display of tinned peaches waiting to be demolished.
public struct StaticProp: Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case pallet
        case wetFloorSign
        case canPyramid
        case moppingBucket
        case shoppingBasket
    }

    public var kind: Kind
    public var progress: Double
    public var lateralOffset: Double

    public init(kind: Kind, progress: Double, lateralOffset: Double) {
        self.kind = kind
        self.progress = progress
        self.lateralOffset = lateralOffset
    }

    /// Radius used for collision and for drawing.
    public var radius: Double {
        switch kind {
        case .pallet: return 1.6
        case .wetFloorSign: return 0.7
        case .canPyramid: return 1.1
        case .moppingBucket: return 0.8
        case .shoppingBasket: return 0.7
        }
    }

    /// Solid props stop you dead; the rest scatter and only cost you speed.
    public var isSolid: Bool {
        switch kind {
        case .pallet: return true
        case .wetFloorSign, .canPyramid, .moppingBucket, .shoppingBasket: return false
        }
    }
}

/// Booster strips: the polished floor a Zamboni-sized buffer just went over.
public struct BoostStrip: Sendable {
    public var progress: Double
    public var lateralOffset: Double
    public var length: Double
    public var width: Double

    public init(progress: Double, lateralOffset: Double, length: Double = 6, width: Double = 3) {
        self.progress = progress
        self.lateralOffset = lateralOffset
        self.length = length
        self.width = width
    }
}

public struct TrackTheme: Sendable {
    public var floorTint: ColorRGB
    public var groutTint: ColorRGB
    public var shelfTint: ColorRGB
    public var accentTint: ColorRGB
    public var ambientTint: ColorRGB

    public init(floorTint: ColorRGB, groutTint: ColorRGB, shelfTint: ColorRGB, accentTint: ColorRGB, ambientTint: ColorRGB) {
        self.floorTint = floorTint
        self.groutTint = groutTint
        self.shelfTint = shelfTint
        self.accentTint = accentTint
        self.ambientTint = ambientTint
    }
}

public struct ColorRGB: Sendable, Equatable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static func hex(_ value: UInt32) -> ColorRGB {
        ColorRGB(
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    public func mixed(with other: ColorRGB, _ t: Double) -> ColorRGB {
        ColorRGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }
}

public struct TrackDefinition: Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var laps: Int
    public var difficulty: Int
    public var controlPoints: [TrackControlPoint]
    /// Width of the scuffed floor outside the racing surface, before the shelves.
    public var shoulderWidth: Double
    public var theme: TrackTheme
    public var surfacePatches: [SurfacePatch]
    public var itemBoxRows: [ItemBoxRow]
    public var props: [StaticProp]
    public var boostStrips: [BoostStrip]

    public init(
        id: String,
        name: String,
        subtitle: String,
        laps: Int = 3,
        difficulty: Int = 1,
        controlPoints: [TrackControlPoint],
        shoulderWidth: Double = 2.5,
        theme: TrackTheme,
        surfacePatches: [SurfacePatch] = [],
        itemBoxRows: [ItemBoxRow] = [],
        props: [StaticProp] = [],
        boostStrips: [BoostStrip] = []
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.laps = laps
        self.difficulty = difficulty
        self.controlPoints = controlPoints
        self.shoulderWidth = shoulderWidth
        self.theme = theme
        self.surfacePatches = surfacePatches
        self.itemBoxRows = itemBoxRows
        self.props = props
        self.boostStrips = boostStrips
    }
}
