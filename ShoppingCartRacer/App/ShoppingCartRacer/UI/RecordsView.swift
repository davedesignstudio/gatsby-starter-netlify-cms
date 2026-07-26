import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var store: GameStore

    private var book: RecordBook { store.session.book }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(title: "Records") { store.go(to: .mainMenu) }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Panel(title: "Career") {
                        LabelledValue("Races finished", "\(book.racesFinished)")
                        LabelledValue("Trophies", "\(book.cupWins)")
                        LabelledValue("Loose change collected", "\(book.totalTokens)")
                        if let favourite = book.favouriteRacerID,
                           let racer = RacerRoster.racer(id: favourite) {
                            LabelledValue("Last driven", racer.name)
                        }
                    }

                    ForEach(TrackLibrary.all, id: \.id) { definition in
                        Panel(title: definition.name) {
                            if store.session.isUnlocked(trackID: definition.id) {
                                let record = book.record(for: definition.id)
                                LabelledValue(
                                    "Best lap",
                                    record?.bestLapTime.map(TimeFormatter.lapTime) ?? "--"
                                )
                                LabelledValue(
                                    "Best race",
                                    record?.bestRaceTime.map(TimeFormatter.lapTime) ?? "--"
                                )
                                LabelledValue(
                                    "Best finish",
                                    record?.bestPosition.map(HUDModel.ordinal) ?? "--"
                                )
                                LabelledValue("Times raced", "\(record?.timesRaced ?? 0)")
                                if let holder = record?.bestLapRacerID,
                                   let racer = RacerRoster.racer(id: holder) {
                                    LabelledValue("Lap record set with", racer.name)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(Theme.muted)
                                    Text("Finish the previous course on the podium to unlock.")
                                        .font(Theme.body(12))
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}
