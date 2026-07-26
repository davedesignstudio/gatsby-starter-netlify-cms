import XCTest
@testable import CartKartCore

final class ItemTests: XCTestCase {
    func testLeadersGetJunkAndBackmarkersGetComebacks() {
        let leader = Dictionary(uniqueKeysWithValues: ItemRoulette.weights(positionFraction: 0, racerCount: 8))
        let last = Dictionary(uniqueKeysWithValues: ItemRoulette.weights(positionFraction: 1, racerCount: 8))

        XCTAssertEqual(leader[.runawayMelon], 0, "the leader must never draw the melon")
        XCTAssertEqual(leader[.bulkBuy], 0, "the leader must never draw invincibility")
        XCTAssertGreaterThan(last[.runawayMelon] ?? 0, 0)
        XCTAssertGreaterThan(last[.bulkBuy] ?? 0, 0)
        XCTAssertGreaterThan(last[.energyDrink] ?? 0, leader[.energyDrink] ?? 0)
        XCTAssertGreaterThan(leader[.grapeSpill] ?? 0, last[.grapeSpill] ?? 0)
    }

    func testMelonNeedsAFieldToChase() {
        let weights = Dictionary(uniqueKeysWithValues: ItemRoulette.weights(positionFraction: 1, racerCount: 2))
        XCTAssertEqual(weights[.runawayMelon], 0)
    }

    func testRolledItemsAreAlwaysValid() {
        var random = SeededRandom(seed: 3)
        var seen: Set<ItemKind> = []
        for step in 0..<4000 {
            let fraction = Double(step % 100) / 99
            seen.insert(ItemRoulette.roll(positionFraction: fraction, racerCount: 8, random: &random))
        }
        // Every item should be reachable somewhere in the field.
        XCTAssertEqual(seen.count, ItemKind.allCases.count)
    }

    func testChargeCounts() {
        XCTAssertEqual(HeldItem(kind: .tripleSoup).charges, 3)
        XCTAssertEqual(HeldItem(kind: .soupCan).charges, 1)
        XCTAssertTrue(ItemKind.grapeSpill.isTrailed)
        XCTAssertFalse(ItemKind.energyDrink.isTrailed)
    }

    // MARK: - In-race behaviour

    /// Two carts nose to tail, so item effects are easy to observe.
    private func makeDuel() -> RaceEngine {
        let entries = [
            RaceConfiguration.Entry(profile: Roster.profile(id: "chrome"), isPlayer: true),
            RaceConfiguration.Entry(profile: Roster.profile(id: "rusty"), isPlayer: false)
        ]
        let engine = RaceEngine(
            configuration: RaceConfiguration(
                track: TrackLibrary.producePlaza,
                entries: entries,
                lapCount: 3,
                seed: 8
            )
        )
        // Roll through the countdown.
        for _ in 0..<Int(4.0 / engine.tuning.fixedTimeStep) {
            engine.advance(deltaTime: engine.tuning.fixedTimeStep, playerInput: .idle)
        }
        _ = engine.drainEvents()
        return engine
    }

    /// Drives the player's cart on autopilot so it stays on the course, with
    /// optional overrides for the throttle and the item button.
    @discardableResult
    private func drive(
        _ engine: RaceEngine,
        seconds: Double,
        throttleCap: Double = 1,
        useItem: Bool = false
    ) -> [RaceEvent] {
        var collected: [RaceEvent] = []
        for _ in 0..<Int(seconds / engine.tuning.fixedTimeStep) {
            var input = engine.autopilotInput(for: 0)
            input.throttle = min(input.throttle, throttleCap)
            input.useItem = useItem
            input.aimBackwards = false
            engine.advance(deltaTime: engine.tuning.fixedTimeStep, playerInput: input)
            collected.append(contentsOf: engine.drainEvents())
        }
        return collected
    }

    func testEnergyDrinkBoostsImmediately() {
        let engine = makeDuel()
        drive(engine, seconds: 3)
        engine.giveItemForTesting(.energyDrink, to: 0)
        let events = drive(engine, seconds: 0.2, useItem: true)
        XCTAssertTrue(events.contains { if case .itemUsed(0, .energyDrink) = $0 { return true } else { return false } })
        XCTAssertTrue(engine.karts[0].isBoosting)
        XCTAssertNil(engine.karts[0].item, "a one-charge item empties the slot")
    }

    func testTripleSoupKeepsTwoChargesAfterFiring() {
        let engine = makeDuel()
        drive(engine, seconds: 3)
        engine.giveItemForTesting(.tripleSoup, to: 0)
        drive(engine, seconds: 0.1, useItem: true)
        XCTAssertEqual(engine.karts[0].item?.charges, 2)
        XCTAssertEqual(engine.projectiles.count, 1)
    }

    func testDroppedSpillSpinsWhoeverRunsOverIt() {
        let engine = makeDuel()
        drive(engine, seconds: 3)

        // Drop a spill directly in front of the AI cart.
        let victim = engine.karts[1]
        let ahead = victim.position + Vec2.direction(victim.heading) * 60
        engine.spawnHazardForTesting(.grapeSpill, at: ahead, radius: 40, owner: 0)

        let events = drive(engine, seconds: 1.5)
        let wasHit = events.contains {
            if case .kartHit(1, .spin, _) = $0 { return true } else { return false }
        }
        XCTAssertTrue(wasHit, "the trailing cart drove straight through a spill")
        XCTAssertFalse(engine.hazards.contains { $0.kind == .grapeSpill }, "a spill is consumed once it trips someone")
    }

    func testTheOwnerGetsAGraceWindowOnTheirOwnSpill() {
        let engine = makeDuel()
        drive(engine, seconds: 3)
        let kart = engine.karts[0]
        engine.spawnHazardForTesting(.grapeSpill, at: kart.position, radius: 60, owner: 0)
        drive(engine, seconds: 0.2)
        XCTAssertNotEqual(engine.karts[0].disruption, .spin, "you should not trip on your own spill")
        XCTAssertTrue(engine.hazards.contains { $0.kind == .grapeSpill })
    }

    func testInvincibleCartsShrugOffHazards() {
        let engine = makeDuel()
        drive(engine, seconds: 3)
        engine.giveItemForTesting(.bulkBuy, to: 0)
        drive(engine, seconds: 0.1, useItem: true)
        XCTAssertTrue(engine.karts[0].isInvincible)

        let kart = engine.karts[0]
        engine.spawnHazardForTesting(
            .grapeSpill,
            at: kart.position + Vec2.direction(kart.heading) * 40,
            radius: 60,
            owner: 1
        )
        drive(engine, seconds: 0.5)
        XCTAssertNil(engine.karts[0].disruption)
        XCTAssertFalse(
            engine.hazards.contains { $0.kind == .grapeSpill },
            "the spill is still swept up, it just does no harm"
        )
    }

    func testMelonHuntsDownTheLeader() throws {
        let engine = makeDuel()
        // Dawdle so the AI cart takes the lead.
        drive(engine, seconds: 10, throttleCap: 0.3)
        guard engine.karts[1].totalProgress > engine.karts[0].totalProgress else {
            throw XCTSkip("the AI did not get ahead in this run")
        }
        engine.giveItemForTesting(.runawayMelon, to: 0)
        drive(engine, seconds: 0.1, throttleCap: 0.3, useItem: true)
        XCTAssertEqual(engine.projectiles.first?.kind, .runawayMelon)

        let events = drive(engine, seconds: 14, throttleCap: 0.3)
        let squashed = events.contains {
            if case .kartHit(1, .squash, _) = $0 { return true } else { return false }
        }
        XCTAssertTrue(squashed, "the melon never caught the leader")
    }

    func testHazardsExpire() {
        let engine = makeDuel()
        engine.spawnHazardForTesting(.flourCloud, at: Vec2(9000, 9000), radius: 40, owner: nil, life: 1.0)
        XCTAssertEqual(engine.hazards.count, 1)
        drive(engine, seconds: 1.5)
        XCTAssertFalse(engine.hazards.contains { $0.position == Vec2(9000, 9000) })
    }
}

// MARK: - Test hooks

extension RaceEngine {
    /// Puts an item straight into a cart's slot, skipping the roulette.
    func giveItemForTesting(_ kind: ItemKind, to kartID: Int) {
        guard let index = karts.firstIndex(where: { $0.id == kartID }) else { return }
        setKartForTesting(at: index) { kart in
            kart.item = HeldItem(kind: kind)
            kart.pendingItem = nil
            kart.itemRouletteTimer = 0
            kart.aiItemTimer = 0
        }
    }
}
