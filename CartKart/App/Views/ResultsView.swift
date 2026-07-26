import CartKartCore
import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    var body: some View {
        VStack(spacing: 16) {
            header

            Panel {
                VStack(spacing: 0) {
                    ForEach(Array(game.lastResults.enumerated()), id: \.element.id) { index, result in
                        ResultRow(
                            result: result,
                            winnerTime: game.lastResults.first?.totalTime,
                            showsPoints: game.mode == .grandPrix
                        )
                        if index < game.lastResults.count - 1 {
                            Divider().overlay(Palette.panelBorder)
                        }
                    }
                }
            }

            if !game.lastPlayerLapTimes.isEmpty {
                Panel(title: "Your laps") {
                    HStack(spacing: 14) {
                        ForEach(Array(game.lastPlayerLapTimes.enumerated()), id: \.offset) { index, lap in
                            VStack(spacing: 2) {
                                Text("L\(index + 1)")
                                    .font(.arcadeBody(11))
                                    .foregroundStyle(Palette.subtleText)
                                Text(TimeFormat.lap(lap))
                                    .font(.arcade(15))
                                    .foregroundStyle(lap == game.lastPlayerLapTimes.min() ? Palette.secondary : Palette.text)
                            }
                        }
                        Spacer()
                        if game.didBreakRecord {
                            Label("New record", systemImage: "star.fill")
                                .font(.arcadeBody(13))
                                .foregroundStyle(Palette.primary)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                ArcadeButton(title: "Menu", systemImage: "house.fill", tint: Palette.danger) {
                    game.quitToMenu()
                }
                ArcadeButton(title: "Retry", systemImage: "arrow.counterclockwise") {
                    game.retryRace()
                }
                ArcadeButton(
                    title: game.hasNextCupRace ? "Next race" : "Continue",
                    systemImage: "chevron.right",
                    isProminent: true
                ) {
                    game.advanceAfterResults()
                }
            }
        }
        .padding(22)
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let player = game.playerResult {
                Text(headline(for: player.place))
                    .font(.arcade(38))
                    .foregroundStyle(player.place <= 3 ? Palette.primary : Palette.text)
                Text("You finished \(TimeFormat.ordinal(player.place)) at \(game.selectedTrack.name)")
                    .font(.arcadeBody(14))
                    .foregroundStyle(Palette.subtleText)
            } else {
                Text("Race complete")
                    .font(.arcade(34))
                    .foregroundStyle(Palette.text)
            }
        }
    }

    private func headline(for place: Int) -> String {
        switch place {
        case 1: return "Aisle champion!"
        case 2, 3: return "On the podium"
        case 4...6: return "Mid-pack shuffle"
        default: return "Blocked in frozen foods"
        }
    }
}

private struct ResultRow: View {
    let result: RaceResult
    let winnerTime: Double?
    let showsPoints: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(TimeFormat.ordinal(result.place))
                .font(.arcade(17))
                .foregroundStyle(result.place == 1 ? Palette.primary : Palette.subtleText)
                .frame(width: 44, alignment: .leading)
            Text(result.profile.emblem)
            Text(result.profile.name)
                .font(.arcadeBody(15))
                .foregroundStyle(result.isPlayer ? Palette.text : Palette.subtleText)
            if result.isPlayer {
                Text("YOU")
                    .font(.arcade(10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.primary))
            }
            Spacer()
            if let time = result.totalTime {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(TimeFormat.lap(time))
                        .font(.arcadeBody(14))
                        .foregroundStyle(Palette.text)
                    if let winnerTime, result.place > 1 {
                        Text(TimeFormat.gap(time - winnerTime))
                            .font(.arcadeBody(11))
                            .foregroundStyle(Palette.subtleText)
                    }
                }
            }
            if showsPoints {
                Text("+\(result.points)")
                    .font(.arcade(15))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
    }
}

struct CupStandingsView: View {
    @EnvironmentObject private var game: GameCoordinator

    var body: some View {
        VStack(spacing: 18) {
            if let grandPrix = game.grandPrix {
                VStack(spacing: 6) {
                    Text(grandPrix.cup.name)
                        .font(.arcade(34))
                        .foregroundStyle(Palette.primary)
                    Text(grandPrix.playerPlace == 1
                         ? "You won the cup. Somebody call the manager."
                         : "Final standings after \(grandPrix.completedRaces) races")
                        .font(.arcadeBody(14))
                        .foregroundStyle(Palette.subtleText)
                }

                Panel {
                    VStack(spacing: 0) {
                        ForEach(Array(grandPrix.standings.enumerated()), id: \.element.id) { index, standing in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.arcade(17))
                                    .foregroundStyle(index == 0 ? Palette.primary : Palette.subtleText)
                                    .frame(width: 26, alignment: .leading)
                                Text(standing.profile.emblem)
                                Text(standing.profile.name)
                                    .font(.arcadeBody(15))
                                    .foregroundStyle(standing.isPlayer ? Palette.text : Palette.subtleText)
                                Spacer()
                                Text("\(standing.points) pts")
                                    .font(.arcade(16))
                                    .foregroundStyle(Palette.secondary)
                            }
                            .padding(.vertical, 8)
                            if index < grandPrix.standings.count - 1 {
                                Divider().overlay(Palette.panelBorder)
                            }
                        }
                    }
                }
            }

            ArcadeButton(title: "Back to menu", systemImage: "house.fill", isProminent: true) {
                game.quitToMenu()
            }
        }
        .padding(22)
    }
}
