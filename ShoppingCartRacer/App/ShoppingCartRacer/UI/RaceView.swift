import SpriteKit
import SwiftUI

struct RaceView: View {
    @EnvironmentObject private var store: GameStore
    @State private var coordinator: RaceCoordinator?
    @State private var failureMessage: String?
    /// Remembered so a restart can rebuild the scene without a geometry pass.
    @State private var lastKnownSize = CGSize(width: 844, height: 390)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let coordinator {
                    SpriteView(scene: coordinator.scene, options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()

                    RaceHUD(coordinator: coordinator)

                    TouchControlsView(coordinator: coordinator, settings: store.settings)

                    if coordinator.isPaused {
                        PauseOverlay(
                            trackName: coordinator.trackName,
                            onResume: { coordinator.setPaused(false) },
                            onRestart: {
                                coordinator.setPaused(false)
                                store.restartRace()
                            },
                            onQuit: {
                                coordinator.setPaused(false)
                                store.abandonRace()
                            }
                        )
                    }
                } else if let failureMessage {
                    VStack(spacing: 16) {
                        Text(failureMessage)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.foreground)
                        Button("Back to menu") { store.abandonRace() }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: 240)
                    }
                    .padding(32)
                } else {
                    ProgressView()
                        .tint(Theme.accent)
                }
            }
            .onAppear { build(size: proxy.size) }
            .onDisappear { coordinator?.stopEngineSound() }
        }
        // A new generation means "start a fresh race", including a restart of the
        // one we are already on.
        .onChange(of: store.session.raceGeneration) { _ in
            coordinator = nil
            build(size: lastKnownSize)
        }
    }

    private func build(size: CGSize) {
        guard coordinator == nil else { return }
        guard let configuration = store.makeRaceConfiguration() else {
            failureMessage = "That course could not be loaded."
            return
        }

        let sceneSize = size.width > 1 && size.height > 1 ? size : lastKnownSize
        lastKnownSize = sceneSize
        let created = RaceCoordinator(
            configuration: configuration,
            settings: store.settings,
            size: sceneSize,
            audio: store.audio,
            haptics: store.haptics,
            gamepad: store.gamepad,
            motion: store.motion,
            onComplete: { result in
                // Let the finish land before cutting to the results.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    store.finishRace(result: result)
                }
            }
        )
        coordinator = created
    }
}

struct PauseOverlay: View {
    let trackName: String
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("PAUSED")
                    .font(Theme.title(30))
                    .foregroundStyle(Theme.foreground)
                Text(trackName)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 8)

                Button("Resume", action: onResume)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Restart race", action: onRestart)
                    .buttonStyle(PrimaryButtonStyle(isProminent: false))
                Button("Abandon shop", action: onQuit)
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.danger, isProminent: false))
            }
            .frame(maxWidth: 300)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.panel))
        }
    }
}
