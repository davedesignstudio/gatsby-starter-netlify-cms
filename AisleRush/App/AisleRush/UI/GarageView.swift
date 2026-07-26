import SwiftUI
import AisleRushCore

/// Pick a racer, a trolley and a set of wheels. The stat bars update live so
/// the trade-offs are visible before you commit.
struct GarageView: View {
    @EnvironmentObject private var flow: GameFlow
    @EnvironmentObject private var store: GameStore

    private var setup: CartSetup { store.setup }

    var body: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 14) {
                header

                HStack(alignment: .top, spacing: 16) {
                    preview
                        .frame(width: 268)

                    VStack(spacing: 12) {
                        picker(
                            title: "Racer",
                            items: Roster.characters.map { PickerItem(id: $0.id, name: $0.name) },
                            selection: store.characterID,
                            tint: Theme.tomato
                        ) { store.characterID = $0 }

                        picker(
                            title: "Trolley",
                            items: Roster.frames.map { PickerItem(id: $0.id, name: $0.name) },
                            selection: store.frameID,
                            tint: Theme.sky
                        ) { store.frameID = $0 }

                        picker(
                            title: "Wheels",
                            items: Roster.wheels.map { PickerItem(id: $0.id, name: $0.name) },
                            selection: store.wheelsID,
                            tint: Theme.lime
                        ) { store.wheelsID = $0 }

                        Panel(padding: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(Roster.frame(id: store.frameID).blurb)
                                Text(Roster.wheels(id: store.wheelsID).blurb)
                            }
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.ink.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack {
            Button("Back") { flow.go(to: .menu) }
                .buttonStyle(QuietButtonStyle())
            Spacer()
            Text("Garage")
                .font(Theme.title(30))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button("Done") { flow.go(to: .menu) }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.lime, isCompact: true))
        }
    }

    private var preview: some View {
        Panel {
            VStack(spacing: 10) {
                Image(uiImage: TextureFactory.cartImage(for: setup))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 96)
                    .rotationEffect(.degrees(-90))
                    .frame(height: 130)
                    .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 6)

                Text(setup.character.name)
                    .font(Theme.heading(20))
                    .foregroundStyle(Theme.ink)
                Text(setup.character.role.uppercased())
                    .font(Theme.body(11))
                    .tracking(1.4)
                    .foregroundStyle(setup.character.primaryColor.color)
                Text(setup.character.quip)
                    .font(Theme.body(12))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .frame(height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(setup.displayBars) { bar in
                        StatBar(label: bar.label, value: bar.value, tint: setup.character.primaryColor.color)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    struct PickerItem: Identifiable {
        let id: String
        let name: String
    }

    private func picker(
        title: String,
        items: [PickerItem],
        selection: String,
        tint: Color,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.body(11))
                .tracking(1.4)
                .foregroundStyle(Theme.ink.opacity(0.45))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            Haptics.selection()
                            Audio.shared.play(.uiTap)
                            onSelect(item.id)
                        } label: {
                            Text(item.name)
                                .font(Theme.body(13))
                                .foregroundStyle(item.id == selection ? .white : Theme.ink.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(item.id == selection ? tint : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(Theme.ink.opacity(item.id == selection ? 0 : 0.12), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
