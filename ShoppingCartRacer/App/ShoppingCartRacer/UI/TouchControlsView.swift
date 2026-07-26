import SwiftUI

/// On-screen driving controls. Steering sits under the left thumb, the drift and
/// item buttons under the right.
struct TouchControlsView: View {
    @ObservedObject var coordinator: RaceCoordinator
    let settings: ControlSettings

    var body: some View {
        // The Spacer is what pushes the controls to the bottom: inside a ZStack a
        // bare HStack would sit vertically centred, right across the track.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 0) {
                steeringControl
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                actionButtons
                    .frame(maxWidth: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    // MARK: - Steering

    @ViewBuilder
    private var steeringControl: some View {
        switch settings.steeringStyle {
        case .touchPad:
            SteeringPad(radius: 62) { coordinator.setSteer($0) }
        case .dragAnywhere:
            // The pad is invisible but fills the bottom-left quarter, so the
            // player can put their thumb anywhere and drag.
            SteeringPad(radius: 96, isVisible: false) { coordinator.setSteer($0) }
        case .tilt:
            VStack(spacing: 6) {
                Image(systemName: "iphone.gen3.landscape")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.muted)
                Text("TILT TO STEER")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Circle().fill(Color(Palette.hudBackground, opacity: 0.35)))
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 12) {
                // The item button always stays mounted, even with an empty slot.
                // Swapping it out at the moment of firing would tear down the
                // gesture mid-press, so the release would never be reported and
                // the simulation would never see another rising edge — the player
                // would be unable to use another item all race.
                let item = coordinator.hud?.heldItem
                HoldButton(
                    title: item.map(itemLabel) ?? "ITEM",
                    systemImage: item.map(itemIcon) ?? "questionmark",
                    diameter: 66,
                    tint: item == nil ? Theme.muted : Theme.accent,
                    isDimmed: item == nil
                ) { coordinator.setFiringItem($0) }

                if !settings.autoAccelerate {
                    HoldButton(title: "GAS", systemImage: "chevron.up", diameter: 66, tint: Theme.good) {
                        coordinator.setAccelerating($0)
                    }
                }
            }

            HStack(spacing: 12) {
                HoldButton(title: "BRAKE", systemImage: "chevron.down", diameter: 62, tint: Theme.danger) {
                    coordinator.setBraking($0)
                }
                HoldButton(title: "DRIFT", systemImage: "wind", diameter: 84, tint: Color(RacerColor(hex: 0x6FD6E8))) {
                    coordinator.setDrifting($0)
                }
            }
        }
    }

    private func itemLabel(_ item: ItemKind) -> String {
        switch item {
        case .energyDrink: return "DRINK"
        case .sodaCan: return "CAN"
        case .greaseSlick: return "GREASE"
        case .crateShield: return "CRATES"
        case .clearanceAnnouncement: return "TANNOY"
        case .expressLane: return "EXPRESS"
        }
    }

    private func itemIcon(_ item: ItemKind) -> String {
        switch item {
        case .energyDrink: return "bolt.fill"
        case .sodaCan: return "cylinder.fill"
        case .greaseSlick: return "drop.fill"
        case .crateShield: return "shield.fill"
        case .clearanceAnnouncement: return "megaphone.fill"
        case .expressLane: return "forward.fill"
        }
    }
}

/// A round pad that reports horizontal deflection while dragged.
struct SteeringPad: View {
    let radius: CGFloat
    var isVisible = true
    let onChange: (Double) -> Void

    @State private var knobOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(Palette.hudBackground, opacity: isVisible ? 0.45 : 0.001))
                .overlay(
                    Circle().stroke(Theme.muted.opacity(isVisible ? 0.35 : 0), lineWidth: 2)
                )

            if isVisible {
                HStack(spacing: radius * 0.7) {
                    Image(systemName: "arrowtriangle.left.fill")
                    Image(systemName: "arrowtriangle.right.fill")
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted.opacity(0.5))

                Circle()
                    .fill(Theme.foreground.opacity(0.85))
                    .frame(width: radius * 0.6, height: radius * 0.6)
                    .offset(x: knobOffset)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clamped = max(-radius, min(radius, value.translation.width))
                    knobOffset = clamped
                    // Screen-right is a right turn, which is a negative steer.
                    onChange(Double(-clamped / radius))
                }
                .onEnded { _ in
                    knobOffset = 0
                    onChange(0)
                }
        )
    }
}

/// Reports press and release, which `Button` cannot do.
struct HoldButton: View {
    let title: String
    let systemImage: String
    let diameter: CGFloat
    let tint: Color
    /// Drawn faintly, for a button that currently does nothing.
    var isDimmed = false
    let onPressChange: (Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.3, weight: .bold))
            Text(title)
                .font(Theme.body(diameter * 0.13))
        }
        .foregroundStyle(isPressed ? .black : tint.opacity(isDimmed ? 0.5 : 1))
        .frame(width: diameter, height: diameter)
        .background(
            Circle().fill(isPressed ? tint : Color(Palette.hudBackground, opacity: isDimmed ? 0.4 : 0.7))
        )
        .overlay(Circle().stroke(tint.opacity(isDimmed ? 0.3 : 0.7), lineWidth: 2))
        .scaleEffect(isPressed ? 0.94 : 1)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    onPressChange(true)
                }
                .onEnded { _ in
                    isPressed = false
                    onPressChange(false)
                }
        )
    }
}