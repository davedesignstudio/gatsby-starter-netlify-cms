import CartKartCore
import SwiftUI

/// Chunky arcade button used throughout the menus.
struct ArcadeButton: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = Palette.primary
    var isProminent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            Feedback.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.arcade(isProminent ? 24 : 18))
                        .frame(width: 30)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.arcade(isProminent ? 26 : 20))
                    if let subtitle {
                        Text(subtitle)
                            .font(.arcadeBody(13))
                            .opacity(0.75)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isProminent ? Color.black : Palette.text)
            .padding(.horizontal, 20)
            .padding(.vertical, isProminent ? 18 : 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isProminent ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.panel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isProminent ? tint.opacity(0.5) : Palette.panelBorder, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Five-pip stat row, as on a kart select screen.
struct StatBar: View {
    let label: String
    let value: Int
    var tint: Color = Palette.primary

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.arcadeBody(12))
                .foregroundStyle(Palette.subtleText)
                .frame(width: 62, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { pip in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(pip <= value ? tint : Color.white.opacity(0.13))
                        .frame(height: 8)
                }
            }
        }
    }
}

/// Little top-down cart drawn with shapes, for menus where SpriteKit is overkill.
struct CartBadge: View {
    let profile: RacerProfile
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle()
                .fill(profile.bodyColor.color.opacity(0.22))
            Circle()
                .stroke(profile.bodyColor.color, lineWidth: 3)
            VStack(spacing: 0) {
                Text(profile.emblem)
                    .font(.system(size: size * 0.42))
                Text(profile.name.prefix(8))
                    .font(.arcadeBody(size * 0.13))
                    .foregroundStyle(Palette.text)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Dark rounded container used for every panel in the menus.
struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.arcade(14))
                    .foregroundStyle(Palette.subtleText)
                    .tracking(1.5)
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.panel.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.panelBorder, lineWidth: 1.5)
        )
    }
}

/// Header shown at the top of the secondary screens.
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var onBack: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let onBack {
                Button(action: {
                    Feedback.shared.impact(.light)
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.arcade(20))
                        .foregroundStyle(Palette.text)
                        .padding(12)
                        .background(Circle().fill(Palette.panel))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.arcade(28))
                    .foregroundStyle(Palette.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.arcadeBody(14))
                        .foregroundStyle(Palette.subtleText)
                }
            }
            Spacer()
        }
    }
}

extension RaceConfiguration.Difficulty {
    var blurb: String {
        switch self {
        case .trolleyDash: return "Relaxed rivals, forgiving pace."
        case .weeklyShop: return "A proper race. Mistakes cost places."
        case .blackFriday: return "Ruthless. They want that last turkey."
        }
    }
}
