import Foundation

/// How a race was set up.
public struct RaceConfiguration: Sendable {
    public enum Mode: String, Sendable {
        case grandPrix
        case singleRace
        /// Alone on the course, no items, chasing the clock.
        case timeTrial
    }

    public enum Difficulty: String, Sendable, CaseIterable {
        case trolleyDash
        case weeklyShop
        case blackFriday

        public var displayName: String {
            switch self {
            case .trolleyDash: return "Trolley Dash"
            case .weeklyShop: return "Weekly Shop"
            case .blackFriday: return "Black Friday"
            }
        }

        /// Baseline AI competence.
        public var skill: Double {
            switch self {
            case .trolleyDash: return 0.68
            case .weeklyShop: return 0.86
            case .blackFriday: return 1.05
            }
        }

        /// How strongly trailing racers get a speed assist.
        public var rubberBand: Double {
            switch self {
            case .trolleyDash: return 0.5
            case .weeklyShop: return 0.85
            case .blackFriday: return 1.1
            }
        }
    }

    public struct Entry: Sendable {
        public let profile: RacerProfile
        public let isPlayer: Bool

        public init(profile: RacerProfile, isPlayer: Bool) {
            self.profile = profile
            self.isPlayer = isPlayer
        }
    }

    public var track: Track
    public var entries: [Entry]
    public var mode: Mode
    public var difficulty: Difficulty
    public var lapCount: Int
    public var seed: UInt64
    public var tuning: RaceTuning

    public init(
        track: Track,
        entries: [Entry],
        mode: Mode = .singleRace,
        difficulty: Difficulty = .weeklyShop,
        lapCount: Int? = nil,
        seed: UInt64 = 0xC0FFEE,
        tuning: RaceTuning = .default
    ) {
        self.track = track
        self.entries = entries
        self.mode = mode
        self.difficulty = difficulty
        self.lapCount = lapCount ?? track.lapCount
        self.seed = seed
        self.tuning = tuning
    }
}

/// Simulates a whole race with a fixed timestep, independent of frame rate.
public final class RaceEngine {
    public let track: Track
    public let tuning: RaceTuning
    public let configuration: RaceConfiguration
    public let lapCount: Int

    public private(set) var karts: [KartState] = []
    public private(set) var hazards: [DroppedHazard] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var itemBoxes: [ItemBoxState] = []
    public private(set) var obstacles: [TrackObstacle]
    public private(set) var phase: RacePhase
    /// Seconds since the lights went green. Negative during the countdown.
    public private(set) var elapsed: Double
    public private(set) var events: [RaceEvent] = []
    public private(set) var results: [RaceResult] = []

    public let playerKartID: Int?

    private var random: SeededRandom
    private var autopilotRandom: SeededRandom
    private var accumulator: Double = 0
    private var nextEntityID: Int = 1
    private var previousUseItem: [Int: Bool] = [:]
    /// Seconds of throttle held during the countdown, for rocket starts.
    private var countdownHold: [Int: Double] = [:]
    private var lastCountdownTick: Int = 4
    private var finishedCount: Int = 0
    private var playerFinishedFor: Double = 0
    /// Cumulative signed lane distance, the basis for laps and ranking.
    private var progressDistance: [Int: Double] = [:]

    /// Once the player is done, wrap the rest of the field up rather than
    /// making them watch the whole convoy roll in.
    public var autoCompleteDelayAfterPlayer: Double = 6

    public init(configuration: RaceConfiguration) {
        self.configuration = configuration
        self.track = configuration.track
        self.tuning = configuration.tuning
        self.lapCount = configuration.lapCount
        self.obstacles = configuration.track.obstacles
        self.random = SeededRandom(seed: configuration.seed)
        self.autopilotRandom = SeededRandom(seed: configuration.seed ^ 0xA11CE)
        self.phase = .countdown(remaining: configuration.tuning.countdownDuration)
        self.elapsed = -configuration.tuning.countdownDuration

        let grid = track.startingGrid(count: configuration.entries.count)
        var player: Int?
        for (index, entry) in configuration.entries.enumerated() {
            let slot = grid[index]
            var kart = KartState(
                id: index,
                profile: entry.profile,
                tuning: configuration.tuning,
                isPlayerControlled: entry.isPlayer,
                position: slot.position,
                heading: slot.heading
            )
            let projection = track.project(slot.position)
            kart.arcLength = projection.arcLength
            kart.lateralOffset = projection.lateralOffset
            kart.sampleHint = projection.sampleIndex
            kart.racePosition = index + 1
            if !entry.isPlayer {
                // Spread skill across the field so the pack strings out.
                let spread = 1.0 - Double(index) * 0.02
                kart.aiSkill = clamp(configuration.difficulty.skill * spread, 0.4, 1.2)
                kart.aiLaneBias = random.double(in: -0.55...0.55)
            } else {
                player = index
            }
            // Karts line up behind the finish line, so start one lane length back.
            progressDistance[index] = projection.arcLength - track.trackLength
            kart.totalProgress = progressDistance[index] ?? 0
            karts.append(kart)
        }
        self.playerKartID = player

        for (index, box) in track.itemBoxes.enumerated() {
            itemBoxes.append(
                ItemBoxState(
                    id: index,
                    position: box.position,
                    radius: box.radius,
                    respawnTimer: 0,
                    arcLength: box.arcLength,
                    lane: box.lane
                )
            )
        }
    }

    // MARK: - Public API

    public var isComplete: Bool { phase == .finished }

    public var playerKart: KartState? {
        guard let playerKartID else { return nil }
        return karts.first { $0.id == playerKartID }
    }

    /// Karts ordered by current race position.
    public var standings: [KartState] {
        karts.sorted { $0.racePosition < $1.racePosition }
    }

    /// Runs the AI controller for any cart, including the player's.
    ///
    /// Used by the attract-mode demo behind the menus, and by tests that need a
    /// cart to actually get round the course.
    public func autopilotInput(for kartID: Int) -> RaceInput {
        guard let kart = karts.first(where: { $0.id == kartID }), phase == .racing else { return .idle }
        let context = AIDriver.Context(
            track: track,
            tuning: tuning,
            hazards: hazards,
            obstacles: obstacles,
            itemBoxes: itemBoxes,
            opponents: karts,
            elapsed: elapsed
        )
        // Deliberately a separate stream so demo driving cannot perturb the
        // deterministic race RNG.
        return AIDriver.input(for: kart, context: context, random: &autopilotRandom)
    }

    /// Removes and returns the events accumulated since the last call.
    public func drainEvents() -> [RaceEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    /// Advances the simulation by real elapsed time, in fixed steps.
    public func advance(deltaTime: Double, playerInput: RaceInput = .idle) {
        guard !isComplete else { return }
        // Clamp so a stall (or a debugger pause) cannot spiral the step count.
        accumulator += clamp(deltaTime, 0, 0.25)
        let step = tuning.fixedTimeStep
        var guardCounter = 0
        while accumulator >= step && guardCounter < 60 {
            accumulator -= step
            guardCounter += 1
            simulate(step: step, playerInput: playerInput)
            if isComplete { break }
        }
    }

    /// Narrow mutation points used by `RaceEngine+TestSupport`.
    func replaceKartForTesting(at index: Int, with kart: KartState) {
        guard karts.indices.contains(index) else { return }
        karts[index] = kart
    }

    func appendHazardForTesting(_ hazard: DroppedHazard) {
        hazards.append(hazard)
    }

    // MARK: - Simulation

    private func simulate(step dt: Double, playerInput: RaceInput) {
        switch phase {
        case .countdown(let remaining):
            updateCountdown(remaining: remaining, playerInput: playerInput, dt: dt)
        case .racing:
            elapsed += dt
        case .finished:
            return
        }

        let racing = phase == .racing
        if racing { updateStuckRecovery(dt: dt) }

        var inputs: [Int: RaceInput] = [:]
        for kart in karts {
            if kart.isPlayerControlled {
                inputs[kart.id] = racing ? playerInput : RaceInput(steer: playerInput.steer)
            } else if racing {
                let context = AIDriver.Context(
                    track: track,
                    tuning: tuning,
                    hazards: hazards,
                    obstacles: obstacles,
                    itemBoxes: itemBoxes,
                    opponents: karts,
                    elapsed: elapsed
                )
                inputs[kart.id] = AIDriver.input(for: kart, context: context, random: &random)
            } else {
                inputs[kart.id] = .idle
            }
        }

        if racing {
            for index in karts.indices {
                karts[index].aiItemTimer = max(0, karts[index].aiItemTimer - dt)
            }
            resolveItemUse(inputs: inputs)
        }

        for index in karts.indices {
            var kart = karts[index]
            kart.surface = surface(for: kart)
            let input = racing ? (inputs[kart.id] ?? .idle) : RaceInput.idle
            let outcome = KartPhysics.step(
                kart: &kart,
                input: input,
                track: track,
                tuning: tuning,
                speedBonus: speedBonus(for: kart),
                dt: dt
            )
            if outcome.releasedTier != .none {
                events.append(.miniTurbo(kartID: kart.id, tier: outcome.releasedTier))
            }
            if outcome.hitWall && kart.speed > 180 {
                events.append(.wallScrape(kartID: kart.id, impact: kart.speed))
            }
            karts[index] = kart
        }

        resolveObstacleCollisions()
        resolveKartCollisions()
        updateItemBoxes(dt: dt)
        updateHazards(dt: dt)
        updateProjectiles(dt: dt)
        updateProgress(dt: dt)
        updateStandings()
        updateCompletion(dt: dt)
    }

    private func updateCountdown(remaining: Double, playerInput: RaceInput, dt: Double) {
        let next = remaining - dt
        let tick = Int(ceil(next - 0.6))
        if tick < lastCountdownTick && tick >= 1 && tick <= 3 {
            lastCountdownTick = tick
            events.append(.countdownTick(tick))
        }

        // Track throttle hold so a well-timed launch gets a rocket start.
        for kart in karts {
            let throttle: Double
            if kart.isPlayerControlled {
                throttle = playerInput.throttle
            } else {
                // AI aims for the window with skill-dependent accuracy.
                let target = tuning.rocketStartWindow.lowerBound
                    + (tuning.rocketStartWindow.upperBound - tuning.rocketStartWindow.lowerBound) * 0.5
                let jitter = (1.1 - kart.aiSkill) * 0.9
                let desired = target + Double((kart.id % 5)) * 0.02 - jitter * 0.5
                throttle = next <= desired ? 1 : 0
            }
            if throttle > 0.5 {
                countdownHold[kart.id, default: 0] += dt
            } else {
                countdownHold[kart.id] = 0
            }
        }

        if next <= 0 {
            phase = .racing
            elapsed = 0
            events.append(.go)
            for index in karts.indices {
                let hold = countdownHold[karts[index].id] ?? 0
                if tuning.rocketStartWindow.contains(hold) {
                    KartPhysics.applyBoost(&karts[index], duration: tuning.rocketStartDuration, strength: 1.05)
                    events.append(.rocketStart(kartID: karts[index].id))
                } else if hold > tuning.rocketStartWindow.upperBound {
                    // Pushed too early: the wheels judder and you bog down.
                    karts[index].disruption = .cloud
                    karts[index].disruptionTimer = 0.8
                }
            }
        } else {
            phase = .countdown(remaining: next)
        }
    }

    /// Notices carts that have stopped making progress and does something
    /// about it: the AI backs out of whatever it is wedged against, and anyone
    /// still stranded after a few seconds gets lifted back onto the lane.
    private func updateStuckRecovery(dt: Double) {
        for index in karts.indices {
            var kart = karts[index]
            defer { karts[index] = kart }
            guard !kart.isFinished else { continue }

            kart.aiReverseTimer = max(0, kart.aiReverseTimer - dt)

            // Being spun out or squashed is meant to stop you; that is not stuck.
            if kart.speed < 70 && kart.disruption == nil {
                kart.stuckTimer += dt
            } else if kart.speed > 150 {
                // Only real progress winds the timer back, so a shove backwards
                // cannot hide a cart that is still jammed against a pallet.
                kart.stuckTimer = max(0, kart.stuckTimer - dt * 2)
            }

            if kart.stuckTimer > tuning.rescueDelay {
                rescue(&kart)
            } else if !kart.isPlayerControlled,
                      kart.aiReverseTimer <= 0,
                      kart.stuckTimer > tuning.aiReverseDelay {
                kart.aiReverseTimer = 0.8
                // Come back on a different line rather than repeating the mistake.
                kart.aiLaneBias = kart.aiLaneBias == 0 ? 0.5 : clamp(-kart.aiLaneBias * 1.3, -0.85, 0.85)
            }
        }
    }

    /// Lifts a cart back onto the centreline facing the right way, the way a
    /// member of staff would untangle a trolley from a display.
    private func rescue(_ kart: inout KartState) {
        let index = track.sampleIndex(atArcLength: kart.arcLength)
        let sample = track.sample(at: index)
        // Put the cart down on clear floor: the centreline itself sometimes has
        // a pallet stack on it, which would stick the cart straight back.
        var placement = sample.position
        for lane in [0.0, 0.45, -0.45, 0.8, -0.8] {
            let candidate = sample.position + sample.tangent.perpendicular * (lane * sample.halfWidth)
            if isClearForRescue(candidate, ignoring: kart.id) {
                placement = candidate
                break
            }
        }
        kart.position = placement
        kart.heading = sample.tangent.angle
        // A push to get going, rather than being dumped at a dead stop.
        kart.velocity = sample.tangent * 140
        kart.isDrifting = false
        kart.driftCharge = 0
        kart.driftTier = .none
        kart.disruption = nil
        kart.disruptionTimer = 0
        kart.spinVisual = 0
        kart.invulnerabilityTimer = max(kart.invulnerabilityTimer, 1.5)
        kart.stuckTimer = 0
        kart.aiReverseTimer = 0
        events.append(.rescued(kartID: kart.id))
    }

    private func isClearForRescue(_ position: Vec2, ignoring kartID: Int) -> Bool {
        for obstacle in obstacles
        where obstacle.position.distance(to: position) < obstacle.radius + tuning.cartRadius * 1.6 {
            return false
        }
        for other in karts
        where other.id != kartID && other.position.distance(to: position) < tuning.cartRadius * 2.4 {
            return false
        }
        return true
    }

    /// Combined pace modifier: a flat handicap by difficulty plus catch-up assist.
    private func speedBonus(for kart: KartState) -> Double {
        // Weaker fields simply do not have the legs; this is what makes
        // Trolley Dash beatable and Black Friday not.
        var bonus = kart.isPlayerControlled ? 1.0 : 1 + (kart.aiSkill - 1.0) * 0.16

        guard configuration.mode != .timeTrial, karts.count > 1 else { return bonus }
        let leader = karts.map(\.totalProgress).max() ?? kart.totalProgress
        let behind = leader - kart.totalProgress
        guard behind > 0 else { return bonus }
        let normalized = clamp(behind / tuning.rubberBandRange, 0, 1)
        let strength = tuning.rubberBandMaxBonus * configuration.difficulty.rubberBand
        // The player gets a gentler hand than the AI.
        let scale = kart.isPlayerControlled ? 0.65 : 1.0
        bonus += normalized * strength * scale
        return bonus
    }

    private func surface(for kart: KartState) -> SurfaceKind {
        for hazard in hazards where hazard.kind == .moppedFloor {
            if hazard.position.distance(to: kart.position) < hazard.radius {
                return .slick
            }
        }
        return track.surface(at: kart.position, hint: kart.sampleHint)
    }

    // MARK: - Items

    private func resolveItemUse(inputs: [Int: RaceInput]) {
        for index in karts.indices {
            let id = karts[index].id
            let input = inputs[id] ?? .idle
            let wasPressed = previousUseItem[id] ?? false
            previousUseItem[id] = input.useItem
            guard input.useItem, !wasPressed else { continue }
            guard karts[index].item != nil, !karts[index].isFinished else { continue }
            fireItem(kartIndex: index, backwards: input.aimBackwards)
        }
    }

    private func fireItem(kartIndex: Int, backwards: Bool) {
        guard var held = karts[kartIndex].item else { return }
        let kart = karts[kartIndex]
        let forward = Vec2.direction(kart.heading)
        events.append(.itemUsed(kartID: kart.id, kind: held.kind))

        switch held.kind {
        case .energyDrink:
            KartPhysics.applyBoost(&karts[kartIndex], duration: tuning.energyDrinkDuration, strength: 1.1)

        case .bulkBuy:
            karts[kartIndex].bulkBuyTimer = tuning.bulkBuyDuration
            karts[kartIndex].disruption = nil
            karts[kartIndex].disruptionTimer = 0

        case .grapeSpill:
            spawnHazard(.grapeSpill, at: kart.position - forward * 52, radius: 34, owner: kart.id, life: 26)

        case .mopBucket:
            spawnHazard(.moppedFloor, at: kart.position - forward * 66, radius: 78, owner: kart.id, life: 16)

        case .flourBomb:
            spawnHazard(.flourCloud, at: kart.position - forward * 60, radius: 92, owner: kart.id, life: 8)

        case .soupCan, .tripleSoup:
            let direction = backwards ? -forward : forward
            let launchSpeed = max(kart.forwardSpeed, 0) + (backwards ? 340 : 620)
            spawnProjectile(
                .soupCan,
                position: kart.position + direction * 46,
                velocity: direction * launchSpeed,
                owner: kart.id,
                life: 4.5,
                radius: 20,
                target: backwards ? nil : nearestTargetAhead(of: kart)
            )

        case .runawayMelon:
            spawnProjectile(
                .runawayMelon,
                position: kart.position + forward * 40,
                velocity: forward * 500,
                owner: kart.id,
                life: 24,
                radius: 34,
                target: leaderID(excluding: kart.id)
            )
        }

        held.charges -= 1
        karts[kartIndex].item = held.charges > 0 ? held : nil
        karts[kartIndex].aiItemTimer = held.charges > 0 ? 0.45 : 1.4
    }

    private func spawnHazard(_ kind: DroppedHazard.Kind, at position: Vec2, radius: Double, owner: Int?, life: Double) {
        hazards.append(
            DroppedHazard(
                id: takeEntityID(),
                kind: kind,
                position: position,
                radius: radius,
                ownerID: owner,
                remainingLife: life,
                ownerGrace: 0.9
            )
        )
    }

    private func spawnProjectile(
        _ kind: Projectile.Kind,
        position: Vec2,
        velocity: Vec2,
        owner: Int,
        life: Double,
        radius: Double,
        target: Int?
    ) {
        let projection = track.project(position)
        projectiles.append(
            Projectile(
                id: takeEntityID(),
                kind: kind,
                position: position,
                velocity: velocity,
                ownerID: owner,
                remainingLife: life,
                trackArcLength: projection.arcLength,
                targetID: target,
                radius: radius
            )
        )
    }

    private func takeEntityID() -> Int {
        defer { nextEntityID += 1 }
        return nextEntityID
    }

    private func nearestTargetAhead(of kart: KartState) -> Int? {
        var best: (id: Int, gap: Double)?
        for other in karts where other.id != kart.id && !other.isFinished {
            let gap = track.arcDelta(from: kart.arcLength, to: other.arcLength)
            guard gap > 0, gap < 900 else { continue }
            if best == nil || gap < best!.gap { best = (other.id, gap) }
        }
        return best?.id
    }

    private func leaderID(excluding: Int) -> Int? {
        karts
            .filter { $0.id != excluding && !$0.isFinished }
            .max(by: { $0.totalProgress < $1.totalProgress })?
            .id
    }

    private func updateItemBoxes(dt: Double) {
        guard configuration.mode != .timeTrial else { return }
        for boxIndex in itemBoxes.indices {
            if itemBoxes[boxIndex].respawnTimer > 0 {
                itemBoxes[boxIndex].respawnTimer = max(0, itemBoxes[boxIndex].respawnTimer - dt)
                continue
            }
            let box = itemBoxes[boxIndex]
            for kartIndex in karts.indices {
                let kart = karts[kartIndex]
                guard kart.item == nil, kart.pendingItem == nil, !kart.isFinished else { continue }
                guard kart.position.distance(to: box.position) < box.radius + tuning.cartRadius else { continue }
                let fraction = karts.count > 1
                    ? Double(kart.racePosition - 1) / Double(karts.count - 1)
                    : 0
                let kind = ItemRoulette.roll(
                    positionFraction: fraction,
                    racerCount: karts.count,
                    random: &random
                )
                karts[kartIndex].pendingItem = kind
                karts[kartIndex].itemRouletteTimer = kart.isPlayerControlled ? 0.85 : 0.35
                itemBoxes[boxIndex].respawnTimer = tuning.itemBoxRespawn
                events.append(.itemBoxCollected(kartID: kart.id, boxID: box.id))
                events.append(.itemGranted(kartID: kart.id, kind: kind))
                break
            }
        }
    }

    private func updateHazards(dt: Double) {
        for index in hazards.indices {
            hazards[index].remainingLife -= dt
            hazards[index].ownerGrace = max(0, hazards[index].ownerGrace - dt)
        }

        var consumed = Set<Int>()
        for hazard in hazards {
            for kartIndex in karts.indices {
                var kart = karts[kartIndex]
                guard !kart.isFinished else { continue }
                if hazard.ownerID == kart.id && hazard.ownerGrace > 0 { continue }
                guard kart.position.distance(to: hazard.position) < hazard.radius + tuning.cartRadius * 0.7 else { continue }

                switch hazard.kind {
                case .grapeSpill:
                    if kart.isInvincible {
                        consumed.insert(hazard.id)
                    } else if KartPhysics.applyDisruption(&kart, .spin, tuning: tuning) {
                        consumed.insert(hazard.id)
                        events.append(.kartHit(kartID: kart.id, by: .spin, sourceKartID: hazard.ownerID))
                    }
                case .moppedFloor:
                    // Grip loss is handled by the surface; hitting it fast also
                    // costs you steering for a moment.
                    if kart.speed > 340, kart.disruption == nil, !kart.isInvincible {
                        if KartPhysics.applyDisruption(&kart, .slip, tuning: tuning) {
                            events.append(.kartHit(kartID: kart.id, by: .slip, sourceKartID: hazard.ownerID))
                        }
                    }
                case .flourCloud:
                    if !kart.isInvincible, kart.disruption == nil {
                        if KartPhysics.applyDisruption(&kart, .cloud, tuning: tuning) {
                            events.append(.kartHit(kartID: kart.id, by: .cloud, sourceKartID: hazard.ownerID))
                        }
                    }
                }
                karts[kartIndex] = kart
            }
        }

        hazards.removeAll { $0.remainingLife <= 0 || consumed.contains($0.id) }
    }

    private func updateProjectiles(dt: Double) {
        var expired = Set<Int>()

        for index in projectiles.indices {
            var projectile = projectiles[index]
            projectile.remainingLife -= dt

            switch projectile.kind {
            case .soupCan:
                // Gentle homing so a well-aimed tin does not miss by a whisker.
                if let targetID = projectile.targetID,
                   let target = karts.first(where: { $0.id == targetID }),
                   !target.isFinished {
                    let toTarget = target.position - projectile.position
                    if toTarget.length < 520 {
                        let desired = toTarget.normalized * projectile.velocity.length
                        projectile.velocity = (projectile.velocity + (desired - projectile.velocity) * clamp(2.4 * dt, 0, 1))
                    }
                }
                projectile.position += projectile.velocity * dt
                // Tins skitter off the shelving and die.
                let projection = track.project(projectile.position)
                if abs(projection.lateralOffset) > projection.halfWidth + track.shoulderWidth {
                    expired.insert(projectile.id)
                }

            case .runawayMelon:
                // Rolls along the racing line hunting the leader.
                let targetProgress: Double
                if let targetID = projectile.targetID,
                   let target = karts.first(where: { $0.id == targetID }) {
                    targetProgress = target.arcLength
                } else {
                    targetProgress = projectile.trackArcLength + 400
                }
                let gap = track.arcDelta(from: projectile.trackArcLength, to: targetProgress)
                let speed: Double = gap > 900 ? 1250 : 900
                projectile.trackArcLength = track.wrapArcLength(projectile.trackArcLength + speed * dt)
                let newPosition = track.position(atArcLength: projectile.trackArcLength)
                projectile.velocity = (newPosition - projectile.position) / max(dt, 1e-6)
                projectile.position = newPosition
            }

            projectiles[index] = projectile
            if projectile.remainingLife <= 0 { expired.insert(projectile.id) }
        }

        // Collisions with carts.
        for projectile in projectiles where !expired.contains(projectile.id) {
            for kartIndex in karts.indices {
                var kart = karts[kartIndex]
                guard !kart.isFinished else { continue }
                if kart.id == projectile.ownerID && projectile.remainingLife > 4.0 { continue }
                guard kart.position.distance(to: projectile.position) < projectile.radius + tuning.cartRadius else { continue }

                switch projectile.kind {
                case .soupCan:
                    if kart.isInvincible {
                        expired.insert(projectile.id)
                    } else if KartPhysics.applyDisruption(&kart, .spin, tuning: tuning) {
                        expired.insert(projectile.id)
                        events.append(.kartHit(kartID: kart.id, by: .spin, sourceKartID: projectile.ownerID))
                    }
                case .runawayMelon:
                    // Only detonates on its mark; everyone else just gets splashed.
                    guard kart.id == projectile.targetID || projectile.targetID == nil else { continue }
                    expired.insert(projectile.id)
                    if KartPhysics.applyDisruption(&kart, .squash, tuning: tuning) {
                        events.append(.kartHit(kartID: kart.id, by: .squash, sourceKartID: projectile.ownerID))
                    }
                    splashDamage(around: projectile.position, radius: 190, excluding: kart.id, source: projectile.ownerID)
                }
                karts[kartIndex] = kart
                if expired.contains(projectile.id) { break }
            }
        }

        projectiles.removeAll { expired.contains($0.id) }
    }

    private func splashDamage(around position: Vec2, radius: Double, excluding: Int, source: Int?) {
        for index in karts.indices {
            var kart = karts[index]
            guard kart.id != excluding, !kart.isFinished else { continue }
            guard kart.position.distance(to: position) < radius else { continue }
            if KartPhysics.applyDisruption(&kart, .spin, tuning: tuning) {
                events.append(.kartHit(kartID: kart.id, by: .spin, sourceKartID: source))
            }
            karts[index] = kart
        }
    }

    // MARK: - Contacts

    private func resolveObstacleCollisions() {
        var smashed: [Int] = []
        for (obstacleIndex, obstacle) in obstacles.enumerated() {
            for kartIndex in karts.indices {
                var kart = karts[kartIndex]
                let offset = kart.position - obstacle.position
                let minimum = obstacle.radius + tuning.cartRadius
                let distance = offset.length
                guard distance < minimum, distance > 1e-6 else { continue }

                if obstacle.isBreakable || kart.isInvincible {
                    smashed.append(obstacleIndex)
                    events.append(.obstacleSmashed(position: obstacle.position, style: obstacle.style))
                    if !kart.isInvincible {
                        kart.velocity *= 0.82
                    }
                } else {
                    let normal = offset / distance
                    kart.position = obstacle.position + normal * minimum
                    let into = kart.velocity.dot(normal)
                    if into < 0 {
                        // Slide around the obstacle rather than stopping dead
                        // against it: a cart parked on a pallet stack for the
                        // rest of the lap is no fun for anybody.
                        let tangent = normal.perpendicular
                        var alongside = kart.velocity.dot(tangent)
                        if abs(alongside) < 70 {
                            // Dead-on hit: pick the side with more track on it.
                            alongside = 70 * deflectionSide(for: obstacle, tangent: tangent)
                        }
                        let bounce = -into * 0.25
                        kart.velocity = normal * bounce
                            + tangent * (alongside * (1 - tuning.obstacleSpeedLoss * 0.35))
                        if kart.speed > 260 {
                            events.append(.wallScrape(kartID: kart.id, impact: kart.speed))
                        }
                    }
                    kart.isDrifting = false
                    kart.driftCharge = 0
                    kart.driftTier = .none
                }
                karts[kartIndex] = kart
            }
        }
        if !smashed.isEmpty {
            let unique = Set(smashed)
            obstacles = obstacles.enumerated().filter { !unique.contains($0.offset) }.map(\.element)
        }
    }

    /// Which way along `tangent` points back towards the middle of the aisle.
    private func deflectionSide(for obstacle: TrackObstacle, tangent: Vec2) -> Double {
        let projection = track.project(obstacle.position)
        // Positive lateral offset means the prop sits left of the centreline,
        // so the roomier side is to its right.
        let towardsCentre = projection.tangent.perpendicular * (projection.lateralOffset > 0 ? -1 : 1)
        return tangent.dot(towardsCentre) >= 0 ? 1 : -1
    }

    private func resolveKartCollisions() {
        guard karts.count > 1 else { return }
        let minimum = tuning.cartRadius * 2
        for i in 0..<(karts.count - 1) {
            for j in (i + 1)..<karts.count {
                let offset = karts[j].position - karts[i].position
                let distance = offset.length
                guard distance < minimum, distance > 1e-6 else { continue }
                let normal = offset / distance
                let overlap = minimum - distance

                let massA = karts[i].physics.mass
                let massB = karts[j].physics.mass
                let total = massA + massB
                karts[i].position -= normal * (overlap * massB / total)
                karts[j].position += normal * (overlap * massA / total)

                let relative = (karts[j].velocity - karts[i].velocity).dot(normal)
                if relative < 0 {
                    let impulse = -(1 + tuning.cartRestitution) * relative / total
                    karts[i].velocity -= normal * (impulse * massB)
                    karts[j].velocity += normal * (impulse * massA)
                    let impact = abs(relative)
                    if impact > 90 {
                        events.append(.kartBumped(kartID: karts[i].id, otherID: karts[j].id, impact: impact))
                    }
                }

                // An invincible cart sends the other one flying.
                if karts[i].isInvincible != karts[j].isInvincible {
                    let victim = karts[i].isInvincible ? j : i
                    let bully = karts[i].isInvincible ? i : j
                    var kart = karts[victim]
                    if KartPhysics.applyDisruption(&kart, .spin, tuning: tuning) {
                        kart.velocity += (victim == j ? normal : -normal) * 420
                        events.append(.kartHit(kartID: kart.id, by: .spin, sourceKartID: karts[bully].id))
                    }
                    karts[victim] = kart
                }
            }
        }
    }

    // MARK: - Progress and standings

    private func updateProgress(dt: Double) {
        for index in karts.indices {
            var kart = karts[index]
            let projection = track.project(kart.position, hint: kart.sampleHint)
            let delta = track.arcDelta(from: kart.arcLength, to: projection.arcLength)
            kart.arcLength = projection.arcLength
            kart.lateralOffset = projection.lateralOffset
            kart.sampleHint = projection.sampleIndex

            var distance = progressDistance[kart.id] ?? 0
            distance += delta
            progressDistance[kart.id] = distance
            kart.totalProgress = distance

            let wrongWay = kart.speed > 90 && kart.velocity.dot(projection.tangent) < -60 && !kart.isFinished
            if wrongWay != kart.isWrongWay {
                kart.isWrongWay = wrongWay
                events.append(.wrongWay(kartID: kart.id, active: wrongWay))
            }

            if !kart.isFinished, phase == .racing {
                let completed = distance > 0 ? Int(floor(distance / track.trackLength)) : 0
                if completed > kart.lapsCompleted {
                    let lapTime = elapsed - kart.currentLapStart
                    kart.lapsCompleted = completed
                    kart.lapTimes.append(lapTime)
                    kart.currentLapStart = elapsed
                    events.append(.lapCompleted(kartID: kart.id, lap: completed, lapTime: lapTime))
                    if completed == lapCount - 1 {
                        events.append(.finalLap(kartID: kart.id))
                    }
                    if completed >= lapCount {
                        finish(kartIndex: index, kart: &kart, time: elapsed)
                    }
                }
            }
            karts[index] = kart
        }
    }

    private func finish(kartIndex: Int, kart: inout KartState, time: Double) {
        finishedCount += 1
        kart.finishTime = time
        kart.finishPlace = finishedCount
        kart.item = nil
        kart.pendingItem = nil
        events.append(.finished(kartID: kart.id, place: finishedCount, totalTime: time))
    }

    private func updateStandings() {
        let ordered = karts.indices.sorted { lhs, rhs in
            let a = karts[lhs]
            let b = karts[rhs]
            switch (a.finishPlace, b.finishPlace) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.totalProgress > b.totalProgress
            }
        }
        for (place, index) in ordered.enumerated() {
            karts[index].racePosition = place + 1
        }
    }

    private func updateCompletion(dt: Double) {
        if let playerKartID, let player = karts.first(where: { $0.id == playerKartID }), player.isFinished {
            playerFinishedFor += dt
        }
        let everyoneHome = karts.allSatisfy(\.isFinished)
        let timedOut = playerFinishedFor >= autoCompleteDelayAfterPlayer
        guard everyoneHome || timedOut else { return }

        if !everyoneHome {
            // Freeze the remaining order by current progress.
            let stragglers = karts.indices
                .filter { !karts[$0].isFinished }
                .sorted { karts[$0].totalProgress > karts[$1].totalProgress }
            for index in stragglers {
                var kart = karts[index]
                finish(kartIndex: index, kart: &kart, time: elapsed)
                karts[index] = kart
            }
        }

        phase = .finished
        results = karts
            .sorted { ($0.finishPlace ?? .max) < ($1.finishPlace ?? .max) }
            .map { kart in
                RaceResult(
                    kartID: kart.id,
                    profile: kart.profile,
                    place: kart.finishPlace ?? karts.count,
                    totalTime: kart.finishTime,
                    bestLap: kart.lapTimes.min(),
                    isPlayer: kart.isPlayerControlled
                )
            }
        events.append(.raceComplete)
    }
}

public extension RaceEngine {
    /// Convenience for tests and demos: run the whole race headlessly.
    /// - Returns: the final results, or an empty array if the race stalled.
    @discardableResult
    func runToCompletion(
        maxSimulatedSeconds: Double = 600,
        playerInput: @escaping (RaceEngine) -> RaceInput = { _ in .fullThrottle }
    ) -> [RaceResult] {
        let step = tuning.fixedTimeStep
        var simulated = 0.0
        while !isComplete && simulated < maxSimulatedSeconds {
            advance(deltaTime: step, playerInput: playerInput(self))
            simulated += step
            // Events would otherwise accumulate forever in a long headless run.
            if events.count > 4096 { _ = drainEvents() }
        }
        return results
    }
}
