import Foundation

public struct Entrant: Sendable {
    public var setup: CartSetup
    public var isPlayer: Bool
    /// Overrides the difficulty-derived skill when set.
    public var skill: Double?

    public init(setup: CartSetup, isPlayer: Bool = false, skill: Double? = nil) {
        self.setup = setup
        self.isPlayer = isPlayer
        self.skill = skill
    }
}

/// The whole race, headless. Feed it inputs and fixed timesteps; read carts,
/// standings and events back out. No rendering, no platform frameworks.
public final class RaceSimulation {
    public let track: Track
    public let config: RaceConfig

    public private(set) var carts: [Cart] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var drops: [Drop] = []
    public private(set) var phase: RacePhase
    /// Seconds since the lights went out. Negative during the countdown.
    public private(set) var time: Double = 0
    /// Cart IDs, leader first.
    public private(set) var standings: [Int] = []
    public private(set) var isComplete = false
    /// Per-crate respawn timers; zero means the crate is up.
    public private(set) var itemBoxCooldowns: [Double]
    /// Per-prop knock-over timers; zero means it is standing.
    public private(set) var propCooldowns: [Double]

    public let playerCartID: Int?

    private var drivers: [Int: AIDriver] = [:]
    private var pendingInputs: [Int: ControlInput] = [:]
    private var random: SeededRandom
    private var nextEntityID = 1
    private var events: [RaceEvent] = []
    private var beepsPlayed: Set<Int> = []
    private var revHold: [Int: Double] = [:]
    private var wrongWayFlags: [Int: Bool] = [:]
    private var finishOrder: [Int] = []
    private var graceTimer: Double?
    private var finalLapAnnounced: Set<Int> = []
    private var stuckTimers: [Int: Double] = [:]

    public init(track: Track, config: RaceConfig, entrants: [Entrant]) {
        self.track = track
        self.config = config
        random = SeededRandom(seed: config.seed)
        phase = .countdown(remaining: config.countdownDuration)
        itemBoxCooldowns = [Double](repeating: 0, count: track.itemBoxes.count)
        propCooldowns = [Double](repeating: 0, count: track.props.count)

        var skillGenerator = SeededRandom(seed: config.seed &* 31 &+ 7)
        var identifiedPlayer: Int?
        for (index, entrant) in entrants.enumerated() {
            let slot = track.startingSlot(index, of: entrants.count)
            var cart = Cart(
                id: index,
                setup: entrant.setup,
                isPlayer: entrant.isPlayer,
                aiSkill: entrant.skill ?? skillGenerator.double(in: config.aiSkillRange),
                position: slot.position,
                heading: slot.heading
            )
            let projection = track.project(slot.position)
            cart.lapDistance = projection.distance
            cart.lateral = projection.lateral
            cart.projectionHint = projection.sampleIndex
            cart.totalDistance = projection.distance
            carts.append(cart)
            if entrant.isPlayer { identifiedPlayer = index }
            if !entrant.isPlayer {
                drivers[index] = AIDriver(cartID: index, skill: cart.aiSkill, seed: config.seed &+ UInt64(index))
            }
        }
        playerCartID = identifiedPlayer
        standings = carts.map(\.id)
        applyDifficultyScaling()
    }

    // MARK: - Input

    public func setInput(_ input: ControlInput, forCart id: Int) {
        pendingInputs[id] = input
    }

    /// Puts a specific item straight into a cart's slot, skipping the roulette.
    public func forceItem(_ kind: ItemKind, forCart id: Int) {
        guard let index = carts.firstIndex(where: { $0.id == id }) else { return }
        carts[index].heldItem = kind
        carts[index].heldCharges = kind.charges
        carts[index].pendingItem = nil
        carts[index].rouletteTimer = 0
        carts[index].orbitingCans = kind == .tripleCans ? 3 : 0
    }

    /// Removes and returns everything that happened since the last call.
    public func drainEvents() -> [RaceEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    public var playerCart: Cart? {
        guard let playerCartID else { return nil }
        return carts.first { $0.id == playerCartID }
    }

    public func cart(withID id: Int) -> Cart? {
        carts.first { $0.id == id }
    }

    public func place(ofCart id: Int) -> Int {
        (standings.firstIndex(of: id) ?? 0) + 1
    }

    // MARK: - Tick

    /// Advances the race. Call with a fixed `dt` (the app uses 1/120).
    public func update(dt: Double) {
        guard !isComplete else { return }

        switch phase {
        case .countdown(let remaining):
            updateCountdown(remaining: remaining, dt: dt)
        case .racing, .finished:
            time += dt
            updateRacing(dt: dt)
        }
    }

    private func updateCountdown(remaining: Double, dt: Double) {
        let next = remaining - dt
        // Beep on each whole second remaining: three, two, one, go.
        for count in [3, 2, 1] where !beepsPlayed.contains(count) {
            if next <= Double(count) + 0.4 {
                beepsPlayed.insert(count)
                events.append(.countdownBeep(count))
            }
        }

        // Holding the throttle as the lights change earns a rocket start;
        // holding it from the very beginning floods the engine instead.
        for index in carts.indices {
            let input = resolveCountdownInput(for: index)
            if input.throttle > 0.2 {
                revHold[carts[index].id, default: 0] += dt
            } else {
                revHold[carts[index].id] = 0
            }
        }

        if next <= 0 {
            phase = .racing
            time = 0
            events.append(.go)
            for index in carts.indices {
                let hold = revHold[carts[index].id] ?? 0
                if hold > 1.9 {
                    carts[index].applySlow(duration: 1.4)
                    events.append(.burnout(cartID: carts[index].id))
                } else if hold > 0.28 {
                    carts[index].grantBoost(duration: 1.5, strength: 1.34)
                    events.append(.rocketStart(cartID: carts[index].id))
                }
            }
        } else {
            phase = .countdown(remaining: next)
        }
    }

    private func resolveCountdownInput(for index: Int) -> ControlInput {
        let cart = carts[index]
        if cart.isPlayer { return pendingInputs[cart.id] ?? .idle }
        // AI carts commit to a start of varying quality.
        let quality = cart.aiSkill
        var generator = SeededRandom(seed: config.seed &+ UInt64(cart.id) &* 977)
        let target = 0.3 + (1 - quality) * generator.double(in: 0...2.0)
        let held = revHold[cart.id] ?? 0
        return ControlInput(throttle: held < target ? 1 : 0)
    }

    private func updateRacing(dt: Double) {
        updateStandings()

        for index in carts.indices {
            guard !carts[index].hasFinished else {
                carts[index].velocity *= exp(-1.5 * dt)
                carts[index].position += carts[index].velocity * dt
                continue
            }

            var input = resolveInput(for: index, dt: dt)
            if carts[index].autopilotTimer > 0 {
                carts[index].autopilotTimer = max(0, carts[index].autopilotTimer - dt)
                input = autopilotInput(for: index)
            }

            updateItemState(index: index, input: input, dt: dt)

            let surface = carts[index].surface
            let driftTierBefore = carts[index].drift.isActive ? carts[index].drift.tier : 0
            CartPhysics.integrate(cart: &carts[index], input: input, surface: surface, dt: dt)
            if carts[index].boostJustStarted == 2, driftTierBefore > 0, !carts[index].drift.isActive {
                events.append(.miniTurbo(cartID: carts[index].id, tier: driftTierBefore))
            }

            resolveTrack(index: index, dt: dt)
        }

        resolveCartContacts()
        resolveProps(dt: dt)
        collectItemBoxes(dt: dt)
        updateOrbitingCans()

        if config.itemsEnabled {
            ItemSystem.updateProjectiles(&projectiles, carts: &carts, track: track, dt: dt, events: &events)
            ItemSystem.updateDrops(&drops, carts: &carts, dt: dt, events: &events)
        }

        for index in itemBoxCooldowns.indices {
            itemBoxCooldowns[index] = max(0, itemBoxCooldowns[index] - dt)
        }
        for index in propCooldowns.indices {
            propCooldowns[index] = max(0, propCooldowns[index] - dt)
        }

        updateStandings()
        applyRubberBanding()
        updateCompletion(dt: dt)
    }

    private func resolveInput(for index: Int, dt: Double) -> ControlInput {
        let cart = carts[index]
        if cart.isPlayer {
            return pendingInputs[cart.id] ?? .idle
        }
        guard var driver = drivers[cart.id] else { return .coasting }
        let input = driver.decide(
            cart: cart,
            track: track,
            carts: carts,
            drops: drops,
            projectiles: projectiles,
            standings: standings,
            dt: dt
        )
        drivers[cart.id] = driver
        return input
    }

    /// Steering for a cart being dragged along by a runaway trolley.
    private func autopilotInput(for index: Int) -> ControlInput {
        let cart = carts[index]
        let target = track.racingLinePoint(atDistance: cart.lapDistance + 10)
        let error = Angle.delta(from: cart.heading, to: (target - cart.position).angle)
        return ControlInput(steer: clamp(error / 0.4, -1, 1), throttle: 1)
    }

    // MARK: - Items

    private func updateItemState(index: Int, input: ControlInput, dt: Double) {
        guard config.itemsEnabled else { return }

        if carts[index].rouletteTimer > 0 {
            carts[index].rouletteTimer -= dt
            if carts[index].rouletteTimer <= 0, let pending = carts[index].pendingItem {
                carts[index].heldItem = pending
                carts[index].heldCharges = pending.charges
                carts[index].pendingItem = nil
                if pending == .tripleCans { carts[index].orbitingCans = 3 }
                events.append(.itemAwarded(cartID: carts[index].id, kind: pending))
            }
        }

        let pressed = input.useItem
        let wasPressed = carts[index].wasFirePressed
        carts[index].wasFirePressed = pressed

        guard let item = carts[index].heldItem, carts[index].isControllable || item.isInstant else {
            carts[index].isTrailingItem = false
            return
        }

        if item.isTrailable {
            if pressed {
                carts[index].isTrailingItem = true
                return
            }
            if wasPressed {
                fire(index: index, aimBackward: input.aimBackward || item == .milkSpill || item == .wetFloorSign)
            }
        } else if pressed, !wasPressed {
            if item == .cleanupCall {
                triggerCleanupCall(from: index)
            }
            fire(index: index, aimBackward: input.aimBackward)
        }
    }

    private func fire(index: Int, aimBackward: Bool) {
        ItemSystem.deploy(
            cart: &carts[index],
            aimBackward: aimBackward,
            nextID: &nextEntityID,
            projectiles: &projectiles,
            drops: &drops,
            allCarts: carts,
            standings: standings,
            events: &events
        )
    }

    private func triggerCleanupCall(from index: Int) {
        let callerID = carts[index].id
        guard let callerPlace = standings.firstIndex(of: callerID) else { return }
        for position in 0..<callerPlace {
            guard let target = carts.firstIndex(where: { $0.id == standings[position] }) else { continue }
            guard !carts[target].isInvincible, !carts[target].hasFinished else { continue }
            carts[target].applySlow(duration: 1.5 + Double(callerPlace - position) * 0.1)
            carts[target].heldItem = nil
            carts[target].heldCharges = 0
            carts[target].orbitingCans = 0
            events.append(.cartHit(cartID: carts[target].id, by: .cleanupCall, sourceID: callerID))
        }
    }

    private func collectItemBoxes(dt: Double) {
        _ = dt
        guard config.itemsEnabled else { return }
        for boxIndex in track.itemBoxes.indices where itemBoxCooldowns[boxIndex] <= 0 {
            let box = track.itemBoxes[boxIndex]
            for cartIndex in carts.indices {
                let cart = carts[cartIndex]
                guard !cart.hasFinished, cart.heldItem == nil, cart.rouletteTimer <= 0 else { continue }
                guard cart.position.distance(to: box.position) < box.radius + cart.collisionRadius else { continue }

                let kind = ItemRoulette.roll(
                    position: place(ofCart: cart.id),
                    fieldSize: carts.count,
                    luck: cart.stats.luck,
                    using: &random
                )
                carts[cartIndex].pendingItem = kind
                carts[cartIndex].rouletteTimer = cart.isPlayer ? 0.85 : 0.4
                carts[cartIndex].boxesCollected += 1
                itemBoxCooldowns[boxIndex] = 4.5
                events.append(.itemBoxCollected(cartID: cart.id))
                break
            }
        }
    }

    /// Cans circling a cart knock over anyone who gets too close.
    private func updateOrbitingCans() {
        for index in carts.indices where carts[index].orbitingCans > 0 {
            let owner = carts[index]
            for other in carts.indices where other != index {
                guard !carts[other].hasFinished, !carts[other].isInvincible else { continue }
                let reach = owner.collisionRadius + carts[other].collisionRadius + 0.75
                guard owner.position.distance(to: carts[other].position) < reach else { continue }
                let side = (carts[other].position - owner.position).cross(Vector2.angled(carts[other].heading))
                carts[other].spinOut(direction: side >= 0 ? 1 : -1, duration: 1.0)
                events.append(.cartHit(cartID: carts[other].id, by: .soupCan, sourceID: owner.id))
                carts[index].orbitingCans -= 1
                carts[index].heldCharges = max(0, carts[index].heldCharges - 1)
                if carts[index].heldCharges <= 0 { carts[index].heldItem = nil }
                break
            }
        }
    }

    // MARK: - Track interaction

    private func resolveTrack(index: Int, dt: Double) {
        var projection = track.project(carts[index].position, hint: carts[index].projectionHint)

        let wall = track.wallDistance(atDistance: projection.distance)
        if abs(projection.lateral) > wall {
            let normal = projection.tangent.perpendicular * (projection.lateral > 0 ? -1 : 1)
            let penetration = abs(projection.lateral) - wall + carts[index].collisionRadius * 0.35
            let impact = CartPhysics.resolveWallCollision(
                cart: &carts[index],
                wallNormal: normal,
                penetration: penetration
            )
            if impact > 3 {
                events.append(.wallImpact(cartID: carts[index].id, force: impact))
            }
            projection = track.project(carts[index].position, hint: projection.sampleIndex)
        }

        carts[index].projectionHint = projection.sampleIndex
        carts[index].lateral = projection.lateral

        if rescueIfStuck(index: index, projection: projection, dt: dt) { return }

        let surface = track.surface(atDistance: projection.distance, lateral: projection.lateral)
        carts[index].surface = surface
        if surface == .boostStrip {
            carts[index].grantBoost(duration: 0.85, strength: 1.32)
        }

        let forwardAlongTrack = carts[index].velocity.dot(projection.tangent)
        let wrongWay = forwardAlongTrack < -2.5 && carts[index].speed > 3
        if wrongWay != (wrongWayFlags[carts[index].id] ?? false) {
            wrongWayFlags[carts[index].id] = wrongWay
            carts[index].isWrongWay = wrongWay
            events.append(.wrongWay(cartID: carts[index].id, active: wrongWay))
        }

        updateLapProgress(index: index, projection: projection, dt: dt)
    }

    /// Last resort for a cart that has wedged itself somewhere: lift it back
    /// onto the racing line facing the right way. Returns true if it fired.
    private func rescueIfStuck(index: Int, projection: TrackProjection, dt: Double) -> Bool {
        let id = carts[index].id
        let idle = carts[index].speed < 1.6 && carts[index].spinTimer <= 0
        stuckTimers[id] = idle ? (stuckTimers[id] ?? 0) + dt : 0
        guard (stuckTimers[id] ?? 0) > 5 else { return false }

        stuckTimers[id] = 0
        let tangent = track.tangent(atDistance: projection.distance)
        carts[index].position = track.racingLinePoint(atDistance: projection.distance)
        carts[index].heading = tangent.angle
        carts[index].velocity = tangent * 6
        carts[index].drift = DriftState()
        carts[index].invincibleTimer = max(carts[index].invincibleTimer, 1.2)
        carts[index].lateral = 0
        carts[index].surface = track.surface(atDistance: projection.distance, lateral: 0)
        updateLapProgress(index: index, projection: track.project(carts[index].position), dt: dt)
        return true
    }

    private func updateLapProgress(index: Int, projection: TrackProjection, dt: Double) {
        _ = dt
        let sectorLength = track.length / Double(track.checkpointCount)
        let sector = min(track.checkpointCount - 1, Int(projection.distance / sectorLength))

        if sector == carts[index].checkpoint {
            carts[index].checkpoint = (sector + 1) % track.checkpointCount
            if sector == 0 {
                registerLineCrossing(index: index)
            }
        }

        carts[index].lapDistance = projection.distance
        let laps = max(0, carts[index].lap - 1)
        carts[index].totalDistance = Double(laps) * track.length + projection.distance
        if carts[index].lap == 0 {
            // Still on the approach to the line for the first time.
            carts[index].totalDistance = projection.distance - track.length
        }
    }

    private func registerLineCrossing(index: Int) {
        if carts[index].lap == 0 {
            carts[index].lap = 1
            carts[index].lapStartTime = time
            return
        }

        let lapTime = time - carts[index].lapStartTime
        carts[index].lapTimes.append(lapTime)
        carts[index].lapStartTime = time
        events.append(.lapCompleted(cartID: carts[index].id, lap: carts[index].lap, lapTime: lapTime))
        carts[index].lap += 1

        if carts[index].lap > config.laps {
            finish(index: index)
        } else if carts[index].lap == config.laps, !finalLapAnnounced.contains(carts[index].id) {
            finalLapAnnounced.insert(carts[index].id)
            events.append(.finalLap(cartID: carts[index].id))
        }
    }

    private func finish(index: Int) {
        carts[index].finishTime = time
        finishOrder.append(carts[index].id)
        carts[index].placement = finishOrder.count
        carts[index].heldItem = nil
        carts[index].orbitingCans = 0
        events.append(.raceFinished(cartID: carts[index].id, place: finishOrder.count, totalTime: time))
        if carts[index].isPlayer {
            phase = .finished
            graceTimer = 18
        }
    }

    private func resolveCartContacts() {
        guard carts.count > 1 else { return }
        for a in 0..<(carts.count - 1) {
            for b in (a + 1)..<carts.count {
                let before = (carts[b].velocity - carts[a].velocity).length
                let touching = carts[a].position.distance(to: carts[b].position)
                    < carts[a].collisionRadius + carts[b].collisionRadius
                guard touching else { continue }
                var first = carts[a]
                var second = carts[b]
                CartPhysics.resolveCartCollision(&first, &second)
                carts[a] = first
                carts[b] = second
                if before > 4 {
                    events.append(.cartBump(cartID: carts[a].id, otherID: carts[b].id, force: before))
                }
            }
        }
    }

    private func resolveProps(dt: Double) {
        _ = dt
        for propIndex in track.props.indices {
            let prop = track.props[propIndex]
            for cartIndex in carts.indices {
                guard !carts[cartIndex].hasFinished else { continue }
                let reach = prop.radius + carts[cartIndex].collisionRadius
                let delta = carts[cartIndex].position - prop.position
                let distance = delta.length
                guard distance < reach, distance > 1e-6 else { continue }

                if prop.isSolid {
                    let normal = delta / distance
                    CartPhysics.resolveWallCollision(
                        cart: &carts[cartIndex],
                        wallNormal: normal,
                        penetration: reach - distance,
                        restitution: 0.15
                    )
                    events.append(.wallImpact(cartID: carts[cartIndex].id, force: carts[cartIndex].speed))
                } else if propCooldowns[propIndex] <= 0 {
                    propCooldowns[propIndex] = 6
                    carts[cartIndex].velocity *= 0.82
                    if prop.kind == .moppingBucket || prop.kind == .canPyramid {
                        carts[cartIndex].applySlow(duration: 0.5)
                    }
                    events.append(.propScattered(index: propIndex))
                }
            }
        }
    }

    // MARK: - Standings

    private func updateStandings() {
        standings = carts.sorted { lhs, rhs in
            switch (lhs.finishTime, rhs.finishTime) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.totalDistance > rhs.totalDistance
            }
        }.map(\.id)

        for (offset, id) in standings.enumerated() {
            if let index = carts.firstIndex(where: { $0.id == id }), !carts[index].hasFinished {
                carts[index].placement = offset + 1
            }
        }
    }

    private func applyDifficultyScaling() {
        let scale: Double
        switch config.difficulty {
        case 0: scale = 0.93
        case 1: scale = 0.985
        default: scale = 1.035
        }
        for index in carts.indices where !carts[index].isPlayer {
            carts[index].stats.topSpeed = carts[index].baseStats.topSpeed * scale
            carts[index].stats.acceleration = carts[index].baseStats.acceleration * scale
        }
    }

    /// Keeps the field within sight of each other without making the AI
    /// obviously teleport: at most +/- 8% top speed.
    private func applyRubberBanding() {
        guard config.rubberBanding else { return }
        let reference: Double
        if let player = playerCart {
            reference = player.totalDistance
        } else if let leader = carts.max(by: { $0.totalDistance < $1.totalDistance }) {
            reference = leader.totalDistance
        } else {
            return
        }

        let baseScale: Double
        switch config.difficulty {
        case 0: baseScale = 0.93
        case 1: baseScale = 0.985
        default: baseScale = 1.035
        }

        for index in carts.indices where !carts[index].isPlayer && !carts[index].hasFinished {
            let gap = reference - carts[index].totalDistance
            let assist = clamp(gap / 140, -1, 1) * 0.08
            let scale = baseScale * (1 + assist)
            carts[index].stats.topSpeed = carts[index].baseStats.topSpeed * scale
            carts[index].stats.acceleration = carts[index].baseStats.acceleration * (1 + assist * 0.7) * baseScale
        }
    }

    private func updateCompletion(dt: Double) {
        if carts.allSatisfy(\.hasFinished) {
            isComplete = true
            return
        }
        if var grace = graceTimer {
            grace -= dt
            graceTimer = grace
            if grace <= 0 {
                // Wrap the race up: everyone still out there is classified in
                // running order so the results screen is complete.
                for id in standings {
                    guard let index = carts.firstIndex(where: { $0.id == id }), !carts[index].hasFinished else { continue }
                    carts[index].finishTime = time + (track.length - carts[index].lapDistance) / 20
                    finishOrder.append(id)
                    carts[index].placement = finishOrder.count
                }
                isComplete = true
            }
        }
    }

    // MARK: - Results

    public var results: [RaceResult] {
        let ordered = carts.sorted { lhs, rhs in
            switch (lhs.finishTime, rhs.finishTime) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.totalDistance > rhs.totalDistance
            }
        }
        return ordered.enumerated().map { offset, cart in
            RaceResult(
                cartID: cart.id,
                place: offset + 1,
                name: cart.setup.character.name,
                isPlayer: cart.isPlayer,
                totalTime: cart.finishTime,
                bestLap: cart.bestLapTime,
                points: GrandPrix.points(forPlace: offset + 1)
            )
        }
    }
}
