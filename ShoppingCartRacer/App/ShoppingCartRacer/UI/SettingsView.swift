import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showResetConfirmation = false

    private var settings: ControlSettings { store.settings }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "Settings") { store.go(to: .mainMenu) }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Panel(title: "Steering") {
                        ForEach(SteeringStyle.allCases, id: \.self) { style in
                            Button {
                                var updated = settings
                                updated.steeringStyle = style
                                store.update(settings: updated)
                                store.syncMotionUpdates(forRacing: false)
                            } label: {
                                HStack {
                                    Image(systemName: settings.steeringStyle == style
                                          ? "largecircle.fill.circle"
                                          : "circle")
                                        .foregroundStyle(settings.steeringStyle == style ? Theme.accent : Theme.muted)
                                    Text(style.displayName)
                                        .font(Theme.body(14))
                                        .foregroundStyle(Theme.foreground)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if settings.steeringStyle == .tilt {
                            Button("Calibrate as level") { store.calibrateTilt() }
                                .buttonStyle(PrimaryButtonStyle(isProminent: false))
                                .padding(.top, 4)
                            if !store.motion.isAvailable {
                                Text("This device has no motion sensor available.")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.danger)
                            }
                        }
                    }

                    Panel(title: "Sensitivity") {
                        HStack {
                            Text("Gentle")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.muted)
                            Slider(
                                value: Binding(
                                    get: { settings.sensitivity },
                                    set: { newValue in
                                        var updated = settings
                                        updated.sensitivity = newValue
                                        store.update(settings: updated)
                                    }
                                ),
                                in: 0.5...1.5
                            )
                            .tint(Theme.accent)
                            Text("Twitchy")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    Panel(title: "Assists and feedback") {
                        SettingsToggle(
                            title: "Hold the throttle for me",
                            subtitle: "Just steer, drift and throw things",
                            isOn: settings.autoAccelerate
                        ) { newValue in
                            var updated = settings
                            updated.autoAccelerate = newValue
                            store.update(settings: updated)
                        }
                        SettingsToggle(title: "Haptics", subtitle: nil, isOn: settings.hapticsEnabled) { newValue in
                            var updated = settings
                            updated.hapticsEnabled = newValue
                            store.update(settings: updated)
                        }
                        SettingsToggle(title: "Sound", subtitle: nil, isOn: settings.soundEnabled) { newValue in
                            var updated = settings
                            updated.soundEnabled = newValue
                            store.update(settings: updated)
                        }
                    }

                    Panel(title: "How to drive") {
                        InstructionRow(icon: "wind", text: "Hold DRIFT into a corner, release at the exit for a mini-turbo.")
                        InstructionRow(icon: "bolt.fill", text: "Feather the throttle as the lights go out for a rocket start.")
                        InstructionRow(icon: "circle.circle", text: "Loose change nudges your top speed up, so collect it.")
                        InstructionRow(icon: "gamecontroller.fill", text: "A connected controller takes over automatically.")
                    }

                    Panel(title: "Danger zone") {
                        Button("Erase all records") { showResetConfirmation = true }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.danger, isProminent: false))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .alert("Erase all records?", isPresented: $showResetConfirmation) {
            Button("Erase", role: .destructive) { store.resetRecords() }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("Lap times, unlocked courses and trophies will all be lost.")
        }
    }
}

private struct SettingsToggle: View {
    let title: String
    let subtitle: String?
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.foreground)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .tint(Theme.accent)
    }
}

private struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
            Text(text)
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
