import SpriteKit
import SwiftUI
import AisleRushCore

struct RaceView: View {
    @ObservedObject var session: RaceSession
    @EnvironmentObject private var settings: GameSettings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(
                scene: session.scene,
                options: [.ignoresSiblingOrder],
                debugOptions: []
            )
            .ignoresSafeArea()
            // Restarting builds a new session and a new scene in the same
            // position in the view tree; the id forces SpriteView to present
            // the new one rather than update in place.
            .id(ObjectIdentifier(session))

            RaceHUDView(hud: session.hud, track: session.track, simulation: session.simulation)
                .allowsHitTesting(false)

            ControlPadView(
                input: session.input,
                steering: settings.steering,
                autoAccelerate: settings.autoAccelerate,
                heldItem: session.hud.heldItem,
                itemIsRolling: session.hud.itemIsRolling,
                driftTier: session.hud.driftTier,
                isCountdown: session.hud.countdown != nil
            )
            .opacity(session.isPaused ? 0 : 1)
            .allowsHitTesting(!session.isPaused)

            pauseButton

            if session.isPaused {
                PauseOverlay(session: session)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.isPaused)
        .statusBarHidden()
        // The controls sit right on the home indicator; make the system wait
        // for a second swipe before it takes one.
        .defersSystemGestures(on: .bottom)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.isPaused = true
            } else {
                // SpriteKit clears isPaused itself on activation, so put the
                // pause back if the player left the game paused.
                session.scene.isPaused = session.isPaused
            }
        }
    }

    private var pauseButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    Haptics.selection()
                    session.isPaused.toggle()
                } label: {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.ink.opacity(0.45)))
                }
                .padding(.trailing, 14)
                .padding(.top, 10)
            }
            Spacer()
        }
    }
}

struct PauseOverlay: View {
    @ObservedObject var session: RaceSession
    @EnvironmentObject private var flow: GameFlow

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            Panel(padding: 22) {
                VStack(spacing: 14) {
                    Text("Paused")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.ink)
                    Text(session.trackDefinition.name)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.ink.opacity(0.55))

                    HStack(spacing: 10) {
                        Button("Resume") { session.isPaused = false }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.lime))
                        Button("Restart") { flow.restartRace() }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.sky))
                        Button("Quit") { flow.go(to: .menu) }
                            .buttonStyle(QuietButtonStyle())
                    }
                }
            }
            .frame(width: 420)
        }
    }
}

/// Speedo, lap counter, item slot, minimap and the various shouty banners.
struct RaceHUDView: View {
    let hud: HUDSnapshot
    let track: Track
    let simulation: RaceSimulation

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    placeAndLap
                    Spacer()
                    minimap
                }
                Spacer()
                HStack(alignment: .bottom) {
                    timings
                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            banners
        }
    }

    private var placeAndLap: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: -6) {
                Text("\(hud.place)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(placeSuffix)
                    .font(Theme.heading(15))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("LAP \(hud.lap)/\(hud.totalLaps)")
                    .font(Theme.heading(15))
                    .foregroundStyle(hud.isFinalLap ? Theme.citrus : .white)
                Text("of \(hud.fieldSize)")
                    .font(Theme.body(11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            .padding(.bottom, 8)
        }
    }

    private var placeSuffix: String {
        String(TimeFormat.ordinal(hud.place).dropFirst("\(hud.place)".count)).uppercased()
    }

    private var minimap: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TrackMapView(
                track: track,
                lineWidth: 5,
                lineColor: .white.opacity(0.55),
                edgeColor: .black.opacity(0.35),
                markers: markers,
                showStartLine: true
            )
            .frame(width: 116, height: 84)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )

            itemSlot
        }
    }

    private var markers: [TrackMapView.Marker] {
        simulation.carts.map { cart in
            TrackMapView.Marker(
                id: cart.id,
                position: cart.position,
                color: cart.isPlayer ? .white : cart.setup.character.primaryColor.color,
                isPlayer: cart.isPlayer
            )
        }
    }

    private var itemSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .frame(width: 64, height: 64)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hud.heldItem == nil ? .white.opacity(0.25) : Theme.citrus, lineWidth: 2.5)
                .frame(width: 64, height: 64)
            ItemGlyph(kind: hud.heldItem, size: 46)
                .opacity(hud.itemIsRolling ? 0.55 : 1)
                .scaleEffect(hud.itemIsRolling ? 0.86 : 1)
                .animation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true), value: hud.itemIsRolling)
        }
    }

    private var timings: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TimeFormat.lap(hud.raceTime))
                .font(Theme.mono(19))
                .foregroundStyle(.white)
            Text("LAP \(TimeFormat.lap(hud.currentLapTime))")
                .font(Theme.mono(12))
                .foregroundStyle(.white.opacity(0.7))
            if let best = hud.bestLapTime {
                Text("BEST \(TimeFormat.lap(best))")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.citrus.opacity(0.9))
            }
            HStack(spacing: 4) {
                Text("\(hud.speedKPH)")
                    .font(Theme.mono(15))
                    .foregroundStyle(hud.isBoosting ? Theme.citrus : .white.opacity(0.85))
                Text("km/h")
                    .font(Theme.body(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
    }

    @ViewBuilder
    private var banners: some View {
        if let countdown = hud.countdown {
            Text("\(countdown)")
                .font(.system(size: 110, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
                .transition(.scale)
                .id(countdown)
        } else if hud.showGo {
            Text("GO!")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(Theme.citrus)
                .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
        }

        VStack {
            Spacer()
            if hud.isWrongWay {
                Text("WRONG WAY")
                    .font(Theme.heading(24))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.tomato))
                    .padding(.bottom, 96)
            } else if hud.isFinalLap, hud.countdown == nil {
                Text("FINAL LAP")
                    .font(Theme.heading(18))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.citrus))
                    .padding(.bottom, 96)
                    .opacity(0.92)
            }
        }
    }
}
