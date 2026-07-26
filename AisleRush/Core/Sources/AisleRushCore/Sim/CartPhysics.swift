import Foundation

/// Arcade cart handling. Deliberately not a real vehicle model: the cart turns
/// its heading directly and the velocity is dragged along behind it, which is
/// what makes drifts feel like drifts.
public enum CartPhysics {
    public struct Tuning: Sendable {
        /// Speed at which steering reaches full effect, m/s.
        public var steeringRampSpeed: Double = 6.0
        /// Steering authority lost between `steeringRampSpeed` and top speed.
        public var highSpeedSteeringLoss: Double = 0.32
        public var brakeDeceleration: Double = 18.0
        public var reverseAcceleration: Double = 6.0
        public var maxReverseSpeed: Double = 6.0
        /// Velocity decay when coasting, 1/s.
        public var coastDrag: Double = 0.55
        /// How hard the cart is pulled back down to its top speed, 1/s.
        public var overspeedDecay: Double = 1.6
        public var spinRate: Double = 9.0
        public var spinDrag: Double = 2.2
        public var slowSpeedMultiplier: Double = 0.55
        public var slowAccelerationMultiplier: Double = 0.6
        public var boostAccelerationMultiplier: Double = 2.1
        public var invincibleSpeedMultiplier: Double = 1.12
        public var autopilotSpeedMultiplier: Double = 1.45
        /// Widest angle between heading and travel while drifting, radians.
        /// Beyond this the steering is progressively cut so a drift cannot
        /// wind itself up into a spin.
        public var maxDriftSlip: Double = 0.58
        /// The same limit off the drift button, where it only matters on ice.
        public var maxGripSlip: Double = 0.95
        /// Slip costs a lot of forward speed. Real physics makes a drift a
        /// braking manoeuvre; capping the loss is what makes it a technique.
        public var driftSpeedScrub: Double = 3.4

        public init() {}
    }

    public static var tuning = Tuning()

    /// Advances one cart by `dt`. Track interaction (walls, surfaces, laps) is
    /// applied separately by `RaceSimulation`.
    public static func integrate(
        cart: inout Cart,
        input: ControlInput,
        surface: Surface,
        dt: Double
    ) {
        let stats = cart.stats
        let tuning = CartPhysics.tuning

        cart.boostJustStarted = max(0, cart.boostJustStarted - 1)
        cart.bumpCooldown = max(0, cart.bumpCooldown - dt)
        cart.invincibleTimer = max(0, cart.invincibleTimer - dt)
        cart.slowTimer = max(0, cart.slowTimer - dt)
        cart.boostTimer = max(0, cart.boostTimer - dt)
        if cart.boostTimer <= 0 { cart.boostStrength = 1 }

        // Off-track surfaces hurt less if you brought the right wheels.
        let resistance = surface.isOffTrack ? stats.offTrackResistance : 0
        let surfaceSpeed = surface.speedMultiplier + (1 - surface.speedMultiplier) * resistance
        let surfaceGrip = surface.gripMultiplier + (1 - surface.gripMultiplier) * resistance * 0.5
        let surfaceDrag = surface.rollingDrag * (1 - resistance)

        var effective = input
        if !cart.isControllable {
            effective = ControlInput(steer: 0, throttle: 0, drift: false)
        }

        if cart.spinTimer > 0 {
            cart.spinTimer = max(0, cart.spinTimer - dt)
            cart.heading = Angle.normalize(cart.heading + tuning.spinRate * cart.spinDirection * dt)
            cart.velocity *= exp(-tuning.spinDrag * dt)
            cart.position += cart.velocity * dt
            cart.surface = surface
            return
        }

        updateDrift(&cart, input: effective, dt: dt)

        // MARK: Steering
        let forward = Vector2.angled(cart.heading)
        var forwardSpeed = cart.velocity.dot(forward)
        var lateralSpeed = cart.velocity.dot(forward.perpendicular)

        let absSpeed = abs(forwardSpeed)
        var steeringAuthority = clamp(absSpeed / tuning.steeringRampSpeed, 0, 1)
        steeringAuthority *= 1 - tuning.highSpeedSteeringLoss * clamp((absSpeed - tuning.steeringRampSpeed) / 18, 0, 1)
        steeringAuthority *= 0.55 + 0.45 * surfaceGrip

        var turn: Double
        if cart.drift.isActive {
            // Steering into the drift tightens the arc, away from it widens it.
            let alignment = clamp(effective.steer * cart.drift.direction, -1, 1)
            turn = stats.turnRate * cart.drift.direction * (0.72 + 0.55 * max(0, alignment) + 0.2 * min(0, alignment))
        } else {
            turn = stats.turnRate * effective.steer
        }
        if forwardSpeed < -0.2 { turn = -turn }

        let slip = cart.speed > 1 ? Angle.delta(from: cart.heading, to: cart.velocity.angle) : 0
        let maxSlip = cart.drift.isActive ? tuning.maxDriftSlip : tuning.maxGripSlip
        if slip * turn < 0 {
            // The turn is widening the slide; fade it out at the limit.
            turn *= clamp(1 - (abs(slip) - maxSlip) / 0.22, 0, 1)
        }

        let forwardBefore = forwardSpeed
        cart.heading = Angle.normalize(cart.heading + turn * steeringAuthority * dt)

        // Rotating the heading leaves the old velocity pointing the wrong way;
        // re-decompose against the new axes before applying grip.
        let newForward = Vector2.angled(cart.heading)
        forwardSpeed = cart.velocity.dot(newForward)
        lateralSpeed = cart.velocity.dot(newForward.perpendicular)

        if cart.drift.isActive, forwardBefore > 0 {
            forwardSpeed = max(forwardSpeed, forwardBefore - tuning.driftSpeedScrub * dt)
        }

        // MARK: Engine
        var topSpeed = stats.topSpeed * surfaceSpeed
        var acceleration = stats.acceleration
        if cart.slowTimer > 0 {
            topSpeed *= tuning.slowSpeedMultiplier
            acceleration *= tuning.slowAccelerationMultiplier
        }
        if cart.isInvincible { topSpeed *= tuning.invincibleSpeedMultiplier }
        if cart.boostTimer > 0 {
            topSpeed *= cart.boostStrength
            acceleration *= tuning.boostAccelerationMultiplier
        }
        if cart.autopilotTimer > 0 {
            topSpeed = stats.topSpeed * tuning.autopilotSpeedMultiplier
            acceleration = max(acceleration, 18)
        }

        let throttle = cart.autopilotTimer > 0 ? 1 : effective.throttle
        if throttle > 0 {
            let headroom = max(0, 1 - forwardSpeed / max(topSpeed, 0.1))
            forwardSpeed += acceleration * throttle * headroom * dt
        } else if throttle < 0 {
            if forwardSpeed > 0.2 {
                forwardSpeed = max(0, forwardSpeed - tuning.brakeDeceleration * -throttle * dt)
            } else {
                forwardSpeed = max(-tuning.maxReverseSpeed, forwardSpeed - tuning.reverseAcceleration * -throttle * dt)
            }
        } else {
            forwardSpeed *= exp(-tuning.coastDrag * dt)
        }

        if forwardSpeed > topSpeed {
            forwardSpeed = damp(forwardSpeed, topSpeed, rate: tuning.overspeedDecay, dt: dt)
        }
        forwardSpeed *= exp(-surfaceDrag * dt)

        // MARK: Grip
        var gripCoefficient = stats.grip * surfaceGrip
        if cart.drift.isActive { gripCoefficient *= stats.driftGrip }
        lateralSpeed *= exp(-gripCoefficient * dt)

        cart.velocity = newForward * forwardSpeed + newForward.perpendicular * lateralSpeed
        cart.position += cart.velocity * dt

        cart.orbitAngle = Angle.normalize(cart.orbitAngle + 2.4 * dt)
        cart.surface = surface
    }

    private static func updateDrift(_ cart: inout Cart, input: ControlInput, dt: Double) {
        let speed = abs(cart.forwardSpeed)

        if cart.drift.isActive {
            let stillDrifting = input.drift && speed > DriftTuning.minimumSpeed * 0.6
            if stillDrifting {
                let alignment = max(0, input.steer * cart.drift.direction)
                cart.drift.charge += dt * (0.35 + 0.45 * alignment) * clamp(speed / 14, 0.4, 1.2)
            } else {
                releaseDrift(&cart)
            }
        } else if input.drift, speed > DriftTuning.minimumSpeed, abs(input.steer) > DriftTuning.minimumSteer {
            cart.drift.isActive = true
            cart.drift.direction = input.steer > 0 ? 1 : -1
            cart.drift.charge = 0
        }
    }

    private static func releaseDrift(_ cart: inout Cart) {
        let tier = cart.drift.tier
        if tier > 0 {
            cart.grantBoost(
                duration: DriftTuning.boostDurations[tier - 1],
                strength: DriftTuning.boostStrengths[tier - 1]
            )
        }
        cart.drift = DriftState()
    }

    /// Bounces a cart off shelving. Returns the impact speed so the caller can
    /// decide how loud to make it.
    @discardableResult
    public static func resolveWallCollision(
        cart: inout Cart,
        wallNormal: Vector2,
        penetration: Double,
        restitution: Double = 0.25
    ) -> Double {
        guard penetration > 0 else { return 0 }
        cart.position += wallNormal * penetration
        let into = cart.velocity.dot(wallNormal)
        guard into < 0 else { return 0 }
        let impact = -into
        // Kill the component into the wall, scrub some of the rest.
        cart.velocity = cart.velocity - wallNormal * into * (1 + restitution)
        cart.velocity *= 0.82
        cart.drift = DriftState()
        if impact > 9 {
            cart.boostTimer = 0
            cart.boostStrength = 1
        }
        return impact
    }

    /// Separates two overlapping carts and swaps momentum along the contact
    /// normal. Heavier carts shove lighter ones.
    public static func resolveCartCollision(_ a: inout Cart, _ b: inout Cart) {
        let delta = b.position - a.position
        let distance = delta.length
        let minimum = a.collisionRadius + b.collisionRadius
        guard distance < minimum, distance > 1e-6 else { return }

        let normal = delta / distance
        let overlap = minimum - distance
        let totalMass = a.stats.mass + b.stats.mass
        a.position -= normal * (overlap * b.stats.mass / totalMass)
        b.position += normal * (overlap * a.stats.mass / totalMass)

        let relative = (b.velocity - a.velocity).dot(normal)
        guard relative < 0 else { return }
        let restitution = 0.35
        let impulse = -(1 + restitution) * relative / (1 / a.stats.mass + 1 / b.stats.mass)
        a.velocity -= normal * (impulse / a.stats.mass)
        b.velocity += normal * (impulse / b.stats.mass)

        // A solid hit from a much heavier cart sends the lighter one spinning.
        let severity = abs(relative)
        if severity > 7, a.bumpCooldown <= 0, b.bumpCooldown <= 0 {
            let ratio = a.stats.mass / b.stats.mass
            if ratio > 1.3 || a.isInvincible {
                b.spinOut(direction: normal.cross(b.velocity) >= 0 ? 1 : -1, duration: 0.7)
            } else if ratio < 0.77 || b.isInvincible {
                a.spinOut(direction: normal.cross(a.velocity) >= 0 ? -1 : 1, duration: 0.7)
            }
            a.bumpCooldown = 0.5
            b.bumpCooldown = 0.5
        }
    }
}
