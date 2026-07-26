import Foundation

/// Personality and short-term memory for one computer-controlled shopper.
///
/// The AI is a lookahead pursuit controller: it aims at a point up the road,
/// works out how fast that corner can be taken, and drifts when the angle gets
/// big. Personality knobs stop the field from driving like five clones.
public struct AIProfile: Sendable {
    /// 0...1 overall competence, from difficulty plus a per-driver wobble.
    public var skill: Double
    /// Multiplier on the corner speed the driver believes it can carry.
    public var bravery: Double
    /// Proportional gain on the heading error.
    public var steerGain: Double
    /// Preferred offset from the centreline, in metres.
    public var lineBias: Double
    /// How eagerly this driver cuts to the inside of a corner.
    public var cornerCutting: Double
    public var aggression: Double

    var wanderPhase: Double
    var wanderRate: Double
    var wanderAmplitude: Double
    var itemCooldown: Double
    var mistakeTimer: Double
    var mistakeSteer: Double
    /// Keeps a drift committed through a corner. Without this the AI lets go the
    /// instant the heading error dips and never banks a mini-turbo.
    var driftHold: Double
    var random: DeterministicRandom

    public init(racer: Racer, difficulty: Difficulty, random source: inout DeterministicRandom) {
        var local = DeterministicRandom(seed: source.next())
        let base = difficulty.aiSkill
        skill = Scalar.clamp(base + local.nextDouble(in: -0.12...0.08), 0.05, 1)
        bravery = Scalar.lerp(0.72, 1.04, skill) + local.nextDouble(in: -0.04...0.04)
        steerGain = Scalar.lerp(1.5, 2.6, skill)
        lineBias = local.nextDouble(in: -1.8...1.8)
        cornerCutting = Scalar.lerp(30, 95, skill)
        // Heavier carts throw their weight around more.
        aggression = Scalar.clamp(racer.stats.weight * 0.6 + skill * 0.4, 0, 1)
        wanderPhase = local.nextDouble(in: 0...(2 * .pi))
        wanderRate = local.nextDouble(in: 0.25...0.6)
        wanderAmplitude = Scalar.lerp(1.6, 0.35, skill)
        itemCooldown = local.nextDouble(in: 0.2...1.2)
        mistakeTimer = 0
        mistakeSteer = 0
        driftHold = 0
        random = local
    }
}

extension RaceSimulation {
    /// Produces one frame of input for an AI cart.
    func aiInput(for index: Int) -> DriverInput {
        let cart = carts[index]
        guard var profile = aiProfiles[cart.id] else { return .flatOut }
        let h = tuning.fixedTimeStep

        profile.wanderPhase += h * profile.wanderRate * 2 * .pi
        profile.itemCooldown = max(0, profile.itemCooldown - h)

        // Occasional lapses in concentration, more often for weaker drivers.
        if profile.mistakeTimer > 0 {
            profile.mistakeTimer -= h
        } else if profile.random.nextBool(probability: (1 - profile.skill) * 0.35 * h) {
            profile.mistakeTimer = profile.random.nextDouble(in: 0.3...0.9)
            profile.mistakeSteer = profile.random.nextDouble(in: -0.55...0.55)
        }

        let speed = cart.forwardSpeed
        let lookahead = Scalar.clamp(7 + speed * 0.85, 8, 30)
        let aimDistance = cart.distance + lookahead
        let halfWidth = geometry.halfWidth(at: aimDistance)

        // Aim towards the inside of whatever is coming up.
        let upcomingCurvature = geometry.curvature(at: cart.distance + lookahead * 0.5, window: 16)
        var lateralTarget = profile.lineBias
        lateralTarget += sin(profile.wanderPhase) * profile.wanderAmplitude
        lateralTarget += Scalar.clamp(upcomingCurvature * profile.cornerCutting, -halfWidth * 0.7, halfWidth * 0.7)

        // Detour towards a crate if the slot is empty and one is roughly on line.
        if cart.heldItem == nil, let boxLateral = itemBoxLateral(near: aimDistance, within: 14, of: cart) {
            lateralTarget = Scalar.lerp(lateralTarget, boxLateral, 0.65)
        }

        lateralTarget = Scalar.clamp(lateralTarget, -halfWidth * 0.88, halfWidth * 0.88)
        lateralTarget = clearLane(
            for: cart,
            aimDistance: aimDistance,
            preferred: lateralTarget,
            halfWidth: halfWidth
        )

        let aimPoint = geometry.position(at: aimDistance, lateral: lateralTarget)
        let desiredHeading = (aimPoint - cart.position).angle
        let headingError = Scalar.angleDelta(from: cart.heading, to: desiredHeading)

        var steer = Scalar.clamp(headingError * profile.steerGain, -1, 1)
        if profile.mistakeTimer > 0 { steer = Scalar.clamp(steer + profile.mistakeSteer, -1, 1) }

        // How fast can the next stretch actually be taken?
        let scanRange = max(12.0, speed * 1.4)
        let worstCurvature = geometry.maxAbsCurvature(at: cart.distance + 2, range: scanRange)
        let lateralCapacity = 9.5 * cart.tuning.gripMultiplier * cart.surface.lateralGrip / 6.0 * profile.bravery
        var cornerSpeed = Double.infinity
        if worstCurvature > 1e-4 {
            // Two separate limits: how much grip there is, and how fast the cart
            // can physically rotate. Ignoring the second one has the AI arriving
            // at hairpins far too quickly to steer round them.
            let gripLimit = (lateralCapacity / worstCurvature).squareRoot()
            let yawRate = cart.isDrifting ? cart.tuning.driftTurnRate : cart.tuning.baseTurnRate
            let steeringLimit = yawRate / worstCurvature
            cornerSpeed = min(gripLimit, steeringLimit)
        }

        var throttle = 1.0
        if speed > cornerSpeed + 2.0 {
            throttle = -0.55
        } else if speed > cornerSpeed {
            // Coast rather than lifting off completely, which would drop the
            // drift and throw away the mini-turbo.
            throttle = 0.25
        }
        if cart.isOffRoad {
            // Point back at the track rather than flooring it through the debris.
            throttle = min(throttle, 0.65)
        }
        if abs(headingError) > 1.6 {
            // Facing the wrong way entirely: reverse out of it.
            throttle = -0.6
            steer = -steer
        }

        // Commit to a drift for a beat rather than flickering in and out of it,
        // which is what actually earns the mini-turbo at the corner exit.
        // Only worthwhile in a genuinely tight corner: sliding through gentle
        // bends scrubs off more speed than the mini-turbo pays back.
        profile.driftHold = max(0, profile.driftHold - h)
        let tightCorner = worstCurvature > 0.05 || abs(headingError) > 0.4
        let stillCornering = worstCurvature > 0.035 || abs(headingError) > 0.22
        let canDrift = aiDriftingEnabled
            && profile.skill > 0.5
            && speed > tuning.driftMinimumSpeed + 1.5
            && throttle > 0.05
            && !cart.surface.isSlippery
        if canDrift, tightCorner || (cart.isDrifting && stillCornering) {
            profile.driftHold = max(profile.driftHold, 0.7)
        }
        // The drift direction is locked in when it starts, so only commit once the
        // steering already agrees with where the corner goes. Committing on a
        // transient flick locks the cart into sliding the wrong way for the whole
        // corner.
        let cornerDirection = Scalar.signum(geometry.curvature(at: cart.distance + lookahead * 0.5, window: 16))
        let steerAgreesWithCorner = cornerDirection == 0 || Scalar.signum(steer) == cornerDirection
        let drift = canDrift
            && profile.driftHold > 0
            && (cart.isDrifting || (abs(steer) > 0.25 && steerAgreesWithCorner))

        // The AI is deliberately allowed to counter-steer all the way to the
        // bail-out. Forcing it to hold every drift banks more mini-turbos but
        // costs whole seconds a lap in scenery, and abandoning a drift that is
        // not working is the faster line.
        let useItem = shouldUseItem(cart: cart, profile: &profile, worstCurvature: worstCurvature, speed: speed)

        aiProfiles[cart.id] = profile
        return DriverInput(throttle: throttle, steer: steer, drift: drift, useItem: useItem)
    }

    /// Picks the lateral offset with the most room, staying as close to the
    /// preferred racing line as the scenery allows.
    ///
    /// Nudging the aim point away from each obstacle in turn does not work: a
    /// row of three cones cancels itself out and the AI drives into the middle
    /// one. Scoring candidate lanes on clearance fixes that.
    private func clearLane(
        for cart: CartState,
        aimDistance: Double,
        preferred: Double,
        halfWidth: Double
    ) -> Double {
        // Only scenery straddling the aim point can matter.
        let window = 4.5 + cart.tuning.radius
        var blockers: [(lateral: Double, radius: Double)] = []

        for (index, obstacle) in configuration.track.definition.obstacles.enumerated() {
            guard obstacleLocations.indices.contains(index) else { continue }
            let location = obstacleLocations[index]
            guard abs(geometry.signedGap(from: aimDistance, to: location.distance)) < window else { continue }
            blockers.append((location.lateral, obstacle.radius))
        }
        for hazard in hazards where hazard.ownerID != cart.id {
            guard abs(geometry.signedGap(from: aimDistance, to: hazard.trackDistance)) < window else { continue }
            blockers.append((hazard.trackLateral, hazard.kind.radius))
        }

        guard !blockers.isEmpty else { return preferred }

        let edge = halfWidth * 0.9
        var bestLateral = preferred
        var bestScore = -Double.infinity
        var candidate = -edge
        while candidate <= edge {
            var clearance = 6.0
            for blocker in blockers {
                clearance = min(clearance, abs(candidate - blocker.lateral) - blocker.radius)
            }
            // Prefer room, but do not throw away the racing line for it.
            let score = min(clearance, 3.0) * 1.6 - abs(candidate - preferred) * 0.5
            if score > bestScore {
                bestScore = score
                bestLateral = candidate
            }
            candidate += 0.8
        }
        return bestLateral
    }

    /// The lateral offset of a nearby, available crate, if there is one worth
    /// steering for.
    private func itemBoxLateral(near distance: Double, within range: Double, of cart: CartState) -> Double? {
        var best: Double?
        var bestGap = range
        for box in itemBoxes where box.isAvailable {
            let gap = geometry.signedGap(from: cart.distance, to: box.trackDistance)
            guard gap > 0, gap < bestGap else { continue }
            bestGap = gap
            best = box.trackLateral
        }
        return best
    }

    private func shouldUseItem(
        cart: CartState,
        profile: inout AIProfile,
        worstCurvature: Double,
        speed: Double
    ) -> Bool {
        guard let item = cart.heldItem, profile.itemCooldown <= 0, !cart.hasFinished else { return false }

        var fire = false
        switch item {
        case .energyDrink:
            // Save it for something resembling a straight.
            fire = worstCurvature < 0.022 && speed > cart.tuning.topSpeed * 0.55 && cart.boostTimer <= 0
        case .crateShield:
            fire = true
        case .expressLane:
            fire = true
        case .clearanceAnnouncement:
            fire = cart.racePosition > 1 && profile.random.nextBool(probability: 0.03)
        case .sodaCan:
            fire = hasTarget(ahead: true, of: cart, within: 34, cone: 0.5)
        case .greaseSlick:
            fire = hasTarget(ahead: false, of: cart, within: 22, cone: 1.1)
                || profile.random.nextBool(probability: 0.004)
        }

        if fire { profile.itemCooldown = 0.75 }
        return fire
    }

    private func hasTarget(ahead: Bool, of cart: CartState, within range: Double, cone: Double) -> Bool {
        let reference = ahead ? cart.heading : Scalar.normalizeAngle(cart.heading + .pi)
        for other in carts where other.id != cart.id && !other.hasFinished {
            let offset = other.position - cart.position
            let distance = offset.length
            guard distance < range else { continue }
            guard abs(Scalar.angleDelta(from: reference, to: offset.angle)) < cone else { continue }
            return true
        }
        return false
    }
}
