import SwiftUI
import AisleRushCore

/// The on-screen controls. Steering lives under the left thumb, everything
/// else under the right, and nothing important sits where a thumb would cover
/// it.
///
/// This view only draws. Touches are handled by `TouchControlLayer` on top of
/// it, because SwiftUI will not reliably track two thumbs at once and this is
/// a game where you must steer and drift simultaneously.
struct ControlPadView: View {
    let input: RaceInput
    let steering: GameSettings.SteeringMode
    let autoAccelerate: Bool
    let heldItem: ItemKind?
    let itemIsRolling: Bool
    let driftTier: Int
    /// The lights are still on, so the gas button doubles as a rev button.
    let isCountdown: Bool

    @StateObject private var visuals = ControlVisualState()

    private var showsGas: Bool { !autoAccelerate || isCountdown }

    var body: some View {
        GeometryReader { geometry in
            let layout = ControlLayout(size: geometry.size, showsGas: showsGas)

            ZStack(alignment: .topLeading) {
                if steering == .touch {
                    steeringTrack(layout)
                } else {
                    tiltHint(layout)
                }

                roundButton(
                    region: .drift,
                    layout: layout,
                    tint: driftTier > 0 ? driftColor : Theme.sky,
                    label: "DRIFT",
                    systemImage: "tornado",
                    ring: driftTier > 0 ? driftColor : nil
                )

                roundButton(
                    region: .brake,
                    layout: layout,
                    tint: Theme.tomato.opacity(0.85),
                    label: "BRAKE",
                    systemImage: "chevron.down"
                )

                if showsGas {
                    roundButton(
                        region: .gas,
                        layout: layout,
                        tint: isCountdown ? Theme.citrus : Theme.lime,
                        label: isCountdown ? "REV" : "GAS",
                        systemImage: "chevron.up"
                    )
                }

                itemButton(layout)

                TouchControlLayer(layout: layout, input: input, visuals: visuals)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Pieces

    private func steeringTrack(_ layout: ControlLayout) -> some View {
        let rect = layout.steerRect
        return ZStack {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 2))
                .frame(width: layout.steerTravel * 2 + 74, height: 74)

            HStack {
                Image(systemName: "arrowtriangle.left.fill")
                Spacer()
                Image(systemName: "arrowtriangle.right.fill")
            }
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(visuals.isSteering ? 0.5 : 0.3))
            .frame(width: layout.steerTravel * 2 + 34)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    private func tiltHint(_ layout: ControlLayout) -> some View {
        Text("TILT TO STEER")
            .font(Theme.body(11))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.4))
            .position(x: layout.steerCentre.x, y: layout.steerCentre.y)
    }

    private func roundButton(
        region: ControlRegion,
        layout: ControlLayout,
        tint: Color,
        label: String,
        systemImage: String,
        ring: Color? = nil
    ) -> some View {
        let diameter = layout.diameter(of: region)
        let isPressed = visuals.pressed.contains(region)
        let centre = layout.centre(of: region)

        return ZStack {
            Circle()
                .fill(tint.opacity(isPressed ? 0.95 : 0.62))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 7, y: isPressed ? 1 : 4)

            VStack(spacing: 1) {
                Image(systemName: systemImage)
                    .font(.system(size: diameter * 0.3, weight: .bold))
                Text(label)
                    .font(Theme.body(diameter * 0.13))
            }
            .foregroundStyle(.white)

            if let ring {
                Circle()
                    .stroke(ring, lineWidth: 5)
                    .frame(width: diameter + 8, height: diameter + 8)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        .position(x: centre.x, y: centre.y)
    }

    private func itemButton(_ layout: ControlLayout) -> some View {
        let diameter = layout.itemDiameter
        let isPressed = visuals.pressed.contains(.item)
        let centre = layout.itemCentre
        let isEmpty = heldItem == nil

        return ZStack {
            Circle()
                .fill(isEmpty ? Color.black.opacity(0.22) : Theme.citrus.opacity(isPressed ? 0.95 : 0.72))
                .overlay(Circle().stroke(.white.opacity(isEmpty ? 0.15 : 0.4), lineWidth: 2))
                .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 7, y: isPressed ? 1 : 4)

            if isEmpty {
                Image(systemName: "shippingbox")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                ItemGlyph(kind: heldItem, size: 52)
                    .opacity(itemIsRolling ? 0.5 : 1)
            }

            if visuals.isAimingBackward {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .offset(y: 30)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        .position(x: centre.x, y: centre.y)
    }

    private var driftColor: Color {
        switch driftTier {
        case 1: return Color(red: 0.35, green: 0.72, blue: 1)
        case 2: return Color(red: 1, green: 0.65, blue: 0.2)
        case 3: return Color(red: 0.78, green: 0.4, blue: 1)
        default: return Theme.sky
        }
    }
}
