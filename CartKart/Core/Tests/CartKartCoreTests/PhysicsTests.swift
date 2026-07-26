import XCTest
@testable import CartKartCore

final class PhysicsTests: XCTestCase {
    /// Wide enough that a cart can hold an input for several seconds without
    /// running out of aisle, so these tests measure the driving model rather
    /// than the shape of a particular course.
    private let track = TestTracks.wideOval
    private let tuning = RaceTuning.default

    /// Places a cart on the centreline at a given fraction of a lap.
    private func makeKart(
        profileID: String = "chrome",
        on track: Track? = nil,
        atFraction fraction: Double = 0.0
    ) -> KartState {
        let course = track ?? self.track
        let index = course.sampleIndex(atArcLength: fraction * course.trackLength)
        let sample = course.sample(at: index)
        var kart = KartState(
            id: 0,
            profile: Roster.profile(id: profileID),
            tuning: tuning,
            isPlayerControlled: true,
            position: sample.position,
            heading: sample.tangent.angle
        )
        let projection = course.project(kart.position)
        kart.arcLength = projection.arcLength
        kart.sampleHint = projection.sampleIndex
        return kart
    }

    @discardableResult
    private func run(
        _ kart: inout KartState,
        input: RaceInput,
        seconds: Double,
        on track: Track? = nil,
        surface: SurfaceKind? = nil,
        onStep: ((KartState, KartPhysics.StepOutcome) -> Void)? = nil
    ) -> KartPhysics.StepOutcome {
        let course = track ?? self.track
        var last = KartPhysics.StepOutcome()
        for _ in 0..<Int(seconds / tuning.fixedTimeStep) {
            kart.surface = surface ?? course.surface(at: kart.position, hint: kart.sampleHint)
            last = KartPhysics.step(
                kart: &kart,
                input: input,
                track: course,
                tuning: tuning,
                speedBonus: 1,
                dt: tuning.fixedTimeStep
            )
            onStep?(kart, last)
        }
        return last
    }

    /// Drives along the centreline, for runs long enough that the course
    /// curvature would otherwise put the cart in a shelf.
    private func runFollowingLane(
        _ kart: inout KartState,
        seconds: Double,
        throttle: Double = 1,
        surface: SurfaceKind? = nil
    ) {
        for _ in 0..<Int(seconds / tuning.fixedTimeStep) {
            kart.surface = surface ?? track.surface(at: kart.position, hint: kart.sampleHint)
            let projection = track.project(kart.position, hint: kart.sampleHint)
            let target = track.position(atArcLength: projection.arcLength + 260)
            let steer = clamp(Angle.delta(from: kart.heading, to: (target - kart.position).angle) * 2.2, -1, 1)
            _ = KartPhysics.step(
                kart: &kart,
                input: RaceInput(throttle: throttle, steer: steer),
                track: track,
                tuning: tuning,
                speedBonus: 1,
                dt: tuning.fixedTimeStep
            )
        }
    }

    func testCartAcceleratesTowardsItsTopSpeed() {
        var kart = makeKart()
        runFollowingLane(&kart, seconds: 8, surface: .tile)
        XCTAssertGreaterThan(kart.speed, kart.physics.topSpeed * 0.9)
        XCTAssertLessThan(kart.speed, kart.physics.topSpeed * 1.02)
    }

    func testStatsChangeTheDrivingCharacter() {
        var quick = makeKart(profileID: "squeaks")
        var fast = makeKart(profileID: "rusty")
        run(&quick, input: .fullThrottle, seconds: 1.0, surface: .tile)
        run(&fast, input: .fullThrottle, seconds: 1.0, surface: .tile)
        XCTAssertGreaterThan(quick.speed, fast.speed, "the acceleration stat should win a short drag")

        var quickLong = makeKart(profileID: "squeaks")
        var fastLong = makeKart(profileID: "rusty")
        runFollowingLane(&quickLong, seconds: 8, surface: .tile)
        runFollowingLane(&fastLong, seconds: 8, surface: .tile)
        XCTAssertGreaterThan(fastLong.speed, quickLong.speed, "the speed stat should win a long run")
        XCTAssertGreaterThan(
            fastLong.speed,
            fastLong.physics.topSpeed * 0.85,
            "the cart should still be flying, not parked in the shelving"
        )
    }

    func testBrakingAndReversing() {
        var kart = makeKart()
        run(&kart, input: .fullThrottle, seconds: 4, surface: .tile)
        let cruising = kart.speed
        XCTAssertGreaterThan(cruising, 300)
        run(&kart, input: RaceInput(throttle: -1), seconds: 1.0, surface: .tile)
        XCTAssertLessThan(kart.speed, cruising * 0.5)
        run(&kart, input: RaceInput(throttle: -1), seconds: 2.5, surface: .tile)
        XCTAssertLessThan(kart.forwardSpeed, -20, "holding brake from a standstill should reverse")
    }

    func testRoughGroundCostsSpeed() {
        var onTile = makeKart()
        var offLane = makeKart()
        run(&onTile, input: .fullThrottle, seconds: 5, surface: .tile)
        run(&offLane, input: .fullThrottle, seconds: 5, surface: .rough)
        XCTAssertLessThan(offLane.speed, onTile.speed * 0.9)
    }

    func testAllTerrainStatSoftensTheRough() {
        var bertha = makeKart(profileID: "bertha")  // all-terrain 5
        var sprout = makeKart(profileID: "sprout")  // all-terrain 1
        run(&bertha, input: .fullThrottle, seconds: 5, surface: .rough)
        run(&sprout, input: .fullThrottle, seconds: 5, surface: .rough)
        XCTAssertGreaterThan(
            bertha.speed / bertha.physics.topSpeed,
            sprout.speed / sprout.physics.topSpeed
        )
    }

    func testSlickFloorRemovesGrip() {
        var grippy = makeKart()
        var slippery = makeKart()
        run(&grippy, input: .fullThrottle, seconds: 3, surface: .tile)
        run(&slippery, input: .fullThrottle, seconds: 3, surface: .slick)
        let turning = RaceInput(throttle: 1, steer: 1)
        // With no grip the cart keeps sliding the way it was going, so the
        // velocity direction lags much further behind the heading.
        run(&grippy, input: turning, seconds: 0.8, surface: .tile)
        run(&slippery, input: turning, seconds: 0.8, surface: .slick)
        let grippySlip = abs(Angle.delta(from: grippy.heading, to: grippy.velocity.angle))
        let slipperySlip = abs(Angle.delta(from: slippery.heading, to: slippery.velocity.angle))
        XCTAssertGreaterThan(slipperySlip, grippySlip)
    }

    func testSteeringNeedsSpeed() {
        var parked = makeKart()
        let headingBefore = parked.heading
        run(&parked, input: RaceInput(throttle: 0, steer: 1), seconds: 1.0, surface: .tile)
        XCTAssertEqual(parked.heading, headingBefore, accuracy: 0.05, "a stationary trolley should barely turn")

        var rolling = makeKart()
        run(&rolling, input: .fullThrottle, seconds: 3, surface: .tile)
        let before = rolling.heading
        run(&rolling, input: RaceInput(throttle: 1, steer: 1), seconds: 1.0, surface: .tile)
        XCTAssertGreaterThan(abs(Angle.delta(from: before, to: rolling.heading)), 0.5)
    }

    func testHardCorneringScrubsSpeed() {
        var straight = makeKart()
        var cornering = makeKart()
        run(&straight, input: .fullThrottle, seconds: 3, surface: .tile)
        run(&cornering, input: .fullThrottle, seconds: 3, surface: .tile)
        run(&straight, input: .fullThrottle, seconds: 1.5, surface: .tile)
        run(&cornering, input: RaceInput(throttle: 1, steer: 1), seconds: 1.5, surface: .tile)
        XCTAssertLessThan(cornering.speed, straight.speed * 0.95, "yanking the trolley round should cost speed")
    }

    func testDriftChargesThroughEveryTierAndPaysOut() {
        var kart = makeKart()
        run(&kart, input: .fullThrottle, seconds: 3, surface: .tile)
        var reachedTiers: Set<DriftTier> = []
        let drifting = RaceInput(throttle: 1, steer: 1, isDrifting: true)
        run(&kart, input: drifting, seconds: 3.2, surface: .tile) { state, _ in
            reachedTiers.insert(state.driftTier)
        }
        XCTAssertTrue(kart.isDrifting)
        XCTAssertTrue(reachedTiers.contains(.squeak))
        XCTAssertTrue(reachedTiers.contains(.rattle))
        XCTAssertEqual(kart.driftTier, .rumble)

        // Releasing the drift button converts the charge into a boost.
        var released = DriftTier.none
        run(&kart, input: .fullThrottle, seconds: 0.1, surface: .tile) { _, outcome in
            if outcome.releasedTier != .none { released = outcome.releasedTier }
        }
        XCTAssertEqual(released, .rumble)
        XCTAssertTrue(kart.isBoosting)
        XCTAssertFalse(kart.isDrifting)
    }

    func testDriftNeedsSpeedAndSteering() {
        var slow = makeKart()
        run(&slow, input: RaceInput(throttle: 1, steer: 1, isDrifting: true), seconds: 0.3, surface: .tile)
        XCTAssertFalse(slow.isDrifting, "you cannot drift from walking pace")

        var straight = makeKart()
        run(&straight, input: .fullThrottle, seconds: 3, surface: .tile)
        run(&straight, input: RaceInput(throttle: 1, steer: 0, isDrifting: true), seconds: 0.5, surface: .tile)
        XCTAssertFalse(straight.isDrifting, "drifting requires a steering input to lean into")
    }

    func testDriftStatChargesFaster() {
        func chargeAfterASecond(_ id: String) -> Double {
            var kart = makeKart(profileID: id)
            run(&kart, input: .fullThrottle, seconds: 3, surface: .tile)
            run(&kart, input: RaceInput(throttle: 1, steer: 1, isDrifting: true), seconds: 1.0, surface: .tile)
            return kart.driftCharge
        }
        XCTAssertGreaterThan(chargeAfterASecond("wobble"), chargeAfterASecond("bertha"))
    }

    func testBoostRaisesSpeedAboveTheNormalLimit() {
        var kart = makeKart()
        run(&kart, input: .fullThrottle, seconds: 5, surface: .tile)
        let normalSpeed = kart.speed
        KartPhysics.applyBoost(&kart, duration: 1.5)
        run(&kart, input: .fullThrottle, seconds: 1.0, surface: .tile)
        XCTAssertGreaterThan(kart.speed, normalSpeed * 1.2)
        // ...and it bleeds back down once the boost ends.
        run(&kart, input: .fullThrottle, seconds: 3.0, surface: .tile)
        XCTAssertLessThan(kart.speed, normalSpeed * 1.05)
    }

    func testShelvesKeepCartsOnTheCourse() {
        let narrow = TestTracks.tightOval
        var kart = makeKart(on: narrow)
        // Aim hard into the shelving and hold it there.
        run(&kart, input: RaceInput(throttle: 1, steer: 1), seconds: 8, on: narrow, surface: .tile) { state, _ in
            let projection = narrow.project(state.position, hint: state.sampleHint)
            let limit = projection.halfWidth + narrow.shoulderWidth + 1
            XCTAssertLessThanOrEqual(abs(projection.lateralOffset), limit)
        }
    }

    func testSpinOutRemovesControlThenRecovers() {
        var kart = makeKart()
        run(&kart, input: .fullThrottle, seconds: 4, surface: .tile)
        let cruising = kart.speed
        XCTAssertTrue(KartPhysics.applyDisruption(&kart, .spin, tuning: tuning))
        run(&kart, input: .fullThrottle, seconds: 0.5, surface: .tile)
        XCTAssertLessThan(kart.speed, cruising * 0.8)
        XCTAssertNotNil(kart.disruption)
        run(&kart, input: .fullThrottle, seconds: 1.2, surface: .tile)
        XCTAssertNil(kart.disruption, "the spin should end on its own")
        XCTAssertGreaterThan(kart.invulnerabilityTimer, 0, "brief mercy window after a hit")
    }

    func testInvincibleAndInvulnerableCartsIgnoreHits() {
        var kart = makeKart()
        kart.bulkBuyTimer = 3
        XCTAssertFalse(KartPhysics.applyDisruption(&kart, .spin, tuning: tuning))
        var recovering = makeKart()
        recovering.invulnerabilityTimer = 1
        XCTAssertFalse(KartPhysics.applyDisruption(&recovering, .spin, tuning: tuning))
    }

    func testStrongerHitsOverrideWeakerOnes() {
        var kart = makeKart()
        XCTAssertTrue(KartPhysics.applyDisruption(&kart, .cloud, tuning: tuning))
        XCTAssertTrue(KartPhysics.applyDisruption(&kart, .squash, tuning: tuning))
        XCTAssertEqual(kart.disruption, .squash)
        // A lesser effect cannot downgrade a squash.
        XCTAssertFalse(KartPhysics.applyDisruption(&kart, .spin, tuning: tuning))
        XCTAssertEqual(kart.disruption, .squash)
    }
}
