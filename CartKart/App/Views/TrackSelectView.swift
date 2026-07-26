import CartKartCore
import SwiftUI

struct TrackSelectView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(
                title: game.mode == .timeTrial ? "Time Trial" : "Pick a course",
                subtitle: game.mode == .timeTrial ? "No rivals, no items, no excuses" : "Four aisles, four flavours of chaos"
            ) {
                game.go(to: .menu)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(TrackLibrary.all, id: \.id) { track in
                        TrackCard(
                            track: track,
                            isSelected: game.selectedTrackID == track.id,
                            bestLap: storage.bestLap(for: track.id)
                        ) {
                            Feedback.shared.impact(.light)
                            game.selectedTrackID = track.id
                        }
                    }
                }
            }

            ArcadeButton(
                title: game.mode == .timeTrial ? "Start Trial" : "Race",
                systemImage: "flag.checkered",
                isProminent: true
            ) {
                if game.mode == .timeTrial {
                    game.startTimeTrial()
                } else {
                    game.startSingleRace()
                }
            }
        }
        .padding(22)
    }
}

private struct TrackCard: View {
    let track: Track
    let isSelected: Bool
    let bestLap: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                TrackThumbnail(track: track)
                    .frame(width: 92, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.arcade(20))
                        .foregroundStyle(Palette.text)
                    Text(track.subtitle)
                        .font(.arcadeBody(12))
                        .foregroundStyle(Palette.subtleText)
                    Text(track.theme.tagline)
                        .font(.arcadeBody(12))
                        .foregroundStyle(track.theme.accent.color)
                    HStack(spacing: 10) {
                        Label("\(track.lapCount) laps", systemImage: "arrow.triangle.2.circlepath")
                        if let bestLap {
                            Label(TimeFormat.lap(bestLap), systemImage: "stopwatch")
                        }
                    }
                    .font(.arcadeBody(11))
                    .foregroundStyle(Palette.subtleText)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? track.theme.accent.color.opacity(0.18) : Palette.panel.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Palette.primary : Palette.panelBorder, lineWidth: isSelected ? 3 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Outline of the course, drawn straight from the simulation's centreline.
struct TrackThumbnail: View {
    let track: Track
    var lineWidth: CGFloat = 7

    var body: some View {
        Canvas { canvas, size in
            let projection = RaceHUDModel.MinimapProjection(track: track)
            var path = Path()
            for (index, sample) in track.samples.enumerated() where index % 3 == 0 {
                let mapped = projection.map(sample.position)
                let point = CGPoint(x: mapped.x * size.width, y: mapped.y * size.height)
                if path.isEmpty {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            canvas.stroke(path, with: .color(track.theme.floor.color.opacity(0.9)), lineWidth: lineWidth)
            canvas.stroke(path, with: .color(track.theme.accent.color), lineWidth: 1.5)
        }
    }
}
