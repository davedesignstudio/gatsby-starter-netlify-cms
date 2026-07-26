import SwiftUI
import AisleRushCore

struct SettingsView: View {
    @EnvironmentObject private var flow: GameFlow
    @EnvironmentObject private var settings: GameSettings
    @EnvironmentObject private var store: GameStore
    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 14) {
                HStack {
                    Button("Back") { flow.go(to: .menu) }
                        .buttonStyle(QuietButtonStyle())
                    Spacer()
                    Text("Settings")
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Color.clear.frame(width: 70, height: 1)
                }

                ScrollView {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 12) {
                            steeringPanel
                            drivingPanel
                        }
                        VStack(spacing: 12) {
                            feedbackPanel
                            recordsPanel
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
        }
    }

    private var steeringPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Steering")
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)

                ForEach(GameSettings.SteeringMode.allCases) { mode in
                    Button {
                        Haptics.selection()
                        settings.steering = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: settings.steering == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(settings.steering == mode ? Theme.tomato : Theme.ink.opacity(0.3))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.title)
                                    .font(Theme.body(14))
                                    .foregroundStyle(Theme.ink)
                                Text(mode.blurb)
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if settings.steering == .tilt {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tilt sensitivity")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        Slider(value: $settings.tiltSensitivity, in: 0.6...1.8)
                            .tint(Theme.tomato)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var drivingPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Driving")
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)

                Toggle(isOn: $settings.autoAccelerate) {
                    label("Auto accelerate", "Hands off the gas. Brake is still yours.")
                }
                .tint(Theme.lime)

                Toggle(isOn: $settings.rotatingCamera) {
                    label("Rotating camera", "Camera follows the cart's nose.")
                }
                .tint(Theme.lime)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Opponent difficulty")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.ink)
                    Picker("", selection: $settings.difficulty) {
                        ForEach(0..<3, id: \.self) { level in
                            Text(RaceConfig.difficultyNames[level]).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var feedbackPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Feel")
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)
                Toggle(isOn: $settings.soundEnabled) {
                    label("Sound", "Squeaky casters and tinned percussion.")
                }
                .tint(Theme.lime)
                Toggle(isOn: $settings.hapticsEnabled) {
                    label("Haptics", "Feel every shelf you meet.")
                }
                .tint(Theme.lime)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recordsPanel: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Records")
                    .font(Theme.heading(16))
                    .foregroundStyle(Theme.ink)

                ForEach(Tracks.all, id: \.id) { definition in
                    HStack {
                        Text(definition.name)
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                        Spacer()
                        Text(store.bestLap(for: definition.id).map(TimeFormat.lap) ?? "—")
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                    }
                }

                Button(confirmingReset ? "Tap again to erase" : "Reset records") {
                    if confirmingReset {
                        store.resetRecords()
                        confirmingReset = false
                        Haptics.notify(.warning)
                    } else {
                        confirmingReset = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: confirmingReset ? Theme.tomato : Theme.ink.opacity(0.4), isCompact: true))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.body(11))
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
    }
}

struct HowToPlayView: View {
    @EnvironmentObject private var flow: GameFlow

    var body: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 12) {
                HStack {
                    Button("Back") { flow.go(to: .menu) }
                        .buttonStyle(QuietButtonStyle())
                    Spacer()
                    Text("How to play")
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Color.clear.frame(width: 70, height: 1)
                }

                ScrollView {
                    VStack(spacing: 12) {
                        Panel(padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Driving")
                                    .font(Theme.heading(16))
                                tip("Steer", "Slide your left thumb, or switch to tilt in settings.")
                                tip("Drift", "Hold DRIFT through a corner. The longer you hold, the bigger the boost when you let go: blue, orange, then purple.")
                                tip("Rocket start", "Hold the gas as the countdown hits two. Hold it from three and you will flood the wheels instead.")
                                tip("Surfaces", "Blue is wet, pale blue is freezer floor, brown is flattened cardboard. All of them will embarrass you.")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Panel(padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("The trolley aisle")
                                    .font(Theme.heading(16))
                                ForEach(ItemKind.allCases, id: \.rawValue) { kind in
                                    HStack(spacing: 10) {
                                        ItemGlyph(kind: kind, size: 34)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(kind.displayName)
                                                .font(Theme.body(13))
                                                .foregroundStyle(Theme.ink)
                                            Text(kind.blurb)
                                                .font(Theme.body(11))
                                                .foregroundStyle(Theme.ink.opacity(0.5))
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                                Text("Tap the item button to throw forward, drag down to throw backward, or hold to trail it behind you as a shield. Whatever you draw depends on how badly you are doing.")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
        }
    }

    private func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(Theme.body(11))
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
    }
}
