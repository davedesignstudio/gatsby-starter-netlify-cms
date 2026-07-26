import Foundation

public enum RaceMode: String, Sendable {
    case grandPrix
    case singleRace
    case timeTrial
}

public struct RaceConfig: Sendable {
    public var laps: Int
    public var fieldSize: Int
    /// 0 = Sunday Shopper, 1 = Weekly Big Shop, 2 = Closing Time.
    public var difficulty: Int
    public var mode: RaceMode
    public var seed: UInt64
    public var countdownDuration: Double
    /// Off in time trial, on everywhere else.
    public var itemsEnabled: Bool
    /// Lets trailing AI carts claw back time so races stay close.
    public var rubberBanding: Bool

    public init(
        laps: Int = 3,
        fieldSize: Int = 8,
        difficulty: Int = 1,
        mode: RaceMode = .singleRace,
        seed: UInt64 = 0xA15E,
        countdownDuration: Double = 3.4,
        itemsEnabled: Bool = true,
        rubberBanding: Bool = true
    ) {
        self.laps = laps
        self.fieldSize = fieldSize
        self.difficulty = difficulty
        self.mode = mode
        self.seed = seed
        self.countdownDuration = countdownDuration
        self.itemsEnabled = itemsEnabled
        self.rubberBanding = rubberBanding
    }

    public static let difficultyNames = ["Sunday Shopper", "Weekly Big Shop", "Closing Time"]

    /// Baseline AI competence for the selected difficulty.
    public var aiSkillRange: ClosedRange<Double> {
        switch difficulty {
        case 0: return 0.42...0.62
        case 1: return 0.6...0.82
        default: return 0.78...0.98
        }
    }
}

public enum RacePhase: Equatable, Sendable {
    case countdown(remaining: Double)
    case racing
    /// The player is done; AI carts keep going until the field is home.
    case finished

    public var isRacing: Bool { self == .racing }
}

/// Things worth a sound effect or a particle. Drained by the presentation layer.
public enum RaceEvent: Sendable, Equatable {
    case countdownBeep(Int)
    case go
    case rocketStart(cartID: Int)
    case burnout(cartID: Int)
    case itemBoxCollected(cartID: Int)
    case itemAwarded(cartID: Int, kind: ItemKind)
    case itemUsed(cartID: Int, kind: ItemKind)
    case projectileFired(cartID: Int, kind: ItemKind)
    case cartHit(cartID: Int, by: ItemKind, sourceID: Int?)
    case wallImpact(cartID: Int, force: Double)
    case cartBump(cartID: Int, otherID: Int, force: Double)
    case propScattered(index: Int)
    case miniTurbo(cartID: Int, tier: Int)
    case lapCompleted(cartID: Int, lap: Int, lapTime: Double)
    case finalLap(cartID: Int)
    case raceFinished(cartID: Int, place: Int, totalTime: Double)
    case wrongWay(cartID: Int, active: Bool)
}

/// A single row of the results screen.
public struct RaceResult: Sendable, Identifiable {
    public var id: Int { cartID }
    public var cartID: Int
    public var place: Int
    public var name: String
    public var isPlayer: Bool
    public var totalTime: Double?
    public var bestLap: Double?
    public var points: Int
}

public enum GrandPrix {
    /// Points awarded for 1st through 8th.
    public static let pointsTable = [15, 12, 10, 8, 6, 4, 2, 1]

    public static func points(forPlace place: Int) -> Int {
        guard place >= 1, place <= pointsTable.count else { return 0 }
        return pointsTable[place - 1]
    }
}

public enum TimeFormat {
    /// m:ss.mmm, the format every lap counter has used since 1992.
    public static func lap(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--.---" }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return String(format: "%d:%06.3f", minutes, remainder)
    }

    public static func short(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--.--" }
        return String(format: "%.2f", seconds)
    }

    public static func ordinal(_ place: Int) -> String {
        let suffix: String
        switch place % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch place % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(place)\(suffix)"
    }
}
