// Views.swift — title, select, how-to, results screens
import SwiftUI

struct TitleView: View {
    var onPlay: () -> Void
    var onHow: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.21, blue: 0.16), Color(red: 0.05, green: 0.12, blue: 0.09)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("MEGAMART GRAND PRIX")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))

                Text("CART\nKART")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.92))
                    .shadow(color: .black.opacity(0.5), radius: 0, y: 4)

                Text("Wild shopping carts. One store. Zero chill.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color(red: 0.66, green: 0.71, blue: 0.64))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Race", action: onPlay)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("How to Play", action: onHow)
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(.top, 12)
            }
            .padding()
        }
    }
}

struct HowToView: View {
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("How to Play")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))

            VStack(alignment: .leading, spacing: 10) {
                tip("Steer", "Tilt left/right on the left side of the screen")
                tip("Gas / Brake", "Hold the green or red pedals")
                tip("Items", "Roll through crates, tap FIRE to use")
                tip("Win", "Finish 3 laps through MegaMart first")
            }
            .padding()
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Banana peels slip rivals. Soda cans boost. Spilled milk is chaos.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Got it", action: onBack)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }

    private func tip(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))
                .frame(width: 90, alignment: .leading)
            Text(body)
                .foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.92))
        }
    }
}

struct SelectView: View {
    @Binding var selected: CartDef
    var onBack: () -> Void
    var onStart: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick Your Cart")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CartCatalog.all) { cart in
                        Button {
                            selected = cart
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [cart.color, cart.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(height: 54)
                                Text(cart.name).font(.headline).foregroundStyle(.white)
                                Text(cart.blurb).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .padding(10)
                            .background(Color.white.opacity(selected == cart ? 0.12 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected == cart ? Color(red: 0.94, green: 0.77, blue: 0.10) : Color.white.opacity(0.12), lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Back", action: onBack).buttonStyle(GhostButtonStyle())
                Button("Start Race", action: onStart).buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
    }
}

struct ResultsView: View {
    var results: [RaceResult]
    var onMenu: () -> Void
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            let you = results.first(where: \.isPlayer)
            Text(title(for: you?.place ?? 99))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))

            VStack(spacing: 8) {
                ForEach(results) { r in
                    HStack {
                        Text("\(r.place)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))
                            .frame(width: 36)
                        Text(r.name + (r.isPlayer ? " (You)" : ""))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(format(r.time))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(r.isPlayer ? Color(red: 0.94, green: 0.77, blue: 0.10).opacity(0.18) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack {
                Button("Menu", action: onMenu).buttonStyle(GhostButtonStyle())
                Button("Race Again", action: onRetry).buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
    }

    private func title(for place: Int) -> String {
        if place == 1 { return "Checkout Champ!" }
        if place <= 3 { return "Podium Run!" }
        return "Back to the Corral"
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", m, s, ms)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.03))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(red: 0.94, green: 0.77, blue: 0.10))
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.72, green: 0.57, blue: 0.04), radius: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
