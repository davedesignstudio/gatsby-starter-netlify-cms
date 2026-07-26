import Foundation

public struct TrackRecord: Codable, Equatable, Sendable {
    public var trackID: String
    public var bestLapTime: Double?
    public var bestRaceTime: Double?
    public var bestPosition: Int?
    /// Who set the lap record.
    public var bestLapRacerID: String?
    public var timesRaced: Int

    public init(
        trackID: String,
        bestLapTime: Double? = nil,
        bestRaceTime: Double? = nil,
        bestPosition: Int? = nil,
        bestLapRacerID: String? = nil,
        timesRaced: Int = 0
    ) {
        self.trackID = trackID
        self.bestLapTime = bestLapTime
        self.bestRaceTime = bestRaceTime
        self.bestPosition = bestPosition
        self.bestLapRacerID = bestLapRacerID
        self.timesRaced = timesRaced
    }
}

public enum NewRecord: Equatable, Sendable {
    case firstTimeOnTrack
    case bestLap(Double)
    case bestRace(Double)
    case bestFinish(Int)
    case trackUnlocked(String)
    case cupWon
}

/// Everything that persists between sessions.
public struct RecordBook: Codable, Equatable, Sendable {
    public var records: [String: TrackRecord]
    public var cupWins: Int
    public var totalTokens: Int
    public var racesFinished: Int
    public var favouriteRacerID: String?

    public init(
        records: [String: TrackRecord] = [:],
        cupWins: Int = 0,
        totalTokens: Int = 0,
        racesFinished: Int = 0,
        favouriteRacerID: String? = nil
    ) {
        self.records = records
        self.cupWins = cupWins
        self.totalTokens = totalTokens
        self.racesFinished = racesFinished
        self.favouriteRacerID = favouriteRacerID
    }

    public func record(for trackID: String) -> TrackRecord? {
        records[trackID]
    }

    /// The first course is always open; the rest need a podium on the one before.
    public func isUnlocked(trackID: String, cupOrder: [String] = TrackLibrary.cupOrder) -> Bool {
        guard let index = cupOrder.firstIndex(of: trackID) else { return true }
        guard index > 0 else { return true }
        let previous = cupOrder[index - 1]
        guard let best = records[previous]?.bestPosition else { return false }
        return best <= 3
    }

    public func unlockedTrackIDs(cupOrder: [String] = TrackLibrary.cupOrder) -> [String] {
        cupOrder.filter { isUnlocked(trackID: $0, cupOrder: cupOrder) }
    }

    /// Folds a finished race into the book and reports anything worth a fanfare.
    @discardableResult
    public mutating func submit(result: RaceResult, cupOrder: [String] = TrackLibrary.cupOrder) -> [NewRecord] {
        guard let player = result.playerStanding else { return [] }

        var achievements: [NewRecord] = []
        var record = records[result.trackID] ?? TrackRecord(trackID: result.trackID)
        if records[result.trackID] == nil {
            achievements.append(.firstTimeOnTrack)
        }

        record.timesRaced += 1

        if let lap = player.bestLapTime, lap > 0, record.bestLapTime.map({ lap < $0 }) ?? true {
            record.bestLapTime = lap
            record.bestLapRacerID = player.racerID
            achievements.append(.bestLap(lap))
        }
        if let total = player.totalTime, total > 0, record.bestRaceTime.map({ total < $0 }) ?? true {
            record.bestRaceTime = total
            achievements.append(.bestRace(total))
        }
        if record.bestPosition.map({ player.position < $0 }) ?? true {
            record.bestPosition = player.position
            achievements.append(.bestFinish(player.position))
        }

        let unlockedBefore = Set(unlockedTrackIDs(cupOrder: cupOrder))
        records[result.trackID] = record
        totalTokens += player.tokens
        if player.totalTime != nil { racesFinished += 1 }
        favouriteRacerID = player.racerID

        for trackID in unlockedTrackIDs(cupOrder: cupOrder) where !unlockedBefore.contains(trackID) {
            achievements.append(.trackUnlocked(trackID))
        }

        return achievements
    }

    public mutating func recordCupWin() {
        cupWins += 1
    }
}

/// Somewhere to keep the record book. `UserDefaults` on the device, memory in
/// tests — the presentation layer does not care which.
public protocol RecordStorage: AnyObject {
    func loadRecordBookData() -> Data?
    func save(recordBookData: Data)
}

public final class InMemoryRecordStorage: RecordStorage {
    private var data: Data?

    public init(data: Data? = nil) {
        self.data = data
    }

    public func loadRecordBookData() -> Data? { data }

    public func save(recordBookData: Data) { data = recordBookData }
}

/// Loads, updates and saves the record book. Corrupt or absent data is treated
/// as a fresh start rather than an error the player has to see.
public final class RecordKeeper {
    public private(set) var book: RecordBook
    private let storage: RecordStorage

    public init(storage: RecordStorage) {
        self.storage = storage
        if let data = storage.loadRecordBookData(),
           let decoded = try? JSONDecoder().decode(RecordBook.self, from: data) {
            book = decoded
        } else {
            book = RecordBook()
        }
    }

    @discardableResult
    public func submit(result: RaceResult) -> [NewRecord] {
        let achievements = book.submit(result: result)
        persist()
        return achievements
    }

    public func recordCupWin() {
        book.recordCupWin()
        persist()
    }

    public func reset() {
        book = RecordBook()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(book) else { return }
        storage.save(recordBookData: data)
    }
}
