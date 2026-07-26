import SwiftUI

struct CharacterSelectView: View {
    @EnvironmentObject private var store: GameStore

    private var racer: Racer { store.session.selectedRacer }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "Pick your trolley") {
                store.go(to: .mainMenu)
            }

            GeometryReader { proxy in
                let isWide = proxy.size.width > proxy.size.height
                let layout = isWide ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 16))

                layout {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                            ForEach(RacerRoster.all) { entry in
                                RacerTile(racer: entry, isSelected: entry.id == racer.id)
                                    .onTapGesture { store.selectRacer(entry.id) }
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        CartPreview(racer: racer)
                            .frame(height: isWide ? 140 : 110)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(racer.primaryColor, opacity: 0.16))
                            )

                        Panel(title: racer.title) {
                            Text(racer.name)
                                .font(Theme.heading(24))
                                .foregroundStyle(Theme.foreground)
                            Text(racer.blurb)
                                .font(Theme.body(13))
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(spacing: 6) {
                                StatBar(label: "Speed", value: racer.stats.speed, tint: Color(racer.primaryColor))
                                StatBar(label: "Accel", value: racer.stats.acceleration, tint: Color(racer.primaryColor))
                                StatBar(label: "Handling", value: racer.stats.handling, tint: Color(racer.primaryColor))
                                StatBar(label: "Weight", value: racer.stats.weight, tint: Color(racer.primaryColor))
                                StatBar(label: "Traction", value: racer.stats.traction, tint: Color(racer.primaryColor))
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(racer.perk.displayName)
                                        .font(Theme.body(13))
                                        .foregroundStyle(Theme.accent)
                                    Text(racer.perk.detail)
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Button(store.session.mode == .grandPrix ? "Start the cup" : "Choose a course") {
                            store.confirmRacer()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: isWide ? 340 : .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct RacerTile: View {
    let racer: Racer
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            CartPreview(racer: racer, showsShadow: false)
                .frame(height: 54)
            Text(racer.name)
                .font(Theme.body(12))
                .foregroundStyle(isSelected ? Theme.foreground : Theme.muted)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color(racer.primaryColor, opacity: 0.24) : Theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color(racer.primaryColor) : .clear, lineWidth: 2)
        )
    }
}

/// Shared header with a back button.
struct NavigationBar: View {
    let title: String
    var trailing: String?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.foreground)
                    .padding(10)
                    .background(Circle().fill(Theme.panel))
            }
            Text(title)
                .font(Theme.heading(20))
                .foregroundStyle(Theme.foreground)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
