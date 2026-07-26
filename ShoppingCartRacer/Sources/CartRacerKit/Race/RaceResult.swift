import Foundation

public struct RaceResult: Equatable, Codable, Sendable {
    public struct Standing: Equatable, Codable, Sendable {
        public let cartID: Int
        public let racerID: String
        public let racerName: String
        public let isPlayer: Bool
        public let position: Int
        /// Nil when the cart had not crossed the line when the race was called.
        public let totalTime: Double?
        public let bestLapTime: Double?
        public let lapTimes: [Double]
        public let tokens: Int

        public init(
            cartID: Int,
            racerID: String,
            racerName: String,
            isPlayer: Bool,
            position: Int,
            totalTime: Double?,
            bestLapTime: Double?,
            lapTimes: [Double],
            tokens: Int
        ) {
            self.cartID = cartID
            self.racerID = racerID
            self.racerName = racerName
            self.isPlayer = isPlayer
            self.position = position
            self.totalTime = totalTime
            self.bestLapTime = bestLapTime
            self.lapTimes = lapTimes
            self.tokens = tokens
        }
    }

    public let trackID: String
    public let trackName: String
    public let laps: Int
    public let difficulty: Difficulty
    public let standings: [Standing]

    public init(trackID: String, trackName: String, laps: Int, difficulty: Difficulty, standings: [Standing]) {
        self.trackID = trackID
        self.trackName = trackName
        self.laps = laps
        self.difficulty = difficulty
        self.standings = standings
    }

    public var playerStanding: Standing? {
        standings.first { $0.isPlayer }
    }

    public var winner: Standing? {
        standings.min { $0.position < $1.position }
    }
}

/// Formats a duration as `m:ss.mmm`, which is what a lap board wants.
public enum TimeFormatter {
    public static func lapTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--.---" }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return String(format: "%d:%06.3f", minutes, remainder)
    }

    public static func gap(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--" }
        return String(format: "%+.3f", seconds)
    }
}
