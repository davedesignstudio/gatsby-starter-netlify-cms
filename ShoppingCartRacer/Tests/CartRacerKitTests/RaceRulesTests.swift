import XCTest
@testable import CartRacerKit

final class RaceRulesTests: XCTestCase {
    private let marge = RacerRoster.racer(id: "marge")!
    private let kev = RacerRoster.racer(id: "kev")!

    // MARK: - Lap counting

    func testLapCountingIsBasedOnDistanceActuallyCovered() {
        let length = 400.0
        var cart = CartState(id: 0, racer: marge, isPlayer: true, position: .zero, heading: 0, startDistance: -7)

        // On the grid, behind the line: no laps yet.
        XCTAssertEqual(cart.lapsCompleted(trackLength: length), 0)
        XCTAssertEqual(cart.displayLap(trackLength: length, totalLaps: 3), 1)

        // Crossing the line for the first time starts lap one, it does not
        // complete one.
        cart.travelled = 5
        XCTAssertEqual(cart.lapsCompleted(trackLength: length), 0)
        XCTAssertEqual(cart.displayLap(trackLength: length, totalLaps: 3), 1)

        cart.travelled = 401
        XCTAssertEqual(cart.lapsCompleted(trackLength: length), 1)
        XCTAssertEqual(cart.displayLap(trackLength: length, totalLaps: 3), 2)

        cart.travelled = 1200
        XCTAssertEqual(cart.lapsCompleted(trackLength: length), 3)
        XCTAssertEqual(cart.displayLap(trackLength: length, totalLaps: 3), 3)
    }

    func testDrivingBackwardsUnwindsProgressInsteadOfScoringALap() {
        let track = TestTracks.circle(radius: 60, halfWidth: 12)
        let simulation = TestTracks.started(
            TestTracks.configuration(track: track, racers: [marge], laps: 1)
        )

        // Forwards for a while.
        simulation.runScripted(seconds: 8, driver: ScriptedDriver())
        let forwardProgress = simulation.carts[0].travelled
        XCTAssertGreaterThan(forwardProgress, 20)

        // Now turn round and drive back over the line. Progress must unwind,
        // and no lap may be credited.
        simulation.carts[0].heading = Scalar.normalizeAngle(simulation.carts[0].heading + .pi)
        simulation.carts[0].velocity = .zero
        var backwards = ScriptedDriver()
        backwards.lookahead = -12
        let events = simulation.runScripted(seconds: 10, driver: backwards)

        XCTAssertLessThan(simulation.carts[0].travelled, forwardProgress)
        XCTAssertFalse(events.contains { if case .lapCompleted = $0 { return true } else { return false } })
        XCTAssertEqual(simulation.carts[0].lapTimes.count, 0)
    }

    func testLapAndFinishEventsFireWithSensibleTimes() {
        guard let configuration = RaceConfiguration.standard(
            trackID: "frozen-foods",
            playerRacerID: "marge",
            difficulty: .busy,
            seed: 0xAB
        ) else { return XCTFail("could not build a race") }

        let report = RaceHarness.run(configuration: configuration)
        XCTAssertTrue(report.everyoneFinished, "not everyone finished")
        XCTAssertFalse(report.timedOut)

        // Three laps each, for five carts.
        XCTAssertEqual(report.lapTimes.count, configuration.laps * configuration.entries.count)
        for lapTime in report.lapTimes {
            XCTAssertGreaterThan(lapTime, 10, "a lap time was implausibly quick")
            XCTAssertLessThan(lapTime, 120, "a lap time was implausibly slow")
        }

        for standing in report.result.standings {
            XCTAssertEqual(standing.lapTimes.count, configuration.laps)
            guard let total = standing.totalTime, let best = standing.bestLapTime else {
                return XCTFail("a finisher has no times")
            }
            XCTAssertLessThan(best, total)
            // The total should be the sum of the laps, give or take the rolling
            // start off the grid.
            XCTAssertEqual(standing.lapTimes.reduce(0, +), total, accuracy: 0.5)
        }
    }

    // MARK: - Ranking

    func testRacePositionsAreUniqueAndOrderedByProgress() {
        let simulation = TestTracks.started(
            TestTracks.configuration(
                track: TestTracks.circle(radius: 90, halfWidth: 16),
                racers: RacerRoster.all
            )
        )
        simulation.installAutopilot()
        for _ in 0..<2400 { simulation.step(simulation.tuning.fixedTimeStep) }

        let positions = simulation.carts.map(\.racePosition).sorted()
        XCTAssertEqual(positions, Array(1...simulation.carts.count))

        let ordered = simulation.standings
        for index in 1..<ordered.count {
            XCTAssertGreaterThanOrEqual(ordered[index - 1].travelled, ordered[index].travelled)
        }
    }

    func testFinishOrderMatchesFinishTimes() {
        guard let configuration = RaceConfiguration.standard(
            trackID: "aisle-seven",
            playerRacerID: "kev",
            difficulty: .busy,
            seed: 0x99
        ) else { return XCTFail("could not build a race") }

        let standings = RaceHarness.run(configuration: configuration).result.standings
        XCTAssertEqual(standings.map(\.position), Array(1...standings.count))

        let times = standings.compactMap(\.totalTime)
        XCTAssertEqual(times.count, standings.count)
        XCTAssertEqual(times, times.sorted(), "finish order disagrees with finish times")
    }

    // MARK: - Determinism

    func testSameSeedProducesTheSameRace() {
        func fingerprint(seed: UInt64) -> String {
            guard let configuration = RaceConfiguration.standard(
                trackID: "loading-dock",
                playerRacerID: "marge",
                difficulty: .blackFriday,
                seed: seed
            ) else { return "" }
            let report = RaceHarness.run(configuration: configuration)
            return report.result.standings
                .map { "\($0.racerID):\($0.position):\(String(format: "%.4f", $0.totalTime ?? -1))" }
                .joined(separator: "|")
        }

        let a = fingerprint(seed: 0x1111)
        XCTAssertFalse(a.isEmpty)
        XCTAssertEqual(a, fingerprint(seed: 0x1111))
        XCTAssertNotEqual(a, fingerprint(seed: 0x2222), "the seed had no effect on the race")
    }

    // MARK: - Field integrity

    func testWholeFieldGetsHomeOnEveryCourseAndDifficulty() {
        for definition in TrackLibrary.all {
            for difficulty in Difficulty.allCases {
                guard let configuration = RaceConfiguration.standard(
                    trackID: definition.id,
                    playerRacerID: "squeak",
                    difficulty: difficulty,
                    seed: 0xC0FFEE
                ) else { return XCTFail("could not build a race") }

                let report = RaceHarness.run(configuration: configuration, maxSimulatedSeconds: 400)
                XCTAssertTrue(
                    report.everyoneFinished,
                    "\(definition.id)/\(difficulty): only \(report.finishedCount)/\(report.fieldSize) finished"
                )
                XCTAssertLessThan(
                    report.worstOverhang,
                    definition.shoulderWidth + 0.1,
                    "\(definition.id): a cart left the premises"
                )
                // A handful of recoveries is fine, a stream of them is a bug.
                XCTAssertLessThan(report.respawns, 12, "\(definition.id)/\(difficulty): carts keep getting stuck")
            }
        }
    }

    func testHarderDifficultiesAreNotSlower() {
        var averages: [Difficulty: Double] = [:]
        for difficulty in Difficulty.allCases {
            var total = 0.0
            var count = 0
            for definition in TrackLibrary.all {
                guard let configuration = RaceConfiguration.standard(
                    trackID: definition.id,
                    playerRacerID: "squeak",
                    difficulty: difficulty,
                    seed: 0x515
                ) else { continue }
                let report = RaceHarness.run(configuration: configuration, maxSimulatedSeconds: 400)
                guard let fastest = report.fastestLap else { continue }
                total += fastest
                count += 1
            }
            averages[difficulty] = total / Double(max(count, 1))
        }

        guard let leisurely = averages[.leisurely], let blackFriday = averages[.blackFriday] else {
            return XCTFail("missing difficulty timings")
        }
        XCTAssertLessThan(blackFriday, leisurely * 1.02, "the hardest AI is slower than the easiest")
    }

    func testEveryRacerCanCompleteEveryCourse() {
        for racer in RacerRoster.all {
            for definition in TrackLibrary.all {
                let configuration = RaceConfiguration(
                    track: Track(definition: definition),
                    entries: [RaceEntry(racer: racer, isPlayer: true)],
                    difficulty: .busy,
                    seed: 0x2B,
                    endsWhenPlayerFinishes: false
                )
                let report = RaceHarness.run(configuration: configuration, maxSimulatedSeconds: 300)
                XCTAssertTrue(
                    report.everyoneFinished,
                    "\(racer.id) could not get round \(definition.id)"
                )
            }
        }
    }

    // MARK: - Grand Prix

    func testGrandPrixAwardsPointsAndTracksStandings() {
        guard var cup = GrandPrix.standard(playerRacerID: "marge", difficulty: .busy) else {
            return XCTFail("could not build a cup")
        }
        XCTAssertEqual(cup.trackIDs.count, 3)
        XCTAssertEqual(cup.roundNumber, 1)
        XCTAssertEqual(cup.currentTrackID, TrackLibrary.cupOrder.first)
        XCTAssertFalse(cup.isComplete)

        var round = 0
        while let trackID = cup.currentTrackID {
            guard let configuration = RaceConfiguration.standard(
                trackID: trackID,
                playerRacerID: "marge",
                difficulty: .busy,
                seed: UInt64(0x100 + round)
            ) else { return XCTFail("could not build a race") }
            cup.record(result: RaceHarness.run(configuration: configuration).result)
            round += 1
        }

        XCTAssertTrue(cup.isComplete)
        XCTAssertEqual(cup.completedRounds, 3)
        XCTAssertNil(cup.currentTrackID)

        for entrant in cup.entrants {
            XCTAssertEqual(entrant.finishes.count, 3)
        }
        // Winning all three would be 45; nobody can score more.
        let leader = cup.standings[0]
        XCTAssertLessThanOrEqual(leader.points, 45)
        XCTAssertGreaterThan(leader.points, 0)
        XCTAssertEqual(cup.standings.map(\.points), cup.standings.map(\.points).sorted(by: >))
        XCTAssertNotNil(cup.playerPosition)
    }

    func testPointsTable() {
        XCTAssertEqual(GrandPrix.points(forPosition: 1), 15)
        XCTAssertEqual(GrandPrix.points(forPosition: 6), 4)
        XCTAssertEqual(GrandPrix.points(forPosition: 7), 0)
        XCTAssertEqual(GrandPrix.points(forPosition: 0), 0)
    }

    func testChampionshipTiesBreakOnBestFinishes() {
        // Two entrants on equal points; the one with the win is ahead.
        var cup = GrandPrix(
            trackIDs: ["a", "b"],
            difficulty: .busy,
            entrants: [
                GrandPrix.Entrant(racerID: "steady", racerName: "Steady", isPlayer: false, points: 24, finishes: [2, 2]),
                GrandPrix.Entrant(racerID: "spiky", racerName: "Spiky", isPlayer: true, points: 24, finishes: [1, 4])
            ]
        )
        XCTAssertEqual(cup.standings.first?.racerID, "spiky")

        cup.record(
            result: RaceResult(
                trackID: "c",
                trackName: "C",
                laps: 3,
                difficulty: .busy,
                standings: [
                    RaceResult.Standing(
                        cartID: 0, racerID: "steady", racerName: "Steady", isPlayer: false,
                        position: 1, totalTime: 100, bestLapTime: 30, lapTimes: [30, 35, 35], tokens: 3
                    )
                ]
            )
        )
        XCTAssertEqual(cup.standings.first?.racerID, "steady")
        XCTAssertEqual(cup.standings.first?.points, 39)
    }

    func testTimeFormatting() {
        XCTAssertEqual(TimeFormatter.lapTime(0), "0:00.000")
        XCTAssertEqual(TimeFormatter.lapTime(9.5), "0:09.500")
        XCTAssertEqual(TimeFormatter.lapTime(75.25), "1:15.250")
        XCTAssertEqual(TimeFormatter.lapTime(-1), "--:--.---")
    }
}
