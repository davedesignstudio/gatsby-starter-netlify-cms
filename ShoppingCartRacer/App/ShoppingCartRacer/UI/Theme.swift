import SwiftUI

/// Bridges the kit's framework-free colours into SwiftUI, plus the handful of
/// shared styles the menus use.
extension Color {
    init(_ racerColor: RacerColor, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: racerColor.red,
            green: racerColor.green,
            blue: racerColor.blue,
            opacity: opacity
        )
    }
}

enum Theme {
    static let background = Color(RacerColor(hex: 0x11131A))
    static let panel = Color(RacerColor(hex: 0x1B1F2A))
    static let panelRaised = Color(RacerColor(hex: 0x252B39))
    static let foreground = Color(Palette.hudForeground)
    static let muted = Color(Palette.hudMuted)
    static let accent = Color(RacerColor(hex: 0xFFB703))
    static let danger = Color(Palette.danger)
    static let good = Color(Palette.good)

    static func title(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func numeric(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    /// The scuffed-linoleum gradient behind every menu.
    static var menuBackground: some View {
        LinearGradient(
            colors: [
                Color(RacerColor(hex: 0x1A1E28)),
                Color(RacerColor(hex: 0x0E1015))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// The chunky supermarket-signage button used throughout the menus.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(18))
            .foregroundStyle(isProminent ? Color.black : Theme.foreground)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isProminent ? tint : Theme.panelRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(isProminent ? 0 : 0.55), lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A labelled panel, like a shelf-edge ticket.
struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.body(12))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel)
        )
    }
}

/// Five pips showing a stat rating, as on the character select screen.
struct StatBar: View {
    let label: String
    let value: Double
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)
                .frame(width: 62, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    let filled = value >= Double(index) / 5 + 0.1
                    RoundedRectangle(cornerRadius: 2)
                        .fill(filled ? tint : Theme.panelRaised)
                        .frame(height: 8)
                }
            }
        }
    }
}
