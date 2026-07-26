import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var state = GameState()

    // The scene is created once and reused across races.
    @State private var scene: GameScene = {
        let s = GameScene(size: CGSize(width: 1024, height: 768))
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear { scene.gameState = state }

            switch state.phase {
            case .menu:
                MenuView { scene.beginCountdown() }
            case .countdown:
                CountdownView(text: state.countdownText)
                RaceHUD(state: state).allowsHitTesting(false)
            case .racing:
                RaceHUD(state: state).allowsHitTesting(false)
            case .finished:
                RaceHUD(state: state).allowsHitTesting(false)
                ResultsView(results: state.results) {
                    scene.beginCountdown()
                } onMenu: {
                    scene.resetRace()
                    state.phase = .menu
                }
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - Menu

private struct MenuView: View {
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Text("CART CHAOS")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                Text("Aisle Racers")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text("Grab a runaway shopping cart and race\nthrough the Mega-Mart Grand Prix!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 4)

                Button(action: onPlay) {
                    Text("START RACE")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 46)
                        .padding(.vertical, 16)
                        .background(Color.yellow, in: Capsule())
                        .shadow(radius: 8)
                }
                .padding(.top, 12)

                VStack(spacing: 4) {
                    Text("◀ ▶  steer   •   auto-accelerate")
                    Text("USE  •  fire your pickup")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 18)
            }
            .padding(40)
        }
    }
}

// MARK: - Countdown

private struct CountdownView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 140, weight: .heavy, design: .rounded))
            .foregroundStyle(text == "GO!" ? .green : .white)
            .shadow(color: .black.opacity(0.6), radius: 10)
    }
}

// MARK: - HUD

private struct RaceHUD: View {
    @ObservedObject var state: GameState

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                infoPill(title: "LAP", value: "\(min(state.lap, state.totalLaps))/\(state.totalLaps)")
                Spacer()
                infoPill(title: "POS", value: state.positionText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ITEM").font(.caption).bold().foregroundStyle(.white.opacity(0.8))
                    Text(state.itemName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(state.itemName == "—" ? .white.opacity(0.5) : .yellow)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            Spacer()
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).bold().foregroundStyle(.white.opacity(0.8))
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Results

private struct ResultsView: View {
    let results: [String]
    let onRematch: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("FINISH!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)

                VStack(spacing: 8) {
                    ForEach(Array(results.enumerated()), id: \.offset) { idx, name in
                        HStack {
                            Text(medal(for: idx))
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .frame(width: 44, alignment: .leading)
                            Text(name)
                                .font(.system(size: 20, weight: name == "You" ? .heavy : .semibold,
                                               design: .rounded))
                                .foregroundStyle(name == "You" ? .yellow : .white)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(name == "You" ? Color.white.opacity(0.18) : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: 360)

                HStack(spacing: 16) {
                    Button(action: onMenu) {
                        Text("MENU")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(Color.white.opacity(0.2), in: Capsule())
                    }
                    Button(action: onRematch) {
                        Text("RACE AGAIN")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(Color.yellow, in: Capsule())
                    }
                }
                .padding(.top, 6)
            }
            .padding(30)
        }
    }

    private func medal(for idx: Int) -> String {
        switch idx {
        case 0: return "1st"
        case 1: return "2nd"
        case 2: return "3rd"
        default: return "\(idx + 1)th"
        }
    }
}
