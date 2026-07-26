import SwiftUI
import AisleRushCore

struct MainMenuView: View {
    @EnvironmentObject private var flow: GameFlow
    @EnvironmentObject private var store: GameStore
    @State private var wobble = false

    var body: some View {
        ZStack {
            StoreBackground()

            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AISLE")
                        .font(Theme.title(64))
                        .foregroundStyle(Theme.tomato)
                        .rotationEffect(.degrees(wobble ? -1.5 : -3))
                    Text("RUSH")
                        .font(Theme.title(64))
                        .foregroundStyle(Theme.ink)
                        .rotationEffect(.degrees(wobble ? 1.5 : 0.5))
                    Text("Trolley racing in the world's least suitable venue.")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .frame(maxWidth: 260, alignment: .leading)
                        .padding(.top, 6)

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        Button("Settings") { flow.go(to: .settings) }
                            .buttonStyle(QuietButtonStyle())
                        Button("How to play") { flow.go(to: .howToPlay) }
                            .buttonStyle(QuietButtonStyle())
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    menuButton("Grand Prix", subtitle: "Race a cup for points", tint: Theme.tomato) {
                        flow.go(to: .cupSelect)
                    }
                    menuButton("Quick Race", subtitle: "One course, eight carts", tint: Theme.sky) {
                        flow.go(to: .trackSelect(.singleRace))
                    }
                    menuButton("Time Trial", subtitle: "Empty store, best lap", tint: Theme.lime) {
                        flow.go(to: .trackSelect(.timeTrial))
                    }
                    menuButton("Garage", subtitle: garageSummary, tint: Theme.grape) {
                        flow.go(to: .garage)
                    }
                }
                .frame(width: 300)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                wobble = true
            }
        }
    }

    private var garageSummary: String {
        let setup = store.setup
        return "\(setup.character.name) · \(setup.frame.name)"
    }

    private func menuButton(_ title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.heading(21))
                    Text(subtitle)
                        .font(Theme.body(12))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PrimaryButtonStyle(tint: tint))
    }
}
