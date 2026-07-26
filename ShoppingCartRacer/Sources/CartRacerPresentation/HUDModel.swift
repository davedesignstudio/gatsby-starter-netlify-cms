import Foundation

/// Everything the heads-up display shows, derived from the simulation in one
/// place so the SwiftUI layer is pure layout.
public struct HUDModel: Equatable, Sendable {
    public enum Countdown: Equatable, Sendable {
        case hidden
        case number(Int)
        case go
    }

    public enum Status: String, Equatable, Sendable {
        case spunOut = "SPUN OUT"
        case stalled = "TANNOY STALL"
        case slipping = "SLIPPING"
        case boosting = "BOOST"
        case expressLane = "EXPRESS LANE"
        case offRoad = "OFF THE AISLE"
    }

    public let lap: Int
    public let totalLaps: Int
    public let lapText: String
    public let position: Int
    public let fieldSize: Int
    public let positionText: String
    public let speedKph: Int
    /// 0...1 against the cart's own ceiling, for the dial.
    public let speedFraction: Double
    public let heldItem: ItemKind?
    public let tokens: Int
    public let shieldCharges: Int
    /// 0...1 remaining boost, for the flame meter.
    public let boostFraction: Double
    /// 0...1 towards the next mini-turbo tier.
    public let driftChargeFraction: Double
    public let driftTier: Int
    public let currentLapTimeText: String
    public let bestLapTimeText: String?
    public let lastLapTimeText: String?
    /// Seconds to the cart ahead, already formatted, or nil when leading.
    public let gapAheadText: String?
    public let countdown: Countdown
    public let status: Status?
    public let isFinished: Bool
    public let lapProgress: Double

    public init?(simulation: RaceSimulation) {
        guard let cart = simulation.playerCart else { return nil }
        let trackLength = simulation.trackLength

        totalLaps = simulation.totalLaps
        lap = cart.displayLap(trackLength: trackLength, totalLaps: simulation.totalLaps)
        lapText = "LAP \(lap)/\(simulation.totalLaps)"
        lapProgress = cart.lapProgress(trackLength: trackLength)

        position = cart.racePosition
        fieldSize = simulation.carts.count
        positionText = HUDModel.ordinal(cart.racePosition)

        let ceiling = cart.tuning.topSpeed
        speedKph = Int((max(0, cart.forwardSpeed) * 3.6).rounded())
        speedFraction = Scalar.clamp(max(0, cart.forwardSpeed) / (ceiling * 1.4), 0, 1)

        heldItem = cart.heldItem
        tokens = cart.tokens
        shieldCharges = cart.shieldCharges
        boostFraction = Scalar.clamp(cart.boostTimer / 1.8, 0, 1)

        let thresholds = simulation.tuning.miniTurboThresholds
        driftTier = cart.miniTurboTier(tuning: simulation.tuning)
        if let top = thresholds.last, top > 0 {
            driftChargeFraction = Scalar.clamp(cart.driftCharge / top, 0, 1)
        } else {
            driftChargeFraction = 0
        }

        let lapElapsed = max(0, simulation.raceClock - cart.lapStartTime)
        currentLapTimeText = TimeFormatter.lapTime(lapElapsed)
        bestLapTimeText = cart.bestLapTime.map(TimeFormatter.lapTime)
        lastLapTimeText = cart.lapTimes.last.map(TimeFormatter.lapTime)

        if cart.racePosition > 1,
           let ahead = simulation.carts.first(where: { $0.racePosition == cart.racePosition - 1 }) {
            // Distance gap converted to time at the current pace, which is what a
            // pit board would tell you.
            let metres = max(0, ahead.travelled - cart.travelled)
            let pace = max(cart.forwardSpeed, 4)
            gapAheadText = String(format: "+%.1fs", metres / pace)
        } else {
            gapAheadText = nil
        }

        switch simulation.phase {
        case .countdown(let remaining):
            let count = Int(ceil(remaining))
            countdown = count >= 1 ? .number(min(count, 3)) : .go
        case .racing:
            // Keep GO! up for a beat after the lights change.
            countdown = simulation.raceClock < 0.9 ? .go : .hidden
        case .complete:
            countdown = .hidden
        }

        if cart.spinoutTimer > 0 {
            status = .spunOut
        } else if cart.expressLaneTimer > 0 {
            status = .expressLane
        } else if cart.stallTimer > 0 {
            status = .stalled
        } else if cart.slipTimer > 0 {
            status = .slipping
        } else if cart.boostTimer > 0 {
            status = .boosting
        } else if cart.isOffRoad {
            status = .offRoad
        } else {
            status = nil
        }

        isFinished = cart.hasFinished
    }

    public static func ordinal(_ value: Int) -> String {
        let suffix: String
        switch (value % 100, value % 10) {
        case (11, _), (12, _), (13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(value)\(suffix)"
    }
}

/// A row on the live standings panel and the results screen.
public struct StandingsRow: Identifiable, Equatable, Sendable {
    public let id: Int
    public let position: Int
    public let racerID: String
    public let name: String
    public let isPlayer: Bool
    public let hasFinished: Bool
    /// Formatted gap to the leader, or the finishing time once home.
    public let detail: String
    public let tokens: Int
    public let color: RacerColor

    public init(
        id: Int,
        position: Int,
        racerID: String,
        name: String,
        isPlayer: Bool,
        hasFinished: Bool,
        detail: String,
        tokens: Int,
        color: RacerColor
    ) {
        self.id = id
        self.position = position
        self.racerID = racerID
        self.name = name
        self.isPlayer = isPlayer
        self.hasFinished = hasFinished
        self.detail = detail
        self.tokens = tokens
        self.color = color
    }

    /// Live order during a race.
    public static func rows(simulation: RaceSimulation) -> [StandingsRow] {
        let standings = simulation.standings
        guard let leader = standings.first else { return [] }
        return standings.map { cart in
            let detail: String
            if let finishTime = cart.finishTime {
                detail = TimeFormatter.lapTime(finishTime)
            } else if cart.id == leader.id {
                detail = "LEADER"
            } else {
                detail = String(format: "-%.0fm", max(0, leader.travelled - cart.travelled))
            }
            return StandingsRow(
                id: cart.id,
                position: cart.racePosition,
                racerID: cart.racer.id,
                name: cart.racer.name,
                isPlayer: cart.isPlayer,
                hasFinished: cart.hasFinished,
                detail: detail,
                tokens: cart.tokens,
                color: cart.racer.primaryColor
            )
        }
    }

    /// Final order for the results screen.
    public static func rows(result: RaceResult) -> [StandingsRow] {
        let winnerTime = result.standings.first?.totalTime
        return result.standings.map { standing in
            let detail: String
            if let total = standing.totalTime {
                if let winnerTime, standing.position > 1 {
                    detail = String(format: "+%.2fs", total - winnerTime)
                } else {
                    detail = TimeFormatter.lapTime(total)
                }
            } else {
                detail = "DNF"
            }
            return StandingsRow(
                id: standing.cartID,
                position: standing.position,
                racerID: standing.racerID,
                name: standing.racerName,
                isPlayer: standing.isPlayer,
                hasFinished: standing.totalTime != nil,
                detail: detail,
                tokens: standing.tokens,
                color: RacerRoster.racer(id: standing.racerID)?.primaryColor ?? Palette.hudForeground
            )
        }
    }
}
