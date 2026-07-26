import CartKartCore
import Combine
import CoreGraphics
import SwiftUI

/// Everything the SwiftUI overlay needs to draw the HUD.
///
/// The scene pushes a snapshot a few times a second instead of on every frame:
/// SpriteKit redraws at 60Hz happily, SwiftUI does not need to.
final class RaceHUDModel: ObservableObject {
    struct Snapshot: Equatable {
        var lap: Int = 1
        var totalLaps: Int = 3
        var position: Int = 1
        var racerCount: Int = 8
        var item: ItemKind?
        var itemCharges: Int = 0
        var isItemSpinning: Bool = false
        var speedFraction: Double = 0
        var raceTime: Double = 0
        var currentLapTime: Double = 0
        var lastLapTime: Double?
        var bestLapTime: Double?
        var driftTier: DriftTier = .none
        var isBoosting: Bool = false
        var isWrongWay: Bool = false
        var isFinalLap: Bool = false
        var hasFinished: Bool = false
        /// "3", "2", "1", "GO!" or nil once racing.
        var countdown: String?
    }

    struct MinimapDot: Equatable, Identifiable {
        var id: Int
        var point: CGPoint
        var color: TrackTheme.RGB
        var isPlayer: Bool
    }

    struct Standing: Equatable, Identifiable {
        var id: Int
        var place: Int
        var name: String
        var emblem: String
        var isPlayer: Bool
    }

    @Published var snapshot = Snapshot()
    /// Track outline in unit space, computed once per race.
    @Published var minimapOutline: [CGPoint] = []
    @Published var minimapDots: [MinimapDot] = []
    @Published var standings: [Standing] = []
    /// Big centre-screen shout such as "FINAL LAP".
    @Published var banner: String?
    @Published var isPaused = false

    private var bannerToken = 0

    func showBanner(_ text: String, duration: Double = 1.6) {
        banner = text
        bannerToken += 1
        let token = bannerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }

    /// Converts world positions into the unit square used by the minimap.
    struct MinimapProjection {
        var origin: CGPoint
        var scale: CGFloat

        init(track: Track) {
            var minX = Double.greatestFiniteMagnitude
            var minY = Double.greatestFiniteMagnitude
            var maxX = -Double.greatestFiniteMagnitude
            var maxY = -Double.greatestFiniteMagnitude
            for sample in track.samples {
                minX = min(minX, sample.position.x)
                minY = min(minY, sample.position.y)
                maxX = max(maxX, sample.position.x)
                maxY = max(maxY, sample.position.y)
            }
            let padding = 220.0
            minX -= padding
            minY -= padding
            maxX += padding
            maxY += padding
            let span = max(maxX - minX, maxY - minY)
            origin = CGPoint(x: minX, y: minY)
            scale = span > 0 ? CGFloat(1 / span) : 1
        }

        func map(_ position: Vec2) -> CGPoint {
            CGPoint(
                x: (CGFloat(position.x) - origin.x) * scale,
                // Flip y: SpriteKit points up, SwiftUI canvases point down.
                y: 1 - (CGFloat(position.y) - origin.y) * scale
            )
        }
    }
}
