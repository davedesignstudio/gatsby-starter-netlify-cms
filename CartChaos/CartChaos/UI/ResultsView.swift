import SwiftUI

struct ResultsView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(playerWon ? "🏆 VICTORY!" : "RACE OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(playerWon ? .yellow : .white)

                if !playerWon {
                    Text("Better luck next aisle!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(gameState.standings) { standing in
                        standingRow(standing)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button {
                        gameState.startRace()
                    } label: {
                        Text("RACE AGAIN")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.cyan)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        gameState.returnToMenu()
                    } label: {
                        Text("MENU")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private var playerWon: Bool {
        gameState.standings.first?.isPlayer == true
    }

    private func standingRow(_ standing: RacerStanding) -> some View {
        HStack {
            Text(positionEmoji(standing.position))
                .font(.title2)

            Text(standing.name)
                .font(.headline)
                .foregroundStyle(standing.isPlayer ? .yellow : .white)

            Spacer()

            if let time = standing.finishTime {
                Text(formatTime(time))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(standing.isPlayer ? Color.yellow.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func positionEmoji(_ pos: Int) -> String {
        switch pos {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(pos)."
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, ms)
    }
}
