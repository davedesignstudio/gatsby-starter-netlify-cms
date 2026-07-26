import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var store: GameStore

    private var result: RaceResult? { store.session.lastResult }

    var body: some View {
        VStack(spacing: 0) {
            headline

            if let result {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Panel(title: "Finishing order") {
                            ForEach(StandingsRow.rows(result: result)) { row in
                                StandingsRowView(row: row)
                            }
                        }

                        if let player = result.playerStanding {
                            Panel(title: "Your race") {
                                LabelledValue("Best lap", player.bestLapTime.map(TimeFormatter.lapTime) ?? "--")
                                LabelledValue("Total", player.totalTime.map(TimeFormatter.lapTime) ?? "DNF")
                                LabelledValue("Loose change", "\(player.tokens)")
                                ForEach(Array(player.lapTimes.enumerated()), id: \.offset) { index, lap in
                                    LabelledValue("Lap \(index + 1)", TimeFormatter.lapTime(lap))
                                }
                            }
                        }

                        if !store.session.lastAchievements.isEmpty {
                            Panel(title: "New for the record book") {
                                ForEach(Array(store.session.lastAchievements.enumerated()), id: \.offset) { _, item in
                                    HStack(spacing: 8) {
                                        Image(systemName: icon(for: item))
                                            .foregroundStyle(Theme.accent)
                                        Text(describe(item))
                                            .font(Theme.body(13))
                                            .foregroundStyle(Theme.foreground)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            VStack(spacing: 10) {
                Button(continueTitle) { store.continueFromResults() }
                    .buttonStyle(PrimaryButtonStyle())
                if store.session.grandPrix == nil {
                    Button("Race again") { store.restartRace() }
                        .buttonStyle(PrimaryButtonStyle(isProminent: false))
                }
            }
            .padding(20)
        }
    }

    private var headline: some View {
        VStack(spacing: 4) {
            if let position = result?.playerStanding?.position {
                Text(HUDModel.ordinal(position))
                    .font(Theme.title(52))
                    .foregroundStyle(position <= 3 ? Theme.accent : Theme.foreground)
                Text(verdict(position: position))
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.muted)
            }
            Text(result?.trackName ?? "")
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    private var continueTitle: String {
        switch store.session.resultsContinuation {
        case .nextRound: return "Next course"
        case .cupFinished: return "Final standings"
        case .backToMenu: return "Back to the shop"
        }
    }

    private func verdict(position: Int) -> String {
        switch position {
        case 1: return "Trolley of the week"
        case 2, 3: return "On the podium"
        case 4: return "Just off the pace"
        default: return "Back to the car park"
        }
    }

    private func icon(for record: NewRecord) -> String {
        switch record {
        case .firstTimeOnTrack: return "map"
        case .bestLap: return "stopwatch"
        case .bestRace: return "timer"
        case .bestFinish: return "flag.checkered"
        case .trackUnlocked: return "lock.open.fill"
        case .cupWon: return "trophy.fill"
        }
    }

    private func describe(_ record: NewRecord) -> String {
        switch record {
        case .firstTimeOnTrack:
            return "First run on this course"
        case .bestLap(let time):
            return "New best lap: \(TimeFormatter.lapTime(time))"
        case .bestRace(let time):
            return "New best race: \(TimeFormatter.lapTime(time))"
        case .bestFinish(let position):
            return "Best finish yet: \(HUDModel.ordinal(position))"
        case .trackUnlocked(let trackID):
            let name = TrackLibrary.definition(id: trackID)?.name ?? trackID
            return "Unlocked \(name)"
        case .cupWon:
            return "Won the Trolley Trophy"
        }
    }
}

struct StandingsRowView: View {
    let row: StandingsRow

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.position)")
                .font(Theme.numeric(15))
                .foregroundStyle(row.position <= 3 ? Theme.accent : Theme.muted)
                .frame(width: 22, alignment: .trailing)

            Circle()
                .fill(Color(row.color))
                .frame(width: 10, height: 10)

            Text(row.name)
                .font(Theme.body(14))
                .foregroundStyle(row.isPlayer ? Theme.foreground : Theme.muted)

            if row.isPlayer {
                Text("YOU")
                    .font(Theme.body(9))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }

            Spacer()

            Text(row.detail)
                .font(Theme.numeric(12))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 5)
    }
}

struct LabelledValue: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.body(13))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(Theme.numeric(13))
                .foregroundStyle(Theme.foreground)
        }
    }
}
