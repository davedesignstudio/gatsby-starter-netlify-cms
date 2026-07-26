import Foundation

public enum GameRoute: Equatable, Sendable {
    case mainMenu
    case characterSelect
    case trackSelect
    case race
    case results
    case cupStandings
    case settings
    case records
}

public enum GameMode: String, Equatable, Sendable {
    case singleRace
    case grandPrix

    public var displayName: String {
        switch self {
        case .singleRace: return "Single Race"
        case .grandPrix: return "Trolley Trophy"
        }
    }
}

/// The navigation and progression state machine, with no UI framework anywhere
/// near it. The SwiftUI layer owns one of these and re-renders when it changes.
public struct GameSession: Sendable {
    public private(set) var route: GameRoute = .mainMenu
    public private(set) var mode: GameMode = .singleRace
    public var selectedRacerID: String
    public var selectedTrackID: String
    public var difficulty: Difficulty = .busy
    public var settings: ControlSettings = .default
    public private(set) var grandPrix: GrandPrix?
    public private(set) var lastResult: RaceResult?
    public private(set) var lastAchievements: [NewRecord] = []
    public private(set) var book: RecordBook
    /// Bumped every time a race should be built from scratch, so the view layer
    /// knows to throw away the old scene.
    public private(set) var raceGeneration: Int = 0
    private var seedCounter: UInt64 = 1

    public init(book: RecordBook = RecordBook(), settings: ControlSettings = .default) {
        self.book = book
        self.settings = settings
        selectedRacerID = book.favouriteRacerID ?? RacerRoster.all[0].id
        selectedTrackID = TrackLibrary.cupOrder.first ?? "aisle-seven"
        if !book.isUnlocked(trackID: selectedTrackID) {
            selectedTrackID = book.unlockedTrackIDs().first ?? selectedTrackID
        }
    }

    // MARK: - Derived

    public var selectedRacer: Racer {
        RacerRoster.racer(id: selectedRacerID) ?? RacerRoster.all[0]
    }

    public var selectedTrack: TrackDefinition {
        TrackLibrary.definition(id: selectedTrackID) ?? TrackLibrary.all[0]
    }

    public func isUnlocked(trackID: String) -> Bool {
        book.isUnlocked(trackID: trackID)
    }

    public var unlockedTrackIDs: [String] {
        book.unlockedTrackIDs()
    }

    /// Position and points banner shown between rounds of a cup.
    public var cupSummary: String? {
        guard let grandPrix else { return nil }
        guard let entrant = grandPrix.playerEntrant, let position = grandPrix.playerPosition else { return nil }
        return "\(HUDModel.ordinal(position)) · \(entrant.points) pts"
    }

    // MARK: - Navigation

    public mutating func go(to route: GameRoute) {
        self.route = route
    }

    public mutating func beginSingleRace() {
        mode = .singleRace
        grandPrix = nil
        route = .characterSelect
    }

    public mutating func beginGrandPrix() {
        mode = .grandPrix
        grandPrix = GrandPrix.standard(playerRacerID: selectedRacerID, difficulty: difficulty)
        route = .characterSelect
    }

    /// Called when the player confirms their character.
    public mutating func confirmRacer() {
        if mode == .grandPrix {
            // The cup fixes the field and the running order, so there is no track
            // to pick: go straight to the first round.
            grandPrix = GrandPrix.standard(playerRacerID: selectedRacerID, difficulty: difficulty)
            selectedTrackID = grandPrix?.currentTrackID ?? selectedTrackID
            startRace()
        } else {
            route = .trackSelect
        }
    }

    public mutating func startRace() {
        raceGeneration += 1
        route = .race
    }

    /// Builds the configuration for the race that is about to start.
    public mutating func makeRaceConfiguration() -> RaceConfiguration? {
        seedCounter = seedCounter &* 6364136223846793005 &+ 1442695040888963407
        let seed = seedCounter ^ UInt64(raceGeneration) &* 0x9E3779B97F4A7C15
        return RaceConfiguration.standard(
            trackID: selectedTrackID,
            playerRacerID: selectedRacerID,
            difficulty: difficulty,
            seed: seed
        )
    }

    // MARK: - Results

    /// Folds a finished race into progression and moves to the results screen.
    public mutating func finishRace(result: RaceResult, keeper: RecordKeeper? = nil) {
        lastResult = result
        if let keeper {
            lastAchievements = keeper.submit(result: result)
            book = keeper.book
        } else {
            lastAchievements = book.submit(result: result)
        }

        if var cup = grandPrix {
            cup.record(result: result)
            grandPrix = cup
            if cup.isComplete, cup.playerPosition == 1 {
                if let keeper {
                    keeper.recordCupWin()
                    book = keeper.book
                } else {
                    book.recordCupWin()
                }
                lastAchievements.append(.cupWon)
            }
        }

        route = .results
    }

    /// What the button on the results screen should do next.
    public enum ResultsContinuation: Equatable, Sendable {
        case nextRound(trackID: String)
        case cupFinished
        case backToMenu
    }

    public var resultsContinuation: ResultsContinuation {
        guard let grandPrix else { return .backToMenu }
        if let next = grandPrix.currentTrackID { return .nextRound(trackID: next) }
        return .cupFinished
    }

    public mutating func continueFromResults() {
        switch resultsContinuation {
        case .nextRound(let trackID):
            selectedTrackID = trackID
            route = .cupStandings
        case .cupFinished:
            route = .cupStandings
        case .backToMenu:
            route = .mainMenu
        }
    }

    /// Leaves the standings table: either into the next race or back to the menu.
    public mutating func continueFromStandings() {
        if let grandPrix, grandPrix.currentTrackID != nil {
            startRace()
        } else {
            self.grandPrix = nil
            route = .mainMenu
        }
    }

    public mutating func abandonRace() {
        grandPrix = nil
        route = .mainMenu
    }

    public mutating func restartRace() {
        startRace()
    }
}
