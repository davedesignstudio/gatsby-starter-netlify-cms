import SpriteKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ZStack {
            ArcadeBackground()

            switch session.phase {
            case .menu:
                MenuView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .racing:
                RaceView(session: session, racer: session.selectedRacer)
                    .ignoresSafeArea()
                    .transition(.opacity)
            case .results(let result):
                ResultsView(result: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: phaseKey)
    }

    private var phaseKey: String {
        switch session.phase {
        case .menu: "menu"
        case .racing: "racing"
        case .results: "results"
        }
    }
}

private struct MenuView: View {
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 28)

                VStack(spacing: 4) {
                    Text("AISLE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(9)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("ALLIES")
                        .font(.system(size: 62, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, Color(red: 1, green: 0.43, blue: 0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 6)
                }

                Text("After-hours cart racing for the community pantry.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    Text("PICK YOUR CART")
                        .font(.caption.weight(.black))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.55))

                    HStack(spacing: 10) {
                        ForEach(RacerStyle.allCases) { racer in
                            RacerCard(
                                racer: racer,
                                isSelected: session.selectedRacer == racer
                            ) {
                                session.selectedRacer = racer
                            }
                        }
                    }
                }
                .padding(18)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 24))

                Button(action: session.startRace) {
                    HStack {
                        Text("START PANTRY RUN")
                        Image(systemName: "cart.fill.badge.plus")
                    }
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundStyle(Color(red: 0.11, green: 0.09, blue: 0.18))
                    .background(
                        LinearGradient(
                            colors: [.yellow, Color(red: 1, green: 0.52, blue: 0.12)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .shadow(color: .orange.opacity(0.35), radius: 18, y: 8)
                }

                HStack(spacing: 18) {
                    ControlHint(icon: "arrow.left.and.right", text: "HOLD TO STEER")
                    ControlHint(icon: "bolt.fill", text: "TAP TO BOOST")
                    ControlHint(icon: "shippingbox.fill", text: "GRAB SUPPLIES")
                }

                if let bestTime = session.bestTime {
                    Label("Best win  \(bestTime.raceTime)", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.yellow)
                }

                Text("An original arcade racer about neighbors helping neighbors.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RacerCard: View {
    let racer: RacerStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(racer.color.opacity(0.22))
                        .frame(width: 58, height: 58)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(racer.color)
                        .rotationEffect(.degrees(-7))
                }

                Text(racer.name)
                    .font(.headline.weight(.black))
                Text(racer.cartName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(
                isSelected ? racer.color.opacity(0.2) : .white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(isSelected ? racer.color : .white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ControlHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.system(size: 8, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RaceView: View {
    @State private var scene: RaceScene

    init(session: GameSession, racer: RacerStyle) {
        _scene = State(initialValue: RaceScene(session: session, racer: racer))
    }

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .background(Color(red: 0.08, green: 0.07, blue: 0.13))
    }
}

private struct ResultsView: View {
    @EnvironmentObject private var session: GameSession
    let result: RaceResult

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: result.place == 1 ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 62, weight: .black))
                .foregroundStyle(result.place == 1 ? .yellow : .white)
                .shadow(color: .orange.opacity(0.4), radius: 18)

            Text(result.place == 1 ? "PANTRY HERO!" : "RUN COMPLETE")
                .font(.system(size: 38, weight: .black, design: .rounded))

            Text(ordinal(result.place) + " PLACE")
                .font(.headline.weight(.black))
                .tracking(4)
                .foregroundStyle(.yellow)

            HStack(spacing: 12) {
                ResultStat(icon: "timer", value: result.time.raceTime, label: "TIME")
                ResultStat(icon: "shippingbox.fill", value: "\(result.pantryItems)", label: "SUPPLIES")
            }

            Button(action: session.startRace) {
                Label("RACE AGAIN", systemImage: "arrow.clockwise")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .foregroundStyle(.black)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 17))
            }

            Button("CHANGE CART", action: session.returnToMenu)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()
        }
        .padding(26)
        .frame(maxWidth: 540)
    }

    private func ordinal(_ number: Int) -> String {
        switch number {
        case 1: "1ST"
        case 2: "2ND"
        case 3: "3RD"
        default: "\(number)TH"
        }
    }
}

private struct ResultStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
            Text(value)
                .font(.title2.monospacedDigit().weight(.black))
            Text(label)
                .font(.caption2.weight(.black))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ArcadeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.15),
                    Color(red: 0.18, green: 0.08, blue: 0.24),
                    Color(red: 0.05, green: 0.14, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                for row in 0..<12 {
                    for column in 0..<7 where (row + column).isMultiple(of: 2) {
                        let rect = CGRect(
                            x: CGFloat(column) * size.width / 7,
                            y: CGFloat(row) * size.height / 12,
                            width: size.width / 7,
                            height: size.height / 12
                        )
                        context.fill(Path(rect), with: .color(.white.opacity(0.018)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
