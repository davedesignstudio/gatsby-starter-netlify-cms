import XCTest
@testable import AisleRushCore

final class CartPhysicsTests: XCTestCase {
    private let dt = 1.0 / 120.0

    private func makeCart(character: String = "tina", frame: String = "rusty", wheels: String = "casters") -> Cart {
        let setup = CartSetup(
            character: Roster.character(id: character),
            frame: Roster.frame(id: frame),
            wheels: Roster.wheels(id: wheels)
        )
        return Cart(id: 0, setup: setup, isPlayer: true, aiSkill: 1, position: .zero, heading: 0)
    }

    private func run(_ cart: inout Cart, seconds: Double, input: ControlInput, surface: Surface = .linoleum) {
        var elapsed = 0.0
        while elapsed < seconds {
            CartPhysics.integrate(cart: &cart, input: input, surface: surface, dt: dt)
            elapsed += dt
        }
    }

    func testFullThrottleApproachesTopSpeedWithoutExceedingIt() {
        var cart = makeCart()
        run(&cart, seconds: 12, input: ControlInput(throttle: 1))
        XCTAssertGreaterThan(cart.forwardSpeed, cart.stats.topSpeed * 0.95)
        XCTAssertLessThanOrEqual(cart.forwardSpeed, cart.stats.topSpeed + 0.01)
    }

    func testAccelerationIsQuickerThanCoastingButSlowerThanBoosting() {
        var plain = makeCart()
        run(&plain, seconds: 2, input: ControlInput(throttle: 1))

        var boosted = makeCart()
        boosted.grantBoost(duration: 4, strength: 1.4)
        run(&boosted, seconds: 2, input: ControlInput(throttle: 1))

        XCTAssertGreaterThan(boosted.forwardSpeed, plain.forwardSpeed * 1.2)
    }

    func testBrakingStopsAndThenReverses() {
        var cart = makeCart()
        run(&cart, seconds: 6, input: ControlInput(throttle: 1))
        XCTAssertGreaterThan(cart.forwardSpeed, 10)

        run(&cart, seconds: 3, input: ControlInput(throttle: -1))
        XCTAssertLessThan(cart.forwardSpeed, 0)
        XCTAssertGreaterThan(cart.forwardSpeed, -CartPhysics.tuning.maxReverseSpeed - 0.01)
    }

    func testCoastingBleedsSpeedOff() {
        var cart = makeCart()
        run(&cart, seconds: 6, input: ControlInput(throttle: 1))
        let top = cart.forwardSpeed
        run(&cart, seconds: 3, input: .idle)
        XCTAssertLessThan(cart.forwardSpeed, top * 0.5)
        XCTAssertGreaterThan(cart.forwardSpeed, 0)
    }

    func testSteeringIsIneffectiveAtAStandstill() {
        var cart = makeCart()
        let heading = cart.heading
        run(&cart, seconds: 1, input: ControlInput(steer: 1, throttle: 0))
        XCTAssertEqual(cart.heading, heading, accuracy: 1e-9)
    }

    func testSteeringLeftTurnsCounterClockwise() {
        var cart = makeCart()
        run(&cart, seconds: 3, input: ControlInput(throttle: 1))
        let before = cart.heading
        run(&cart, seconds: 1, input: ControlInput(steer: 1, throttle: 1))
        XCTAssertGreaterThan(Angle.delta(from: before, to: cart.heading), 0.3)
    }

    func testOffTrackSurfacesCostSpeedAndKnobbliesHelp() {
        var onTrack = makeCart()
        run(&onTrack, seconds: 10, input: ControlInput(throttle: 1))

        var offTrack = makeCart()
        run(&offTrack, seconds: 10, input: ControlInput(throttle: 1), surface: .scuffed)
        XCTAssertLessThan(offTrack.forwardSpeed, onTrack.forwardSpeed * 0.8)

        var knobbly = makeCart(wheels: "allterrain")
        run(&knobbly, seconds: 10, input: ControlInput(throttle: 1), surface: .scuffed)
        XCTAssertGreaterThan(knobbly.forwardSpeed, offTrack.forwardSpeed + 1)
    }

    func testIceRobsGripSoTheCartSlidesWide() {
        func lateralDrift(on surface: Surface) -> Double {
            var cart = makeCart()
            run(&cart, seconds: 4, input: ControlInput(throttle: 1), surface: surface)
            run(&cart, seconds: 1.2, input: ControlInput(steer: 1, throttle: 1), surface: surface)
            return abs(cart.slipAngle)
        }
        XCTAssertGreaterThan(lateralDrift(on: .ice), lateralDrift(on: .linoleum) + 0.1)
    }

    func testDriftBuildsChargeThroughTheTiers() {
        var cart = makeCart()
        run(&cart, seconds: 4, input: ControlInput(throttle: 1))

        let drifting = ControlInput(steer: 1, throttle: 1, drift: true)
        run(&cart, seconds: 0.9, input: drifting)
        XCTAssertTrue(cart.drift.isActive)
        XCTAssertEqual(cart.drift.tier, 1)

        run(&cart, seconds: 1.2, input: drifting)
        XCTAssertEqual(cart.drift.tier, 2)

        run(&cart, seconds: 1.4, input: drifting)
        XCTAssertEqual(cart.drift.tier, 3)
    }

    func testReleasingADriftFiresAMiniTurbo() {
        var cart = makeCart()
        run(&cart, seconds: 4, input: ControlInput(throttle: 1))
        run(&cart, seconds: 1.0, input: ControlInput(steer: 1, throttle: 1, drift: true))
        XCTAssertGreaterThan(cart.drift.tier, 0)

        CartPhysics.integrate(cart: &cart, input: ControlInput(steer: 1, throttle: 1), surface: .linoleum, dt: dt)
        XCTAssertFalse(cart.drift.isActive)
        XCTAssertGreaterThan(cart.boostTimer, 0)
        XCTAssertGreaterThan(cart.boostStrength, 1)
    }

    func testDriftingSlidesTheCartSidewaysMoreThanGrippingDoes() {
        func slip(drifting: Bool) -> Double {
            var cart = makeCart()
            run(&cart, seconds: 4, input: ControlInput(throttle: 1))
            run(&cart, seconds: 1.0, input: ControlInput(steer: 1, throttle: 1, drift: drifting))
            return abs(cart.slipAngle)
        }
        XCTAssertGreaterThan(slip(drifting: true), slip(drifting: false) + 0.08)
    }

    func testDriftRefusesToStartBelowTheSpeedThreshold() {
        var cart = makeCart()
        run(&cart, seconds: 0.2, input: ControlInput(throttle: 1))
        run(&cart, seconds: 0.2, input: ControlInput(steer: 1, throttle: 1, drift: true))
        XCTAssertFalse(cart.drift.isActive)
    }

    func testSpinningOutRemovesControlAndTheHeldItem() {
        var cart = makeCart()
        cart.heldItem = .soupCan
        run(&cart, seconds: 5, input: ControlInput(throttle: 1))
        let speed = cart.forwardSpeed

        cart.spinOut(direction: 1)
        XCTAssertNil(cart.heldItem)
        XCTAssertFalse(cart.isControllable)

        run(&cart, seconds: 0.5, input: ControlInput(steer: -1, throttle: 1))
        XCTAssertLessThan(cart.speed, speed)

        run(&cart, seconds: 1.0, input: ControlInput(throttle: 1))
        XCTAssertTrue(cart.isControllable)
    }

    func testWallCollisionPushesTheCartBackAndScrubsSpeed() {
        var cart = makeCart()
        run(&cart, seconds: 6, input: ControlInput(throttle: 1))
        cart.velocity = Vector2(15, -8)
        let before = cart.speed

        let impact = CartPhysics.resolveWallCollision(cart: &cart, wallNormal: Vector2(0, 1), penetration: 0.4)
        XCTAssertGreaterThan(impact, 7)
        XCTAssertEqual(cart.position.y, 0.4, accuracy: 1e-9)
        XCTAssertLessThan(cart.speed, before)
        XCTAssertGreaterThan(cart.velocity.y, 0, "the cart should be moving away from the wall")
    }

    func testHeavyCartsShoveLightOnesAside() {
        let heavySetup = CartSetup(
            character: Roster.character(id: "gus"),
            frame: Roster.frame(id: "jumbo"),
            wheels: Roster.wheels(id: "rubber")
        )
        let lightSetup = CartSetup(
            character: Roster.character(id: "sue"),
            frame: Roster.frame(id: "sprinter"),
            wheels: Roster.wheels(id: "casters")
        )
        var heavy = Cart(id: 0, setup: heavySetup, isPlayer: false, aiSkill: 1, position: .zero, heading: 0)
        var light = Cart(id: 1, setup: lightSetup, isPlayer: false, aiSkill: 1, position: Vector2(1.4, 0.2), heading: 0)
        heavy.velocity = Vector2(20, 0)
        light.velocity = Vector2(4, 0)

        CartPhysics.resolveCartCollision(&heavy, &light)

        XCTAssertGreaterThan(light.velocity.x, 4, "the light cart should be punted forward")
        XCTAssertLessThan(heavy.velocity.x, 20)
        XCTAssertGreaterThan(light.position.distance(to: heavy.position), 1.4)
    }

    func testStatsStayInsideTheirDesignedRanges() {
        for character in Roster.characters {
            for frame in Roster.frames {
                for wheels in Roster.wheels {
                    let stats = CartSetup(character: character, frame: frame, wheels: wheels).stats
                    XCTAssertGreaterThan(stats.topSpeed, 15)
                    XCTAssertLessThan(stats.topSpeed, 34)
                    XCTAssertGreaterThan(stats.acceleration, 5)
                    XCTAssertGreaterThan(stats.grip, 3)
                    XCTAssertGreaterThan(stats.turnRate, 1.4)
                    XCTAssertTrue((0...1).contains(stats.luck))
                }
            }
        }
    }

    func testEveryCombinationRendersFiveStatBars() {
        for character in Roster.characters {
            let bars = Roster.defaultSetup(for: character).displayBars
            XCTAssertEqual(bars.count, 5)
            for bar in bars {
                XCTAssertTrue((1...5).contains(bar.value), "\(character.name) \(bar.label) = \(bar.value)")
            }
        }
    }
}
