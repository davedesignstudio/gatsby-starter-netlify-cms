import SwiftUI
import AisleRushCore

/// Shared look: a bright supermarket palette, chunky type, and the handful of
/// reusable controls the menus are built from.
enum Theme {
    static let ink = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let tomato = Color(red: 0.91, green: 0.29, blue: 0.24)
    static let lime = Color(red: 0.29, green: 0.63, blue: 0.36)
    static let citrus = Color(red: 0.97, green: 0.72, blue: 0.19)
    static let sky = Color(red: 0.29, green: 0.56, blue: 0.86)
    static let grape = Color(red: 0.45, green: 0.36, blue: 0.78)

    static func title(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func mono(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

extension ColorRGB {
    var color: Color {
        Color(red: r, green: g, blue: b)
    }
}

/// The tiled linoleum backdrop the menus sit on.
struct StoreBackground: View {
    var tint: Color = Theme.paper

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint, tint.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geometry in
                Canvas { context, size in
                    let step: CGFloat = 46
                    var path = Path()
                    var x: CGFloat = 0
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(path, with: .color(Theme.ink.opacity(0.05)), lineWidth: 1)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.tomato
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(isCompact ? 16 : 20))
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 16 : 26)
            .padding(.vertical, isCompact ? 9 : 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint)
                    .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(16))
            .foregroundStyle(Theme.ink.opacity(0.75))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.ink.opacity(0.2), lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A card with the game's rounded, slightly cartoonish edge treatment.
struct Panel<Content: View>: View {
    var tint: Color = .white
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(tint)
                    .shadow(color: Theme.ink.opacity(0.12), radius: 10, y: 4)
            )
    }
}

/// Five-segment stat readout used on the character and parts pickers.
struct StatBar: View {
    var label: String
    var value: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .frame(width: 52, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index < value ? tint : Theme.ink.opacity(0.12))
                        .frame(width: 14, height: 8)
                }
            }
        }
    }
}

struct ItemGlyph: View {
    var kind: ItemKind?
    var size: CGFloat = 44

    var body: some View {
        Image(uiImage: kind.map(TextureFactory.itemImage) ?? TextureFactory.unknownItemImage())
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
