import Foundation

/// Runs a whole race with no renderer attached. Tests use this to prove the
/// field can actually complete a lap; `RaceLab` uses it to dump balance numbers.
public enum RaceHarness {
    public struct Report: Sendable {
        public var result: RaceResult
        public var simulatedSeconds: Double
        public var finishedCount: Int
        public var fieldSize: Int
        /// Worst distance any cart ended up outside the racing surface, in metres.
        public var worstOverhang: Double
        public var wallScrapes: Int
        public var respawns: Int
        public var spinouts: Int
        public var itemsUsed: Int
        public var driftsStarted: Int
        public var miniTurbos: Int
        public var tokensCollected: Int
        public var lapTimes: [Double]
        public var timedOut: Bool
        /// Cart ids that never made it home, with how far they got.
        public var unfinished: [(cartID: Int, racerName: String, travelled: Double)]

        public var everyoneFinished: Bool { finishedCount == fieldSize }

        public var fastestLap: Double? { lapTimes.min() }
        public var slowestLap: Double? { lapTimes.max() }

        public var averageLap: Double? {
            guard !lapTimes.isEmpty else { return nil }
            return lapTimes.reduce(0, +) / Double(lapTimes.count)
        }
    }

    /// - Parameters:
    ///   - autopilotPlayer: drives the player's cart with the AI as well, so a
    ///     race can run unattended.
    ///   - stopWhenPlayerFinishes: mirror the game's behaviour (`true`) or keep
    ///     going until the whole field is home (`false`), which is what the
    ///     balance tests want.
    /// - Parameter trace: called every `traceInterval` seconds with the live
    ///   simulation, for telemetry dumps while tuning.
    public static func run(
        configuration incoming: RaceConfiguration,
        autopilotPlayer: Bool = true,
        stopWhenPlayerFinishes: Bool = false,
        maxSimulatedSeconds: Double = 600,
        drifting: Bool = true,
        traceInterval: Double = 0,
        trace: ((RaceSimulation) -> Void)? = nil
    ) -> Report {
        let configuration = incoming.with(endsWhenPlayerFinishes: stopWhenPlayerFinishes)
        let simulation = RaceSimulation(configuration: configuration)
        simulation.aiDriftingEnabled = drifting
        if autopilotPlayer { simulation.installAutopilot() }

        var report = Report(
            result: simulation.result(),
            simulatedSeconds: 0,
            finishedCount: 0,
            fieldSize: configuration.entries.count,
            worstOverhang: 0,
            wallScrapes: 0,
            respawns: 0,
            spinouts: 0,
            itemsUsed: 0,
            driftsStarted: 0,
            miniTurbos: 0,
            tokensCollected: 0,
            lapTimes: [],
            timedOut: false,
            unfinished: []
        )

        let step = simulation.tuning.fixedTimeStep
        var elapsed = 0.0
        var finished = false
        var nextTrace = 0.0

        while elapsed < maxSimulatedSeconds {
            simulation.step(step)
            elapsed += step

            if let trace, traceInterval > 0, elapsed >= nextTrace {
                nextTrace = elapsed + traceInterval
                trace(simulation)
            }

            for event in simulation.drainEvents() {
                switch event {
                case .wallScrape: report.wallScrapes += 1
                case .respawned: report.respawns += 1
                case .spunOut: report.spinouts += 1
                case .itemUsed: report.itemsUsed += 1
                case .driftStarted: report.driftsStarted += 1
                case .miniTurbo: report.miniTurbos += 1
                case .tokenCollected: report.tokensCollected += 1
                case .lapCompleted(_, _, let lapTime): report.lapTimes.append(lapTime)
                default: break
                }
            }

            for cart in simulation.carts {
                let overhang = max(0, abs(cart.lateral) - configuration.track.geometry.halfWidth(at: cart.distance))
                report.worstOverhang = max(report.worstOverhang, overhang)
            }

            let allHome = simulation.carts.allSatisfy(\.hasFinished)
            let playerHome = simulation.playerCart?.hasFinished ?? true
            if allHome || (stopWhenPlayerFinishes && playerHome) {
                finished = true
                break
            }
        }

        report.simulatedSeconds = elapsed
        report.timedOut = !finished
        report.finishedCount = simulation.carts.filter(\.hasFinished).count
        report.unfinished = simulation.carts
            .filter { !$0.hasFinished }
            .map { (cartID: $0.id, racerName: $0.racer.name, travelled: $0.travelled) }
        report.result = simulation.result()
        return report
    }
}
