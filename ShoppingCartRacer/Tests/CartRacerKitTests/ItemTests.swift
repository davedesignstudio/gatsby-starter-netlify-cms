import XCTest
@testable import CartRacerKit

final class ItemTests: XCTestCase {
    private let marge = RacerRoster.racer(id: "marge")!
    private let kev = RacerRoster.racer(id: "kev")!

    // MARK: - Roulette

    func testLeaderIsDeniedTheComebackItems() {
        let roulette = ItemRoulette()
        let leader = roulette.weights(racePosition: 1, fieldSize: 5)
        XCTAssertEqual(leader[.expressLane], 0)
        XCTAssertEqual(leader[.clearanceAnnouncement], 0)
        // The leader mostly gets defensive junk to sit on.
        XCTAssertGreaterThan(leader[.greaseSlick] ?? 0, leader[.sodaCan] ?? 0)
    }

    func testBackMarkerGetsTheComebackItems() {
        let roulette = ItemRoulette()
        let last = roulette.weights(racePosition: 5, fieldSize: 5)
        XCTAssertGreaterThan(last[.expressLane] ?? 0, 0)
        XCTAssertGreaterThan(last[.clearanceAnnouncement] ?? 0, 0)
        XCTAssertGreaterThan(last[.sodaCan] ?? 0, last[.greaseSlick] ?? 0)
    }

    func testRouletteOnlyEverDrawsPermittedItems() {
        let roulette = ItemRoulette()
        var random = DeterministicRandom(seed: 5)
        for position in 1...5 {
            var drawn: Set<ItemKind> = []
            for _ in 0..<3000 {
                drawn.insert(roulette.draw(racePosition: position, fieldSize: 5, random: &random))
            }
            if position == 1 {
                XCTAssertFalse(drawn.contains(.expressLane))
                XCTAssertFalse(drawn.contains(.clearanceAnnouncement))
            }
            if position == 5 {
                XCTAssertTrue(drawn.contains(.expressLane))
            }
        }
    }

    func testRouletteIsDeterministicForASeed() {
        let roulette = ItemRoulette()
        func sequence() -> [ItemKind] {
            var random = DeterministicRandom(seed: 777)
            return (0..<50).map { _ in roulette.draw(racePosition: 3, fieldSize: 5, random: &random) }
        }
        XCTAssertEqual(sequence(), sequence())
    }

    // MARK: - Pickups

    func testDrivingThroughACrateFillsTheItemSlotAndTheCrateRespawns() {
        let track = TestTracks.circle(radius: 70, halfWidth: 10)
        var definition = track.definition
        let crate = ItemBoxSpawn(position: track.geometry.position(at: 40, lateral: 0), respawnDelay: 2)
        definition = TrackDefinition(
            id: definition.id,
            name: definition.name,
            subtitle: definition.subtitle,
            theme: definition.theme,
            recommendedLaps: definition.recommendedLaps,
            nodes: definition.nodes,
            shoulderWidth: definition.shoulderWidth,
            obstacles: [],
            boostPads: [],
            itemBoxes: [crate],
            tokens: []
        )
        let simulation = TestTracks.started(
            TestTracks.configuration(track: Track(definition: definition), racers: [marge], laps: 5)
        )

        // Drive until the crate is taken, then check the state at that moment —
        // by the end of a lap it will legitimately have respawned.
        var collected = false
        var elapsed = 0.0
        let driver = ScriptedDriver()
        while elapsed < 40, !collected {
            for cart in simulation.carts {
                simulation.setInput(driver.input(for: cart, geometry: simulation.geometry), forCart: cart.id)
            }
            simulation.step(simulation.tuning.fixedTimeStep)
            elapsed += simulation.tuning.fixedTimeStep
            collected = simulation.drainEvents().contains { event in
                if case .itemCollected(let cartID, _) = event { return cartID == 0 }
                return false
            }
        }

        XCTAssertTrue(collected, "never picked up the crate")
        XCTAssertNotNil(simulation.carts[0].heldItem)
        XCTAssertFalse(simulation.itemBoxes[0].isAvailable, "crate should be on cooldown right after being taken")

        simulation.runScripted(seconds: crate.respawnDelay + 0.5, driver: driver)
        XCTAssertTrue(simulation.itemBoxes[0].isAvailable, "crate never came back")
    }

    func testTokensRaiseTopSpeed() {
        /// Cruising speed after a long run, with and without loose change.
        func cruisingSpeed(tokens: Int) -> Double {
            let simulation = TestTracks.started(
                TestTracks.configuration(track: TestTracks.circle(radius: 140, halfWidth: 14), racers: [marge])
            )
            simulation.carts[0].tokens = tokens
            simulation.runScripted(seconds: 25, driver: ScriptedDriver())
            return simulation.carts[0].forwardSpeed
        }
        XCTAssertGreaterThan(cruisingSpeed(tokens: 12), cruisingSpeed(tokens: 0) + 0.3)
    }

    // MARK: - Effects

    private func startedPair() -> RaceSimulation {
        TestTracks.started(
            TestTracks.configuration(
                track: TestTracks.circle(radius: 120, halfWidth: 16),
                racers: [marge, kev]
            )
        )
    }

    func testEnergyDrinkBoosts() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 8, driver: ScriptedDriver())
        let before = simulation.carts[0].forwardSpeed

        simulation.carts[0].heldItem = .energyDrink
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertGreaterThan(simulation.carts[0].boostTimer, 0)
        XCTAssertNil(simulation.carts[0].heldItem)

        simulation.runScripted(seconds: 0.8, driver: ScriptedDriver())
        XCTAssertGreaterThan(simulation.carts[0].forwardSpeed, before + 1)
    }

    func testItemButtonIsEdgeTriggered() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())
        simulation.carts[0].heldItem = .energyDrink

        // Hold the button down for a while, then refill the slot: the held button
        // must not immediately empty it again.
        var elapsed = 0.0
        while elapsed < 1.0 {
            simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
            simulation.step(simulation.tuning.fixedTimeStep)
            elapsed += simulation.tuning.fixedTimeStep
        }
        simulation.carts[0].heldItem = .crateShield
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertEqual(simulation.carts[0].heldItem, .crateShield, "a held button fired a newly picked-up item")
    }

    func testThrownCanSpinsOutTheCartAhead() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())

        // Line the target up directly in front of the thrower.
        let thrower = simulation.carts[0]
        simulation.carts[1].position = thrower.position + thrower.forward * 12
        simulation.carts[1].heading = thrower.heading
        simulation.carts[1].velocity = thrower.forward * 4

        simulation.carts[0].heldItem = .sodaCan
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertEqual(simulation.projectiles.count, 1)

        var events: [RaceEvent] = []
        var elapsed = 0.0
        while elapsed < 2.5 {
            simulation.setInput(DriverInput(throttle: 1), forCart: 0)
            simulation.setInput(DriverInput(throttle: 0.4), forCart: 1)
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
            elapsed += simulation.tuning.fixedTimeStep
        }

        XCTAssertTrue(events.contains { if case .spunOut(let id) = $0 { return id == 1 } else { return false } })
        XCTAssertTrue(simulation.projectiles.isEmpty, "the can should be consumed on impact")
    }

    func testCrateShieldEatsAHitThenShatters() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 5, driver: ScriptedDriver())

        simulation.carts[1].heldItem = .crateShield
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 1)
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertEqual(simulation.carts[1].shieldCharges, 3)

        _ = simulation.drainEvents()
        simulation.applySpinout(cartIndex: 1)
        let events = simulation.drainEvents()

        XCTAssertTrue(events.contains { if case .shieldBlocked = $0 { return true } else { return false } })
        XCTAssertEqual(simulation.carts[1].shieldCharges, 2)
        XCTAssertEqual(simulation.carts[1].spinoutTimer, 0, "the shield should have absorbed the hit entirely")
    }

    func testGreaseSlickMakesTheCartBehindLoseGrip() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())

        // Drop the slick right where the trailing cart is about to be.
        let target = simulation.carts[1]
        simulation.spawnHazard(ownerID: 0, kind: .greaseSlick, position: target.position + target.forward * 3)
        XCTAssertEqual(simulation.hazards.count, 1)

        var events: [RaceEvent] = []
        var elapsed = 0.0
        while elapsed < 2.0 {
            for cart in simulation.carts {
                simulation.setInput(ScriptedDriver().input(for: cart, geometry: simulation.geometry), forCart: cart.id)
            }
            simulation.step(simulation.tuning.fixedTimeStep)
            events += simulation.drainEvents()
            elapsed += simulation.tuning.fixedTimeStep
        }

        XCTAssertTrue(events.contains { if case .slipped(let id, _) = $0 { return id == 1 } else { return false } })
        XCTAssertTrue(simulation.hazards.isEmpty, "grease should be wiped up by whoever finds it")
    }

    func testClearanceAnnouncementOnlyStallsCartsAhead() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())

        // Force a known order: cart 1 leading, cart 0 chasing.
        simulation.carts[1].travelled = simulation.carts[0].travelled + 40
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertEqual(simulation.carts[1].racePosition, 1)
        XCTAssertEqual(simulation.carts[0].racePosition, 2)

        simulation.carts[0].heldItem = .clearanceAnnouncement
        simulation.carts[1].invulnerabilityTimer = 0
        _ = simulation.drainEvents()
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
        simulation.step(simulation.tuning.fixedTimeStep)
        let events = simulation.drainEvents()

        XCTAssertTrue(events.contains { if case .stalled(let id) = $0 { return id == 1 } else { return false } })
        XCTAssertGreaterThan(simulation.carts[1].stallTimer, 0)
        XCTAssertEqual(simulation.carts[0].stallTimer, 0, "the announcer should not stall themselves")
    }

    func testExpressLaneRocketsTheCartUpTheTrack() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 5, driver: ScriptedDriver())

        // Park it well off the racing line first; the express lane should reel it
        // back in as well as speed it up.
        simulation.carts[0].position = simulation.geometry.position(at: simulation.carts[0].distance, lateral: 9)
        let progressBefore = simulation.carts[0].travelled
        simulation.carts[0].heldItem = .expressLane
        simulation.setInput(DriverInput(throttle: 1, useItem: true), forCart: 0)
        simulation.step(simulation.tuning.fixedTimeStep)
        XCTAssertGreaterThan(simulation.carts[0].expressLaneTimer, 0)

        simulation.runScripted(seconds: 2, driver: ScriptedDriver())
        let cart = simulation.carts[0]
        XCTAssertGreaterThan(cart.travelled - progressBefore, cart.tuning.topSpeed * 2 * 0.9)
        XCTAssertLessThan(abs(cart.lateral), 4, "express lane should pull the cart back to the racing line")
    }

    func testSpinoutsRespectInvulnerability() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 5, driver: ScriptedDriver())

        simulation.applySpinout(cartIndex: 0)
        XCTAssertGreaterThan(simulation.carts[0].spinoutTimer, 0)
        let timer = simulation.carts[0].spinoutTimer

        // A second hit in the invulnerable window must not stack.
        simulation.applySpinout(cartIndex: 0)
        XCTAssertEqual(simulation.carts[0].spinoutTimer, timer, accuracy: 1e-9)
    }

    func testQuickRecoveryPerkShortensSpinouts() {
        let squeak = RacerRoster.racer(id: "squeak")!
        XCTAssertEqual(squeak.perk, .quickRecovery)
        let simulation = TestTracks.started(
            TestTracks.configuration(
                track: TestTracks.circle(radius: 120, halfWidth: 16),
                racers: [squeak, marge]
            )
        )
        simulation.applySpinout(cartIndex: 0)
        simulation.applySpinout(cartIndex: 1)
        XCTAssertLessThan(simulation.carts[0].spinoutTimer, simulation.carts[1].spinoutTimer)
    }

    func testASpunOutCartCannotDrive() {
        let simulation = startedPair()
        simulation.runScripted(seconds: 6, driver: ScriptedDriver())
        simulation.applySpinout(cartIndex: 0)
        let speedAtImpact = simulation.carts[0].forwardSpeed

        simulation.runScripted(seconds: 0.6, driver: ScriptedDriver())
        XCTAssertLessThan(simulation.carts[0].forwardSpeed, speedAtImpact)
        XCTAssertTrue(simulation.carts[0].isDisabled)
    }
}
