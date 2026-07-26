import SwiftUI
import AisleRushCore

struct ResultsView: View {
    let outcome: RaceOutcome

    @EnvironmentObject private var flow: GameFlow
    @State private var revealed = 0

    var body: some View {
        ZStack {
            StoreBackground(tint: Theme.paper)

            VStack(spacing: 12) {
                header

                HStack(alignment: .top, spacing: 14) {
                    resultsTable
                    sidebar.frame(width: 240)
                }

                actions
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .onAppear(perform: revealRows)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(headline)
                .font(Theme.title(30))
                .foregroundStyle(place == 1 ? Theme.citrus : Theme.ink)
            Text("\(outcome.trackName)\(outcome.cupName.map { " · \($0)" } ?? "")")
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
    }

    private var place: Int { outcome.playerResult?.place ?? 0 }

    private var headline: String {
        guard outcome.mode != .timeTrial else { return "Time Trial Complete" }
        switch place {
        case 1: return "You won the aisle"
        case 2, 3: return "On the podium"
        case 4...6: return "Mid-pack shopping"
        default: return "Cleanup on aisle you"
        }
    }

    private var resultsTable: some View {
        Panel(padding: 12) {
            VStack(spacing: 3) {
                ForEach(Array(outcome.results.enumerated()), id: \.element.id) { index, result in
                    HStack(spacing: 10) {
                        Text(TimeFormat.ordinal(result.place))
                            .font(Theme.mono(13))
                            .foregroundStyle(result.place <= 3 ? Theme.citrus : Theme.ink.opacity(0.45))
                            .frame(width: 34, alignment: .leading)
                        Text(result.name)
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.ink)
                            .fontWeight(result.isPlayer ? .heavy : .regular)
                        Spacer(minLength: 8)
                        if let best = result.bestLap {
                            Text(TimeFormat.lap(best))
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.ink.opacity(0.4))
                        }
                        Text(result.totalTime.map(TimeFormat.lap) ?? "DNF")
                            .font(Theme.mono(13))
                            .foregroundStyle(Theme.ink.opacity(0.75))
                            .frame(width: 84, alignment: .trailing)
                        if outcome.mode == .grandPrix {
                            Text("+\(result.points)")
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.lime)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(result.isPlayer ? Theme.citrus.opacity(0.18) : Color.clear)
                    )
                    .opacity(index < revealed ? 1 : 0)
                    .offset(y: index < revealed ? 0 : 8)
                    .animation(.easeOut(duration: 0.2), value: revealed)
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            Panel(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your race")
                        .font(Theme.heading(15))
                        .foregroundStyle(Theme.ink)
                    row("Finish", outcome.playerResult?.totalTime.map(TimeFormat.lap) ?? "DNF")
                    row("Best lap", outcome.playerBestLap.map(TimeFormat.lap) ?? "—")
                    if outcome.isNewLapRecord {
                        badge("New lap record", tint: Theme.lime)
                    }
                    if outcome.isNewRaceRecord {
                        badge("New race record", tint: Theme.sky)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let standings = outcome.cupStandings {
                Panel(padding: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(outcome.isFinalRaceOfCup ? "Final standings" : "Cup standings")
                            .font(Theme.heading(15))
                            .foregroundStyle(Theme.ink)
                        ForEach(standings.prefix(5)) { standing in
                            HStack {
                                Text(standing.name)
                                    .font(Theme.body(12))
                                    .fontWeight(standing.isPlayer ? .bold : .regular)
                                Spacer()
                                Text("\(standing.points)")
                                    .font(Theme.mono(12))
                            }
                            .foregroundStyle(standing.isPlayer ? Theme.ink : Theme.ink.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink.opacity(0.5))
            Spacer()
            Text(value)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.ink)
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(Theme.body(10))
            .tracking(1.2)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Menu") { flow.go(to: .menu) }
                .buttonStyle(QuietButtonStyle())
            Spacer()
            if outcome.mode == .grandPrix, !outcome.isFinalRaceOfCup {
                Button("Next race") { flow.advanceCup() }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.tomato))
            } else {
                Button("Race again") { flow.restartRace() }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.tomato))
            }
        }
    }

    private func revealRows() {
        revealed = 0
        for index in outcome.results.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 * Double(index)) {
                revealed = index + 1
            }
        }
    }
}
