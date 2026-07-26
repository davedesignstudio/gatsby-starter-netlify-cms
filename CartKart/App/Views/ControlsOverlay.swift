import CartKartCore
import SwiftUI

/// Touch controls: steering on the left, actions on the right.
///
/// Carts accelerate by themselves, as in most phone kart racers, so the player
/// is only ever asked to steer, drift, brake and throw things.
struct ControlsOverlay: View {
    @ObservedObject var controls: ControlState
    @ObservedObject var hud: RaceHUDModel
    let scheme: Storage.ControlScheme

    var body: some View {
        HStack(spacing: 0) {
            steeringSide
            actionSide
        }
        .opacity(hud.isPaused ? 0 : 1)
        .allowsHitTesting(!hud.isPaused)
    }

    // MARK: - Steering

    @ViewBuilder
    private var steeringSide: some View {
        switch scheme {
        case .slide:
            SlideSteering(controls: controls)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .buttons:
            HStack(spacing: 14) {
                SteerButton(direction: .left, controls: controls)
                SteerButton(direction: .right, controls: controls)
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        case .tilt:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private var actionSide: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Spacer()
            HStack(alignment: .bottom, spacing: 14) {
                HoldButton(
                    label: "BRAKE",
                    systemImage: "hand.raised.fill",
                    tint: Palette.danger,
                    diameter: 68
                ) { isDown in
                    controls.isBraking = isDown
                }

                Button {
                    Feedback.shared.impact(.light)
                    controls.requestItem()
                } label: {
                    ActionFace(
                        label: hud.snapshot.item?.displayName ?? "ITEM",
                        systemImage: hud.snapshot.item == nil ? "shippingbox" : nil,
                        emoji: hud.snapshot.item?.emoji,
                        tint: hud.snapshot.item == nil ? Color.white.opacity(0.25) : Palette.secondary,
                        diameter: 82
                    )
                }
                .buttonStyle(.plain)
                .disabled(hud.snapshot.item == nil)

                HoldButton(
                    label: driftLabel,
                    systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                    tint: driftTint,
                    diameter: 104
                ) { isDown in
                    controls.isDrifting = isDown
                }
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var driftLabel: String {
        hud.snapshot.driftTier == .none ? "DRIFT" : hud.snapshot.driftTier.label
    }

    private var driftTint: Color {
        switch hud.snapshot.driftTier {
        case .none: return Palette.primary
        case .squeak: return Color(red: 0.4, green: 0.75, blue: 1)
        case .rattle: return Color(red: 1, green: 0.62, blue: 0.15)
        case .rumble: return Color(red: 0.78, green: 0.45, blue: 1)
        }
    }
}

/// Invisible pad: put a thumb down anywhere and slide to steer.
private struct SlideSteering: View {
    @ObservedObject var controls: ControlState
    @State private var anchor: CGFloat?

    /// Sideways travel, in points, that corresponds to full lock.
    private let fullLockDistance: CGFloat = 78

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.white.opacity(0.001)
            SteeringIndicator(steer: controls.steer)
                .padding(.leading, 30)
                .padding(.bottom, 30)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = anchor ?? value.startLocation.x
                    if anchor == nil { anchor = start }
                    let offset = value.location.x - start
                    // Screen-right should turn the cart right, which is negative steer.
                    controls.steer = Double(-clampCG(offset / fullLockDistance, -1, 1))
                }
                .onEnded { _ in
                    anchor = nil
                    controls.steer = 0
                }
        )
    }

    private func clampCG(_ value: CGFloat, _ minimum: CGFloat, _ maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

/// Shows how much lock is being applied, so slide steering is legible.
private struct SteeringIndicator: View {
    let steer: Double

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.3))
                .frame(width: 150, height: 16)
            Circle()
                .fill(Palette.primary)
                .frame(width: 26, height: 26)
                .offset(x: CGFloat(-steer) * 62)
                .animation(.interactiveSpring(response: 0.15), value: steer)
        }
    }
}

private struct SteerButton: View {
    enum Direction {
        case left
        case right

        var value: Double { self == .left ? 1 : -1 }
        var icon: String { self == .left ? "chevron.left" : "chevron.right" }
    }

    let direction: Direction
    @ObservedObject var controls: ControlState

    var body: some View {
        HoldButton(label: "", systemImage: direction.icon, tint: Palette.primary, diameter: 86) { isDown in
            controls.steer = isDown ? direction.value : 0
        }
    }
}

/// Round button that reports press and release.
private struct HoldButton: View {
    let label: String
    var systemImage: String?
    var tint: Color
    var diameter: CGFloat
    let onChange: (Bool) -> Void

    @State private var isDown = false

    var body: some View {
        ActionFace(label: label, systemImage: systemImage, emoji: nil, tint: tint, diameter: diameter)
            .scaleEffect(isDown ? 0.92 : 1)
            .animation(.interactiveSpring(response: 0.16), value: isDown)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isDown else { return }
                        isDown = true
                        Feedback.shared.impact(.light)
                        onChange(true)
                    }
                    .onEnded { _ in
                        isDown = false
                        onChange(false)
                    }
            )
    }
}

/// Shared look for every round control.
private struct ActionFace: View {
    let label: String
    var systemImage: String?
    var emoji: String?
    var tint: Color
    var diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.28))
            Circle()
                .stroke(tint, lineWidth: 3)
            VStack(spacing: 2) {
                if let emoji {
                    Text(emoji).font(.system(size: diameter * 0.36))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: diameter * 0.3, weight: .bold))
                        .foregroundStyle(.white)
                }
                if !label.isEmpty {
                    Text(label)
                        .font(.arcade(min(13, diameter * 0.15)))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.35), radius: 6)
    }
}
