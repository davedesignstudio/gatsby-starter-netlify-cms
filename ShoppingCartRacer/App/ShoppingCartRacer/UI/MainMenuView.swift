import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var store: GameStore
    @State private var rollingHeading = 0.0

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height

            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TROLLEY")
                        .font(Theme.title(isWide ? 46 : 38))
                        .foregroundStyle(Theme.accent)
                    Text("TROPHY")
                        .font(Theme.title(isWide ? 46 : 38))
                        .foregroundStyle(Theme.foreground)
                    Text("Supermarket kart racing")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    CartPreview(racer: store.session.selectedRacer, heading: rollingHeading)
                        .frame(height: isWide ? 150 : 120)
                        .padding(.vertical, 8)

                    HStack(spacing: 14) {
                        Label("\(store.session.book.cupWins)", systemImage: "trophy.fill")
                        Label("\(store.session.book.totalTokens)", systemImage: "circle.circle.fill")
                        Label("\(store.session.book.racesFinished)", systemImage: "flag.checkered")
                    }
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Button("Trolley Trophy") { store.beginGrandPrix() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Single Race") { store.beginSingleRace() }
                        .buttonStyle(PrimaryButtonStyle(isProminent: false))
                    Button("Records") { store.go(to: .records) }
                        .buttonStyle(PrimaryButtonStyle(isProminent: false))
                    Button("Settings") { store.go(to: .settings) }
                        .buttonStyle(PrimaryButtonStyle(isProminent: false))

                    Text("Hold the drift button through a corner, release for a mini-turbo.")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .frame(maxWidth: isWide ? 300 : .infinity)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            // A slow idle wobble, as if the cart is rolling on a wonky wheel.
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                rollingHeading = 0.12
            }
        }
    }
}
