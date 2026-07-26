import SwiftUI

struct TrackSelectView: View {
    @EnvironmentObject private var store: GameStore

    private var definition: TrackDefinition { store.session.selectedTrack }
    private var record: TrackRecord? { store.session.book.record(for: definition.id) }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "Pick a course") {
                store.go(to: .characterSelect)
            }

            GeometryReader { proxy in
                let isWide = proxy.size.width > proxy.size.height
                let layout = isWide ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 14))

                layout {
                    VStack(spacing: 10) {
                        ForEach(TrackLibrary.all, id: \.id) { entry in
                            TrackRow(
                                definition: entry,
                                isSelected: entry.id == definition.id,
                                isLocked: !store.session.isUnlocked(trackID: entry.id),
                                bestLap: store.session.book.record(for: entry.id)?.bestLapTime
                            )
                            .onTapGesture { store.selectTrack(entry.id) }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: isWide ? 320 : .infinity)

                    VStack(spacing: 14) {
                        TrackMapView(definition: definition)
                            .frame(maxWidth: .infinity)
                            .frame(height: isWide ? 210 : 160)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel)
                            )

                        Panel {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(definition.name)
                                        .font(Theme.heading(20))
                                        .foregroundStyle(Theme.foreground)
                                    Text(definition.subtitle)
                                        .font(Theme.body(12))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(definition.recommendedLaps) LAPS")
                                        .font(Theme.numeric(13))
                                        .foregroundStyle(Theme.accent)
                                    Text("\(Int(Track(definition: definition).length)) m")
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.muted)
                                }
                            }

                            if let record, let bestLap = record.bestLapTime {
                                HStack {
                                    Text("Best lap")
                                        .font(Theme.body(12))
                                        .foregroundStyle(Theme.muted)
                                    Spacer()
                                    Text(TimeFormatter.lapTime(bestLap))
                                        .font(Theme.numeric(14))
                                        .foregroundStyle(Theme.foreground)
                                }
                                if let best = record.bestPosition {
                                    HStack {
                                        Text("Best finish")
                                            .font(Theme.body(12))
                                            .foregroundStyle(Theme.muted)
                                        Spacer()
                                        Text(HUDModel.ordinal(best))
                                            .font(Theme.numeric(14))
                                            .foregroundStyle(best <= 3 ? Theme.good : Theme.foreground)
                                    }
                                }
                            } else {
                                Text("No lap time set yet.")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.muted)
                            }
                        }

                        DifficultyPicker(selection: store.session.difficulty) { store.setDifficulty($0) }

                        Button("Race") { store.startRace() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: isWide ? .infinity : .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct TrackRow: View {
    let definition: TrackDefinition
    let isSelected: Bool
    let isLocked: Bool
    let bestLap: Double?

    var body: some View {
        HStack(spacing: 12) {
            TrackMapView(definition: definition, lineWidth: 2, showsStart: false)
                .frame(width: 52, height: 52)
                .opacity(isLocked ? 0.3 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(Theme.body(15))
                    .foregroundStyle(isLocked ? Theme.muted : Theme.foreground)
                Text(isLocked ? "Finish the previous course on the podium" : definition.theme.displayName)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill").foregroundStyle(Theme.muted)
            } else if let bestLap {
                Text(TimeFormatter.lapTime(bestLap))
                    .font(Theme.numeric(11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.panelRaised : Theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
        )
    }
}

/// Course outline drawn from the same minimap projection the HUD uses.
struct TrackMapView: View {
    let definition: TrackDefinition
    var lineWidth: CGFloat = 5
    var showsStart = true

    var body: some View {
        Canvas { context, size in
            let track = Track(definition: definition)
            let map = MinimapModel(track: track, sampleSpacing: 4)
            guard map.outline.count > 1 else { return }

            var path = Path()
            for (index, point) in map.outline.enumerated() {
                // Unit space has y up; the canvas has y down.
                let location = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            path.closeSubpath()

            let palette = Palette.palette(for: definition.theme)
            context.stroke(
                path,
                with: .color(Color(palette.floorBase, opacity: 0.85)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            if showsStart {
                let start = CGPoint(x: map.startLine.x * size.width, y: (1 - map.startLine.y) * size.height)
                let marker = CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: marker), with: .color(Color(palette.accent)))
            }
        }
        .padding(8)
    }
}

struct DifficultyPicker: View {
    let selection: Difficulty
    let onChange: (Difficulty) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                Button {
                    onChange(difficulty)
                } label: {
                    Text(difficulty.displayName)
                        .font(Theme.body(12))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(difficulty == selection ? Theme.accent : Theme.panel)
                        )
                        .foregroundStyle(difficulty == selection ? .black : Theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
