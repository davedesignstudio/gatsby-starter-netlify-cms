import SwiftUI
import AisleRushCore

struct TrackSelectView: View {
    let mode: RaceMode

    @EnvironmentObject private var flow: GameFlow
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var settings: GameSettings

    var body: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 14) {
                header

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Tracks.all, id: \.id) { definition in
                            card(for: definition)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 8)
                }

                if mode != .timeTrial {
                    difficultyPicker
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
        }
    }

    private var header: some View {
        HStack {
            Button("Back") { flow.go(to: .menu) }
                .buttonStyle(QuietButtonStyle())
            Spacer()
            VStack(spacing: 2) {
                Text(mode == .timeTrial ? "Time Trial" : "Quick Race")
                    .font(Theme.title(28))
                    .foregroundStyle(Theme.ink)
                Text(mode == .timeTrial ? "No items, no traffic, no excuses" : "Eight carts, three laps")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            Spacer()
            Color.clear.frame(width: 70, height: 1)
        }
    }

    private func card(for definition: TrackDefinition) -> some View {
        let track = TrackCache.shared.track(id: definition.id)
        let best = mode == .timeTrial ? store.bestLap(for: definition.id) : store.bestRace(for: definition.id)

        return Button {
            if mode == .timeTrial {
                flow.startTimeTrial(trackID: definition.id)
            } else {
                flow.startSingleRace(trackID: definition.id)
            }
        } label: {
            Panel(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    TrackMapView(
                        track: track,
                        lineWidth: 8,
                        lineColor: definition.theme.floorTint.color,
                        edgeColor: definition.theme.shelfTint.color
                    )
                    .frame(height: 118)

                    Text(definition.name)
                        .font(Theme.heading(17))
                        .foregroundStyle(Theme.ink)
                    Text(definition.subtitle)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ForEach(1...3, id: \.self) { pip in
                            Circle()
                                .fill(pip <= definition.difficulty ? definition.theme.accentTint.color : Theme.ink.opacity(0.12))
                                .frame(width: 7, height: 7)
                        }
                        Text("\(Int(track.length)) m")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.ink.opacity(0.45))
                        Spacer(minLength: 0)
                    }

                    Text(best.map { (mode == .timeTrial ? "Best lap " : "Best race ") + TimeFormat.lap($0) } ?? "No record yet")
                        .font(Theme.mono(11))
                        .foregroundStyle(best == nil ? Theme.ink.opacity(0.35) : Theme.lime)
                }
                .frame(width: 208, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 10) {
            Text("Difficulty")
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink.opacity(0.5))
            ForEach(0..<3, id: \.self) { level in
                Button {
                    Haptics.selection()
                    settings.difficulty = level
                } label: {
                    Text(RaceConfig.difficultyNames[level])
                        .font(Theme.body(13))
                        .foregroundStyle(settings.difficulty == level ? .white : Theme.ink.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(settings.difficulty == level ? Theme.tomato : Color.white)
                        )
                        .overlay(
                            Capsule().stroke(Theme.ink.opacity(settings.difficulty == level ? 0 : 0.12), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CupSelectView: View {
    @EnvironmentObject private var flow: GameFlow
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var settings: GameSettings

    var body: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 14) {
                HStack {
                    Button("Back") { flow.go(to: .menu) }
                        .buttonStyle(QuietButtonStyle())
                    Spacer()
                    Text("Grand Prix")
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Color.clear.frame(width: 70, height: 1)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Cups.all) { cup in
                            cupCard(cup)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
        }
    }

    private func cupCard(_ cup: Cup) -> some View {
        Button {
            flow.startCup(cup.id)
        } label: {
            Panel(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(cup.name)
                            .font(Theme.heading(18))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        if let place = store.trophy(for: cup.id) {
                            Text(TimeFormat.ordinal(place))
                                .font(Theme.mono(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(trophyColor(place)))
                        }
                    }
                    Text(cup.blurb)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.ink.opacity(0.55))

                    HStack(spacing: 8) {
                        ForEach(cup.tracks, id: \.id) { definition in
                            VStack(spacing: 4) {
                                TrackMapView(
                                    track: TrackCache.shared.track(id: definition.id),
                                    lineWidth: 5,
                                    lineColor: definition.theme.floorTint.color,
                                    edgeColor: definition.theme.shelfTint.color,
                                    showStartLine: false
                                )
                                .frame(width: 72, height: 58)
                                Text(definition.name)
                                    .font(Theme.body(9))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                                    .lineLimit(1)
                                    .frame(width: 78)
                            }
                        }
                    }

                    Text("\(cup.trackIDs.count) races · \(RaceConfig.difficultyNames[settings.difficulty])")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.ink.opacity(0.45))
                }
                .frame(width: 268, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func trophyColor(_ place: Int) -> Color {
        switch place {
        case 1: return Theme.citrus
        case 2: return Color(white: 0.62)
        case 3: return Color(red: 0.72, green: 0.47, blue: 0.25)
        default: return Theme.ink.opacity(0.4)
        }
    }
}
