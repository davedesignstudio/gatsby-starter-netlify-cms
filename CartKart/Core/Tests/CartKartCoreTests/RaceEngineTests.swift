import XCTest
@testable import CartKartCore

final class RaceEngineTests: XCTestCase {
    private func configuration(
        track: Track = TrackLibrary.producePlaza,
        racers: Int = 8,
        playerIndex: Int? = 0,
        laps: Int? = nil,
        difficulty: RaceConfiguration.Difficulty = .weeklyShop,
        seed: UInt64 = 99
    ) -> RaceConfiguration {
        let entries = (0..<racers).map { index in
            RaceConfiguration.Entry(
                profile: Roster.all[index % Roster.all.count],
                isPlayer: index == playerIndex
            )
        }
        return RaceConfiguration(
            track: track,
            entries: entries,
            difficulty: difficulty,
            lapCount: laps,
            seed: seed
        )
    }

    /// Advances by whole simulation steps.
    private func advance(_ engine: RaceEngine, seconds: Double, input: RaceInput = .fullThrottle) {
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(seconds / step) {
            engine.advance(deltaTime: step, playerInput: input)
        }
    }

    /// Advances with the player's cart handed over to the AI controller, for
    /// tests that care about race flow rather than about driving inputs.
    private func advanceOnAutopilot(_ engine: RaceEngine, seconds: Double) {
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(seconds / step) {
            let input = engine.playerKartID.map { engine.autopilotInput(for: $0) } ?? .fullThrottle
            engine.advance(deltaTime: step, playerInput: input)
        }
    }

    private func autopilot(_ engine: RaceEngine) -> RaceInput {
        engine.playerKartID.map { engine.autopilotInput(for: $0) } ?? .fullThrottle
    }

    func testGridSetup() {
        let engine = RaceEngine(configuration: configuration())
        XCTAssertEqual(engine.karts.count, 8)
        XCTAssertEqual(engine.playerKartID, 0)
        XCTAssertEqual(Set(engine.karts.map(\.racePosition)).count, 8)
        for kart in engine.karts {
            XCTAssertEqual(kart.lapsCompleted, 0)
            XCTAssertNil(kart.item)
            XCTAssertLessThan(kart.totalProgress, 0, "carts line up behind the finish line")
        }
    }

    func testNobodyMovesBeforeTheLightsGoOut() {
        let engine = RaceEngine(configuration: configuration())
        let before = engine.karts.map(\.position)
        advance(engine, seconds: 2.0)
        for (kart, start) in zip(engine.karts, before) {
            XCTAssertEqual(kart.position.distance(to: start), 0, accuracy: 0.001)
        }
        if case .countdown = engine.phase {} else { XCTFail("expected to still be counting down") }
    }

    func testCountdownEmitsTicksThenGoes() {
        let engine = RaceEngine(configuration: configuration())
        var ticks: [Int] = []
        var wentGreen = false
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(5.0 / step) {
            engine.advance(deltaTime: step, playerInput: .fullThrottle)
            for event in engine.drainEvents() {
                switch event {
                case .countdownTick(let value): ticks.append(value)
                case .go: wentGreen = true
                default: break
                }
            }
        }
        XCTAssertEqual(ticks, [3, 2, 1])
        XCTAssertTrue(wentGreen)
        XCTAssertEqual(engine.phase, .racing)
        XCTAssertGreaterThan(engine.karts[0].speed, 0)
    }

    func testWellTimedThrottleGrantsARocketStart() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0))
        let step = engine.tuning.fixedTimeStep
        var rocketed = false
        var remaining = engine.tuning.countdownDuration
        for _ in 0..<Int(4.5 / step) {
            // Start pushing 0.45s before the lights, inside the launch window.
            let input = remaining <= 0.45 ? RaceInput.fullThrottle : RaceInput.idle
            engine.advance(deltaTime: step, playerInput: input)
            if case .countdown(let value) = engine.phase { remaining = value }
            for case .rocketStart(let id) in engine.drainEvents() where id == 0 { rocketed = true }
        }
        XCTAssertTrue(rocketed)
    }

    func testPushingTooEarlyBogsTheCartDown() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0))
        advance(engine, seconds: 4.0, input: .fullThrottle)
        XCTAssertEqual(engine.phase, .racing)
        XCTAssertEqual(engine.karts[0].disruption, .cloud)
    }

    func testLapsOnlyCountAfterAFullLap() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0, laps: 3))
        advanceOnAutopilot(engine, seconds: 5.0)
        XCTAssertEqual(engine.karts[0].lapsCompleted, 0, "crossing the line at the start is not a lap")

        var sawLap = false
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(45.0 / step) where !sawLap {
            engine.advance(deltaTime: step, playerInput: autopilot(engine))
            for case .lapCompleted(_, let lap, let time) in engine.drainEvents() {
                XCTAssertEqual(lap, 1)
                XCTAssertGreaterThan(time, 5, "a lap of Produce Plaza cannot be that quick")
                sawLap = true
            }
        }
        XCTAssertTrue(sawLap, "a full-throttle cart should complete a lap within 45s")
        XCTAssertEqual(engine.karts[0].lapTimes.count, 1)
    }

    func testDrivingBackwardsDoesNotBankProgress() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0))
        advanceOnAutopilot(engine, seconds: 6.0)
        let progress = engine.karts[0].totalProgress
        XCTAssertGreaterThan(progress, 0)

        // Spin round and drive back over the line.
        advance(engine, seconds: 4.0, input: RaceInput(throttle: 1, steer: 1))
        advance(engine, seconds: 6.0, input: .fullThrottle)
        XCTAssertEqual(engine.karts[0].lapsCompleted, 0)
        var sawWrongWay = false
        for case .wrongWay(_, let active) in engine.drainEvents() where active { sawWrongWay = true }
        // Either the cart is behind where it was, or it was flagged going the wrong way.
        XCTAssertTrue(sawWrongWay || engine.karts[0].totalProgress < progress + 200)
    }

    func testFullFieldFinishesAndPlacesAreUnique() {
        let engine = RaceEngine(configuration: configuration(racers: 8, laps: 2))
        let results = engine.runToCompletion(maxSimulatedSeconds: 400) { $0.autopilotInput(for: 0) }
        XCTAssertEqual(results.count, 8)
        XCTAssertEqual(Set(results.map(\.place)), Set(1...8))
        XCTAssertEqual(results.map(\.place), Array(1...8), "results should be ordered by place")
        XCTAssertTrue(engine.isComplete)

        for result in results {
            XCTAssertNotNil(result.totalTime)
            XCTAssertGreaterThan(result.totalTime ?? 0, 10)
        }
        // The winner should not be slower than the runner-up.
        let times = results.compactMap(\.totalTime)
        XCTAssertEqual(times, times.sorted())
    }

    func testAIOnlyFieldCompletesEveryLapOnEveryTrack() {
        for track in TrackLibrary.all {
            let engine = RaceEngine(
                configuration: configuration(track: track, racers: 6, playerIndex: nil, laps: 2, seed: 5)
            )
            let results = engine.runToCompletion(maxSimulatedSeconds: 500)
            XCTAssertEqual(results.count, 6, "field stalled on \(track.name)")
            for kart in engine.karts {
                XCTAssertEqual(kart.lapsCompleted, 2, "\(kart.profile.name) did not finish \(track.name)")
                XCTAssertEqual(kart.lapTimes.count, 2)
                for lap in kart.lapTimes {
                    XCTAssertGreaterThan(lap, 5, "implausibly quick lap on \(track.name)")
                    XCTAssertLessThan(lap, 120, "implausibly slow lap on \(track.name)")
                }
            }
        }
    }

    /// A cart wedged against a pallet or grinding along the shelving for the
    /// rest of the race is the worst kind of bug: the race still "works", it is
    /// just no fun. Watch for anyone crawling for an implausibly long time.
    func testNobodyGetsPermanentlyStuck() {
        for track in TrackLibrary.all {
            let engine = RaceEngine(
                configuration: configuration(track: track, racers: 8, playerIndex: nil, laps: 2, seed: 31)
            )
            var crawlingFor: [Int: Double] = [:]
            var worstCrawl: [Int: Double] = [:]
            var rescues = 0
            let step = engine.tuning.fixedTimeStep
            var elapsed = 0.0
            while !engine.isComplete && elapsed < 400 {
                engine.advance(deltaTime: step)
                elapsed += step
                for case .rescued in engine.drainEvents() { rescues += 1 }
                for kart in engine.karts where !kart.isFinished {
                    // Spin-outs and melon hits are meant to stop you; only count
                    // time spent slow while nominally in control.
                    if kart.speed < 80, kart.disruption == nil, engine.phase == .racing {
                        crawlingFor[kart.id, default: 0] += step
                        worstCrawl[kart.id] = max(worstCrawl[kart.id] ?? 0, crawlingFor[kart.id] ?? 0)
                    } else {
                        crawlingFor[kart.id] = 0
                    }
                }
            }
            for kart in engine.karts {
                // Reversing frees most jams; anything worse is caught by the
                // staff rescue after `rescueDelay`.
                XCTAssertLessThan(
                    worstCrawl[kart.id] ?? 0,
                    engine.tuning.rescueDelay + 1.2,
                    "\(kart.profile.name) crawled for ages on \(track.name)"
                )
            }
            // Rescues are a safety net, not a normal part of a lap.
            XCTAssertLessThanOrEqual(rescues, 4, "too many carts needed rescuing on \(track.name)")
        }
    }

    func testStrandedPlayerIsPutBackOnTheLane() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0))
        advance(engine, seconds: 4.0, input: .idle)
        _ = engine.drainEvents()

        // Wedge the cart nose-first into the shelving, the way a bad landing
        // from a spin-out leaves you.
        let track = engine.track
        let sample = track.sample(at: track.sampleIndex(atArcLength: engine.karts[0].arcLength))
        let outwards = sample.tangent.perpendicular
        engine.setKartForTesting(at: 0) { kart in
            kart.position = sample.position + outwards * (sample.halfWidth + track.shoulderWidth - 20)
            kart.heading = outwards.angle
            kart.velocity = .zero
        }

        // Hold the throttle: the cart is pushing into a shelf and going nowhere.
        var rescued = false
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(8.0 / step) {
            engine.advance(deltaTime: step, playerInput: RaceInput(throttle: 1))
            for case .rescued(let id) in engine.drainEvents() where id == 0 { rescued = true }
        }

        XCTAssertTrue(rescued, "a cart pinned against the shelving should be recovered")
        let projection = engine.track.project(engine.karts[0].position)
        XCTAssertLessThan(
            abs(projection.lateralOffset),
            projection.halfWidth,
            "the rescue should leave the cart on driveable floor"
        )
    }

    func testAParkedPlayerIsLeftAlone() {
        let engine = RaceEngine(configuration: configuration(racers: 1, playerIndex: 0))
        advance(engine, seconds: 4.0, input: .idle)
        _ = engine.drainEvents()

        // Sitting still on purpose is not being stuck.
        var rescued = false
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(8.0 / step) {
            engine.advance(deltaTime: step, playerInput: .idle)
            for case .rescued in engine.drainEvents() { rescued = true }
        }
        XCTAssertFalse(rescued)
    }

    func testHarderDifficultyIsActuallyHarder() {
        // A single race is noisy: one soup can decides it. Average a few.
        func averageWinningTime(_ difficulty: RaceConfiguration.Difficulty) -> Double {
            let seeds: [UInt64] = [21, 404, 777, 9001]
            let times = seeds.map { seed -> Double in
                let engine = RaceEngine(
                    configuration: configuration(
                        racers: 6,
                        playerIndex: nil,
                        laps: 2,
                        difficulty: difficulty,
                        seed: seed
                    )
                )
                return engine.runToCompletion(maxSimulatedSeconds: 500).first?.totalTime
                    ?? .greatestFiniteMagnitude
            }
            return times.reduce(0, +) / Double(times.count)
        }
        let hard = averageWinningTime(.blackFriday)
        let easy = averageWinningTime(.trolleyDash)
        XCTAssertLessThan(hard, easy, "Black Friday rivals should beat Trolley Dash rivals round a lap")
        XCTAssertLessThan(averageWinningTime(.weeklyShop), easy)
    }

    func testSameSeedProducesTheSameRace() {
        func run() -> [String] {
            let engine = RaceEngine(configuration: configuration(racers: 6, laps: 2, seed: 1234))
            return engine.runToCompletion(maxSimulatedSeconds: 400, playerInput: { $0.autopilotInput(for: 0) }).map {
                "\($0.place):\($0.profile.id):\(String(format: "%.4f", $0.totalTime ?? 0))"
            }
        }
        XCTAssertEqual(run(), run())
    }

    func testFrameRateDoesNotChangeTheOutcome() {
        func run(frameTime: Double) -> Double {
            let engine = RaceEngine(configuration: configuration(racers: 4, playerIndex: nil, laps: 1, seed: 77))
            var simulated = 0.0
            while !engine.isComplete && simulated < 300 {
                engine.advance(deltaTime: frameTime)
                simulated += frameTime
                _ = engine.drainEvents()
            }
            return engine.results.first?.totalTime ?? 0
        }
        // 120Hz and 30Hz callers both consume the same fixed steps.
        XCTAssertEqual(run(frameTime: 1.0 / 120), run(frameTime: 1.0 / 30), accuracy: 0.02)
    }

    func testItemBoxesGrantItemsAndRespawn() {
        let engine = RaceEngine(configuration: configuration(racers: 4, laps: 3))
        var granted = 0
        var smashedBox: Int?
        var refilled = false
        let step = engine.tuning.fixedTimeStep
        for _ in 0..<Int(30.0 / step) {
            engine.advance(deltaTime: step, playerInput: autopilot(engine))
            for case .itemGranted in engine.drainEvents() { granted += 1 }
            if let id = smashedBox {
                if engine.itemBoxes.first(where: { $0.id == id })?.isAvailable == true { refilled = true }
            } else {
                smashedBox = engine.itemBoxes.first { !$0.isAvailable }?.id
            }
        }
        XCTAssertGreaterThan(granted, 0, "nobody picked up an item in 30 seconds of racing")
        XCTAssertNotNil(smashedBox, "smashed boxes should go on a respawn timer")
        XCTAssertTrue(refilled, "a smashed box should come back after its respawn timer")
    }

    func testTimeTrialHasNoItemBoxPickups() {
        var config = configuration(racers: 1, playerIndex: 0, laps: 1)
        config.mode = .timeTrial
        let engine = RaceEngine(configuration: config)
        engine.runToCompletion(maxSimulatedSeconds: 200) { $0.autopilotInput(for: 0) }
        XCTAssertTrue(engine.karts.allSatisfy { $0.item == nil && $0.pendingItem == nil })
    }

    func testRaceWrapsUpShortlyAfterThePlayerFinishes() {
        let engine = RaceEngine(configuration: configuration(racers: 8, laps: 1))
        engine.autoCompleteDelayAfterPlayer = 2
        let results = engine.runToCompletion(maxSimulatedSeconds: 300) { $0.autopilotInput(for: 0) }
        XCTAssertEqual(results.count, 8)
        guard let player = engine.playerKart, let playerTime = player.finishTime else {
            return XCTFail("the player never finished")
        }
        // Everyone is classified within the grace period of the player.
        for kart in engine.karts {
            XCTAssertNotNil(kart.finishTime)
            XCTAssertLessThanOrEqual((kart.finishTime ?? 0), playerTime + 2.5)
        }
    }
}
