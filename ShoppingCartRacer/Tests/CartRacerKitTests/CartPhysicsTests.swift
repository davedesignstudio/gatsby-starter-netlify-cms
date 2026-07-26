import XCTest
@testable import CartRacerKit

final class CartPhysicsTests: XCTestCase {
    private let marge = RacerRoster.racer(id: "marge")!

    func testCountdownHoldsTheFieldStill() {
        let simulation = RaceSimulation(
            configuration: TestTracks.configuration(track: TestTracks.circle(), racers: [marge])
        )
        simulation.setPlayerInput(.flatOut)
        let start = simulation.carts[0].position

        for _ in 0..<200 { simulation.step(simulation.tuning.fixedTimeStep) }

        XCTAssertEqual(simulation.carts[0].position.distance(to: start), 0, accuracy: 1e-9)
        if case .countdown = simulation.phase {} else { XCTFail("expected to still be counting down") }
    }

    func testLightsGoGreenAndCartsGetMoving() {
        let simulation = TestTracks.started(
            TestTracks.configuration(track: TestTracks.circle(), racers: [marge])
        )
        XCTAssertTrue(simulation.phase.isRacing)

        simulation.runScripted(seconds: 3, driver: ScriptedDriver())
        XCTAssertGreaterThan(simulation.carts[0].forwardSpeed, 5)
        XCTAssertGreaterThan(simulation.carts[0].travelled, 0)
    }

    func testHoldingTheThrottleThroughTheCountdownGivesARocketStart() {
        let simulation = RaceSimulation(
            configuration: TestTracks.configuration(track: TestTracks.circle(), racers: [marge])
        )
        // Feather it in the last moment of the countdown.
        var events: [RaceEvent] = []
        while !simulation.phase.isRacing {
            if case .countdown(let remaining) = simulation.phase, remaining < 0.3 {
                simulation.setPlayerInput(.flatOut)
            }
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
        }
        XCTAssertTrue(events.contains(.rocketStart(cartID: 0)))
        XCTAssertGreaterThan(simulation.carts[0].boostTimer, 0)
    }

    func testFloodingTheEngineOnTheGridIsPunished() {
        let simulation = RaceSimulation(
            configuration: TestTracks.configuration(track: TestTracks.circle(), racers: [marge])
        )
        var events: [RaceEvent] = []
        while !simulation.phase.isRacing {
            simulation.setPlayerInput(.flatOut)
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
        }
        XCTAssertTrue(events.contains(.floodedEngine(cartID: 0)))
        XCTAssertGreaterThan(simulation.carts[0].stallTimer, 0)
    }

    func testCartsReachTopSpeedButNotBeyondIt() {
        let simulation = TestTracks.started(
            TestTracks.configuration(track: TestTracks.circle(radius: 140, halfWidth: 14), racers: [marge])
        )
        simulation.runScripted(seconds: 20, driver: ScriptedDriver())

        let cart = simulation.carts[0]
        let ceiling = cart.tuning.topSpeed
        XCTAssertGreaterThan(cart.forwardSpeed, ceiling * 0.85, "cart never got up to speed")
        XCTAssertLessThan(cart.forwardSpeed, ceiling * 1.02, "cart exceeded its top speed with no boost")
    }

    func testBrakingStopsTheCart() {
        let simulation = TestTracks.started(
            TestTracks.configuration(track: TestTracks.circle(radius: 140, halfWidth: 14), racers: [marge])
        )
        simulation.runScripted(seconds: 8, driver: ScriptedDriver())
        XCTAssertGreaterThan(simulation.carts[0].forwardSpeed, 8)

        var braking = ScriptedDriver()
        braking.throttle = -1
        simulation.runScripted(seconds: 4, driver: braking)
        XCTAssertLessThan(simulation.carts[0].forwardSpeed, 1)
    }

    func testSlipperyFloorsCostGripNotTopSpeed() {
        func peakSpeed(on surface: Surface) -> Double {
            let simulation = TestTracks.started(
                TestTracks.configuration(
                    track: TestTracks.circle(radius: 140, halfWidth: 14, surface: surface),
                    racers: [marge]
                )
            )
            simulation.runScripted(seconds: 18, driver: ScriptedDriver())
            return simulation.carts[0].forwardSpeed
        }
        // Carpet is the slow surface; frost is fast but has no grip.
        XCTAssertLessThan(peakSpeed(on: .carpetRunner), peakSpeed(on: .polishedTile) * 0.95)
        XCTAssertGreaterThan(peakSpeed(on: .freezerFrost), peakSpeed(on: .polishedTile) * 0.95)
        XCTAssertLessThan(Surface.freezerFrost.lateralGrip, Surface.polishedTile.lateralGrip)
    }

    func testCartsCannotLeaveThePremises() {
        let track = TestTracks.circle(radius: 70, halfWidth: 10, shoulderWidth: 4)
        let simulation = TestTracks.started(TestTracks.configuration(track: track, racers: [marge]))

        // Drive hard at the shelving for a while.
        var elapsed = 0.0
        var worstOverhang = 0.0
        while elapsed < 12 {
            simulation.setInput(DriverInput(throttle: 1, steer: -1), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            let cart = simulation.carts[0]
            let limit = track.geometry.halfWidth(at: cart.distance) + track.definition.shoulderWidth
            worstOverhang = max(worstOverhang, abs(cart.lateral) - limit)
            elapsed += simulation.tuning.fixedTimeStep
        }
        XCTAssertLessThan(worstOverhang, 0.05, "a cart got through the wall")
    }

    func testScrapingTheShelvingIsReportedAndCostsSpeed() {
        let track = TestTracks.circle(radius: 70, halfWidth: 6, shoulderWidth: 2)
        let simulation = TestTracks.started(TestTracks.configuration(track: track, racers: [marge]))
        simulation.runScripted(seconds: 5, driver: ScriptedDriver())
        let cruising = simulation.carts[0].forwardSpeed

        var events: [RaceEvent] = []
        var elapsed = 0.0
        while elapsed < 3 {
            simulation.setInput(DriverInput(throttle: 1, steer: -1), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
            elapsed += simulation.tuning.fixedTimeStep
        }

        let scrapes = events.filter {
            if case .wallScrape = $0 { return true }
            return false
        }
        XCTAssertFalse(scrapes.isEmpty, "hitting the shelving raised no event")
        XCTAssertLessThan(simulation.carts[0].forwardSpeed, cruising)
    }

    // MARK: - Drift

    func testHoldingADriftEarnsAMiniTurboThatIsActuallyFaster() {
        // A 25 m circle is about the radius a drift naturally holds at racing
        // speed, so the pursuit controller can sit in the slide the way a player
        // leaning on the drift button through a long corner would.
        let track = TestTracks.circle(radius: 25, halfWidth: 12)
        let simulation = TestTracks.started(TestTracks.configuration(track: track, racers: [marge]))

        // Get up to speed first: a drift needs pace to start.
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())
        XCTAssertGreaterThan(simulation.carts[0].forwardSpeed, simulation.tuning.driftMinimumSpeed)

        var sliding = ScriptedDriver()
        sliding.drift = true
        let driftEvents = simulation.runScripted(seconds: 2.4, driver: sliding)

        XCTAssertTrue(driftEvents.contains(.driftStarted(cartID: 0)), "no drift started")
        XCTAssertTrue(simulation.carts[0].isDrifting, "drift did not stay committed")
        XCTAssertGreaterThan(simulation.carts[0].driftCharge, simulation.tuning.miniTurboThresholds[1])
        XCTAssertGreaterThan(simulation.carts[0].miniTurboTier(tuning: simulation.tuning), 1)

        let speedBefore = simulation.carts[0].forwardSpeed
        let releaseEvents = simulation.runScripted(seconds: 0.1, driver: ScriptedDriver())

        let turbos = releaseEvents.compactMap { event -> Int? in
            if case .miniTurbo(_, let tier) = event { return tier }
            return nil
        }
        XCTAssertEqual(turbos.count, 1, "releasing a charged drift did not fire a mini-turbo")
        XCTAssertGreaterThan(turbos.first ?? 0, 1, "expected at least a second-tier mini-turbo")
        XCTAssertGreaterThan(simulation.carts[0].boostTimer, 0)

        simulation.runScripted(seconds: 0.5, driver: ScriptedDriver())
        XCTAssertGreaterThan(simulation.carts[0].forwardSpeed, speedBefore, "mini-turbo did not speed the cart up")
    }

    func testDriftingTurnsTighterThanNormalSteering() {
        /// Tightest cornering radius the cart manages, in metres.
        func turnRadius(drifting: Bool) -> Double {
            let simulation = TestTracks.started(
                TestTracks.configuration(track: TestTracks.circle(radius: 140, halfWidth: 25), racers: [marge])
            )
            simulation.runScripted(seconds: 10, driver: ScriptedDriver())

            // Accumulate the rotation step by step: measuring the end-to-end
            // angle wraps once the cart has turned more than half a circle.
            var rotation = 0.0
            var distance = 0.0
            var elapsed = 0.0
            let step = simulation.tuning.fixedTimeStep
            while elapsed < 1.2 {
                let before = simulation.carts[0].heading
                simulation.setInput(DriverInput(throttle: 1, steer: 1, drift: drifting), forCart: 0)
                simulation.step(step)
                rotation += abs(Scalar.angleDelta(from: before, to: simulation.carts[0].heading))
                distance += simulation.carts[0].speed * step
                elapsed += step
            }
            return distance / max(rotation, 1e-6)
        }

        let sliding = turnRadius(drifting: true)
        let gripping = turnRadius(drifting: false)
        XCTAssertLessThan(sliding, gripping * 0.8, "drifting should corner tighter than steering")
        // And both should be sane for a supermarket, not a fighter jet.
        XCTAssertGreaterThan(sliding, 3)
        XCTAssertLessThan(gripping, 40)
    }

    func testFullLockCounterSteerFlicksTheDriftAndLosesTheCharge() {
        let simulation = TestTracks.started(
            TestTracks.configuration(track: TestTracks.circle(radius: 25, halfWidth: 14), racers: [marge])
        )
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())

        var sliding = ScriptedDriver()
        sliding.drift = true
        simulation.runScripted(seconds: 1.2, driver: sliding)
        XCTAssertTrue(simulation.carts[0].isDrifting)
        XCTAssertEqual(simulation.carts[0].driftDirection, 1, "expected a left-hand drift on a left-hand circle")
        let chargeBefore = simulation.carts[0].driftCharge
        XCTAssertGreaterThan(chargeBefore, 0.9)

        // Slam the steering the other way, the way a player would when the drift
        // is taking them somewhere they do not want to go.
        var elapsed = 0.0
        while elapsed < 0.6 {
            simulation.setInput(DriverInput(throttle: 1, steer: -1, drift: true), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            elapsed += simulation.tuning.fixedTimeStep
        }

        // Either the slide has ended or it has flipped, but the bank of charge is
        // gone either way — no free mini-turbo out of a botched drift.
        XCTAssertLessThan(simulation.carts[0].driftCharge, chargeBefore)
        XCTAssertNotEqual(simulation.carts[0].driftDirection, 1)
    }

    func testDriftNeedsSpeedToStart() {
        let simulation = TestTracks.started(
            TestTracks.configuration(track: TestTracks.circle(), racers: [marge])
        )
        var elapsed = 0.0
        while elapsed < 0.3 {
            simulation.setInput(DriverInput(throttle: 0.05, steer: 1, drift: true), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            elapsed += simulation.tuning.fixedTimeStep
        }
        XCTAssertFalse(simulation.carts[0].isDrifting)
    }

    // MARK: - Recovery

    func testAWedgedCartIsRecovered() {
        let track = TestTracks.circle(radius: 70, halfWidth: 8, shoulderWidth: 3)
        let simulation = TestTracks.started(TestTracks.configuration(track: track, racers: [marge]))

        // Park the cart against the wall, facing straight into it.
        let outwardHeading = track.geometry.tangentAngle(at: 40) - .pi / 2
        simulation.carts[0].position = track.geometry.position(at: 40, lateral: -10.9)
        simulation.carts[0].heading = outwardHeading
        simulation.carts[0].velocity = .zero

        var events: [RaceEvent] = []
        var elapsed = 0.0
        while elapsed < 6 {
            simulation.setInput(DriverInput(throttle: 1, steer: 0), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
            elapsed += simulation.tuning.fixedTimeStep
        }

        XCTAssertTrue(events.contains(.respawned(cartID: 0)), "a stuck cart was never recovered")
        XCTAssertLessThan(abs(simulation.carts[0].lateral), 8, "recovery did not return the cart to the track")
    }

    func testCartsPushEachOtherAroundWithoutOverlapping() {
        let simulation = TestTracks.started(
            TestTracks.configuration(
                track: TestTracks.circle(radius: 90, halfWidth: 14),
                racers: [marge, RacerRoster.racer(id: "todd")!]
            )
        )
        // Put them on top of each other and let the solver sort it out.
        simulation.carts[1].position = simulation.carts[0].position + Vector2(0.3, 0.1)
        simulation.runScripted(seconds: 4, driver: ScriptedDriver())

        let separation = simulation.carts[0].position.distance(to: simulation.carts[1].position)
        let combined = simulation.carts[0].tuning.radius + simulation.carts[1].tuning.radius
        XCTAssertGreaterThan(separation, combined * 0.9, "carts ended up inside each other")
    }
}
