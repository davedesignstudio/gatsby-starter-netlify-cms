import XCTest
@testable import AisleRushCore

/// Not an assertion suite: a pacing report used while tuning. Skipped unless
/// RACE_REPORT is set in the environment.
final class RacePacingReport: XCTestCase {
    func testPrintTrouble() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RACE_TROUBLE"] != nil)
        let id = ProcessInfo.processInfo.environment["RACE_TROUBLE"] ?? "produce-loop"
        let track = Tracks.track(id: id)
        let race = RaceSimulation(
            track: track,
            config: RaceConfig(laps: 3, difficulty: 1, seed: 2024, itemsEnabled: false),
            entrants: RaceHarness.field(size: 8)
        )
        var impacts = [Int](repeating: 0, count: 8)
        var crawlTime = [Double](repeating: 0, count: 8)
        var offTrackTime = [Double](repeating: 0, count: 8)
        var elapsed = 0.0
        while !race.isComplete, elapsed < 400 {
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .wallImpact(let cartID, let force) = event, force > 4 { impacts[cartID] += 1 }
            }
            for cart in race.carts where !cart.hasFinished {
                if cart.speed < 6 { crawlTime[cart.id] += RaceHarness.dt }
                if cart.surface.isOffTrack { offTrackTime[cart.id] += RaceHarness.dt }
            }
            elapsed += RaceHarness.dt
        }
        var crawlHistogram = [Double](repeating: 0, count: 20)
        let replay = RaceSimulation(
            track: track,
            config: RaceConfig(laps: 3, difficulty: 1, seed: 2024, itemsEnabled: false),
            entrants: RaceHarness.field(size: 8)
        )
        var replayElapsed = 0.0
        while !replay.isComplete, replayElapsed < 400 {
            replay.update(dt: RaceHarness.dt)
            _ = replay.drainEvents()
            for cart in replay.carts where !cart.hasFinished && cart.speed < 6 {
                let bucket = min(19, Int(cart.lapDistance / track.length * 20))
                crawlHistogram[bucket] += RaceHarness.dt
            }
            replayElapsed += RaceHarness.dt
        }
        print("crawl by track fraction:")
        for (bucket, seconds) in crawlHistogram.enumerated() where seconds > 1 {
            print(String(format: "  %.2f-%.2f : %6.1fs", Double(bucket) / 20, Double(bucket + 1) / 20, seconds))
        }

        print("--- \(track.definition.name) ---")
        for cart in race.carts.sorted(by: { ($0.finishTime ?? 999) < ($1.finishTime ?? 999) }) {
            print(String(
                format: "%-20@ skill=%.2f total=%6.1f best=%5.1f walls=%3d crawl=%5.1fs offTrack=%5.1fs",
                cart.setup.character.name as NSString,
                cart.aiSkill,
                cart.finishTime ?? -1,
                cart.bestLapTime ?? -1,
                impacts[cart.id],
                crawlTime[cart.id],
                offTrackTime[cart.id]
            ))
        }
    }

    func testPrintPacing() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RACE_REPORT"] != nil)
        let itemsEnabled = ProcessInfo.processInfo.environment["RACE_ITEMS"] != "0"
        for definition in Tracks.all {
            let track = Tracks.track(id: definition.id)
            let race = RaceSimulation(
                track: track,
                config: RaceConfig(laps: 3, difficulty: 1, seed: 2024, itemsEnabled: itemsEnabled),
                entrants: RaceHarness.field(size: 8)
            )
            RaceHarness.run(race)
            let best = race.carts.compactMap(\.bestLapTime).min() ?? 0
            let worst = race.carts.compactMap(\.bestLapTime).max() ?? 0
            let winner = race.results[0]
            print(String(
                format: "%-22@ len=%6.1fm  bestLap=%5.1fs  slowestBestLap=%5.1fs  winner=%@ %6.1fs  spread=%5.1fs",
                definition.name as NSString,
                track.length,
                best,
                worst,
                winner.name as NSString,
                winner.totalTime ?? 0,
                (race.results.last?.totalTime ?? 0) - (winner.totalTime ?? 0)
            ))
        }
    }
}
