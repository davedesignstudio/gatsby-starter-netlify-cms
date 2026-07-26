import SwiftUI
import AisleRushCore

/// The on-screen controls. Steering lives under the left thumb, everything
/// else under the right, and nothing important sits where a thumb would cover
/// it.
struct ControlPadView: View {
    let input: RaceInput
    let steering: GameSettings.SteeringMode
    let autoAccelerate: Bool
    let heldItem: ItemKind?
    let itemIsRolling: Bool
    let driftTier: Int

    @State private var steerValue: Double = 0
    @State private var thumbOffset: CGSize = .zero
    @State private var isSteering = false

    /// Thumb travel, in points, for full lock.
    private let steerTravel: CGFloat = 78

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if steering == .touch {
                steeringPad
            } else {
                tiltHint
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 14) {
                VStack(spacing: 12) {
                    itemButton
                    if !autoAccelerate {
                        pedal("Gas", tint: Theme.lime, systemImage: "chevron.up") { pressed in
                            input.throttle = pressed ? 1 : 0
                        }
                    }
                }
                VStack(spacing: 12) {
                    brakeButton
                    driftButton
                }
            }
            .padding(.trailing, 26)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Steering

    private var steeringPad: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: steerTravel * 2 + 74, height: 74)
                .overlay(
                    Capsule().stroke(.white.opacity(0.16), lineWidth: 2)
                )

            HStack(spacing: steerTravel * 2 - 30) {
                Image(systemName: "arrowtriangle.left.fill")
                Image(systemName: "arrowtriangle.right.fill")
            }
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.3))

            Circle()
                .fill(isSteering ? Color.white.opacity(0.9) : Color.white.opacity(0.55))
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                )
                .offset(x: thumbOffset.width)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .frame(width: steerTravel * 2 + 96, height: 150)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isSteering = true
                    let clamped = max(-steerTravel, min(steerTravel, value.translation.width))
                    thumbOffset = CGSize(width: clamped, height: 0)
                    // Positive steer is a left turn in the simulation.
                    steerValue = Double(-clamped / steerTravel)
                    input.steer = shaped(steerValue)
                }
                .onEnded { _ in
                    isSteering = false
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        thumbOffset = .zero
                    }
                    steerValue = 0
                    input.steer = 0
                }
        )
        .padding(.leading, 22)
        .padding(.bottom, 14)
    }

    /// A light curve near centre: precise for small corrections, still full
    /// lock at the edges.
    private func shaped(_ value: Double) -> Double {
        let sign: Double = value < 0 ? -1 : 1
        let magnitude = min(abs(value), 1)
        return sign * (magnitude * magnitude * 0.45 + magnitude * 0.55)
    }

    private var tiltHint: some View {
        Text("TILT TO STEER")
            .font(Theme.body(11))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.4))
            .padding(.leading, 30)
            .padding(.bottom, 30)
    }

    // MARK: - Buttons

    private var driftButton: some View {
        HoldButton(
            label: "DRIFT",
            systemImage: "tornado",
            tint: driftTier > 0 ? driftColor : Theme.sky,
            diameter: 96
        ) { pressed in
            input.drift = pressed
            if pressed { Haptics.impact(.light) }
        }
        .overlay(
            Circle()
                .stroke(driftColor, lineWidth: driftTier > 0 ? 5 : 0)
                .frame(width: 104, height: 104)
                .opacity(driftTier > 0 ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: driftTier)
        )
    }

    private var driftColor: Color {
        switch driftTier {
        case 1: return Color(red: 0.35, green: 0.72, blue: 1)
        case 2: return Color(red: 1, green: 0.65, blue: 0.2)
        case 3: return Color(red: 0.78, green: 0.4, blue: 1)
        default: return Theme.sky
        }
    }

    private var brakeButton: some View {
        pedal("Brake", tint: Theme.tomato.opacity(0.85), systemImage: "chevron.down") { pressed in
            input.brake = pressed
        }
    }

    private func pedal(_ title: String, tint: Color, systemImage: String, onChange: @escaping (Bool) -> Void) -> some View {
        HoldButton(label: title.uppercased(), systemImage: systemImage, tint: tint, diameter: 64, onChange: onChange)
    }

    private var itemButton: some View {
        ItemButton(
            heldItem: heldItem,
            isRolling: itemIsRolling
        ) { pressed, backward in
            input.fire = pressed
            input.aimBackward = backward
        }
    }
}

/// A round button that reports press and release, rather than a tap.
struct HoldButton: View {
    let label: String
    let systemImage: String
    let tint: Color
    var diameter: CGFloat = 84
    let onChange: (Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
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
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    onChange(true)
                }
                .onEnded { _ in
                    isPressed = false
                    onChange(false)
                }
        )
    }
}

/// Tap to throw forward, drag down to throw backward, hold to trail the item
/// behind the cart as a shield.
struct ItemButton: View {
    let heldItem: ItemKind?
    let isRolling: Bool
    let onChange: (_ pressed: Bool, _ backward: Bool) -> Void

    @State private var isPressed = false
    @State private var isBackward = false

    private var isEmpty: Bool { heldItem == nil }

    var body: some View {
        ZStack {
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
                    .opacity(isRolling ? 0.5 : 1)
            }

            if isBackward {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .offset(y: 30)
            }
        }
        .frame(width: 82, height: 82)
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isBackward = value.translation.height > 26
                    if !isPressed {
                        isPressed = true
                        Haptics.impact(.light)
                    }
                    onChange(true, isBackward)
                }
                .onEnded { _ in
                    isPressed = false
                    onChange(false, isBackward)
                    isBackward = false
                }
        )
    }
}
