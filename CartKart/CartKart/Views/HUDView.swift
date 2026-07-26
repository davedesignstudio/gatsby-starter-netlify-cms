import SwiftUI

struct HUDView: View {
    @ObservedObject var gameState: GameState
    let onExit: () -> Void

    var body: some View {
        VStack {
            if gameState.phase == .racing || gameState.phase == .countdown {
                racingHUD
            }

            Spacer()

            if gameState.phase == .finished {
                resultsOverlay
            } else if gameState.phase == .countdown {
                countdownOverlay
            }
        }
        .padding()
    }

    private var racingHUD: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LAP \(min(gameState.playerLap + 1, gameState.totalLaps))/\(gameState.totalLaps)")
                    .font(.title3.weight(.black))
                Text(gameState.positionText)
                    .font(.headline)
                    .foregroundColor(.yellow)
                if let item = gameState.heldItem {
                    Label(item.displayName, systemImage: item.iconName)
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f", gameState.playerSpeed))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                Text("MPH")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(12)
            .background(.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var countdownOverlay: some View {
        Text(gameState.countdownText)
            .font(.system(size: 96, weight: .black, design: .rounded))
            .foregroundStyle(.yellow)
            .shadow(color: .orange, radius: 20)
            .transition(.scale)
    }

    private var resultsOverlay: some View {
        VStack(spacing: 20) {
            Text(gameState.playerPosition == 1 ? "YOU WIN!" : "RACE OVER")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(gameState.playerPosition == 1 ? .yellow : .white)

            Text("You finished \(ordinal(gameState.playerPosition))")
                .font(.title2)

            Text(String(format: "Best lap: %.2fs", gameState.bestLapTime))
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(gameState.finalStandings, id: \.name) { standing in
                    HStack {
                        Text("\(standing.rank).")
                            .fontWeight(.bold)
                            .frame(width: 28, alignment: .leading)
                        Text(standing.name)
                        Spacer()
                        if standing.isPlayer {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .font(.body.weight(standing.isPlayer ? .bold : .regular))
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 16) {
                Button("Menu", action: onExit)
                    .buttonStyle(GameButtonStyle(color: .gray))
            }
        }
        .padding(24)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }
}

struct GameButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}
