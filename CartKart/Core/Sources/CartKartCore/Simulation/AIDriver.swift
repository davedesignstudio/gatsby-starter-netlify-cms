import Foundation

/// Decides what a computer-controlled cart wants to do this frame.
///
/// The AI aims at a point further along the racing line, brakes for corners it
/// cannot take flat, drifts through the long ones, and swerves around anything
/// lying on the floor. Skill scales the aggression and the amount of noise.
public struct AIDriver {
    public struct Context {
        public let track: Track
        public let tuning: RaceTuning
        public let hazards: [DroppedHazard]
        public let obstacles: [TrackObstacle]
        public let itemBoxes: [ItemBoxState]
        public let opponents: [KartState]
        public let elapsed: Double

        public init(
            track: Track,
            tuning: RaceTuning,
            hazards: [DroppedHazard],
            obstacles: [TrackObstacle],
            itemBoxes: [ItemBoxState],
            opponents: [KartState],
            elapsed: Double
        ) {
            self.track = track
            self.tuning = tuning
            self.hazards = hazards
            self.obstacles = obstacles
            self.itemBoxes = itemBoxes
            self.opponents = opponents
            self.elapsed = elapsed
        }
    }

    public static func input(for kart: KartState, context: Context, random: inout SeededRandom) -> RaceInput {
        let track = context.track
        let skill = clamp(kart.aiSkill, 0.4, 1.2)
        let speed = kart.speed

        if kart.aiReverseTimer > 0 {
            return reverseOut(of: kart, track: track)
        }

        // Look further ahead the faster we are going.
        let lookahead = clamp(150 + speed * 0.55, 150, 480)
        var targetArc = track.wrapArcLength(kart.arcLength + lookahead)
        var lane = kart.aiLaneBias

        // Detour towards a nearby item box if we are empty-handed.
        if kart.item == nil, kart.pendingItem == nil {
            if let box = nearestUsefulItemBox(kart: kart, context: context) {
                lane = clamp(box.lane, -0.9, 0.9)
                targetArc = box.arcLength
            }
        }

        // Aim for a boost pad if one is roughly on our line.
        if let pad = nearestFeature(context.track.boostPads, kart: kart, track: track, maxGap: 420) {
            lane = lerp(lane, clamp(pad.lane, -0.9, 0.9), 0.6)
        }

        var targetPoint = point(on: track, arc: targetArc, lane: lane)

        // Steer around hazards, obstacles and slow carts in the way.
        if let dodge = avoidanceOffset(kart: kart, context: context) {
            lane = clamp(lane + dodge, -0.95, 0.95)
            targetPoint = point(on: track, arc: targetArc, lane: lane)
        }

        // MARK: Steering
        let toTarget = targetPoint - kart.position
        let desired = toTarget.angle
        var steer = Angle.delta(from: kart.heading, to: desired) * 1.9

        // A lane nudge is not enough when a pallet is already under the nose;
        // in that case turn away from it as hard as possible.
        if let escape = escapeSteer(for: kart, context: context) {
            steer = escape
        }
        // Weaker drivers wander a little.
        let noise = (1.05 - skill) * 0.45
        if noise > 0.001 {
            steer += random.double(in: -noise...noise)
        }
        steer = clamp(steer, -1, 1)

        // MARK: Throttle
        let cornerSeverity = upcomingCurvature(kart: kart, track: track, distance: clamp(speed * 0.7, 120, 460))
        // A grippy cart can carry a little more speed through the same corner,
        // on top of the grip it already gets from the physics.
        let gripFactor = pow(kart.physics.grip / context.tuning.baseGrip, 0.35)
        let cornerSpeedCap = kart.physics.topSpeed * gripFactor * clamp(1.05 - cornerSeverity * 130, 0.42, 1.0)
        var throttle = 1.0
        if speed > cornerSpeedCap * (0.9 + 0.2 * skill) {
            throttle = speed > cornerSpeedCap * 1.25 ? -0.6 : 0.15
        }
        if kart.surface == .rough {
            // Get back on the tile rather than powering through the cereal.
            throttle = min(throttle, 0.85)
        }

        // MARK: Drifting
        // Only commit to a drift in a genuine, sustained corner: a drift locks
        // the cart into an arc, so starting one on a kink loses more time than
        // the mini-turbo pays back.
        var isDrifting = abs(steer) > 0.55
            && cornerSeverity > 0.0026
            && speed > context.tuning.driftMinimumSpeed * 1.1
            && skill > 0.55
        if kart.isDrifting {
            // Hold it until the corner opens up, then cash in the charge.
            let charged = kart.driftTier == .rumble
            isDrifting = abs(steer) > 0.34 && cornerSeverity > 0.0018 && !(charged && abs(steer) < 0.45)
        }

        // MARK: Items
        let useItem = shouldUseItem(kart: kart, context: context, random: &random)

        return RaceInput(
            throttle: throttle,
            steer: steer,
            isDrifting: isDrifting,
            useItem: useItem,
            aimBackwards: kart.item?.kind == .grapeSpill && hasCloseChaser(kart: kart, context: context)
        )
    }

    // MARK: - Helpers

    /// Backs away from whatever the cart is jammed against, turning the nose
    /// back towards the racing line as it goes.
    private static func reverseOut(of kart: KartState, track: Track) -> RaceInput {
        let target = track.position(atArcLength: kart.arcLength + 200)
        let desired = Angle.delta(from: kart.heading, to: (target - kart.position).angle)
        // Steering is mirrored when rolling backwards, hence the sign flip.
        return RaceInput(throttle: -1, steer: clamp(-desired * 2, -1, 1))
    }

    private static func point(on track: Track, arc: Double, lane: Double) -> Vec2 {
        let index = track.sampleIndex(atArcLength: arc)
        let sample = track.sample(at: index)
        return sample.position + sample.tangent.perpendicular * (lane * sample.halfWidth * 0.72)
    }

    /// Mean curvature over the next `distance` units, used as a corner alarm.
    private static func upcomingCurvature(kart: KartState, track: Track, distance: Double) -> Double {
        let spacing = max(track.trackLength / Double(track.samples.count), 1)
        let steps = max(3, Int(distance / spacing))
        let start = track.sampleIndex(atArcLength: kart.arcLength)
        var sum = 0.0
        for i in 0..<steps {
            sum += track.sample(at: start + i).curvature
        }
        return abs(sum / Double(steps))
    }

    private static func nearestFeature(
        _ features: [TrackFeature],
        kart: KartState,
        track: Track,
        maxGap: Double
    ) -> TrackFeature? {
        var best: (feature: TrackFeature, gap: Double)?
        for feature in features {
            let gap = track.arcDelta(from: kart.arcLength, to: feature.arcLength)
            guard gap > 30, gap < maxGap else { continue }
            if best == nil || gap < best!.gap { best = (feature, gap) }
        }
        return best?.feature
    }

    private static func nearestUsefulItemBox(kart: KartState, context: Context) -> ItemBoxState? {
        var best: (box: ItemBoxState, gap: Double)?
        for box in context.itemBoxes where box.isAvailable {
            let gap = context.track.arcDelta(from: kart.arcLength, to: box.arcLength)
            guard gap > 20, gap < 520 else { continue }
            if best == nil || gap < best!.gap { best = (box, gap) }
        }
        return best?.box
    }

    /// Full lock away from anything the cart is about to bury its nose in.
    private static func escapeSteer(for kart: KartState, context: Context) -> Double? {
        let forward = Vec2.direction(kart.heading)
        var worst: (side: Double, distance: Double)?
        for obstacle in context.obstacles where !obstacle.isBreakable {
            let offset = obstacle.position - kart.position
            let ahead = offset.dot(forward)
            let clearance = obstacle.radius + context.tuning.cartRadius
            // Only when it is genuinely in front and almost touching.
            guard ahead > 0, ahead < clearance + 34 else { continue }
            let side = offset.dot(forward.perpendicular)
            guard abs(side) < clearance else { continue }
            if worst == nil || ahead < worst!.distance {
                worst = (side, ahead)
            }
        }
        guard let worst else { return nil }
        // Turn towards whichever side the obstacle is not on.
        return worst.side >= 0 ? -1 : 1
    }

    /// Returns a lane nudge (in half-width units) to dodge whatever is ahead.
    private static func avoidanceOffset(kart: KartState, context: Context) -> Double? {
        let forward = Vec2.direction(kart.heading)
        let scanDistance = clamp(kart.speed * 0.55 + 90, 110, 380)
        var nudge = 0.0

        func consider(position: Vec2, radius: Double, weight: Double) {
            let offset = position - kart.position
            let ahead = offset.dot(forward)
            guard ahead > 0, ahead < scanDistance else { return }
            let side = offset.dot(forward.perpendicular)
            let clearance = radius + context.tuning.cartRadius * 1.4
            guard abs(side) < clearance else { return }
            let urgency = (1 - ahead / scanDistance) * weight
            // Push away from whichever side the object sits on.
            nudge += (side >= 0 ? -1.0 : 1.0) * urgency
        }

        for hazard in context.hazards where hazard.kind != .flourCloud {
            consider(position: hazard.position, radius: hazard.radius, weight: 0.9)
        }
        for obstacle in context.obstacles where !obstacle.isBreakable {
            consider(position: obstacle.position, radius: obstacle.radius, weight: 1.1)
        }
        for other in context.opponents where other.id != kart.id {
            // Only avoid carts that are genuinely slower than us.
            guard other.speed < kart.speed - 40 else { continue }
            consider(position: other.position, radius: context.tuning.cartRadius, weight: 0.7)
        }
        return abs(nudge) < 0.01 ? nil : clamp(nudge, -1, 1)
    }

    private static func hasCloseChaser(kart: KartState, context: Context) -> Bool {
        for other in context.opponents where other.id != kart.id {
            let gap = context.track.arcDelta(from: other.arcLength, to: kart.arcLength)
            if gap > 0 && gap < 260 { return true }
        }
        return false
    }

    private static func shouldUseItem(kart: KartState, context: Context, random: inout SeededRandom) -> Bool {
        guard let item = kart.item, kart.aiItemTimer <= 0 else { return false }
        switch item.kind {
        case .energyDrink:
            // Save the boost for a straight.
            return upcomingCurvature(kart: kart, track: context.track, distance: 260) < 0.0018
        case .bulkBuy:
            return true
        case .runawayMelon:
            return true
        case .soupCan, .tripleSoup:
            // Fire when someone is in front and roughly lined up.
            let forward = Vec2.direction(kart.heading)
            for other in context.opponents where other.id != kart.id {
                let offset = other.position - kart.position
                let ahead = offset.dot(forward)
                guard ahead > 40, ahead < 700 else { continue }
                if abs(offset.dot(forward.perpendicular)) < 90 { return true }
            }
            return false
        case .grapeSpill:
            return hasCloseChaser(kart: kart, context: context) || random.chance(0.004)
        case .mopBucket, .flourBomb:
            return hasCloseChaser(kart: kart, context: context) || random.chance(0.003)
        }
    }
}
