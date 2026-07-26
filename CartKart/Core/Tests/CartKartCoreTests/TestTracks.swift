import Foundation
@testable import CartKartCore

/// Synthetic courses used to isolate the driving model from the quirks of any
/// particular shop floor.
enum TestTracks {
    private static let theme = TrackTheme(
        floor: .init(0.9, 0.9, 0.9),
        rough: .init(0.6, 0.6, 0.6),
        shelf: .init(0.3, 0.3, 0.3),
        accent: .init(1, 0, 0),
        tagline: "Test aisle"
    )

    private static func oval(
        id: String,
        radiusX: Double,
        radiusY: Double,
        halfWidth: Double,
        shoulderWidth: Double,
        points: Int = 24,
        sampleSpacing: Double = 16
    ) -> Track {
        let controlPoints = (0..<points).map { index -> TrackControlPoint in
            let angle = Double(index) / Double(points) * 2 * .pi
            return TrackControlPoint(
                Vec2(cos(angle) * radiusX, sin(angle) * radiusY),
                halfWidth: halfWidth
            )
        }
        return Track(
            id: id,
            name: id,
            subtitle: "",
            theme: theme,
            controlPoints: controlPoints,
            shoulderWidth: shoulderWidth,
            sampleSpacing: sampleSpacing
        )
    }

    /// Huge and generous: a cart can hold a fixed input for eight seconds and
    /// drift in circles without ever meeting a shelf.
    static let wideOval = oval(
        id: "test-wide-oval",
        radiusX: 6000,
        radiusY: 5000,
        halfWidth: 2500,
        shoulderWidth: 1500,
        sampleSpacing: 40
    )

    /// Small and narrow, for testing that the shelving actually contains carts.
    static let tightOval = oval(
        id: "test-tight-oval",
        radiusX: 700,
        radiusY: 500,
        halfWidth: 150,
        shoulderWidth: 60
    )
}
