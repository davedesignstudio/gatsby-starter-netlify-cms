import CartKartCore
import SwiftUI

struct CartSelectView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "Choose your cart", subtitle: "Every trolley handles differently") {
                game.go(to: .menu)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Roster.all) { profile in
                        Button {
                            Feedback.shared.impact(.light)
                            storage.selectedCartID = profile.id
                        } label: {
                            VStack(spacing: 8) {
                                CartBadge(profile: profile, size: 78)
                                Text(profile.name)
                                    .font(.arcadeBody(13))
                                    .foregroundStyle(Palette.text)
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(storage.selectedCartID == profile.id
                                          ? profile.bodyColor.color.opacity(0.25)
                                          : Palette.panel.opacity(0.8))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        storage.selectedCartID == profile.id ? Palette.primary : Palette.panelBorder,
                                        lineWidth: storage.selectedCartID == profile.id ? 3 : 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Panel {
                let cart = storage.selectedCart
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cart.name)
                            .font(.arcade(24))
                            .foregroundStyle(Palette.text)
                        Text(cart.tagline)
                            .font(.arcadeBody(13))
                            .foregroundStyle(Palette.subtleText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(cart.weight.rawValue.capitalized + " weight")
                            .font(.arcadeBody(12))
                            .foregroundStyle(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 5) {
                        StatBar(label: "Speed", value: cart.speed)
                        StatBar(label: "Accel", value: cart.acceleration, tint: Palette.secondary)
                        StatBar(label: "Handling", value: cart.handling, tint: Palette.secondary)
                        StatBar(label: "Drift", value: cart.drift, tint: Palette.primary)
                        StatBar(label: "Off-road", value: cart.allTerrain, tint: Palette.primary)
                    }
                    .frame(maxWidth: 230)
                }
            }

            ArcadeButton(title: "Ready", systemImage: "checkmark", isProminent: true) {
                game.go(to: .menu)
            }
        }
        .padding(22)
    }
}
