import Foundation

// MARK: - Cart dynamics
//
// The model is deliberately arcade: a heading that the steering rotates
// directly, a forward speed driven by an engine curve, and a lateral velocity
// that surface grip drags back into line. Understeer, drifts and spinouts all
// fall out of those three pieces rather than being special-cased.
extension RaceSimulation {
    func integrate(cartIndex index: Int, input rawInput: DriverInput, delta h: Double) {
        var cart = carts[index]

        cart.boostTimer = max(0, cart.boostTimer - h)
        if cart.boostTimer == 0 { cart.boostStrength = 0 }
        cart.spinoutTimer = max(0, cart.spinoutTimer - h)
        cart.stallTimer = max(0, cart.stallTimer - h)
        cart.slipTimer = max(0, cart.slipTimer - h)
        cart.invulnerabilityTimer = max(0, cart.invulnerabilityTimer - h)
        cart.scrapeIntensity = max(0, cart.scrapeIntensity - h * 4)
        cart.shieldAngle = (cart.shieldAngle + h * 3.2).truncatingRemainder(dividingBy: 2 * .pi)

        if cart.expressLaneTimer > 0 {
            cart.expressLaneTimer = max(0, cart.expressLaneTimer - h)
            cart.invulnerabilityTimer = max(cart.invulnerabilityTimer, 0.4)
            advanceExpressLane(&cart, delta: h)
            carts[index] = cart
            return
        }

        var input = rawInput
        if cart.spinoutTimer > 0 {
            input = DriverInput(throttle: 0, steer: 0, drift: false, useItem: input.useItem)
        }
        if cart.stallTimer > 0 {
            input.throttle = min(input.throttle, 0)
        }

        let surface = cart.surface
        let perkWetBonus = cart.racer.perk == .wetFloorSpecialist && surface.isSlippery ? 2.0 : 1.0
        var lateralGrip = surface.lateralGrip * cart.tuning.gripMultiplier * perkWetBonus
        if cart.slipTimer > 0 { lateralGrip *= 0.22 }

        updateDrift(&cart, input: input, delta: h)
        if cart.isDrifting { lateralGrip *= tuning.driftGripScale }

        // MARK: Heading

        let forwardSpeedBefore = cart.forwardSpeed
        // Yaw rate rises with speed and then caps, which is what gives a cart a
        // roughly constant tight radius when shuffling about and progressively
        // more understeer as it gets going. A flat rate would let a cart at full
        // speed corner on a 4 m radius and make drifting pointless.
        // The floor lets a wedged trolley still pivot on the spot.
        let steeringAuthority = max(
            0.18,
            min(1, abs(forwardSpeedBefore) / (0.5 * cart.tuning.topSpeed))
        )
        let gripAuthority = Scalar.clamp(lateralGrip / 6.0, 0.5, 1.15)

        let headingBefore = cart.heading
        if cart.spinoutTimer > 0 {
            cart.heading = Scalar.normalizeAngle(cart.heading + cart.spinRate * h)
            cart.spinRate = Scalar.damp(cart.spinRate, 0, rate: 1.1, dt: h)
        } else if cart.isDrifting {
            // While sliding, steering modulates how tight the arc is instead of
            // choosing the direction. Steering away from the slide has to be able
            // to open the arc right out to roughly a 40 m radius: if the tightest
            // available line is still tighter than the corner, a drifting cart
            // can only ever spiral into the inside shelving.
            let alignment = Scalar.clamp(input.steer * cart.driftDirection, -1, 1)
            let tightness = 0.08 + 0.92 * (alignment * 0.5 + 0.5)
            let rate = cart.tuning.driftTurnRate * tightness * steeringAuthority
            cart.heading = Scalar.normalizeAngle(cart.heading + cart.driftDirection * rate * h)
        } else {
            let rate = cart.tuning.baseTurnRate * steeringAuthority * gripAuthority
            let direction = forwardSpeedBefore < -0.2 ? -1.0 : 1.0
            cart.heading = Scalar.normalizeAngle(cart.heading + input.steer * rate * direction * h)
        }

        // A drift has to be quick, not just showy. Carrying most of the velocity
        // round with the nose keeps the speed that the heading change would
        // otherwise dump into a sideways slide for friction to destroy — the
        // leftover fraction is the visible slide angle.
        if cart.isDrifting {
            let headingChange = Scalar.angleDelta(from: headingBefore, to: cart.heading)
            cart.velocity = cart.velocity.rotated(by: headingChange * 0.82)
        }

        // MARK: Longitudinal

        let forward = cart.forward
        let left = forward.perpendicular
        var alongSpeed = cart.velocity.dot(forward)
        var sideSpeed = cart.velocity.dot(left)

        let tokenBonus = 1 + Double(cart.tokens) * tuning.tokenSpeedBonus
        var topSpeed = cart.tuning.topSpeed * surface.topSpeedFactor * tokenBonus * cart.performanceScale
        var forceScale = 1.0
        if cart.boostTimer > 0 {
            topSpeed *= tuning.boostSpeedMultiplier * (0.94 + 0.06 * cart.boostStrength)
            forceScale = tuning.boostForceMultiplier
        }

        let longitudinalGrip = surface.longitudinalGrip
        if input.throttle > 0 {
            let headroom = max(0, 1 - alongSpeed / max(topSpeed, 0.5))
            alongSpeed += cart.tuning.enginePower * forceScale * longitudinalGrip * input.throttle * headroom * h
        } else if input.throttle < 0 {
            if alongSpeed > 0.3 {
                alongSpeed += cart.tuning.brakePower * longitudinalGrip * input.throttle * h
            } else {
                alongSpeed = max(-cart.tuning.reverseSpeed, alongSpeed + input.throttle * 6.5 * h)
            }
        }

        // Rolling resistance, plus extra scrub while spun out or sliding sideways.
        // It has to fall away near a standstill: at full strength the deep pile
        // carpet and the spilled-stock run-off out-drag a heavy cart's engine
        // entirely, and the cart can never get going again.
        let speedFraction = min(1, abs(alongSpeed) / max(cart.tuning.topSpeed, 1))
        var drag = surface.rollingResistance * (0.22 + 0.78 * speedFraction)
        if cart.spinoutTimer > 0 { drag += 7 }
        // Sliding sideways scrubs speed, but a controlled drift is supposed to be
        // the fast way round, so it pays far less of that penalty.
        drag += abs(sideSpeed) * (cart.isDrifting ? 0.12 : 0.35)
        alongSpeed -= Scalar.signum(alongSpeed) * drag * h
        if abs(alongSpeed) < 0.06, abs(input.throttle) < 0.05 { alongSpeed = 0 }

        // Bleed off anything above the current ceiling, which is what makes a
        // boost fade smoothly instead of falling off a cliff.
        if alongSpeed > topSpeed {
            alongSpeed = Scalar.damp(alongSpeed, topSpeed, rate: 2.6, dt: h)
        }

        // MARK: Lateral

        sideSpeed *= exp(-lateralGrip * h)
        if cart.isDrifting {
            // Kick the tail out so a drift reads as a drift on screen.
            sideSpeed -= cart.driftDirection * 2.2 * h
        }
        let sideLimit = 0.62 * abs(alongSpeed) + 2.2
        sideSpeed = Scalar.clamp(sideSpeed, -sideLimit, sideLimit)

        cart.velocity = forward * alongSpeed + left * sideSpeed
        cart.position += cart.velocity * h

        updateStuckState(&cart, input: input, delta: h)
        carts[index] = cart
    }

    private func updateDrift(_ cart: inout CartState, input: DriverInput, delta h: Double) {
        // Hysteresis on speed: a corner scrubs speed off, and losing the drift
        // (and its charge) halfway round for that reason feels like a bug.
        let threshold = cart.isDrifting ? tuning.driftMinimumSpeed * 0.7 : tuning.driftMinimumSpeed
        let fastEnough = cart.forwardSpeed > threshold
        let wantsDrift = input.drift && input.throttle > 0.05 && fastEnough && cart.spinoutTimer <= 0

        if wantsDrift {
            if cart.isDrifting {
                let chargeRate = cart.racer.perk == .driftCharger ? 1.35 : 1.0
                cart.driftCharge += h * chargeRate

                // Steering hard against the slide bails out of the drift. Without
                // this escape hatch a badly committed drift drags the cart across
                // the full width of the aisle with no way to stop it.
                // The threshold sits above the range used to widen the drift arc,
                // so only a deliberate full-lock counter-steer abandons it. The
                // charge is lost, and if the driver is still asking for a drift
                // it re-commits the other way on the next step — a flick, rather
                // than being locked into a slide going the wrong way.
                if input.steer * cart.driftDirection < -0.85 {
                    cart.counterSteerTimer += h
                    if cart.counterSteerTimer > 0.35 {
                        cart.isDrifting = false
                        cart.driftDirection = 0
                        cart.driftCharge = 0
                        cart.counterSteerTimer = 0
                    }
                } else {
                    cart.counterSteerTimer = 0
                }
            } else if abs(input.steer) > 0.18 {
                cart.isDrifting = true
                cart.driftDirection = Scalar.signum(input.steer)
                cart.driftCharge = 0
                cart.counterSteerTimer = 0
                emit(.driftStarted(cartID: cart.id))
            }
        } else if cart.isDrifting {
            releaseDrift(&cart)
        }
    }

    private func releaseDrift(_ cart: inout CartState) {
        let tier = cart.miniTurboTier(tuning: tuning)
        cart.isDrifting = false
        cart.driftDirection = 0
        cart.counterSteerTimer = 0
        let charge = cart.driftCharge
        cart.driftCharge = 0
        guard tier > 0 else { return }
        let duration = tuning.miniTurboDurations[min(tier - 1, tuning.miniTurboDurations.count - 1)]
        // A long hold past the top tier still only pays the top tier.
        _ = charge
        applyBoost(&cart, duration: duration, strength: 1.0 + 0.15 * Double(tier))
        emit(.miniTurbo(cartID: cart.id, tier: tier))
    }

    private func advanceExpressLane(_ cart: inout CartState, delta h: Double) {
        // Auto-pilot: hug the centreline and go.
        let aheadDistance = cart.distance + 9
        let target = geometry.position(at: aheadDistance, lateral: 0)
        let desired = (target - cart.position).angle
        cart.heading = Scalar.normalizeAngle(
            cart.heading + Scalar.angleDelta(from: cart.heading, to: desired) * min(1, 6 * h)
        )
        let speed = cart.tuning.topSpeed * tuning.expressLaneSpeedMultiplier
        cart.velocity = cart.forward * speed
        cart.position += cart.velocity * h
        cart.isDrifting = false
        cart.driftCharge = 0
        cart.spinoutTimer = 0
        cart.slipTimer = 0
        cart.stallTimer = 0
    }

    private func updateStuckState(_ cart: inout CartState, input: DriverInput, delta h: Double) {
        let tryingToMove = abs(input.throttle) > 0.25
        if cart.speed < tuning.stuckSpeedThreshold, tryingToMove, cart.spinoutTimer <= 0 {
            cart.stuckTimer += h
        } else {
            cart.stuckTimer = max(0, cart.stuckTimer - h * 2)
        }
    }

    // MARK: - Track bounds

    /// Keeps the cart on the premises and updates its lap progress. This is the
    /// one place where `travelled` advances, so lap counting is always tied to
    /// real distance covered.
    func resolveTrackBounds(cartIndex index: Int, delta h: Double) {
        var cart = carts[index]
        let location = geometry.location(of: cart.position, hint: cart.segmentHint)
        cart.segmentHint = location.segmentIndex

        cart.travelled += geometry.signedGap(from: cart.distance, to: location.distance)
        cart.distance = location.distance
        cart.lateral = location.lateral
        cart.isOffRoad = abs(location.lateral) > location.halfWidth
        cart.surface = cart.isOffRoad ? tuning.offRoadSurface : location.surface

        let limit = location.halfWidth + configuration.track.definition.shoulderWidth
        if abs(location.lateral) > limit {
            let outwardSign = Scalar.signum(location.lateral)
            let tangent = Vector2(angle: location.tangentAngle)
            let outward = tangent.perpendicular * outwardSign
            let excess = abs(location.lateral) - limit

            cart.position -= outward * excess
            let closingSpeed = cart.velocity.dot(outward)
            if closingSpeed > 0 {
                // Cancel the component into the shelving and keep sliding along
                // it. The speed penalty scales with how hard the hit was, so
                // brushing the shelves is cheap but resting against them is
                // free — otherwise a cart pinned to a wall never gets away.
                cart.velocity -= outward * closingSpeed * 1.05
                let intensity = Scalar.clamp(closingSpeed / 8, 0, 1)
                cart.velocity *= Scalar.lerp(1, tuning.wallSpeedRetention, intensity)
                if intensity > 0.08 {
                    cart.scrapeIntensity = max(cart.scrapeIntensity, intensity)
                    emit(.wallScrape(cartID: cart.id, intensity: intensity, position: cart.position))
                }
                cart.isDrifting = false
                cart.driftCharge = 0
            }
            cart.lateral = outwardSign * limit
        }

        if cart.stuckTimer > tuning.stuckDuration {
            respawn(&cart)
        }

        carts[index] = cart
    }

    private func respawn(_ cart: inout CartState) {
        let heading = geometry.tangentAngle(at: cart.distance)
        cart.position = geometry.position(at: cart.distance, lateral: 0)
        cart.heading = heading
        cart.velocity = Vector2(angle: heading, length: 4)
        cart.spinoutTimer = 0
        cart.slipTimer = 0
        cart.stuckTimer = 0
        cart.isDrifting = false
        cart.driftCharge = 0
        cart.invulnerabilityTimer = max(cart.invulnerabilityTimer, 1.2)
        emit(.respawned(cartID: cart.id))
    }

    // MARK: - Collisions

    func resolveCartCollisions() {
        guard carts.count > 1 else { return }
        for a in 0..<(carts.count - 1) {
            for b in (a + 1)..<carts.count {
                let cartA = carts[a]
                let cartB = carts[b]
                let combinedRadius = cartA.tuning.radius + cartB.tuning.radius
                let offset = cartB.position - cartA.position
                let distance = offset.length
                guard distance < combinedRadius, distance > 1e-6 else { continue }

                let normal = offset / distance
                let overlap = combinedRadius - distance

                // An express-lane cart is a battering ram, not a participant.
                if cartA.expressLaneTimer > 0 && cartB.expressLaneTimer <= 0 {
                    knockAside(index: b, from: normal)
                    continue
                }
                if cartB.expressLaneTimer > 0 && cartA.expressLaneTimer <= 0 {
                    knockAside(index: a, from: -normal)
                    continue
                }

                let massA = effectiveMass(cartA)
                let massB = effectiveMass(cartB)
                let total = massA + massB

                carts[a].position -= normal * (overlap * massB / total)
                carts[b].position += normal * (overlap * massA / total)

                let closing = (cartB.velocity - cartA.velocity).dot(normal)
                if closing < 0 {
                    let restitution = 0.35
                    let impulse = -(1 + restitution) * closing / (1 / massA + 1 / massB)
                    carts[a].velocity -= normal * (impulse / massA)
                    carts[b].velocity += normal * (impulse / massB)

                    let intensity = Scalar.clamp(-closing / 8, 0, 1)
                    if intensity > 0.15 {
                        let contact = cartA.position + normal * cartA.tuning.radius
                        emit(.cartBump(cartID: cartA.id, otherID: cartB.id, intensity: intensity, position: contact))
                    }
                }
            }
        }
    }

    private func effectiveMass(_ cart: CartState) -> Double {
        cart.racer.perk == .bulldozer ? cart.tuning.mass * 1.6 : cart.tuning.mass
    }

    private func knockAside(index: Int, from normal: Vector2) {
        carts[index].velocity += normal * 6
        applySpinout(cartIndex: index)
    }

    func resolveObstacleCollisions() {
        let obstacles = configuration.track.definition.obstacles
        guard !obstacles.isEmpty else { return }

        for index in carts.indices {
            var cart = carts[index]
            guard cart.expressLaneTimer <= 0 else { continue }
            for obstacle in obstacles {
                let combined = obstacle.radius + cart.tuning.radius
                let offset = cart.position - obstacle.position
                let distance = offset.length
                guard distance < combined, distance > 1e-6 else { continue }

                let normal = offset / distance
                cart.position += normal * (combined - distance)

                // Sliding contact: only the component driving into the prop is
                // removed, and the speed penalty is proportional to the impact.
                // Applying the full penalty on every frame of contact used to
                // pin carts against cones for good.
                let closing = -cart.velocity.dot(normal)
                if closing > 0 {
                    cart.velocity += normal * closing * (obstacle.kind.isSoft ? 1.0 : 1.1)
                    let impact = Scalar.clamp(closing / 6, 0, 1)
                    cart.velocity *= Scalar.lerp(1, obstacle.kind.speedRetention, impact)
                    cart.isDrifting = false
                    cart.driftCharge = 0

                    if !obstacle.kind.isSoft, closing > 4 {
                        cart.spinRate = Scalar.signum(normal.cross(cart.forward)) * 5
                        cart.spinoutTimer = max(cart.spinoutTimer, 0.35)
                    }
                    if closing > 1.5 {
                        emit(.obstacleHit(cartID: cart.id, kind: obstacle.kind, position: obstacle.position))
                    }
                }
            }
            carts[index] = cart
        }
    }

    // MARK: - Status effects

    func applyBoost(to index: Int, duration: Double, strength: Double) {
        var cart = carts[index]
        applyBoost(&cart, duration: duration, strength: strength)
        carts[index] = cart
    }

    func applyBoost(_ cart: inout CartState, duration: Double, strength: Double) {
        let scale = cart.racer.perk == .boostHoarder ? 1.3 : 1.0
        cart.boostTimer = max(cart.boostTimer, duration * scale)
        cart.boostStrength = max(cart.boostStrength, strength)
        cart.stallTimer = 0
        emit(.boostStarted(cartID: cart.id, strength: strength))
    }

    func applySpinout(cartIndex index: Int) {
        var cart = carts[index]
        guard cart.invulnerabilityTimer <= 0, cart.expressLaneTimer <= 0 else { return }

        if cart.shieldCharges > 0 {
            cart.shieldCharges -= 1
            cart.invulnerabilityTimer = 0.4
            emit(.shieldBlocked(cartID: cart.id, position: cart.position))
            carts[index] = cart
            return
        }

        let recovery = cart.racer.perk == .quickRecovery ? 0.7 : 1.0
        cart.spinoutTimer = tuning.spinoutDuration * recovery
        cart.invulnerabilityTimer = tuning.invulnerabilityAfterHit
        cart.spinRate = cart.velocity.length > 3 ? 9 : 6
        cart.velocity *= 0.25
        cart.isDrifting = false
        cart.driftCharge = 0
        cart.boostTimer = 0
        emit(.spunOut(cartID: cart.id))
        carts[index] = cart
    }

    func applySlip(cartIndex index: Int, at position: Vector2) {
        var cart = carts[index]
        guard cart.expressLaneTimer <= 0 else { return }
        if cart.racer.perk == .wetFloorSpecialist {
            cart.slipTimer = max(cart.slipTimer, tuning.slipDuration * 0.5)
        } else {
            cart.slipTimer = max(cart.slipTimer, tuning.slipDuration)
        }
        // A shove sideways: you keep your speed but lose the back end.
        let sideways = cart.forward.perpendicular * (cart.speed * 0.55)
        cart.velocity = cart.velocity * 0.82 + sideways
        cart.isDrifting = false
        cart.driftCharge = 0
        emit(.slipped(cartID: cart.id, position: position))
        carts[index] = cart
    }

    func applyStall(cartIndex index: Int) {
        var cart = carts[index]
        guard cart.expressLaneTimer <= 0, cart.invulnerabilityTimer <= 0 else { return }
        cart.stallTimer = max(cart.stallTimer, tuning.stallDuration)
        cart.velocity *= 0.55
        cart.boostTimer = 0
        cart.heldItem = nil
        cart.isDrifting = false
        cart.driftCharge = 0
        emit(.stalled(cartID: cart.id))
        carts[index] = cart
    }
}
