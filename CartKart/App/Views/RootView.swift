import CartKartCore
import SwiftUI

/// Top level screen switcher.
struct RootView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            switch game.route {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .cartSelect:
                CartSelectView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .trackSelect:
                TrackSelectView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .race:
                RaceView(configuration: game.currentRace ?? game.makeRaceConfiguration())
                    .id(game.raceInstanceID)
                    .transition(.opacity)
            case .results:
                ResultsView()
                    .transition(.opacity)
            case .cupStandings:
                CupStandingsView()
                    .transition(.opacity)
            case .howToPlay:
                HowToPlayView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Feedback.shared.isSoundEnabled = storage.soundEnabled
            Feedback.shared.isHapticsEnabled = storage.hapticsEnabled
            Feedback.shared.start()
        }
        .onChange(of: storage.soundEnabled) { newValue in
            Feedback.shared.isSoundEnabled = newValue
        }
        .onChange(of: storage.hapticsEnabled) { newValue in
            Feedback.shared.isHapticsEnabled = newValue
        }
    }
}
