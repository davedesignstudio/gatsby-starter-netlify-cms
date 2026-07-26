import SwiftUI

struct RaceHUDView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        HStack {
            hudPanel(title: "POS", value: ordinal(gameState.playerPosition))

            Spacer()

            if gameState.phase == .countdown {
                Text("\(gameState.countdownValue)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            } else {
                hudPanel(title: "LAP", value: "\(min(gameState.currentLap, gameState.totalLaps))/\(gameState.totalLaps)")
            }

            Spacer()

            hudPanel(title: "TIME", value: formatTime(gameState.raceTime))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        if gameState.boostMeter > 0.1 {
            boostBar
        }
    }

    private var boostBar: some View {
        VStack(spacing: 4) {
            Text("DRIFT BOOST")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.cyan)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * gameState.boostMeter)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
    }

    private func hudPanel(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n {
        case 1: suffix = "ST"
        case 2: suffix = "ND"
        case 3: suffix = "RD"
        default: suffix = "TH"
        }
        return "\(n)\(suffix)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, ms)
    }
}
