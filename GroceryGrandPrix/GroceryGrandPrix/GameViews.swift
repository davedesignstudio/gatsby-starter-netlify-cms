import SwiftUI

// MARK: - Menu

struct MenuView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ZStack {
            LinearGradient(colors: [.ggpDark, Color(red: 0.10, green: 0.16, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("🛒💨")
                    .font(.system(size: 60))
                Text("GROCERY GRAND PRIX")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.ggpAccent)
                    .multilineTextAlignment(.center)
                Text("Shopping Cart Kart Racing")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                if let best = game.bestTime {
                    Text("Best Lap Time  " + GameState.format(time: best))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.ggpAccent.opacity(0.9))
                }

                Button {
                    game.requestStart()
                } label: {
                    Text("START RACE")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.ggpDark)
                        .frame(width: 260, height: 62)
                        .background(Capsule().fill(Color.ggpAccent))
                }
                .padding(.top, 6)

                howToPlay
                    .padding(.top, 8)
            }
            .padding()
        }
    }

    private var howToPlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW TO PLAY")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Label("Steer with ◀ ▶.  You auto-accelerate.", systemImage: "arrow.left.arrow.right")
            Label("Hold DRIFT in turns to charge a mini-boost.", systemImage: "flame.fill")
            Label("Grab 🛒 boxes for items, then tap USE.", systemImage: "cube.box.fill")
            Label("🥤 Boost · 🥛 Milk trap · 🥫 Can attack.", systemImage: "bolt.fill")
            Text("Finish \(game.totalLaps) laps ahead of the pack!")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.ggpAccent.opacity(0.9))
                .padding(.top, 2)
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.85))
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.ggpPanel.opacity(0.9)))
    }
}

// MARK: - Racing overlay (HUD + controls + countdown)

struct RacingOverlay: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ZStack {
            VStack {
                topHUD
                Spacer()
                controls
            }
            .padding()

            if !game.countdownText.isEmpty {
                Text(game.countdownText)
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundColor(game.countdownText == "GO!" ? .green : .ggpAccent)
                    .shadow(radius: 8)
                    .transition(.scale)
            }
        }
    }

    private var topHUD: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                hudPill(title: "LAP", value: "\(game.lap)/\(game.totalLaps)")
                hudPill(title: "POS", value: "\(game.rank)/\(game.racerCount)")
                hudPill(title: "TIME", value: GameState.format(time: game.raceTime))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(game.speed)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(game.boostActive ? .green : .white)
                    Text("km/h")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                if game.boostActive {
                    Text("BOOST!")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ggpPanel.opacity(0.85)))
        }
    }

    private func hudPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(minWidth: 62)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ggpPanel.opacity(0.85)))
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 18) {
                HoldButton { pressed in game.steerLeft = pressed } label: {
                    controlCircle(text: "◀", color: .blue)
                }
                HoldButton { pressed in game.steerRight = pressed } label: {
                    controlCircle(text: "▶", color: .blue)
                }
            }
            Spacer()
            HStack(alignment: .bottom, spacing: 18) {
                HoldButton { pressed in game.driftHeld = pressed } label: {
                    controlCircle(text: "DRIFT", color: .orange, small: true)
                }
                HoldButton { pressed in game.brakeHeld = pressed } label: {
                    controlCircle(text: "BRAKE", color: .red, small: true)
                }
                itemButton
            }
        }
    }

    private var itemButton: some View {
        Button {
            if game.heldItem != nil { game.useItemRequested = true }
        } label: {
            VStack(spacing: 2) {
                Text(game.heldItem?.icon ?? "—")
                    .font(.system(size: 34))
                Text(game.heldItem == nil ? "ITEM" : "USE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 92, height: 92)
            .background(
                Circle().fill(game.heldItem == nil ? Color.ggpPanel.opacity(0.7) : Color.green.opacity(0.85))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
        }
    }

    private func controlCircle(text: String, color: Color, small: Bool = false) -> some View {
        Text(text)
            .font(.system(size: small ? 16 : 34, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: small ? 80 : 92, height: small ? 80 : 92)
            .background(Circle().fill(color.opacity(0.8)))
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
    }
}

// MARK: - Results

struct ResultsView: View {
    @EnvironmentObject var game: GameState

    private var playerResult: RaceResult? {
        game.results.first(where: { $0.isPlayer })
    }

    var body: some View {
        ZStack {
            Color.ggpDark.opacity(0.94).ignoresSafeArea()

            VStack(spacing: 14) {
                Text(headline)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.ggpAccent)

                if let pr = playerResult {
                    Text("Your time  " + GameState.format(time: pr.time))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }

                VStack(spacing: 8) {
                    ForEach(game.results) { r in
                        HStack {
                            Text(medal(r.position))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(width: 44, alignment: .leading)
                            Text(r.name)
                                .font(.system(size: 18, weight: r.isPlayer ? .heavy : .medium, design: .rounded))
                                .foregroundColor(r.isPlayer ? .ggpAccent : .white)
                            Spacer()
                            Text(r.finished ? GameState.format(time: r.time) : "—")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(r.isPlayer ? Color.ggpAccent.opacity(0.15) : Color.ggpPanel.opacity(0.8)))
                    }
                }
                .frame(maxWidth: 420)

                HStack(spacing: 14) {
                    Button { game.requestRestart() } label: {
                        actionLabel("RACE AGAIN", bg: .ggpAccent, fg: .ggpDark)
                    }
                    Button { game.phase = .menu } label: {
                        actionLabel("MENU", bg: .ggpPanel, fg: .white)
                    }
                }
                .padding(.top, 6)
            }
            .padding()
        }
    }

    private var headline: String {
        guard let pr = playerResult else { return "FINISH!" }
        switch pr.position {
        case 1: return "🏆 YOU WIN!"
        case 2: return "🥈 2ND PLACE"
        case 3: return "🥉 3RD PLACE"
        default: return "FINISH!"
        }
    }

    private func medal(_ pos: Int) -> String {
        switch pos {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(pos)."
        }
    }

    private func actionLabel(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundColor(fg)
            .frame(width: 160, height: 54)
            .background(Capsule().fill(bg))
    }
}

// MARK: - Hold button

struct HoldButton<Label: View>: View {
    let onPressChange: (Bool) -> Void
    @ViewBuilder let label: () -> Label
    @GestureState private var pressing = false

    var body: some View {
        label()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, state, _ in state = true }
            )
            .onChange(of: pressing) { newValue in
                onPressChange(newValue)
            }
    }
}
