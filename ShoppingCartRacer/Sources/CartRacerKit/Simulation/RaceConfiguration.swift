import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    /// Sunday morning shop.
    case leisurely
    /// Saturday afternoon.
    case busy
    /// Doors just opened on the sale.
    case blackFriday

    public var displayName: String {
        switch self {
        case .leisurely: return "Leisurely"
        case .busy: return "Busy Saturday"
        case .blackFriday: return "Black Friday"
        }
    }

    /// Overall AI competence, 0...1.
    public var aiSkill: Double {
        switch self {
        case .leisurely: return 0.42
        case .busy: return 0.68
        case .blackFriday: return 0.92
        }
    }

    /// How hard the field elastic-bands towards the player.
    public var rubberBanding: Double {
        switch self {
        case .leisurely: return 0.05
        case .busy: return 0.09
        case .blackFriday: return 0.14
        }
    }
}

public struct RaceEntry: Sendable {
    public let racer: Racer
    public let isPlayer: Bool

    public init(racer: Racer, isPlayer: Bool) {
        self.racer = racer
        self.isPlayer = isPlayer
    }
}

public struct RaceConfiguration: Sendable {
    public let track: Track
    public let laps: Int
    public let entries: [RaceEntry]
    public let difficulty: Difficulty
    public let seed: UInt64
    /// Length of the pre-race countdown in seconds.
    public let countdownDuration: Double
    /// The game stops the clock once the player is home; the balance harness
    /// turns this off so it can watch the whole field finish.
    public let endsWhenPlayerFinishes: Bool

    public init(
        track: Track,
        laps: Int? = nil,
        entries: [RaceEntry],
        difficulty: Difficulty = .busy,
        seed: UInt64 = 0xC0FFEE,
        countdownDuration: Double = 3.2,
        endsWhenPlayerFinishes: Bool = true
    ) {
        self.track = track
        self.laps = laps ?? track.definition.recommendedLaps
        self.entries = entries
        self.difficulty = difficulty
        self.seed = seed
        self.countdownDuration = countdownDuration
        self.endsWhenPlayerFinishes = endsWhenPlayerFinishes
    }

    public func with(endsWhenPlayerFinishes value: Bool) -> RaceConfiguration {
        RaceConfiguration(
            track: track,
            laps: laps,
            entries: entries,
            difficulty: difficulty,
            seed: seed,
            countdownDuration: countdownDuration,
            endsWhenPlayerFinishes: value
        )
    }

    /// Standard five-cart field: the player plus the rest of the roster.
    public static func standard(
        trackID: String,
        playerRacerID: String,
        difficulty: Difficulty = .busy,
        opponentCount: Int = 4,
        seed: UInt64 = 0xC0FFEE,
        laps: Int? = nil
    ) -> RaceConfiguration? {
        guard let definition = TrackLibrary.definition(id: trackID),
              let player = RacerRoster.racer(id: playerRacerID) else { return nil }
        var entries = [RaceEntry(racer: player, isPlayer: true)]
        entries += RacerRoster.opponents(excluding: playerRacerID, count: opponentCount)
            .map { RaceEntry(racer: $0, isPlayer: false) }
        return RaceConfiguration(
            track: Track(definition: definition),
            laps: laps,
            entries: entries,
            difficulty: difficulty,
            seed: seed
        )
    }
}

public enum RacePhase: Equatable, Sendable {
    case countdown(remaining: Double)
    case racing
    /// Everyone who matters has crossed the line.
    case complete

    public var isRacing: Bool { self == .racing }
}

/// Global physics constants. Kept in one struct so balance passes are a diff in
/// a single place rather than a scavenger hunt through the step function.
public struct SimulationTuning: Sendable {
    public var fixedTimeStep: Double = 1.0 / 120.0
    public var maxSubstepsPerFrame: Int = 6

    /// Extra top speed and engine force while boosting.
    public var boostSpeedMultiplier: Double = 1.38
    public var boostForceMultiplier: Double = 2.2
    public var padBoostStrength: Double = 1.0

    /// Drift charge thresholds, in seconds, for the three mini-turbo tiers.
    public var miniTurboThresholds: [Double] = [0.65, 1.35, 2.15]
    public var miniTurboDurations: [Double] = [0.55, 0.95, 1.45]
    public var driftMinimumSpeed: Double = 6.0
    /// How much lateral grip a drifting cart gives up.
    public var driftGripScale: Double = 0.34

    public var spinoutDuration: Double = 1.35
    public var slipDuration: Double = 1.9
    public var stallDuration: Double = 1.5
    public var invulnerabilityAfterHit: Double = 1.1

    public var wallSpeedRetention: Double = 0.72
    public var offRoadSurface: Surface = .spillDebris

    /// Loose change caps out; each token is a small top-speed bump.
    public var maxTokens: Int = 12
    public var tokenSpeedBonus: Double = 0.006

    public var stuckSpeedThreshold: Double = 1.2
    public var stuckDuration: Double = 3.5

    public var projectileSpeed: Double = 21.0
    public var projectileLifetime: Double = 4.5
    public var projectileHomingRate: Double = 2.2
    public var hazardLifetime: Double = 22.0

    public var expressLaneDuration: Double = 3.0
    public var expressLaneSpeedMultiplier: Double = 1.55

    public init() {}
}
