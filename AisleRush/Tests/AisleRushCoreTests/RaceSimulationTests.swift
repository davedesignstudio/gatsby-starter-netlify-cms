import XCTest
@testable import AisleRushCore

/// Shared helpers for driving whole races headlessly.
enum RaceHarness {
    static let dt = 1.0 / 120.0

    static func field(size: Int, playerAt: Int? = nil) -> [Entrant] {
        (0..<size).map { index in
            let character = Roster.characters[index % Roster.characters.count]
            let frame = Roster.frames[index % Roster.frames.count]
            let wheels = Roster.wheels[(index / 2) % Roster.wheels.count]
            return Entrant(
                setup: CartSetup(character: character, frame: frame, wheels: wheels),
                isPlayer: index == playerAt
            )
        }
    }

    static func makeRace(
        trackID: String = "produce-loop",
        laps: Int = 3,
        fieldSize: Int = 8,
        difficulty: Int = 1,
        playerAt: Int? = nil,
        seed: UInt64 = 0xA15E,
        items: Bool = true
    ) -> RaceSimulation {
        let track = Tracks.track(id: trackID)
        let config = RaceConfig(
            laps: laps,
            fieldSize: fieldSize,
            difficulty: difficulty,
            mode: .singleRace,
            seed: seed,
            itemsEnabled: items
        )
        return RaceSimulation(track: track, config: config, entrants: field(size: fieldSize, playerAt: playerAt))
    }

    /// A simple pursuit controller, so tests can drive the player's cart
    /// through the input path the app uses.
    static func follow(_ cart: Cart, on track: Track, useItem: Bool = false) -> ControlInput {
        let target = track.racingLinePoint(atDistance: cart.lapDistance + 12)
        let error = Angle.delta(from: cart.heading, to: (target - cart.position).angle)
        return ControlInput(steer: clamp(error / 0.5, -1, 1), throttle: 1, useItem: useItem)
    }

    /// Runs until the race completes or the clock runs out.
    @discardableResult
    static func run(_ race: RaceSimulation, maxSeconds: Double = 400) -> [RaceEvent] {
        var collected: [RaceEvent] = []
        var elapsed = 0.0
        while !race.isComplete, elapsed < maxSeconds {
            race.update(dt: dt)
            collected.append(contentsOf: race.drainEvents())
            elapsed += dt
        }
        return collected
    }
}

final class RaceSimulationTests: XCTestCase {
    func testCountdownBeepsThenReleasesTheField() {
        let race = RaceHarness.makeRace()
        var beeps: [Int] = []
        var started = false
        var elapsed = 0.0
        while elapsed < 5 {
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .countdownBeep(let n) = event { beeps.append(n) }
                if case .go = event { started = true }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertEqual(beeps, [3, 2, 1])
        XCTAssertTrue(started)
        XCTAssertTrue(race.phase.isRacing)
    }

    func testNobodyMovesBeforeTheLightsGoOut() {
        let race = RaceHarness.makeRace()
        let start = race.carts.map(\.position)
        for _ in 0..<120 { race.update(dt: RaceHarness.dt) }
        for (index, cart) in race.carts.enumerated() {
            XCTAssertEqual(cart.position.distance(to: start[index]), 0, accuracy: 1e-9)
        }
    }

    func testHoldingTheThrottleIntoTheLightsEarnsARocketStart() {
        let race = RaceHarness.makeRace(playerAt: 0)
        var elapsed = 0.0
        var rocketed = false
        while elapsed < 5 {
            // Start feathering the throttle a second before the lights change.
            let remaining: Double
            if case .countdown(let value) = race.phase { remaining = value } else { remaining = 0 }
            race.setInput(ControlInput(throttle: remaining < 1.0 ? 1 : 0), forCart: 0)
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .rocketStart(let cartID) = event, cartID == 0 { rocketed = true }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertTrue(rocketed)
        XCTAssertGreaterThan(race.carts[0].speed, 5)
    }

    func testJumpingTheStartFloodsTheEngine() {
        let race = RaceHarness.makeRace(playerAt: 0)
        var burned = false
        var elapsed = 0.0
        while elapsed < 5 {
            race.setInput(ControlInput(throttle: 1), forCart: 0)
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .burnout(let cartID) = event, cartID == 0 { burned = true }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertTrue(burned)
    }

    func testEveryCourseCanBeRacedToTheFlagByTheAI() {
        for definition in Tracks.all {
            let race = RaceHarness.makeRace(trackID: definition.id, laps: 3, fieldSize: 8)
            RaceHarness.run(race, maxSeconds: 400)

            XCTAssertTrue(race.isComplete, "\(definition.name) never finished")
            for cart in race.carts {
                XCTAssertNotNil(cart.finishTime, "\(cart.setup.character.name) is still lost in \(definition.name)")
                XCTAssertEqual(cart.lapTimes.count, 3, "\(cart.setup.character.name) miscounted laps")
                for lap in cart.lapTimes {
                    XCTAssertGreaterThan(lap, 8, "a \(definition.name) lap in \(lap)s means the lap counter is wrong")
                    XCTAssertLessThan(lap, 120, "a \(definition.name) lap took \(lap)s")
                }
            }

            let places = race.results.map(\.place)
            XCTAssertEqual(places, Array(1...8))
            let winner = race.results[0]
            XCTAssertNotNil(winner.totalTime)
        }
    }

    func testFinishingOrderMatchesElapsedTime() {
        let race = RaceHarness.makeRace(fieldSize: 8)
        RaceHarness.run(race)
        let times = race.results.compactMap(\.totalTime)
        XCTAssertEqual(times.count, 8)
        XCTAssertEqual(times, times.sorted())
    }

    func testTheFieldStaysCloseEnoughToBeARace() {
        let race = RaceHarness.makeRace(fieldSize: 8, seed: 991)
        RaceHarness.run(race)
        let times = race.results.compactMap(\.totalTime)
        let spread = times.last! - times.first!
        XCTAssertLessThan(spread, 60, "the field spread out by \(spread)s")
        XCTAssertGreaterThan(spread, 0.05, "every cart finished at once, which means nobody is racing")
    }

    func testTheSameSeedProducesTheSameRace() {
        let first = RaceHarness.makeRace(seed: 4242)
        let second = RaceHarness.makeRace(seed: 4242)
        RaceHarness.run(first)
        RaceHarness.run(second)

        XCTAssertEqual(first.results.map(\.cartID), second.results.map(\.cartID))
        for (a, b) in zip(first.results, second.results) {
            XCTAssertEqual(a.totalTime ?? -1, b.totalTime ?? -2, accuracy: 1e-9)
        }
    }

    func testDifferentSeedsProduceDifferentRaces() {
        let first = RaceHarness.makeRace(seed: 1)
        let second = RaceHarness.makeRace(seed: 2)
        RaceHarness.run(first)
        RaceHarness.run(second)
        let a = first.results.compactMap(\.totalTime)
        let b = second.results.compactMap(\.totalTime)
        XCTAssertNotEqual(a, b)
    }

    func testHarderDifficultiesProduceQuickerWinners() {
        func winningTime(difficulty: Int) -> Double {
            let race = RaceHarness.makeRace(difficulty: difficulty, seed: 77, items: false)
            RaceHarness.run(race)
            return race.results[0].totalTime ?? .infinity
        }
        let easy = winningTime(difficulty: 0)
        let hard = winningTime(difficulty: 2)
        XCTAssertLessThan(hard, easy, "Closing Time should be faster than Sunday Shopper")
    }

    func testCartsStayInsideTheShelvingForAWholeRace() {
        for definition in Tracks.all {
            let track = Tracks.track(id: definition.id)
            let race = RaceSimulation(
                track: track,
                config: RaceConfig(laps: 2, seed: 5150),
                entrants: RaceHarness.field(size: 8)
            )
            var elapsed = 0.0
            var worst = 0.0
            while !race.isComplete, elapsed < 300 {
                race.update(dt: RaceHarness.dt)
                _ = race.drainEvents()
                for cart in race.carts {
                    let projection = track.project(cart.position, hint: cart.projectionHint)
                    let allowance = track.wallDistance(atDistance: projection.distance) + cart.collisionRadius
                    worst = max(worst, abs(projection.lateral) - allowance)
                }
                elapsed += RaceHarness.dt
            }
            XCTAssertLessThan(worst, 0.6, "a cart clipped \(worst)m into the shelves on \(definition.name)")
        }
    }

    func testWrongWayIsReportedAndCleared() {
        let race = RaceHarness.makeRace(playerAt: 0, items: false)
        var elapsed = 0.0
        var flagged = false
        var cleared = false
        while elapsed < 20 {
            // Reverse away from the line, then turn around.
            let throttle: Double = elapsed < 12 ? -1 : 1
            race.setInput(ControlInput(throttle: throttle), forCart: 0)
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .wrongWay(let cartID, let active) = event, cartID == 0 {
                    if active { flagged = true } else if flagged { cleared = true }
                }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertTrue(flagged)
        XCTAssertTrue(cleared)
    }

    func testLapTimesAddUpToTheTotal() {
        let race = RaceHarness.makeRace(laps: 3, fieldSize: 4, items: false)
        RaceHarness.run(race)
        for cart in race.carts {
            guard let total = cart.finishTime else { return XCTFail("\(cart.setup.character.name) did not finish") }
            let sum = cart.lapTimes.reduce(0, +)
            // The gap is the run from the grid to the line on the opening lap.
            XCTAssertEqual(sum, total, accuracy: 3.0)
        }
    }

    func testStandingsAreOrderedByDistanceCovered() {
        let race = RaceHarness.makeRace(fieldSize: 6, items: false)
        var elapsed = 0.0
        while elapsed < 40 {
            race.update(dt: RaceHarness.dt)
            _ = race.drainEvents()
            elapsed += RaceHarness.dt
        }
        let distances = race.standings.compactMap { race.cart(withID: $0)?.totalDistance }
        XCTAssertEqual(distances, distances.sorted(by: >))
        XCTAssertEqual(race.place(ofCart: race.standings[0]), 1)
    }

    func testGrandPrixPointsRewardTheWinner() {
        XCTAssertEqual(GrandPrix.points(forPlace: 1), 15)
        XCTAssertEqual(GrandPrix.points(forPlace: 8), 1)
        XCTAssertEqual(GrandPrix.points(forPlace: 9), 0)
        let table = (1...8).map(GrandPrix.points(forPlace:))
        XCTAssertEqual(table, table.sorted(by: >))
    }

    func testTimeFormatting() {
        XCTAssertEqual(TimeFormat.lap(83.456), "1:23.456")
        XCTAssertEqual(TimeFormat.lap(9.1), "0:09.100")
        XCTAssertEqual(TimeFormat.ordinal(1), "1st")
        XCTAssertEqual(TimeFormat.ordinal(2), "2nd")
        XCTAssertEqual(TimeFormat.ordinal(3), "3rd")
        XCTAssertEqual(TimeFormat.ordinal(4), "4th")
        XCTAssertEqual(TimeFormat.ordinal(11), "11th")
    }
}
