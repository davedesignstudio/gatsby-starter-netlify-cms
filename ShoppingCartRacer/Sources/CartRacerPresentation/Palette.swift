import Foundation

/// Art direction, expressed in plain numbers so it can be unit tested and so the
/// renderer has a single source of truth for every colour on screen.
public struct Palette: Sendable {
    public var floorBase: RacerColor
    public var floorAlternate: RacerColor
    public var floorGrout: RacerColor
    public var shoulder: RacerColor
    public var shelfBody: RacerColor
    public var shelfTrim: RacerColor
    public var shelfStock: [RacerColor]
    public var backdrop: RacerColor
    public var ceilingLight: RacerColor
    public var accent: RacerColor
    public var lineMarking: RacerColor

    public static let hudBackground = RacerColor(hex: 0x11131A)
    public static let hudForeground = RacerColor(hex: 0xF6F7FB)
    public static let hudMuted = RacerColor(hex: 0x8A90A6)
    public static let boostGlow = RacerColor(hex: 0xFFD166)
    public static let danger = RacerColor(hex: 0xEF476F)
    public static let good = RacerColor(hex: 0x06D6A0)

    /// Surfaces are tinted rather than fully coloured, so the floor still reads
    /// as one continuous shop even where the grip changes.
    public static func tint(for surface: Surface) -> RacerColor {
        switch surface {
        case .polishedTile: return RacerColor(hex: 0xD9DEE7)
        case .rubberMat: return RacerColor(hex: 0x3B4252)
        case .wetFloor: return RacerColor(hex: 0x9FD8F2)
        case .freezerFrost: return RacerColor(hex: 0xCDEFF7)
        case .loadingDockAsphalt: return RacerColor(hex: 0x585F6B)
        case .carpetRunner: return RacerColor(hex: 0xA3453B)
        case .spillDebris: return RacerColor(hex: 0xB8A177)
        }
    }

    public static func palette(for theme: TrackTheme) -> Palette {
        switch theme {
        case .grocery:
            return Palette(
                floorBase: RacerColor(hex: 0xE6E9EF),
                floorAlternate: RacerColor(hex: 0xDCE0E8),
                floorGrout: RacerColor(hex: 0xC3C8D2),
                shoulder: RacerColor(hex: 0xC8B79A),
                shelfBody: RacerColor(hex: 0x4A5568),
                shelfTrim: RacerColor(hex: 0xF4A259),
                shelfStock: [
                    RacerColor(hex: 0xEF476F),
                    RacerColor(hex: 0xFFD166),
                    RacerColor(hex: 0x06D6A0),
                    RacerColor(hex: 0x118AB2),
                    RacerColor(hex: 0xF78C6B)
                ],
                backdrop: RacerColor(hex: 0x1B1E27),
                ceilingLight: RacerColor(hex: 0xFFF6D8),
                accent: RacerColor(hex: 0xFFB703),
                lineMarking: RacerColor(hex: 0xFFFFFF)
            )
        case .frozenFoods:
            return Palette(
                floorBase: RacerColor(hex: 0xDCEEF5),
                floorAlternate: RacerColor(hex: 0xCFE6F0),
                floorGrout: RacerColor(hex: 0xAFCEDC),
                shoulder: RacerColor(hex: 0xA9C4CF),
                shelfBody: RacerColor(hex: 0x2E4A5A),
                shelfTrim: RacerColor(hex: 0x8ADAF2),
                shelfStock: [
                    RacerColor(hex: 0xB8E1FF),
                    RacerColor(hex: 0x6FD6E8),
                    RacerColor(hex: 0xE8F7FF),
                    RacerColor(hex: 0x4C8DA8),
                    RacerColor(hex: 0xD1F0E0)
                ],
                backdrop: RacerColor(hex: 0x101C24),
                ceilingLight: RacerColor(hex: 0xEAF9FF),
                accent: RacerColor(hex: 0x48CAE4),
                lineMarking: RacerColor(hex: 0xF0FBFF)
            )
        case .loadingDock:
            return Palette(
                floorBase: RacerColor(hex: 0x5A6270),
                floorAlternate: RacerColor(hex: 0x515865),
                floorGrout: RacerColor(hex: 0x3F4551),
                shoulder: RacerColor(hex: 0x6E6455),
                shelfBody: RacerColor(hex: 0x3A3F4B),
                shelfTrim: RacerColor(hex: 0xE0A72C),
                shelfStock: [
                    RacerColor(hex: 0x9C6B3F),
                    RacerColor(hex: 0xB58A5A),
                    RacerColor(hex: 0x7E8A97),
                    RacerColor(hex: 0xE0A72C),
                    RacerColor(hex: 0x6B4F3A)
                ],
                backdrop: RacerColor(hex: 0x0E1116),
                ceilingLight: RacerColor(hex: 0xFFE9B0),
                accent: RacerColor(hex: 0xE76F51),
                lineMarking: RacerColor(hex: 0xF2E8C9)
            )
        }
    }
}
