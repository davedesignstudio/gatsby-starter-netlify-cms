import Combine
import Foundation
import AisleRushCore

/// What happened at the end of a race, in the shape the results screen wants.
struct RaceOutcome {
    var trackID: String
    var trackName: String
    var results: [RaceResult]
    var playerResult: RaceResult?
    var playerBestLap: Double?
    var isNewLapRecord: Bool
    var isNewRaceRecord: Bool
    var mode: RaceMode
    /// Populated during a cup: running points after this race.
    var cupStandings: [CupStanding]?
    var cupName: String?
    var isFinalRaceOfCup = false
}

struct CupStanding: Identifiable {
    var id: Int
    var name: String
    var points: Int
    var isPlayer: Bool
}

/// A championship in progress. The field is generated once and carried between
/// races so the points table means something.
struct CupProgress {
    var cup: Cup
    var raceIndex: Int
    var entrants: [Entrant]
    var points: [Int: Int]

    var currentTrackID: String { cup.trackIDs[min(raceIndex, cup.trackIDs.count - 1)] }
    var isFinalRace: Bool { raceIndex >= cup.trackIDs.count - 1 }

    func standings() -> [CupStanding] {
        entrants.enumerated()
            .map { index, entrant in
                CupStanding(
                    id: index,
                    name: entrant.setup.character.name,
                    points: points[index] ?? 0,
                    isPlayer: entrant.isPlayer
                )
            }
            .sorted { ($0.points, $1.isPlayer ? 1 : 0) > ($1.points, $0.isPlayer ? 1 : 0) }
    }
}

/// Top-level navigation and the glue between menus, races and saved progress.
final class GameFlow: ObservableObject {
    enum Screen: Equatable {
        case menu
        case garage
        case trackSelect(RaceMode)
        case cupSelect
        case race
        case results
        case settings
        case howToPlay
    }

    @Published var screen: Screen = .menu
    @Published var session: RaceSession?
    @Published var outcome: RaceOutcome?

    let store: GameStore
    let settings: GameSettings
    private(set) var cup: CupProgress?

    init(store: GameStore = GameStore(), settings: GameSettings = GameSettings()) {
        self.store = store
        self.settings = settings
    }

    // MARK: - Navigation

    func go(to screen: Screen) {
        Audio.shared.play(.uiTap)
        withCleanup(screen)
    }

    private func withCleanup(_ next: Screen) {
        if next != .race {
            Audio.shared.stopEngineLoop()
        }
        screen = next
    }

    // MARK: - Starting races

    func startSingleRace(trackID: String) {
        cup = nil
        let entrants = makeField(playerSetup: store.setup)
        beginRace(trackID: trackID, entrants: entrants, mode: .singleRace)
    }

    func startTimeTrial(trackID: String) {
        cup = nil
        let entrants = [Entrant(setup: store.setup, isPlayer: true)]
        beginRace(trackID: trackID, entrants: entrants, mode: .timeTrial)
    }

    func startCup(_ cupID: String) {
        let selected = Cups.cup(id: cupID)
        let entrants = makeField(playerSetup: store.setup)
        cup = CupProgress(cup: selected, raceIndex: 0, entrants: entrants, points: [:])
        beginRace(trackID: selected.trackIDs[0], entrants: entrants, mode: .grandPrix)
    }

    func advanceCup() {
        guard var progress = cup, !progress.isFinalRace else {
            return finishCup()
        }
        progress.raceIndex += 1
        cup = progress
        beginRace(trackID: progress.currentTrackID, entrants: progress.entrants, mode: .grandPrix)
    }

    /// Closes out a championship. Separate from `advanceCup` so the results
    /// screen cannot replay the last race and award its points twice.
    func finishCup() {
        cup = nil
        go(to: .menu)
    }

    func restartRace() {
        guard let session else { return }
        beginRace(trackID: session.trackDefinition.id, entrants: session.entrants, mode: session.mode)
    }

    private func beginRace(trackID: String, entrants: [Entrant], mode: RaceMode) {
        let definition = Tracks.definition(id: trackID)
        let config = RaceConfig(
            laps: mode == .timeTrial ? 3 : definition.laps,
            fieldSize: entrants.count,
            difficulty: settings.difficulty,
            mode: mode,
            seed: UInt64.random(in: 1...UInt64.max),
            itemsEnabled: mode != .timeTrial,
            rubberBanding: mode != .timeTrial
        )
        let newSession = RaceSession(
            definition: definition,
            config: config,
            entrants: entrants,
            settings: settings
        )
        newSession.onComplete = { [weak self] results in
            self?.finish(results: results, session: newSession)
        }
        session = newSession
        outcome = nil
        withCleanup(.race)
    }

    /// Eight racers: the player plus a spread of characters and parts. Grid
    /// slots follow this order, so the player starts mid-pack rather than on
    /// pole; there is nothing to come back from at the front.
    private func makeField(playerSetup: CartSetup) -> [Entrant] {
        let others = Roster.characters.filter { $0.id != playerSetup.character.id }
        var entrants = others.prefix(7).enumerated().map { index, character in
            Entrant(
                setup: CartSetup(
                    character: character,
                    frame: Roster.frames[(index + 1) % Roster.frames.count],
                    wheels: Roster.wheels[(index + 2) % Roster.wheels.count]
                ),
                isPlayer: false
            )
        }
        entrants.insert(Entrant(setup: playerSetup, isPlayer: true), at: min(4, entrants.count))
        return entrants
    }

    // MARK: - Finishing

    private func finish(results: [RaceResult], session: RaceSession) {
        let trackID = session.trackDefinition.id
        let player = results.first(where: \.isPlayer)
        var newLapRecord = false
        var newRaceRecord = false

        if let bestLap = player?.bestLap {
            newLapRecord = store.recordLap(bestLap, trackID: trackID)
        }
        if let total = player?.totalTime {
            newRaceRecord = store.recordRace(total, trackID: trackID)
        }

        var standings: [CupStanding]?
        var cupName: String?
        var isFinal = false
        if var progress = cup {
            for result in results {
                progress.points[result.cartID, default: 0] += GrandPrix.points(forPlace: result.place)
            }
            cup = progress
            standings = progress.standings()
            cupName = progress.cup.name
            isFinal = progress.isFinalRace
            if isFinal, let playerRow = standings?.firstIndex(where: { $0.isPlayer }) {
                store.recordCup(progress.cup.id, place: playerRow + 1)
            }
        }

        outcome = RaceOutcome(
            trackID: trackID,
            trackName: session.trackDefinition.name,
            results: results,
            playerResult: player,
            playerBestLap: player?.bestLap,
            isNewLapRecord: newLapRecord,
            isNewRaceRecord: newRaceRecord,
            mode: session.mode,
            cupStandings: standings,
            cupName: cupName,
            isFinalRaceOfCup: isFinal
        )
        withCleanup(.results)
    }
}
