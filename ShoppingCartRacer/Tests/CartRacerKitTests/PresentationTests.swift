import XCTest
@testable import CartRacerKit

final class PresentationTests: XCTestCase {
    // MARK: - Art plans

    func testTrackArtPlanCoversTheCourseAndKeepsSceneryOffTheRoad() {
        for definition in TrackLibrary.all {
            let track = Track(definition: definition)
            let plan = TrackArtPlan(track: track)

            XCTAssertEqual(plan.slices.count, definition.nodes.count)
            XCTAssertFalse(plan.props.isEmpty, "\(definition.id) has no scenery")
            XCTAssertFalse(plan.lights.isEmpty, "\(definition.id) has no lighting")

            // The ribbon has to be the right width everywhere.
            for slice in plan.slices {
                let width = slice.left.distance(to: slice.right)
                let expected = track.geometry.halfWidth(at: slice.distance) * 2
                XCTAssertEqual(width, expected, accuracy: 0.3)
                XCTAssertGreaterThan(slice.shoulderLeft.distance(to: slice.shoulderRight), width)
            }

            // No prop may sit on the racing surface or the run-off, on any part of
            // the lap — courses double back on themselves.
            for prop in plan.props {
                let location = track.geometry.location(of: prop.position)
                let clearance = abs(location.lateral) - location.halfWidth - definition.shoulderWidth
                XCTAssertGreaterThan(clearance, 0, "\(prop.kind) blocks the road on \(definition.id)")
            }

            // Lights run down the middle of the aisle.
            for light in plan.lights {
                let location = track.geometry.location(of: light.position)
                XCTAssertLessThan(abs(location.lateral), 1.0)
            }

            XCTAssertLessThan(plan.bounds.min.x, plan.bounds.max.x)
            XCTAssertLessThan(plan.bounds.min.y, plan.bounds.max.y)
        }
    }

    func testSurfaceRunsCoverTheWholeLapWithNoGaps() {
        for definition in TrackLibrary.all {
            let plan = TrackArtPlan(track: Track(definition: definition))
            let runs = plan.surfaceRuns
            let count = plan.slices.count
            XCTAssertGreaterThan(runs.count, 1, "\(definition.id) should have several floor types")

            // The renderer fills a quad between each consecutive pair of slices.
            // Every quad on the lap has to be covered by some run, including the
            // one straddling the start line, or there is a visible sliver of bare
            // floor across the track.
            var covered: Set<Int> = []
            for run in runs {
                XCTAssertFalse(run.indices.isEmpty)
                for (first, second) in zip(run.indices, run.indices.dropFirst()) {
                    XCTAssertEqual(second, (first + 1) % count, "run indices are not consecutive")
                    covered.insert(first)
                }
                // Each run must be one floor type all the way through.
                for index in run.indices.dropLast() {
                    XCTAssertEqual(plan.slices[index].surface, run.surface)
                }
            }
            XCTAssertEqual(covered.count, count, "\(definition.id) has a gap in the floor")

            // And the runs should follow the floor types in order.
            XCTAssertEqual(runs.first?.surface, plan.slices[0].surface)
        }
    }

    func testTrackArtPlanIsDeterministic() {
        let track = Track(definition: TrackLibrary.all[0])
        let first = TrackArtPlan(track: track)
        let second = TrackArtPlan(track: track)
        XCTAssertEqual(first.props.count, second.props.count)
        for (a, b) in zip(first.props, second.props) {
            XCTAssertEqual(a.kind, b.kind)
            XCTAssertEqual(a.position.x, b.position.x, accuracy: 1e-12)
            XCTAssertEqual(a.position.y, b.position.y, accuracy: 1e-12)
        }
        // A different seed should dress the shop differently.
        let alternate = TrackArtPlan(track: track, seed: 0xDEAD)
        XCTAssertNotEqual(alternate.props.first?.position.x, first.props.first?.position.x)
    }

    func testCartArtPlanFitsTheCollisionRadiusAndIsStable() {
        for racer in RacerRoster.all {
            let plan = CartArtPlan(racer: racer)
            let tuning = CartTuning(racer: racer)

            XCTAssertGreaterThan(plan.length, 0.8)
            XCTAssertGreaterThan(plan.width, 0.5)
            XCTAssertEqual(plan.wheels.count, 4)
            XCTAssertFalse(plan.cargo.isEmpty, "\(racer.id) has an empty basket")

            // The drawing should be in the same ballpark as the body used by the
            // physics, or carts will look like they collide with thin air.
            XCTAssertLessThan(plan.length, tuning.radius * 4)
            XCTAssertGreaterThan(plan.length, tuning.radius)

            // Cargo stays inside the basket.
            for piece in plan.cargo {
                XCTAssertLessThan(abs(piece.offset.y), plan.width * 0.5)
                XCTAssertLessThan(abs(piece.offset.x), plan.length * 0.5)
            }

            // Same racer, same basket, every time.
            let again = CartArtPlan(racer: racer)
            XCTAssertEqual(plan.cargo.count, again.cargo.count)
            XCTAssertEqual(plan.cargo.first?.offset.x, again.cargo.first?.offset.x)
        }

        // Different characters should not all look identical.
        let squeak = CartArtPlan(racer: RacerRoster.racer(id: "squeak")!)
        let todd = CartArtPlan(racer: RacerRoster.racer(id: "todd")!)
        XCTAssertNotEqual(squeak.length, todd.length)
        XCTAssertNotEqual(squeak.cargo.count, todd.cargo.count)
    }

    // MARK: - Minimap

    func testMinimapFitsInsideTheUnitSquareAndKeepsAspectRatio() {
        for definition in TrackLibrary.all {
            let track = Track(definition: definition)
            let map = MinimapModel(track: track)
            XCTAssertGreaterThan(map.outline.count, 20)

            for point in map.outline {
                XCTAssertGreaterThanOrEqual(point.x, -1e-9)
                XCTAssertLessThanOrEqual(point.x, 1 + 1e-9)
                XCTAssertGreaterThanOrEqual(point.y, -1e-9)
                XCTAssertLessThanOrEqual(point.y, 1 + 1e-9)
            }

            // Aspect ratio preserved: a square metre stays a square on the map.
            let world = track.geometry.bounds
            let horizontal = map.project(Vector2(world.max.x, world.min.y)).x - map.project(world.min).x
            let vertical = map.project(Vector2(world.min.x, world.max.y)).y - map.project(world.min).y
            let worldRatio = (world.max.x - world.min.x) / (world.max.y - world.min.y)
            XCTAssertEqual(horizontal / vertical, worldRatio, accuracy: 0.01)

            // The whole course must fit, using the full width or the full height.
            let xs = map.outline.map(\.x)
            let ys = map.outline.map(\.y)
            let widest = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!)
            XCTAssertEqual(widest, 1 - map.padding * 2, accuracy: 0.02)
        }
    }

    func testMinimapBlipsPutThePlayerOnTop() {
        guard let configuration = RaceConfiguration.standard(
            trackID: "aisle-seven",
            playerRacerID: "marge"
        ) else { return XCTFail("no configuration") }
        let simulation = RaceSimulation(configuration: configuration)
        let map = MinimapModel(track: configuration.track)
        let blips = map.blips(carts: simulation.carts)
        XCTAssertEqual(blips.count, simulation.carts.count)
        XCTAssertTrue(blips.last?.isPlayer ?? false, "the player's blip should draw last")
    }

    // MARK: - HUD

    func testHUDModelReportsTheRaceState() {
        guard let configuration = RaceConfiguration.standard(
            trackID: "frozen-foods",
            playerRacerID: "marge",
            difficulty: .busy
        ) else { return XCTFail("no configuration") }
        let simulation = RaceSimulation(configuration: configuration)

        guard let counting = HUDModel(simulation: simulation) else { return XCTFail("no HUD") }
        XCTAssertEqual(counting.countdown, .number(3))
        XCTAssertEqual(counting.lapText, "LAP 1/3")
        XCTAssertEqual(counting.fieldSize, 5)
        XCTAssertEqual(counting.speedKph, 0)
        XCTAssertNil(counting.heldItem)

        simulation.installAutopilot()
        for _ in 0..<3000 { simulation.step(simulation.tuning.fixedTimeStep) }

        guard let racing = HUDModel(simulation: simulation) else { return XCTFail("no HUD") }
        XCTAssertEqual(racing.countdown, .hidden)
        XCTAssertGreaterThan(racing.speedKph, 10)
        XCTAssertTrue((0...1).contains(racing.speedFraction))
        XCTAssertTrue((0...1).contains(racing.lapProgress))
        XCTAssertTrue((1...5).contains(racing.position))
        XCTAssertEqual(racing.positionText, HUDModel.ordinal(racing.position))
        if racing.position == 1 {
            XCTAssertNil(racing.gapAheadText)
        } else {
            XCTAssertNotNil(racing.gapAheadText)
        }
    }

    func testOrdinals() {
        XCTAssertEqual(HUDModel.ordinal(1), "1st")
        XCTAssertEqual(HUDModel.ordinal(2), "2nd")
        XCTAssertEqual(HUDModel.ordinal(3), "3rd")
        XCTAssertEqual(HUDModel.ordinal(4), "4th")
        XCTAssertEqual(HUDModel.ordinal(11), "11th")
        XCTAssertEqual(HUDModel.ordinal(12), "12th")
        XCTAssertEqual(HUDModel.ordinal(13), "13th")
        XCTAssertEqual(HUDModel.ordinal(21), "21st")
    }

    func testStandingsRowsCoverTheFieldAndShowGaps() {
        guard let configuration = RaceConfiguration.standard(
            trackID: "aisle-seven",
            playerRacerID: "kev"
        ) else { return XCTFail("no configuration") }
        let simulation = RaceSimulation(configuration: configuration)
        simulation.installAutopilot()
        for _ in 0..<2000 { simulation.step(simulation.tuning.fixedTimeStep) }

        let live = StandingsRow.rows(simulation: simulation)
        XCTAssertEqual(live.count, 5)
        XCTAssertEqual(live.map(\.position), Array(1...5))
        XCTAssertEqual(live.first?.detail, "LEADER")
        XCTAssertEqual(live.filter(\.isPlayer).count, 1)

        let report = RaceHarness.run(configuration: configuration)
        let final = StandingsRow.rows(result: report.result)
        XCTAssertEqual(final.count, 5)
        XCTAssertEqual(final.map(\.position), Array(1...5))
        XCTAssertTrue(final.dropFirst().allSatisfy { $0.detail.hasPrefix("+") }, "gaps to the winner missing")
    }

    // MARK: - Controls

    func testSteeringFilterIgnoresATrembleAndReachesFullLock() {
        var filter = SteeringFilter()
        let settings = ControlSettings()

        // Inside the dead zone: nothing at all.
        for _ in 0..<20 {
            XCTAssertEqual(filter.update(raw: 0.04, settings: settings, delta: 1.0 / 60), 0, accuracy: 1e-12)
        }

        // Held at full lock, it gets all the way there.
        var value = 0.0
        for _ in 0..<120 {
            value = filter.update(raw: 1, settings: settings, delta: 1.0 / 60)
        }
        XCTAssertEqual(value, 1, accuracy: 1e-6)

        // And back to centre when released.
        for _ in 0..<120 {
            value = filter.update(raw: 0, settings: settings, delta: 1.0 / 60)
        }
        XCTAssertEqual(value, 0, accuracy: 1e-6)
    }

    func testSteeringFilterRateLimitsSuddenFlicks() {
        var filter = SteeringFilter()
        let step = filter.update(raw: -1, settings: ControlSettings(), delta: 1.0 / 60)
        XCTAssertLessThan(abs(step), 0.2, "steering snapped to full lock in a single frame")
        XCTAssertLessThan(step, 0)
    }

    func testSteeringCurveGivesFinerControlNearTheCentre() {
        var filter = SteeringFilter()
        let settings = ControlSettings()
        // With expo, a half-deflection should map to well under half lock.
        var value = 0.0
        for _ in 0..<200 {
            value = filter.update(raw: 0.5, settings: settings, delta: 1.0 / 60)
        }
        XCTAssertLessThan(value, 0.45)
        XCTAssertGreaterThan(value, 0.1)
    }

    func testSensitivitySettingScalesSteering() {
        func settled(sensitivity: Double) -> Double {
            var filter = SteeringFilter()
            var settings = ControlSettings()
            settings.sensitivity = sensitivity
            var value = 0.0
            for _ in 0..<200 {
                value = filter.update(raw: 0.5, settings: settings, delta: 1.0 / 60)
            }
            return value
        }
        XCTAssertGreaterThan(settled(sensitivity: 1.5), settled(sensitivity: 0.6))
    }

    func testControlMapperMapsButtonsToDriverInput() {
        var mapper = ControlMapper()
        var settings = ControlSettings()
        settings.autoAccelerate = false

        let idle = mapper.input(from: RawControlState(), settings: settings, delta: 1.0 / 60)
        XCTAssertEqual(idle.throttle, 0)
        XCTAssertFalse(idle.drift)

        let driving = mapper.input(
            from: RawControlState(accelerating: true, drifting: true, firingItem: true),
            settings: settings,
            delta: 1.0 / 60
        )
        XCTAssertEqual(driving.throttle, 1)
        XCTAssertTrue(driving.drift)
        XCTAssertTrue(driving.useItem)

        let braking = mapper.input(
            from: RawControlState(accelerating: true, braking: true),
            settings: settings,
            delta: 1.0 / 60
        )
        XCTAssertEqual(braking.throttle, -1, "braking must win over the throttle")

        settings.autoAccelerate = true
        let automatic = mapper.input(from: RawControlState(), settings: settings, delta: 1.0 / 60)
        XCTAssertEqual(automatic.throttle, 1)
    }

    // MARK: - Starting a race through the real control path

    /// Runs a race from the countdown, driving the player's cart through
    /// `ControlMapper` exactly as the scene does.
    private func runStart(
        settings: ControlSettings,
        controls: @escaping (RacePhase) -> RawControlState,
        seconds: Double = 4.5
    ) -> (events: [RaceEvent], cart: CartState) {
        guard let configuration = RaceConfiguration.standard(
            trackID: "aisle-seven",
            playerRacerID: "marge",
            difficulty: .busy
        ) else {
            fatalError("could not build a race")
        }
        let simulation = RaceSimulation(configuration: configuration)
        var mapper = ControlMapper()
        var events: [RaceEvent] = []
        let step = simulation.tuning.fixedTimeStep
        var elapsed = 0.0

        while elapsed < seconds {
            let phase = simulation.phase
            let input = mapper.input(
                from: controls(phase),
                settings: settings,
                delta: step,
                isCountingDown: phase.isCountingDown
            )
            simulation.setPlayerInput(input)
            simulation.step(step)
            events += simulation.drainEvents()
            elapsed += step
        }
        return (events, simulation.playerCart!)
    }

    func testAutoThrottleDoesNotFloodTheEngineOnTheGrid() {
        // The assist holds the throttle down. If that applied during the
        // countdown the player would flood the engine before every single race.
        var settings = ControlSettings()
        settings.autoAccelerate = true

        let outcome = runStart(settings: settings) { _ in RawControlState() }

        XCTAssertFalse(
            outcome.events.contains { if case .floodedEngine = $0 { return true } else { return false } },
            "the automatic throttle flooded the engine on the grid"
        )
        XCTAssertEqual(outcome.cart.stallTimer, 0)
        // And the assist still gets the cart away once the lights change.
        XCTAssertGreaterThan(outcome.cart.forwardSpeed, 4)
    }

    func testRevvingOnTheDriftButtonEarnsARocketStartWithTheAssistOn() {
        var settings = ControlSettings()
        settings.autoAccelerate = true

        let outcome = runStart(settings: settings) { phase in
            // Feather it as the last light goes out.
            if case .countdown(let remaining) = phase, remaining < 0.4 {
                return RawControlState(drifting: true)
            }
            return RawControlState()
        }

        XCTAssertTrue(
            outcome.events.contains(.rocketStart(cartID: 0)),
            "revving on the grid did not earn a rocket start"
        )
    }

    func testHoldingTheRevTooLongStillFloodsTheEngine() {
        var settings = ControlSettings()
        settings.autoAccelerate = true

        let outcome = runStart(settings: settings) { phase in
            phase.isCountingDown ? RawControlState(drifting: true) : RawControlState()
        }

        XCTAssertTrue(
            outcome.events.contains { if case .floodedEngine = $0 { return true } else { return false } },
            "revving from the first light should flood the engine"
        )
    }

    func testManualThrottleStillControlsTheStart() {
        var settings = ControlSettings()
        settings.autoAccelerate = false

        let idle = runStart(settings: settings) { _ in RawControlState() }
        XCTAssertFalse(idle.events.contains(.rocketStart(cartID: 0)))
        XCTAssertLessThan(idle.cart.forwardSpeed, 1, "the cart moved with no throttle")

        let launched = runStart(settings: settings) { phase in
            if case .countdown(let remaining) = phase {
                return RawControlState(accelerating: remaining < 0.4)
            }
            return RawControlState(accelerating: true)
        }
        XCTAssertTrue(launched.events.contains(.rocketStart(cartID: 0)))
        XCTAssertGreaterThan(launched.cart.forwardSpeed, 4)
    }

    func testRocketStartHintMatchesTheControlScheme() {
        var settings = ControlSettings()
        settings.autoAccelerate = true
        XCTAssertTrue(ControlMapper.rocketStartHint(settings: settings).contains("DRIFT"))
        settings.autoAccelerate = false
        XCTAssertTrue(ControlMapper.rocketStartHint(settings: settings).contains("GAS"))
    }

    func testTiltSteeringDirectionAndCalibration() {
        var settings = ControlSettings()
        // Turning the device one way steers one way, and symmetrically.
        XCTAssertLessThan(ControlMapper.tiltSteer(angle: 0.5, settings: settings), 0)
        XCTAssertGreaterThan(ControlMapper.tiltSteer(angle: -0.5, settings: settings), 0)
        XCTAssertEqual(ControlMapper.tiltSteer(angle: 0, settings: settings), 0)
        XCTAssertEqual(abs(ControlMapper.tiltSteer(angle: 0.9, settings: settings)), 1, accuracy: 1e-12)

        // However the player is holding the device can be calibrated as centred.
        settings.tiltNeutral = 1.2
        XCTAssertEqual(ControlMapper.tiltSteer(angle: 1.2, settings: settings), 0, accuracy: 1e-12)
        XCTAssertLessThan(ControlMapper.tiltSteer(angle: 1.5, settings: settings), 0)

        // A neutral near the wrap point must not invert the steering.
        settings.tiltNeutral = .pi - 0.05
        XCTAssertLessThan(ControlMapper.tiltSteer(angle: -.pi + 0.05, settings: settings), 0)
        XCTAssertGreaterThan(ControlMapper.tiltSteer(angle: .pi - 0.3, settings: settings), 0)
    }

    // MARK: - Records and progression

    func testRecordBookTracksPersonalBests() {
        var book = RecordBook()
        XCTAssertNil(book.record(for: "aisle-seven"))

        let first = makeResult(trackID: "aisle-seven", position: 4, total: 130, best: 40)
        var achievements = book.submit(result: first)
        XCTAssertTrue(achievements.contains(.firstTimeOnTrack))
        XCTAssertTrue(achievements.contains(.bestLap(40)))
        XCTAssertTrue(achievements.contains(.bestFinish(4)))
        XCTAssertEqual(book.records["aisle-seven"]?.timesRaced, 1)
        XCTAssertEqual(book.racesFinished, 1)

        // A slower race sets no records.
        achievements = book.submit(result: makeResult(trackID: "aisle-seven", position: 5, total: 140, best: 44))
        XCTAssertTrue(achievements.isEmpty)
        XCTAssertEqual(book.records["aisle-seven"]?.bestLapTime, 40)
        XCTAssertEqual(book.records["aisle-seven"]?.bestPosition, 4)
        XCTAssertEqual(book.records["aisle-seven"]?.timesRaced, 2)

        // A quicker one does.
        achievements = book.submit(result: makeResult(trackID: "aisle-seven", position: 1, total: 120, best: 36))
        XCTAssertTrue(achievements.contains(.bestLap(36)))
        XCTAssertTrue(achievements.contains(.bestRace(120)))
        XCTAssertTrue(achievements.contains(.bestFinish(1)))
    }

    func testCoursesUnlockByFinishingOnThePodium() {
        var book = RecordBook()
        let order = TrackLibrary.cupOrder
        XCTAssertTrue(book.isUnlocked(trackID: order[0]))
        XCTAssertFalse(book.isUnlocked(trackID: order[1]))
        XCTAssertEqual(book.unlockedTrackIDs(), [order[0]])

        // Fourth place is not enough.
        book.submit(result: makeResult(trackID: order[0], position: 4, total: 130, best: 40))
        XCTAssertFalse(book.isUnlocked(trackID: order[1]))

        // A podium opens the next course, and reports it.
        let achievements = book.submit(result: makeResult(trackID: order[0], position: 3, total: 128, best: 39))
        XCTAssertTrue(achievements.contains(.trackUnlocked(order[1])))
        XCTAssertTrue(book.isUnlocked(trackID: order[1]))
        XCTAssertFalse(book.isUnlocked(trackID: order[2]))
    }

    func testRecordKeeperPersistsAcrossSessions() {
        let storage = InMemoryRecordStorage()
        let keeper = RecordKeeper(storage: storage)
        keeper.submit(result: makeResult(trackID: "aisle-seven", position: 2, total: 125, best: 38))
        keeper.recordCupWin()

        let reopened = RecordKeeper(storage: storage)
        XCTAssertEqual(reopened.book.records["aisle-seven"]?.bestLapTime, 38)
        XCTAssertEqual(reopened.book.cupWins, 1)
        XCTAssertEqual(reopened.book.racesFinished, 1)

        reopened.reset()
        XCTAssertTrue(RecordKeeper(storage: storage).book.records.isEmpty)
    }

    func testCorruptSaveDataStartsAFreshBook() {
        let storage = InMemoryRecordStorage(data: Data("not json".utf8))
        XCTAssertTrue(RecordKeeper(storage: storage).book.records.isEmpty)
    }

    // MARK: - Session flow

    func testSingleRaceFlow() {
        var session = GameSession()
        XCTAssertEqual(session.route, .mainMenu)

        session.beginSingleRace()
        XCTAssertEqual(session.route, .characterSelect)
        XCTAssertEqual(session.mode, .singleRace)

        session.selectedRacerID = "kev"
        session.confirmRacer()
        XCTAssertEqual(session.route, .trackSelect)

        session.startRace()
        XCTAssertEqual(session.route, .race)
        XCTAssertEqual(session.raceGeneration, 1)

        guard let configuration = session.makeRaceConfiguration() else { return XCTFail("no configuration") }
        XCTAssertEqual(configuration.track.id, session.selectedTrackID)
        XCTAssertTrue(configuration.entries.contains { $0.isPlayer && $0.racer.id == "kev" })
        XCTAssertEqual(configuration.entries.count, 5)

        session.finishRace(result: makeResult(trackID: session.selectedTrackID, position: 1, total: 120, best: 37))
        XCTAssertEqual(session.route, .results)
        XCTAssertEqual(session.resultsContinuation, .backToMenu)
        XCTAssertNotNil(session.lastResult)

        session.continueFromResults()
        XCTAssertEqual(session.route, .mainMenu)
    }

    func testEachRaceGetsAFreshSeed() {
        var session = GameSession()
        session.startRace()
        let first = session.makeRaceConfiguration()?.seed
        session.startRace()
        let second = session.makeRaceConfiguration()?.seed
        XCTAssertNotNil(first)
        XCTAssertNotEqual(first, second, "two races in a row played out identically")
    }

    func testGrandPrixFlowRunsThreeRoundsThenReturnsToTheMenu() {
        var session = GameSession()
        session.selectedRacerID = "marge"
        session.beginGrandPrix()
        XCTAssertEqual(session.mode, .grandPrix)

        // Confirming the character goes straight into round one.
        session.confirmRacer()
        XCTAssertEqual(session.route, .race)
        XCTAssertEqual(session.selectedTrackID, TrackLibrary.cupOrder[0])

        for round in 0..<3 {
            XCTAssertEqual(session.selectedTrackID, TrackLibrary.cupOrder[round])
            session.finishRace(result: makeResult(trackID: session.selectedTrackID, position: 1, total: 120, best: 37))
            XCTAssertEqual(session.route, .results)

            if round < 2 {
                XCTAssertEqual(
                    session.resultsContinuation,
                    .nextRound(trackID: TrackLibrary.cupOrder[round + 1])
                )
            } else {
                XCTAssertEqual(session.resultsContinuation, .cupFinished)
            }

            session.continueFromResults()
            XCTAssertEqual(session.route, .cupStandings)
            XCTAssertNotNil(session.cupSummary)
            session.continueFromStandings()
        }

        XCTAssertEqual(session.route, .mainMenu)
        XCTAssertEqual(session.book.cupWins, 1)
        XCTAssertTrue(session.lastAchievements.contains(.cupWon))
    }

    func testWinningTheCupIsOnlyRecordedWhenTheCupIsWon() {
        var session = GameSession()
        session.beginGrandPrix()
        session.confirmRacer()
        for _ in 0..<3 {
            session.finishRace(result: makeResult(trackID: session.selectedTrackID, position: 5, total: 190, best: 55))
            session.continueFromResults()
            session.continueFromStandings()
        }
        XCTAssertEqual(session.book.cupWins, 0)
    }

    func testSessionStartsOnAnUnlockedCourseAndRemembersTheLastRacer() {
        var book = RecordBook()
        book.submit(result: makeResult(trackID: TrackLibrary.cupOrder[0], position: 1, total: 120, best: 37))
        let session = GameSession(book: book)
        XCTAssertEqual(session.selectedRacerID, "marge")
        XCTAssertTrue(session.isUnlocked(trackID: session.selectedTrackID))
        XCTAssertEqual(session.unlockedTrackIDs.count, 2)
    }

    // MARK: - Helpers

    private func makeResult(trackID: String, position: Int, total: Double, best: Double) -> RaceResult {
        var standings: [RaceResult.Standing] = []
        let names = RacerRoster.all
        for index in 0..<5 {
            let racer = names[index % names.count]
            let isPlayer = index == position - 1
            standings.append(
                RaceResult.Standing(
                    cartID: index,
                    racerID: isPlayer ? "marge" : racer.id,
                    racerName: isPlayer ? "Marge" : racer.name,
                    isPlayer: isPlayer,
                    position: index + 1,
                    totalTime: total + Double(index),
                    bestLapTime: isPlayer ? best : best + 1,
                    lapTimes: [best, best + 1, best + 2],
                    tokens: 4
                )
            )
        }
        return RaceResult(
            trackID: trackID,
            trackName: TrackLibrary.definition(id: trackID)?.name ?? trackID,
            laps: 3,
            difficulty: .busy,
            standings: standings
        )
    }
}
