import CartKartCore
import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height

            ZStack {
                Palette.storeGradient.ignoresSafeArea()
                AisleBackdrop()

                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 26) {
                            titleBlock
                            menuBlock
                        }
                    } else {
                        VStack(spacing: 22) {
                            titleBlock
                            menuBlock
                        }
                    }
                }
                .padding(26)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CART")
                .font(.arcade(64))
                .foregroundStyle(Palette.primary)
            Text("KART")
                .font(.arcade(64))
                .foregroundStyle(Palette.secondary)
                .offset(x: 26)
            Text("Trolley racing in aisle four")
                .font(.arcadeBody(16))
                .foregroundStyle(Palette.subtleText)
                .padding(.top, 4)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                CartBadge(profile: storage.selectedCart, size: 66)
                VStack(alignment: .leading, spacing: 2) {
                    Text(storage.selectedCart.name)
                        .font(.arcade(20))
                        .foregroundStyle(Palette.text)
                    Text(storage.selectedCart.tagline)
                        .font(.arcadeBody(12))
                        .foregroundStyle(Palette.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if storage.cupWins > 0 {
                Label("\(storage.cupWins) cup\(storage.cupWins == 1 ? "" : "s") won", systemImage: "trophy.fill")
                    .font(.arcadeBody(13))
                    .foregroundStyle(Palette.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var menuBlock: some View {
        VStack(spacing: 12) {
            ArcadeButton(
                title: "Trolley Cup",
                subtitle: "Four courses, points decide the winner",
                systemImage: "trophy.fill",
                isProminent: true
            ) {
                game.startCup()
            }
            ArcadeButton(title: "Quick Race", subtitle: "Pick a course and go", systemImage: "flag.checkered") {
                game.mode = .singleRace
                game.go(to: .trackSelect)
            }
            ArcadeButton(title: "Time Trial", subtitle: "Empty store, just you and the clock", systemImage: "stopwatch") {
                game.mode = .timeTrial
                game.go(to: .trackSelect)
            }
            ArcadeButton(title: "Choose Cart", subtitle: storage.selectedCart.name, systemImage: "cart.fill") {
                game.go(to: .cartSelect)
            }

            Panel(title: "Settings") {
                Picker("Difficulty", selection: $storage.difficulty) {
                    ForEach(RaceConfiguration.Difficulty.allCases, id: \.self) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)
                Text(storage.difficulty.blurb)
                    .font(.arcadeBody(12))
                    .foregroundStyle(Palette.subtleText)

                Picker("Steering", selection: $storage.controlScheme) {
                    ForEach(Storage.ControlScheme.allCases) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
                Text(storage.controlScheme.explanation)
                    .font(.arcadeBody(12))
                    .foregroundStyle(Palette.subtleText)

                HStack(spacing: 18) {
                    Toggle("Sound", isOn: $storage.soundEnabled)
                    Toggle("Haptics", isOn: $storage.hapticsEnabled)
                }
                .font(.arcadeBody(14))
                .tint(Palette.primary)
            }

            Button("How to play") {
                game.go(to: .howToPlay)
            }
            .font(.arcadeBody(14))
            .foregroundStyle(Palette.subtleText)
        }
        .frame(maxWidth: 460)
    }
}

/// Slowly scrolling shelving, so the menu looks like it is in a shop.
private struct AisleBackdrop: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            Canvas { canvas, size in
                let seconds = context.date.timeIntervalSinceReferenceDate
                let offset = CGFloat(seconds.truncatingRemainder(dividingBy: 12) / 12) * 180
                let spacing: CGFloat = 180
                var x = -spacing + offset
                while x < size.width + spacing {
                    let rect = CGRect(x: x, y: 0, width: 94, height: size.height)
                    canvas.fill(Path(rect), with: .color(.white.opacity(0.025)))
                    canvas.fill(
                        Path(CGRect(x: x + 12, y: 0, width: 70, height: size.height)),
                        with: .color(.white.opacity(0.02))
                    )
                    x += spacing
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
