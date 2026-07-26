import SwiftUI

@main
struct ShoppingCartRacerApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .onAppear { store.startSystems() }
        }
    }
}

/// Swaps screens based on the session's route.
struct RootView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            Theme.menuBackground

            switch store.session.route {
            case .mainMenu:
                MainMenuView()
            case .characterSelect:
                CharacterSelectView()
            case .trackSelect:
                TrackSelectView()
            case .race:
                RaceView()
            case .results:
                ResultsView()
            case .cupStandings:
                CupStandingsView()
            case .settings:
                SettingsView()
            case .records:
                RecordsView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.session.route)
        .onChange(of: store.session.route) { _ in
            store.syncMotionUpdates(forRacing: store.session.route == .race)
        }
    }
}
