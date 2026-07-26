import SwiftUI

struct CupStandingsView: View {
    @EnvironmentObject private var store: GameStore

    private var cup: GrandPrix? { store.session.grandPrix }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("TROLLEY TROPHY")
                    .font(Theme.title(30))
                    .foregroundStyle(Theme.accent)
                if let cup {
                    Text(cup.isComplete
                         ? "Final standings"
                         : "After round \(cup.completedRounds) of \(cup.trackIDs.count)")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 16)

            if let cup {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Panel(title: "Championship") {
                            let standings = cup.standings
                            ForEach(standings.indices, id: \.self) { index in
                                let entrant = standings[index]
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(Theme.numeric(15))
                                        .foregroundStyle(index < 3 ? Theme.accent : Theme.muted)
                                        .frame(width: 22, alignment: .trailing)

                                    Circle()
                                        .fill(Color(RacerRoster.racer(id: entrant.racerID)?.primaryColor
                                                    ?? Palette.hudMuted))
                                        .frame(width: 10, height: 10)

                                    Text(entrant.racerName)
                                        .font(Theme.body(14))
                                        .foregroundStyle(entrant.isPlayer ? Theme.foreground : Theme.muted)

                                    if entrant.isPlayer {
                                        Text("YOU")
                                            .font(Theme.body(9))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Theme.accent))
                                    }

                                    Spacer()

                                    // Round-by-round finishes, then the points.
                                    HStack(spacing: 4) {
                                        ForEach(entrant.finishes.indices, id: \.self) { round in
                                            let finish = entrant.finishes[round]
                                            Text("\(finish)")
                                                .font(Theme.numeric(10))
                                                .foregroundStyle(Theme.muted)
                                                .frame(width: 16, height: 16)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.panelRaised))
                                        }
                                    }

                                    Text("\(entrant.points)")
                                        .font(Theme.numeric(15))
                                        .foregroundStyle(Theme.foreground)
                                        .frame(width: 32, alignment: .trailing)
                                }
                                .padding(.vertical, 5)
                            }
                        }

                        if let next = cup.currentTrackID,
                           let definition = TrackLibrary.definition(id: next) {
                            Panel(title: "Up next") {
                                HStack(spacing: 12) {
                                    TrackMapView(definition: definition, lineWidth: 3)
                                        .frame(width: 72, height: 72)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(definition.name)
                                            .font(Theme.heading(17))
                                            .foregroundStyle(Theme.foreground)
                                        Text(definition.subtitle)
                                            .font(Theme.body(12))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                }
                            }
                        }

                        if cup.isComplete, cup.playerPosition == 1 {
                            Panel {
                                HStack(spacing: 10) {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(Theme.accent)
                                    Text("Champion of the shop floor. The trolley bay salutes you.")
                                        .font(Theme.body(13))
                                        .foregroundStyle(Theme.foreground)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Button(cup?.currentTrackID == nil ? "Back to the shop" : "To the grid") {
                store.continueFromStandings()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(20)
        }
    }
}
