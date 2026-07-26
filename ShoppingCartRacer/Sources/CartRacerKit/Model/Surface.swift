import Foundation

/// What the wheels are rolling over. Every store floor type trades grip against
/// speed, which is the main reason the racing line matters.
public enum Surface: String, Codable, CaseIterable, Sendable {
    /// Freshly buffed shop floor: the default racing surface.
    case polishedTile
    /// Entrance matting — grippy but drags a little.
    case rubberMat
    /// Someone dropped a yoghurt. Almost no lateral grip.
    case wetFloor
    /// Frozen aisle condensation: fast but treacherous.
    case freezerFrost
    /// Loading dock outside the roller shutter.
    case loadingDockAsphalt
    /// Seasonal carpet runner: slow and sticky.
    case carpetRunner
    /// Spilled birdseed / broken pallets in the shoulder.
    case spillDebris

    /// How much of the engine force reaches the floor.
    public var longitudinalGrip: Double {
        switch self {
        case .polishedTile: return 1.0
        case .rubberMat: return 1.05
        case .wetFloor: return 0.55
        case .freezerFrost: return 0.7
        case .loadingDockAsphalt: return 0.95
        case .carpetRunner: return 0.9
        case .spillDebris: return 0.6
        }
    }

    /// Resistance to sliding sideways, per second of decay.
    public var lateralGrip: Double {
        switch self {
        case .polishedTile: return 6.0
        case .rubberMat: return 9.0
        case .wetFloor: return 1.1
        case .freezerFrost: return 2.0
        case .loadingDockAsphalt: return 7.0
        case .carpetRunner: return 8.0
        case .spillDebris: return 4.0
        }
    }

    /// Multiplier applied to the cart's top speed.
    public var topSpeedFactor: Double {
        switch self {
        case .polishedTile: return 1.0
        case .rubberMat: return 0.94
        case .wetFloor: return 0.97
        case .freezerFrost: return 1.02
        case .loadingDockAsphalt: return 0.98
        case .carpetRunner: return 0.82
        case .spillDebris: return 0.6
        }
    }

    /// Rolling resistance, in m/s² of deceleration at top speed.
    public var rollingResistance: Double {
        switch self {
        case .polishedTile: return 1.4
        case .rubberMat: return 2.6
        case .wetFloor: return 1.0
        case .freezerFrost: return 0.8
        case .loadingDockAsphalt: return 2.0
        case .carpetRunner: return 4.2
        case .spillDebris: return 6.0
        }
    }

    /// Whether a cart can meaningfully steer here; used by the AI to decide
    /// when to bail out of a drift.
    public var isSlippery: Bool {
        lateralGrip < 2.5
    }

    public var displayName: String {
        switch self {
        case .polishedTile: return "Polished Tile"
        case .rubberMat: return "Entrance Matting"
        case .wetFloor: return "Wet Floor"
        case .freezerFrost: return "Freezer Frost"
        case .loadingDockAsphalt: return "Loading Dock"
        case .carpetRunner: return "Carpet Runner"
        case .spillDebris: return "Spilled Stock"
        }
    }
}
