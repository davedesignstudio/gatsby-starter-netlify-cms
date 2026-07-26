import Foundation

/// Arcade top-down driving model: grippy forward motion, damped lateral slide,
/// and a drift mode that trades grip for a mini-turbo.
public enum KartPhysics {
    /// Result of one physics step that the engine may want to react to.
    public struct StepOutcome: Sendable {
        public var releasedTier: DriftTier = .none
        public var hitWall: Bool = false
    }

    public static func step(
        kart: inout KartState,
        input: RaceInput,
        track: Track,
        tuning: RaceTuning,
        speedBonus: Double,
        dt: Double
    ) -> StepOutcome {
        var outcome = StepOutcome()

        advanceTimers(&kart, tuning: tuning, dt: dt)

        let controllable = kart.disruption?.allowsControl ?? true
        var steerInput = controllable ? clamp(input.steer, -1, 1) : 0
        var throttleInput = clamp(input.throttle, -1, 1)
        if let disruption = kart.disruption, !disruption.allowsControl {
            // Spun out or flattened: no drive, just carry the remaining momentum.
            throttleInput = 0
        }
        if kart.isFinished {
            // Finished carts coast to the shop exit on autopilot.
            throttleInput = min(throttleInput, 0.45)
        }

        // MARK: Surface response
        var speedMultiplier = 1.0
        var gripMultiplier = 1.0
        var extraDrag = 0.0
        switch kart.surface {
        case .tile:
            break
        case .rough:
            if !kart.isInvincible {
                speedMultiplier *= kart.physics.roughPenalty
                gripMultiplier *= 0.85
                extraDrag = 1.9
            }
        case .slick:
            speedMultiplier *= tuning.slickSpeedMultiplier
            gripMultiplier *= tuning.slickGripMultiplier
        }
        if kart.disruption == .cloud {
            speedMultiplier *= 0.72
        }
        if kart.disruption == .slip {
            gripMultiplier *= 0.2
            steerInput = 0
        }
        if kart.isInvincible {
            speedMultiplier *= tuning.bulkBuySpeedMultiplier
        }
        speedMultiplier *= speedBonus

        // MARK: Drift
        updateDrift(
            &kart,
            input: input,
            steerInput: steerInput,
            controllable: controllable,
            tuning: tuning,
            outcome: &outcome,
            dt: dt
        )

        var effectiveSteer = steerInput
        if kart.isDrifting {
            // Locked into an arc, with limited authority to tighten or open it.
            let bias = kart.driftDirection * tuning.driftSteerBias
            let modulation = steerInput * 0.45
            effectiveSteer = clamp(bias + modulation, -1, 1) * tuning.driftSteerMultiplier
            gripMultiplier *= tuning.driftGripMultiplier
        }

        // MARK: Steering
        let speed = kart.velocity.length
        let topSpeed = kart.physics.topSpeed * speedMultiplier
        // A trolley standing still does not turn; authority ramps in with speed
        // and tapers off again at the top end so straights stay stable.
        let rampIn = clamp(speed / tuning.steerSpeedFloor, 0, 1)
        let taper = 1 - tuning.steerSpeedFalloff * clamp(speed / max(topSpeed, 1), 0, 1)
        // Reversing flips the steering, as pushing a trolley backwards does.
        let reverseSign: Double = kart.velocity.dot(Vec2.direction(kart.heading)) < -12 ? -1 : 1
        let steerRate = effectiveSteer * tuning.maxSteerRate * rampIn * taper * reverseSign
        kart.heading = Angle.normalize(kart.heading + steerRate * dt)
        kart.steerVisual = approach(kart.steerVisual, effectiveSteer, rate: 12, dt: dt)
        let targetLean = kart.isDrifting ? kart.driftDirection * 0.42 : 0
        kart.driftLean = approach(kart.driftLean, targetLean, rate: 8, dt: dt)

        // MARK: Longitudinal
        let newForward = Vec2.direction(kart.heading)
        let newRight = -newForward.perpendicular
        var forwardSpeed = kart.velocity.dot(newForward)
        var lateralSpeed = kart.velocity.dot(newRight)

        if kart.boostTimer > 0 {
            let boostTarget = topSpeed * tuning.boostSpeedMultiplier * kart.boostStrength
            if forwardSpeed < boostTarget {
                forwardSpeed = min(boostTarget, forwardSpeed + tuning.boostAcceleration * dt)
            }
        } else if throttleInput > 0 {
            if forwardSpeed < topSpeed {
                let headroom = clamp(1 - forwardSpeed / max(topSpeed, 1), 0.18, 1)
                forwardSpeed += kart.physics.acceleration * throttleInput * headroom * dt
            } else {
                forwardSpeed = approach(forwardSpeed, topSpeed, rate: 2.2, dt: dt)
            }
        } else if throttleInput < 0 {
            if forwardSpeed > 0 {
                forwardSpeed = max(0, forwardSpeed - tuning.brakeForce * dt)
            } else {
                forwardSpeed = max(-tuning.reverseTopSpeed, forwardSpeed + throttleInput * kart.physics.acceleration * 0.6 * dt)
            }
        } else {
            forwardSpeed = approach(forwardSpeed, 0, rate: tuning.rollingDrag, dt: dt)
        }

        if extraDrag > 0 {
            forwardSpeed = approach(forwardSpeed, min(forwardSpeed, topSpeed), rate: extraDrag, dt: dt)
        }
        if kart.boostTimer <= 0 && forwardSpeed > topSpeed {
            // Bleed off leftover boost speed rather than cutting it dead.
            forwardSpeed = approach(forwardSpeed, topSpeed, rate: 1.6, dt: dt)
        }

        // Lateral velocity decays exponentially: high grip means the cart goes
        // where it points, low grip means it slides like a bad castor wheel.
        let grip = kart.physics.grip * gripMultiplier
        lateralSpeed *= exp(-grip * dt)

        if let disruption = kart.disruption, !disruption.allowsControl {
            let decay: Double = disruption == .squash ? 4.0 : 2.4
            forwardSpeed = approach(forwardSpeed, 0, rate: decay, dt: dt)
            lateralSpeed = approach(lateralSpeed, 0, rate: decay, dt: dt)
        }

        kart.velocity = newForward * forwardSpeed + newRight * lateralSpeed
        kart.position += kart.velocity * dt

        // MARK: Walls
        if resolveWalls(&kart, track: track, tuning: tuning) {
            outcome.hitWall = true
        }

        return outcome
    }

    // MARK: - Helpers

    private static func advanceTimers(_ kart: inout KartState, tuning: RaceTuning, dt: Double) {
        kart.boostTimer = max(0, kart.boostTimer - dt)
        if kart.boostTimer == 0 { kart.boostStrength = 1 }
        kart.bulkBuyTimer = max(0, kart.bulkBuyTimer - dt)
        kart.invulnerabilityTimer = max(0, kart.invulnerabilityTimer - dt)

        if kart.disruption != nil {
            kart.disruptionTimer -= dt
            if kart.disruption == .spin || kart.disruption == .squash {
                kart.spinVisual = Angle.normalize(kart.spinVisual + 11 * dt)
            }
            if kart.disruptionTimer <= 0 {
                kart.disruption = nil
                kart.disruptionTimer = 0
                kart.spinVisual = 0
                kart.invulnerabilityTimer = max(kart.invulnerabilityTimer, tuning.invulnerabilityAfterHit)
            }
        } else if kart.spinVisual != 0 {
            kart.spinVisual = 0
        }

        if kart.itemRouletteTimer > 0 {
            kart.itemRouletteTimer = max(0, kart.itemRouletteTimer - dt)
            if kart.itemRouletteTimer == 0, let pending = kart.pendingItem {
                kart.item = HeldItem(kind: pending)
                kart.pendingItem = nil
            }
        }
    }

    private static func updateDrift(
        _ kart: inout KartState,
        input: RaceInput,
        steerInput: Double,
        controllable: Bool,
        tuning: RaceTuning,
        outcome: inout StepOutcome,
        dt: Double
    ) {
        let speed = kart.velocity.length
        let wantsDrift = input.isDrifting && controllable && !kart.isFinished

        if kart.isDrifting {
            let stillValid = wantsDrift && speed > tuning.driftMinimumSpeed * 0.6
            if stillValid {
                // Charge faster when actually steering into the drift.
                let commitment = 0.55 + 0.45 * clamp(steerInput * kart.driftDirection + 0.6, 0, 1)
                kart.driftCharge += dt * kart.physics.driftCharge * commitment
                kart.driftTier = tier(for: kart.driftCharge, tuning: tuning)
            } else {
                let tier = kart.driftTier
                if tier != .none {
                    let duration = tuning.miniTurboBoostDurations[tier.rawValue - 1]
                    applyBoost(&kart, duration: duration, strength: 1 + 0.06 * Double(tier.rawValue - 1))
                    outcome.releasedTier = tier
                }
                kart.isDrifting = false
                kart.driftDirection = 0
                kart.driftCharge = 0
                kart.driftTier = .none
            }
        } else if wantsDrift && speed > tuning.driftMinimumSpeed && abs(steerInput) > 0.15 {
            kart.isDrifting = true
            kart.driftDirection = steerInput > 0 ? 1 : -1
            kart.driftCharge = 0
            kart.driftTier = .none
        }
    }

    private static func tier(for charge: Double, tuning: RaceTuning) -> DriftTier {
        var result = DriftTier.none
        for (index, threshold) in tuning.miniTurboThresholds.enumerated() where charge >= threshold {
            result = DriftTier(rawValue: index + 1) ?? result
        }
        return result
    }

    /// Adds a boost, keeping the stronger/longer of the current and new one.
    public static func applyBoost(_ kart: inout KartState, duration: Double, strength: Double = 1) {
        kart.boostStrength = max(kart.boostStrength, strength)
        kart.boostTimer = max(kart.boostTimer, duration)
    }

    /// Applies a hit, respecting invincibility and hit severity.
    @discardableResult
    public static func applyDisruption(
        _ kart: inout KartState,
        _ disruption: Disruption,
        tuning: RaceTuning
    ) -> Bool {
        guard kart.canBeHit else { return false }
        if let current = kart.disruption, current.severity > disruption.severity { return false }
        kart.disruption = disruption
        switch disruption {
        case .spin: kart.disruptionTimer = tuning.spinOutDuration
        case .slip: kart.disruptionTimer = tuning.slipDuration
        case .squash: kart.disruptionTimer = tuning.squashDuration
        case .cloud: kart.disruptionTimer = 2.0
        }
        if !disruption.allowsControl {
            kart.isDrifting = false
            kart.driftCharge = 0
            kart.driftTier = .none
            kart.boostTimer = 0
            kart.boostStrength = 1
        }
        return true
    }

    /// Keeps carts inside the shelving. Returns true on a fresh wall contact.
    @discardableResult
    private static func resolveWalls(_ kart: inout KartState, track: Track, tuning: RaceTuning) -> Bool {
        let projection = track.project(kart.position, hint: kart.sampleHint)
        kart.sampleHint = projection.sampleIndex
        let limit = projection.halfWidth + track.shoulderWidth - tuning.cartRadius
        guard abs(projection.lateralOffset) > limit else { return false }

        let normalSign: Double = projection.lateralOffset > 0 ? -1 : 1
        let normal = projection.tangent.perpendicular * normalSign
        let penetration = abs(projection.lateralOffset) - limit
        kart.position += normal * penetration

        let into = kart.velocity.dot(normal)
        if into < 0 {
            // Reflect the inward component and scrub speed along the shelf.
            kart.velocity -= normal * into * (1 + tuning.wallRestitution)
            kart.velocity *= (1 - tuning.wallSpeedLoss * 0.35)
            kart.isDrifting = false
            kart.driftCharge = 0
            kart.driftTier = .none
            return true
        }
        return false
    }
}
