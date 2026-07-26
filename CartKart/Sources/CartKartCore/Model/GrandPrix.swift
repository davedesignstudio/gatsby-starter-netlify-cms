import Foundation

/// A sequence of courses raced back to back for points.
public struct Cup: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let trackIDs: [String]

    public var tracks: [Track] { trackIDs.map { TrackLibrary.track(id: $0) } }

    public static let trolleyCup = Cup(
        id: "trolley",
        name: "Trolley Cup",
        trackIDs: ["produce-plaza", "frozen-foods", "bulk-warehouse", "checkout-chaos"]
    )

    public static let all: [Cup] = [trolleyCup]
}

/// Running totals across a cup.
public struct GrandPrixState: Sendable {
    public struct Standing: Sendable, Identifiable {
        public let profile: RacerProfile
        public var points: Int
        public var isPlayer: Bool
        public var id: String { profile.id }
    }

    public let cup: Cup
    public private(set) var standings: [Standing]
    public private(set) var completedRaces: Int = 0

    public init(cup: Cup, entries: [RaceConfiguration.Entry]) {
        self.cup = cup
        self.standings = entries.map { Standing(profile: $0.profile, points: 0, isPlayer: $0.isPlayer) }
    }

    public var isComplete: Bool { completedRaces >= cup.trackIDs.count }

    public var currentTrack: Track? {
        guard completedRaces < cup.trackIDs.count else { return nil }
        return TrackLibrary.track(id: cup.trackIDs[completedRaces])
    }

    public mutating func record(results: [RaceResult]) {
        for result in results {
            guard let index = standings.firstIndex(where: { $0.profile.id == result.profile.id }) else { continue }
            standings[index].points += result.points
        }
        standings.sort { $0.points > $1.points }
        completedRaces += 1
    }

    /// Position of the player in the cup, 1-based.
    public var playerPlace: Int? {
        standings.firstIndex(where: { $0.isPlayer }).map { $0 + 1 }
    }
}

public enum TimeFormat {
    /// `1:23.456`
    public static func lap(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--.---" }
        let minutes = Int(seconds) / 60
        let remaining = seconds - Double(minutes * 60)
        return String(format: "%d:%06.3f", minutes, remaining)
    }

    /// `+2.431` gap strings for the results table.
    public static func gap(_ seconds: Double) -> String {
        String(format: "+%.3f", max(0, seconds))
    }

    public static func ordinal(_ place: Int) -> String {
        let suffix: String
        switch (place % 100, place % 10) {
        case (11, _), (12, _), (13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(place)\(suffix)"
    }
}
