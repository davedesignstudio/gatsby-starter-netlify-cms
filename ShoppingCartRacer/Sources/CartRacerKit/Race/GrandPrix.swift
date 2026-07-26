import Foundation

/// Three courses, points after each one, trophy at the end.
public struct GrandPrix: Equatable, Codable, Sendable {
    /// Points for 1st, 2nd, 3rd, ... Anyone past the end of the table scores nothing.
    public static let pointsTable: [Int] = [15, 12, 10, 8, 6, 4]

    public struct Entrant: Equatable, Codable, Sendable {
        public let racerID: String
        public let racerName: String
        public let isPlayer: Bool
        public var points: Int
        /// Finishing position in each completed round.
        public var finishes: [Int]

        public init(racerID: String, racerName: String, isPlayer: Bool, points: Int = 0, finishes: [Int] = []) {
            self.racerID = racerID
            self.racerName = racerName
            self.isPlayer = isPlayer
            self.points = points
            self.finishes = finishes
        }
    }

    public let trackIDs: [String]
    public let difficulty: Difficulty
    public private(set) var entrants: [Entrant]
    public private(set) var completedRounds: Int

    public init(trackIDs: [String] = TrackLibrary.cupOrder, difficulty: Difficulty, entrants: [Entrant]) {
        self.trackIDs = trackIDs
        self.difficulty = difficulty
        self.entrants = entrants
        self.completedRounds = 0
    }

    public var isComplete: Bool { completedRounds >= trackIDs.count }

    public var currentTrackID: String? {
        isComplete ? nil : trackIDs[completedRounds]
    }

    public var roundNumber: Int { min(completedRounds + 1, trackIDs.count) }

    public static func points(forPosition position: Int) -> Int {
        guard position >= 1, position <= pointsTable.count else { return 0 }
        return pointsTable[position - 1]
    }

    public mutating func record(result: RaceResult) {
        for standing in result.standings {
            guard let index = entrants.firstIndex(where: { $0.racerID == standing.racerID }) else { continue }
            entrants[index].points += Self.points(forPosition: standing.position)
            entrants[index].finishes.append(standing.position)
        }
        completedRounds += 1
    }

    /// Championship order: points, then count-back on best finishes.
    public var standings: [Entrant] {
        entrants.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            let lhsBest = lhs.finishes.sorted()
            let rhsBest = rhs.finishes.sorted()
            for (a, b) in zip(lhsBest, rhsBest) where a != b { return a < b }
            return lhs.racerID < rhs.racerID
        }
    }

    public var playerEntrant: Entrant? {
        entrants.first { $0.isPlayer }
    }

    public var playerPosition: Int? {
        standings.firstIndex { $0.isPlayer }.map { $0 + 1 }
    }

    /// Builds a cup for the player's chosen character plus the rest of the roster.
    public static func standard(playerRacerID: String, difficulty: Difficulty, opponentCount: Int = 4) -> GrandPrix? {
        guard let player = RacerRoster.racer(id: playerRacerID) else { return nil }
        var entrants = [Entrant(racerID: player.id, racerName: player.name, isPlayer: true)]
        entrants += RacerRoster.opponents(excluding: playerRacerID, count: opponentCount)
            .map { Entrant(racerID: $0.id, racerName: $0.name, isPlayer: false) }
        return GrandPrix(difficulty: difficulty, entrants: entrants)
    }
}
