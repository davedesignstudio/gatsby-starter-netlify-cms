import Foundation

/// What the wheels are rolling over. Every surface scales grip and top speed,
/// and some of them actively try to ruin your line.
public enum Surface: String, Sendable, CaseIterable {
    /// Polished aisle floor: the intended racing surface.
    case linoleum
    /// Outside the aisle. Scuffed, dusty, slow.
    case scuffed
    /// Produce misters left a slick. Very low grip, normal speed: entertaining.
    case wet
    /// Flattened cardboard and shrink wrap. Grippy but draggy.
    case cardboard
    /// Freezer section. Almost no grip at all.
    case ice
    /// Buffed strip that shoves you forward.
    case boostStrip

    public var gripMultiplier: Double {
        switch self {
        case .linoleum: return 1.0
        case .scuffed: return 0.85
        case .wet: return 0.4
        case .cardboard: return 0.95
        case .ice: return 0.22
        case .boostStrip: return 1.05
        }
    }

    public var speedMultiplier: Double {
        switch self {
        case .linoleum: return 1.0
        case .scuffed: return 0.62
        case .wet: return 0.95
        case .cardboard: return 0.72
        case .ice: return 1.0
        case .boostStrip: return 1.0
        }
    }

    /// Extra velocity-proportional drag, 1/s.
    public var rollingDrag: Double {
        switch self {
        case .linoleum: return 0.0
        case .scuffed: return 1.5
        case .wet: return 0.1
        case .cardboard: return 1.1
        case .ice: return 0.0
        case .boostStrip: return 0.0
        }
    }

    public var isOffTrack: Bool {
        self == .scuffed || self == .cardboard
    }
}
