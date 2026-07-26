import XCTest
@testable import AisleRushCore

final class ItemTests: XCTestCase {
    private let dt = 1.0 / 120.0

    private func makeCart(id: Int = 0, at position: Vector2 = .zero, heading: Double = 0) -> Cart {
        Cart(
            id: id,
            setup: Roster.defaultSetup(for: Roster.characters[id % Roster.characters.count]),
            isPlayer: id == 0,
            aiSkill: 0.8,
            position: position,
            heading: heading
        )
    }

    // MARK: - Roulette

    func testTheLeaderNeverDrawsARescueItem() {
        var generator = SeededRandom(seed: 99)
        var drawn: Set<ItemKind> = []
        for _ in 0..<4000 {
            drawn.insert(ItemRoulette.roll(position: 1, fieldSize: 8, luck: 0.5, using: &generator))
        }
        XCTAssertFalse(drawn.contains(.vipCard))
        XCTAssertFalse(drawn.contains(.runawayCart))
        XCTAssertFalse(drawn.contains(.cleanupCall))
        XCTAssertTrue(drawn.contains(.milkSpill))
        XCTAssertTrue(drawn.contains(.soupCan))
    }

    func testTheBackOfTheFieldGetsTheGoodStuff() {
        var generator = SeededRandom(seed: 7)
        var counts: [ItemKind: Int] = [:]
        for _ in 0..<4000 {
            let kind = ItemRoulette.roll(position: 8, fieldSize: 8, luck: 0.5, using: &generator)
            counts[kind, default: 0] += 1
        }
        let rescue = (counts[.energyDrink] ?? 0) + (counts[.vipCard] ?? 0)
            + (counts[.runawayCart] ?? 0) + (counts[.rogueMelon] ?? 0)
        XCTAssertGreaterThan(Double(rescue) / 4000, 0.55, "last place should mostly draw comeback items")
        XCTAssertLessThan(Double(counts[.milkSpill] ?? 0) / 4000, 0.1)
    }

    func testLuckShiftsTheDistributionWithoutBreakingIt() {
        let unlucky = ItemRoulette.weights(position: 4, fieldSize: 8, luck: 0.0)
        let lucky = ItemRoulette.weights(position: 4, fieldSize: 8, luck: 1.0)
        XCTAssertGreaterThan(lucky[.energyDrink] ?? 0, unlucky[.energyDrink] ?? 0)
        XCTAssertLessThan(lucky[.milkSpill] ?? 0, unlucky[.milkSpill] ?? 0)
        for weights in [unlucky, lucky] {
            XCTAssertEqual(weights.count, 9)
            for (_, weight) in weights { XCTAssertGreaterThanOrEqual(weight, 0) }
        }
    }

    func testEveryItemIsReachableSomewhereInTheField() {
        var generator = SeededRandom(seed: 31337)
        var seen: Set<ItemKind> = []
        for position in 1...8 {
            for _ in 0..<3000 {
                seen.insert(ItemRoulette.roll(position: position, fieldSize: 8, luck: 0.5, using: &generator))
            }
        }
        XCTAssertEqual(seen.count, ItemKind.allCases.count)
    }

    // MARK: - Projectiles

    func testASoupCanFlungForwardSpinsTheCartAhead() {
        var thrower = makeCart(id: 0, at: .zero)
        var victim = makeCart(id: 1, at: Vector2(18, 0))
        thrower.heldItem = .soupCan
        thrower.heldCharges = 1

        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &thrower,
            aimBackward: false,
            nextID: &nextID,
            projectiles: &projectiles,
            drops: &drops,
            allCarts: [thrower, victim],
            standings: [0, 1],
            events: &events
        )
        XCTAssertEqual(projectiles.count, 1)
        XCTAssertNil(thrower.heldItem)

        let track = Tracks.track(id: "closing-time")
        var carts = [thrower, victim]
        for _ in 0..<180 {
            ItemSystem.updateProjectiles(&projectiles, carts: &carts, track: track, dt: dt, events: &events)
            if carts[1].spinTimer > 0 { break }
        }
        XCTAssertGreaterThan(carts[1].spinTimer, 0, "the can should have connected")
        XCTAssertEqual(carts[0].spinTimer, 0, "the thrower should not hit themselves")
        XCTAssertTrue(projectiles.isEmpty)
        XCTAssertTrue(events.contains(.cartHit(cartID: 1, by: .soupCan, sourceID: 0)))
    }

    func testAVIPShrugsOffAProjectile() {
        var thrower = makeCart(id: 0, at: .zero)
        var victim = makeCart(id: 1, at: Vector2(14, 0))
        victim.invincibleTimer = 5
        thrower.heldItem = .soupCan
        thrower.heldCharges = 1

        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &thrower, aimBackward: false, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [thrower, victim], standings: [0, 1], events: &events
        )
        var carts = [thrower, victim]
        let track = Tracks.track(id: "closing-time")
        for _ in 0..<180 {
            ItemSystem.updateProjectiles(&projectiles, carts: &carts, track: track, dt: dt, events: &events)
        }
        XCTAssertEqual(carts[1].spinTimer, 0)
    }

    func testTheMelonChasesACartThatIsNotDirectlyAhead() {
        var thrower = makeCart(id: 0, at: .zero)
        let victim = makeCart(id: 1, at: Vector2(26, 7))
        thrower.heldItem = .rogueMelon
        thrower.heldCharges = 1

        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &thrower, aimBackward: false, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [thrower, victim], standings: [1, 0], events: &events
        )
        XCTAssertEqual(projectiles.first?.targetID, 1)

        var carts = [thrower, victim]
        let track = Tracks.track(id: "closing-time")
        for _ in 0..<300 {
            ItemSystem.updateProjectiles(&projectiles, carts: &carts, track: track, dt: dt, events: &events)
            if carts[1].spinTimer > 0 { break }
        }
        XCTAssertGreaterThan(carts[1].spinTimer, 0, "the melon should have tracked its target down")
    }

    func testADroppedSpillCatchesTheCartBehind() {
        var dropper = makeCart(id: 0, at: .zero)
        dropper.heldItem = .milkSpill
        dropper.heldCharges = 1

        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &dropper, aimBackward: true, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [dropper], standings: [0], events: &events
        )
        XCTAssertEqual(drops.count, 1)
        XCTAssertLessThan(drops[0].position.x, 0, "the spill belongs behind the cart")

        var follower = makeCart(id: 1, at: drops[0].position - Vector2(4, 0))
        follower.velocity = Vector2(12, 0)
        var carts = [dropper, follower]
        for _ in 0..<120 {
            for index in carts.indices {
                carts[index].position += carts[index].velocity * dt
            }
            ItemSystem.updateDrops(&drops, carts: &carts, dt: dt, events: &events)
            if carts[1].spinTimer > 0 { break }
        }
        XCTAssertGreaterThan(carts[1].spinTimer, 0)
        XCTAssertTrue(drops.isEmpty, "a spill is used up once someone finds it")
    }

    func testTheDropperIsBrieflyImmuneToTheirOwnMess() {
        var dropper = makeCart(id: 0, at: .zero)
        dropper.heldItem = .milkSpill
        dropper.heldCharges = 1
        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &dropper, aimBackward: true, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [dropper], standings: [0], events: &events
        )
        dropper.position = drops[0].position
        var carts = [dropper]
        for _ in 0..<30 {
            ItemSystem.updateDrops(&drops, carts: &carts, dt: dt, events: &events)
        }
        XCTAssertEqual(carts[0].spinTimer, 0)
    }

    func testInstantItemsApplyTheirEffectImmediately() {
        var cart = makeCart()
        cart.heldItem = .energyDrink
        cart.heldCharges = 1
        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1
        ItemSystem.deploy(
            cart: &cart, aimBackward: false, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [cart], standings: [0], events: &events
        )
        XCTAssertGreaterThan(cart.boostTimer, 1)
        XCTAssertGreaterThan(cart.boostStrength, 1.3)

        var vip = makeCart()
        vip.heldItem = .vipCard
        vip.heldCharges = 1
        vip.spinTimer = 1
        ItemSystem.deploy(
            cart: &vip, aimBackward: false, nextID: &nextID,
            projectiles: &projectiles, drops: &drops,
            allCarts: [vip], standings: [0], events: &events
        )
        XCTAssertTrue(vip.isInvincible)
        XCTAssertEqual(vip.spinTimer, 0, "a VIP card should shake off a spin")
    }

    func testTripleCansFireOneAtATime() {
        var cart = makeCart()
        cart.heldItem = .tripleCans
        cart.heldCharges = 3
        cart.orbitingCans = 3
        var projectiles: [Projectile] = []
        var drops: [Drop] = []
        var events: [RaceEvent] = []
        var nextID = 1

        for expected in [2, 1, 0] {
            ItemSystem.deploy(
                cart: &cart, aimBackward: false, nextID: &nextID,
                projectiles: &projectiles, drops: &drops,
                allCarts: [cart], standings: [0], events: &events
            )
            XCTAssertEqual(cart.orbitingCans, expected)
        }
        XCTAssertNil(cart.heldItem)
        XCTAssertEqual(projectiles.count, 3)
    }

    // MARK: - In a real race

    func testCartsPickUpItemsDuringARaceAndTheCratesComeBack() {
        let race = RaceHarness.makeRace(fieldSize: 8, seed: 606)
        var awarded = 0
        var used = 0
        var elapsed = 0.0
        while !race.isComplete, elapsed < 200 {
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .itemAwarded = event { awarded += 1 }
                if case .itemUsed = event { used += 1 }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertGreaterThan(awarded, 20, "the field barely picked anything up")
        XCTAssertGreaterThan(used, 15, "the AI is hoarding")
        XCTAssertTrue(race.itemBoxCooldowns.allSatisfy { $0 >= 0 })
    }

    func testAPlayerCanPickUpAndFireAnItem() {
        let race = RaceHarness.makeRace(fieldSize: 4, playerAt: 0, seed: 12)
        var fired = false
        var elapsed = 0.0
        var frame = 0
        while elapsed < 60, !fired {
            let player = race.carts[0]
            // Tap rather than hold: holding a trailable item keeps it out
            // behind the cart as a shield instead of throwing it.
            frame += 1
            let wantsToFire = player.heldItem != nil && frame % 24 < 12
            race.setInput(RaceHarness.follow(player, on: race.track, useItem: wantsToFire), forCart: 0)
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .itemUsed(let cartID, _) = event, cartID == 0 { fired = true }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertTrue(fired, "the player never managed to use an item")
    }

    func testCleanupCallSlowsEverybodyInFront() {
        let track = Tracks.track(id: "closing-time")
        let race = RaceSimulation(
            track: track,
            config: RaceConfig(laps: 3, fieldSize: 4, seed: 5),
            entrants: RaceHarness.field(size: 4, playerAt: 3)
        )
        // Let the field get going and spread out a little.
        for _ in 0..<Int(12 / RaceHarness.dt) {
            race.setInput(ControlInput(throttle: 1), forCart: 3)
            race.update(dt: RaceHarness.dt)
            _ = race.drainEvents()
        }
        XCTAssertGreaterThan(race.place(ofCart: 3), 1, "the test needs the player to be behind someone")

        race.forceItem(.cleanupCall, forCart: 3)
        race.setInput(ControlInput(throttle: 1, useItem: true), forCart: 3)
        race.update(dt: RaceHarness.dt)
        let events = race.drainEvents()

        let slowed = events.compactMap { event -> Int? in
            if case .cartHit(let cartID, .cleanupCall, _) = event { return cartID }
            return nil
        }
        XCTAssertFalse(slowed.isEmpty)
        for id in slowed {
            XCTAssertLessThan(race.place(ofCart: id), race.place(ofCart: 3))
            XCTAssertGreaterThan(race.cart(withID: id)?.slowTimer ?? 0, 0)
        }
    }

    func testItemsCanBeTurnedOffEntirely() {
        let race = RaceHarness.makeRace(fieldSize: 4, seed: 3, items: false)
        var awarded = 0
        var elapsed = 0.0
        while !race.isComplete, elapsed < 200 {
            race.update(dt: RaceHarness.dt)
            for event in race.drainEvents() {
                if case .itemAwarded = event { awarded += 1 }
            }
            elapsed += RaceHarness.dt
        }
        XCTAssertEqual(awarded, 0)
        XCTAssertTrue(race.carts.allSatisfy { $0.heldItem == nil })
    }
}
