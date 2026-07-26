import Foundation

/// Waypoint-following opponent. Aims at a point down the racing line, brakes
/// for the corner speed limits the track precomputed, drifts through the long
/// bends, and throws things when it has something to throw.
public struct AIDriver: Sendable {
    public let cartID: Int
    /// 0...1. Scales every other number in here.
    public var skill: Double

    /// Slow lateral wander so a pack of AI carts does not drive as one object.
    private var wanderPhase: Double
    private var wanderSpeed: Double
    private var wanderAmplitude: Double
    /// Time until the AI notices it is holding an item.
    private var itemDelay: Double
    private var driftHold: Double = 0
    private var recoveryTimer: Double = 0
    /// How long the cart has been going nowhere with the throttle open.
    private var stuckTimer: Double = 0
    /// Counts down while backing out of whatever we drove into.
    private var reverseTimer: Double = 0
    private var random: SeededRandom

    public init(cartID: Int, skill: Double, seed: UInt64) {
        self.cartID = cartID
        self.skill = clamp(skill, 0, 1)
        var generator = SeededRandom(seed: seed &* 0x2545_F491 &+ UInt64(cartID &+ 1))
        wanderPhase = generator.double(in: 0...(2 * .pi))
        wanderSpeed = generator.double(in: 0.25...0.6)
        wanderAmplitude = generator.double(in: 0.5...1.7) * (1.2 - self.skill)
        itemDelay = generator.double(in: 0.2...1.1)
        random = generator
    }

    public mutating func decide(
        cart: Cart,
        track: Track,
        carts: [Cart],
        drops: [Drop],
        projectiles: [Projectile],
        standings: [Int],
        dt: Double
    ) -> ControlInput {
        wanderPhase += wanderSpeed * dt
        itemDelay = max(0, itemDelay - dt)
        driftHold = max(0, driftHold - dt)
        recoveryTimer = max(0, recoveryTimer - dt)

        var input = ControlInput()
        let speed = max(cart.forwardSpeed, 0)
        let distance = cart.lapDistance

        // Nose against a pallet or a shelf: back up and try again.
        if cart.isControllable {
            if cart.speed < 2.2 {
                stuckTimer += dt
            } else {
                stuckTimer = 0
            }
        }
        if stuckTimer > 1.1, reverseTimer <= 0 {
            reverseTimer = 0.85
            stuckTimer = 0
        }
        if reverseTimer > 0 {
            reverseTimer -= dt
            let towardsLine = track.racingLinePoint(atDistance: distance + 6) - cart.position
            let error = Angle.delta(from: cart.heading, to: towardsLine.angle)
            // Reversing flips the steering, so aim the tail where the nose
            // needs to end up.
            return ControlInput(steer: clamp(-error / 0.6, -1, 1), throttle: -1)
        }

        // MARK: Where to point
        let lookahead = clamp(5.5 + speed * (0.5 + 0.18 * skill), 5, 30)
        var aimOffset = sin(wanderPhase) * wanderAmplitude
        aimOffset += avoidanceOffset(cart: cart, track: track, carts: carts, drops: drops, lookahead: lookahead)

        // The wander and avoidance nudges stack on top of the racing line, so
        // clamp the sum rather than the nudge: otherwise a corner-cutting line
        // plus a dodge puts the cart in the shelving.
        let half = track.halfWidth(atDistance: distance + lookahead)
        let lineOffset = track.racingLineOffset(atDistance: distance + lookahead)
        let bound = half * 0.82
        aimOffset = clamp(lineOffset + aimOffset, -bound, bound) - lineOffset
        let target = track.racingLinePoint(atDistance: distance + lookahead, extraOffset: aimOffset)

        let toTarget = target - cart.position
        let desiredHeading = toTarget.length > 0.01 ? toTarget.angle : cart.heading
        var error = Angle.delta(from: cart.heading, to: desiredHeading)

        // Countersteer out of a slide rather than fighting it.
        if abs(cart.slipAngle) > 0.35 {
            error -= cart.slipAngle * 0.35 * skill
        }

        input.steer = clamp(error / 0.55, -1, 1)

        // MARK: How fast
        let brakeLookahead = clamp(speed * 0.9, 6, 34)
        var limit = track.speedLimit(atDistance: distance + brakeLookahead)
        limit = min(limit, track.speedLimit(atDistance: distance + brakeLookahead * 0.5))
        // Weaker drivers leave more margin and are worse at judging the limit.
        let margin = 0.78 + 0.24 * skill
        let targetSpeed = limit * margin

        if speed > targetSpeed * 1.16 {
            input.throttle = -0.75
        } else if speed > targetSpeed {
            input.throttle = 0.12
        } else {
            input.throttle = 1
        }

        // Recover from being off the racing surface or pointed at a shelf.
        if abs(cart.lateral) > half * 1.05 {
            input.throttle = max(input.throttle, 0.6)
            recoveryTimer = 0.5
        }
        if cart.isWrongWay {
            input.throttle = 1
        }

        // MARK: Drifting
        let corner = abs(track.curvature(atDistance: distance + 8))
        let sustained = abs(track.curvature(atDistance: distance + 20))
        let wantsDrift = skill > 0.35
            && speed > DriftTuning.minimumSpeed + 2
            && corner > 0.02
            && sustained > 0.012
            && abs(input.steer) > 0.35
            && recoveryTimer <= 0
        if wantsDrift {
            driftHold = 0.35
        }
        // Hold the drift until the mini-turbo has charged, then let go.
        let chargedEnough = cart.drift.tier >= (skill > 0.72 ? 2 : 1)
        let cornerEnding = corner < 0.012
        input.drift = driftHold > 0 && !(chargedEnough && cornerEnding)

        // MARK: Items
        if cart.heldItem != nil, itemDelay <= 0 {
            let decision = itemDecision(cart: cart, track: track, carts: carts, standings: standings)
            input.useItem = decision.use
            input.aimBackward = decision.backward
            if decision.use {
                itemDelay = random.double(in: 0.25...0.9) * (1.6 - skill)
            }
        } else if cart.heldItem == nil {
            itemDelay = max(itemDelay, random.double(in: 0.15...0.7))
        }

        // Keep trailable items out behind as a shield when someone is close.
        if cart.heldItem?.isTrailable == true, !input.useItem, skill > 0.55 {
            input.useItem = threatIsClose(cart: cart, carts: carts) && !readyToThrow(cart: cart, carts: carts)
        }

        return input
    }

    private func avoidanceOffset(
        cart: Cart,
        track: Track,
        carts: [Cart],
        drops: [Drop],
        lookahead: Double
    ) -> Double {
        var offset = 0.0
        let forward = Vector2.angled(cart.heading)
        let scanRange = max(lookahead, 10)

        for other in carts where other.id != cart.id {
            let delta = other.position - cart.position
            let ahead = delta.dot(forward)
            guard ahead > 0, ahead < scanRange else { continue }
            let side = delta.dot(forward.perpendicular)
            guard abs(side) < 3.2 else { continue }
            let urgency = (1 - ahead / scanRange)
            // Steer around the side they are not on.
            offset += (side >= 0 ? -1 : 1) * urgency * 3.4 * (0.5 + skill * 0.5)
        }

        for drop in drops {
            let delta = drop.position - cart.position
            let ahead = delta.dot(forward)
            guard ahead > 0, ahead < scanRange * 0.8 else { continue }
            let side = delta.dot(forward.perpendicular)
            guard abs(side) < drop.radius + 2.2 else { continue }
            let urgency = (1 - ahead / (scanRange * 0.8))
            offset += (side >= 0 ? -1 : 1) * urgency * 3.8 * skill
        }

        // Pallets do not move, so give them a wide berth regardless of skill.
        let propRange = max(scanRange, 18.0)
        for prop in track.props where prop.isSolid {
            let delta = prop.position - cart.position
            let ahead = delta.dot(forward)
            guard ahead > 0, ahead < propRange else { continue }
            let side = delta.dot(forward.perpendicular)
            let clearance = prop.radius + cart.collisionRadius + 1.4
            guard abs(side) < clearance else { continue }
            let urgency = 1 - ahead / propRange
            let escape = clearance - abs(side)
            offset += (side >= 0 ? -1 : 1) * (escape + 0.6) * (0.5 + urgency)
        }

        // Sniff out the item crates when we have nothing.
        if cart.heldItem == nil, cart.rouletteTimer <= 0 {
            var best: Double?
            for box in track.itemBoxes {
                let delta = box.position - cart.position
                let ahead = delta.dot(forward)
                guard ahead > 2, ahead < 26 else { continue }
                let side = delta.dot(forward.perpendicular)
                guard abs(side) < 9 else { continue }
                if best == nil || abs(side) < abs(best!) { best = side }
            }
            if let best { offset += clamp(best, -4, 4) * (0.35 + 0.4 * skill) }
        }

        return offset
    }

    private func threatIsClose(cart: Cart, carts: [Cart]) -> Bool {
        let backward = -Vector2.angled(cart.heading)
        for other in carts where other.id != cart.id {
            let delta = other.position - cart.position
            let behind = delta.dot(backward)
            if behind > 0, behind < 16, abs(delta.dot(backward.perpendicular)) < 4 { return true }
        }
        return false
    }

    private func readyToThrow(cart: Cart, carts: [Cart]) -> Bool {
        let forward = Vector2.angled(cart.heading)
        for other in carts where other.id != cart.id {
            let delta = other.position - cart.position
            let ahead = delta.dot(forward)
            if ahead > 2, ahead < 30, abs(delta.dot(forward.perpendicular)) < 3.4 { return true }
        }
        return false
    }

    private func itemDecision(
        cart: Cart,
        track: Track,
        carts: [Cart],
        standings: [Int]
    ) -> (use: Bool, backward: Bool) {
        guard let item = cart.heldItem else { return (false, false) }
        let place = (standings.firstIndex(of: cart.id) ?? 0) + 1

        switch item {
        case .energyDrink:
            // Spend it on a straight, where it is worth the most.
            let straightAhead = abs(track.curvature(atDistance: cart.lapDistance + 14)) < 0.015
            return (straightAhead || skill < 0.4, false)

        case .vipCard, .runawayCart:
            return (true, false)

        case .cleanupCall:
            return (place > 2, false)

        case .rogueMelon:
            guard let targetID = ItemSystem.cartAhead(of: cart.id, standings: standings, carts: carts),
                  let target = carts.first(where: { $0.id == targetID }) else {
                return (skill < 0.5, false)
            }
            return (cart.position.distance(to: target.position) < 55, false)

        case .soupCan, .tripleCans:
            if readyToThrow(cart: cart, carts: carts) { return (true, false) }
            if threatIsClose(cart: cart, carts: carts), skill > 0.6 { return (true, true) }
            return (skill < 0.35, false)

        case .milkSpill, .wetFloorSign:
            // Drop it where it is most annoying: mid-corner or under pressure.
            let inCorner = abs(track.curvature(atDistance: cart.lapDistance)) > 0.02
            return (threatIsClose(cart: cart, carts: carts) || inCorner || skill < 0.4, true)
        }
    }
}
