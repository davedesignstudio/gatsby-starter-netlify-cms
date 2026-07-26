import CartKartCore
import SpriteKit
import SwiftUI

/// Hosts the SpriteKit race, the HUD and the touch controls.
struct RaceView: View {
    let configuration: RaceConfiguration

    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage
    @StateObject private var hud = RaceHUDModel()
    @StateObject private var controls = ControlState()
    @State private var scene: RaceScene?
    @State private var showPauseMenu = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                        .ignoresSafeArea()
                } else {
                    LoadingCard(track: configuration.track)
                }

                HUDOverlay(hud: hud, track: configuration.track, isTimeTrial: configuration.mode == .timeTrial)
                    .allowsHitTesting(false)

                ControlsOverlay(controls: controls, hud: hud, scheme: storage.controlScheme)

                topBar

                if showPauseMenu {
                    PauseMenu(
                        trackName: configuration.track.name,
                        onResume: { setPaused(false) },
                        onRestart: {
                            setPaused(false)
                            game.retryRace()
                        },
                        onQuit: {
                            setPaused(false)
                            game.quitToMenu()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .onAppear {
                controls.beginTiltIfNeeded(storage.controlScheme)
                if scene == nil {
                    scene = makeScene(size: proxy.size)
                }
            }
            .onDisappear {
                controls.stopTilt()
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var topBar: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    setPaused(true)
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.arcade(16))
                        .foregroundStyle(.white)
                        .padding(11)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func setPaused(_ paused: Bool) {
        hud.isPaused = paused
        withAnimation(.easeInOut(duration: 0.18)) {
            showPauseMenu = paused
        }
        if paused { controls.reset() }
    }

    private func makeScene(size: CGSize) -> RaceScene {
        let engine = RaceEngine(configuration: configuration)
        let scene = RaceScene(
            size: size == .zero ? CGSize(width: 1024, height: 768) : size,
            engine: engine,
            controls: controls,
            hud: hud,
            controlScheme: storage.controlScheme
        )
        scene.onRaceComplete = { results, lapTimes, totalTime in
            // Let the finish banner breathe before the results table appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                game.raceFinished(results: results, playerLapTimes: lapTimes, playerTotalTime: totalTime)
            }
        }
        return scene
    }
}

/// Shown for the frame or two before the scene exists.
private struct LoadingCard: View {
    let track: Track

    var body: some View {
        ZStack {
            track.theme.floor.color.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(track.name)
                    .font(.arcade(30))
                    .foregroundStyle(Palette.text)
                Text(track.theme.tagline)
                    .font(.arcadeBody(15))
                    .foregroundStyle(Palette.subtleText)
            }
        }
    }
}

private struct PauseMenu: View {
    let trackName: String
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Paused")
                    .font(.arcade(34))
                    .foregroundStyle(Palette.text)
                Text(trackName)
                    .font(.arcadeBody(14))
                    .foregroundStyle(Palette.subtleText)
                ArcadeButton(title: "Resume", systemImage: "play.fill", isProminent: true, action: onResume)
                ArcadeButton(title: "Restart race", systemImage: "arrow.counterclockwise", action: onRestart)
                ArcadeButton(title: "Quit to menu", systemImage: "xmark", tint: Palette.danger, action: onQuit)
            }
            .frame(maxWidth: 380)
            .padding(26)
        }
    }
}
