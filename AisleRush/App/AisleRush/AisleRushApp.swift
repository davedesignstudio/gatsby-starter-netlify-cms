import SwiftUI

@main
struct AisleRushApp: App {
    @StateObject private var flow = GameFlow()

    init() {
        Audio.shared.prepare()
        Haptics.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(flow)
                .environmentObject(flow.store)
                .environmentObject(flow.settings)
                .preferredColorScheme(.light)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var flow: GameFlow

    var body: some View {
        ZStack {
            switch flow.screen {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .garage:
                GarageView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .trackSelect(let mode):
                TrackSelectView(mode: mode)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .cupSelect:
                CupSelectView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .race:
                if let session = flow.session {
                    RaceView(session: session)
                        .transition(.opacity)
                } else {
                    MainMenuView()
                }
            case .results:
                if let outcome = flow.outcome {
                    ResultsView(outcome: outcome)
                        .transition(.opacity)
                } else {
                    MainMenuView()
                }
            case .settings:
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .howToPlay:
                HowToPlayView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flow.screen)
    }
}
