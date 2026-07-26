import CartKartCore
import Combine
import Foundation
import SwiftUI

/// Owns the screen flow and builds race configurations.
///
/// The simulation itself lives in `CartKartCore`; this type only decides which
/// race happens next and remembers what came out of the last one.
final class GameCoordinator: ObservableObject {
    enum Route: Equatable {
        case menu
        case cartSelect
        case trackSelect
        case race
        case results
        case cupStandings
        case howToPlay
    }

    @Published private(set) var route: Route = .menu
    @Published var mode: RaceConfiguration.Mode = .singleRace
    @Published var selectedTrackID: String = TrackLibrary.all[0].id
    @Published private(set) var lastResults: [RaceResult] = []
    @Published private(set) var lastPlayerLapTimes: [Double] = []
    @Published private(set) var didBreakRecord = false
    @Published private(set) var grandPrix: GrandPrixState?
    /// Built once when a race starts, so redrawing a view never reshuffles the grid.
    @Published private(set) var currentRace: RaceConfiguration?
    /// Changes for every race so SwiftUI gives each one a fresh scene.
    @Published private(set) var raceInstanceID = 0

    let storage: Storage
    /// Bumped for every race so restarting reshuffles item luck.
    private var raceCounter: UInt64 = 0

    init(storage: Storage) {
        self.storage = storage
    }

    var selectedTrack: Track {
        if mode == .grandPrix, let track = grandPrix?.currentTrack {
            return track
        }
        return TrackLibrary.track(id: selectedTrackID)
    }

    // MARK: - Navigation

    func go(to route: Route) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.route = route
        }
    }

    func startCup() {
        mode = .grandPrix
        grandPrix = GrandPrixState(cup: .trolleyCup, entries: makeEntries())
        beginRace()
    }

    func startSingleRace() {
        mode = .singleRace
        grandPrix = nil
        beginRace()
    }

    func startTimeTrial() {
        mode = .timeTrial
        grandPrix = nil
        beginRace()
    }

    private func beginRace() {
        currentRace = makeRaceConfiguration()
        raceInstanceID += 1
        go(to: .race)
    }

    /// Chooses the field: the player's cart plus a shuffled set of rivals.
    private func makeEntries() -> [RaceConfiguration.Entry] {
        let player = storage.selectedCart
        var entries = [RaceConfiguration.Entry(profile: player, isPlayer: true)]
        guard mode != .timeTrial else { return entries }

        var rivals = Roster.all.filter { $0.id != player.id }
        var random = SeededRandom(seed: 0xCA27 &+ raceCounter)
        for index in stride(from: rivals.count - 1, to: 0, by: -1) {
            rivals.swapAt(index, random.int(in: 0...index))
        }
        entries.append(contentsOf: rivals.prefix(7).map { RaceConfiguration.Entry(profile: $0, isPlayer: false) })
        return entries
    }

    /// The configuration for the race that is about to start.
    func makeRaceConfiguration() -> RaceConfiguration {
        let entries: [RaceConfiguration.Entry]
        if mode == .grandPrix, let grandPrix {
            // Keep the same field for the whole cup.
            entries = grandPrix.standings.map {
                RaceConfiguration.Entry(profile: $0.profile, isPlayer: $0.isPlayer)
            }
        } else {
            entries = makeEntries()
        }
        return RaceConfiguration(
            track: selectedTrack,
            entries: entries,
            mode: mode,
            difficulty: storage.difficulty,
            seed: 0xC0FFEE &+ raceCounter &* 977
        )
    }

    // MARK: - Race lifecycle

    func raceFinished(results: [RaceResult], playerLapTimes: [Double], playerTotalTime: Double?) {
        raceCounter &+= 1
        lastResults = results
        lastPlayerLapTimes = playerLapTimes
        didBreakRecord = storage.recordRace(
            trackID: selectedTrack.id,
            lapTimes: playerLapTimes,
            totalTime: playerTotalTime
        )
        if mode == .grandPrix {
            grandPrix?.record(results: results)
        }
        go(to: .results)
    }

    func retryRace() {
        raceCounter &+= 1
        beginRace()
    }

    /// What the button under the results table should say and do.
    var hasNextCupRace: Bool {
        mode == .grandPrix && !(grandPrix?.isComplete ?? true)
    }

    func advanceAfterResults() {
        if mode == .grandPrix {
            if let grandPrix, grandPrix.isComplete {
                if grandPrix.playerPlace == 1 { storage.recordCupWin() }
                go(to: .cupStandings)
            } else {
                beginRace()
            }
        } else {
            go(to: .trackSelect)
        }
    }

    func quitToMenu() {
        grandPrix = nil
        go(to: .menu)
    }

    var playerResult: RaceResult? {
        lastResults.first { $0.isPlayer }
    }
}
