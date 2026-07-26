import Foundation

/// The whole game, minus the pixels.
///
/// The simulation runs on a fixed timestep and is fully deterministic given the
/// same seed and the same input stream, which is what makes it testable without
/// a screen. Nothing in here knows about SpriteKit, UIKit or audio.
public final class RaceSimulation {
    public let configuration: RaceConfiguration
    public var tuning: SimulationTuning
    /// Balance switch: lets the lab time the field with drifting disabled to
    /// confirm that sliding through corners is actually the faster line.
    public var aiDriftingEnabled = true

    // Written by the dynamics and item extensions, read-only to the app.
    public internal(set) var carts: [CartState] = []
    public internal(set) var projectiles: [Projectile] = []
    public internal(set) var hazards: [Hazard] = []
    public internal(set) var itemBoxes: [ItemBoxRuntime] = []
    public internal(set) var tokens: [TokenRuntime] = []
    public private(set) var phase: RacePhase
    /// Seconds since the simulation began, including the countdown.
    public private(set) var elapsedTime: Double = 0
    /// Seconds since the lights went green. Lap times are measured against this.
    public private(set) var raceClock: Double = 0

    var track: Track { configuration.track }
    var geometry: TrackGeometry { configuration.track.geometry }

    var random: DeterministicRandom
    var aiProfiles: [Int: AIProfile] = [:]
    /// Centreline projections of the static obstacles, in definition order.
    var obstacleLocations: [TrackGeometry.Location] = []
    var pendingEvents: [RaceEvent] = []
    var nextObjectID = 1

    /// Tracks the previous frame's item button so firing is edge-triggered.
    var itemButtonDown: [Int: Bool] = [:]
    let roulette = ItemRoulette()

    private var inputs: [Int: DriverInput] = [:]
    private var rocketCharge: [Int: Double] = [:]
    private var accumulator: Double = 0
    private var lastBeepAnnounced = Int.max
    private var finishedCount = 0

    public init(configuration: RaceConfiguration, tuning: SimulationTuning = SimulationTuning()) {
        self.configuration = configuration
        self.tuning = tuning
        self.random = DeterministicRandom(seed: configuration.seed)
        self.phase = .countdown(remaining: configuration.countdownDuration)
        buildGrid()
        buildPickups()
    }

    // MARK: - Setup

    private func buildGrid() {
        let entries = configuration.entries
        // Pole goes to the front of the grid; the player lines up at the back so
        // there is actually a race to drive rather than a lonely time trial.
        let slotOrder: [Int] = {
            var order = Array(entries.indices)
            if let playerIndex = entries.firstIndex(where: \.isPlayer) {
                order.removeAll { $0 == playerIndex }
                order.append(playerIndex)
            }
            return order
        }()

        for (slot, entryIndex) in slotOrder.enumerated() {
            let entry = entries[entryIndex]
            let grid = track.gridSlot(index: slot)
            var cart = CartState(
                id: entryIndex,
                racer: entry.racer,
                isPlayer: entry.isPlayer,
                position: grid.position,
                heading: grid.heading,
                startDistance: -grid.distanceBehindLine
            )
            let location = geometry.location(of: grid.position)
            cart.distance = location.distance
            cart.lateral = location.lateral
            cart.surface = location.surface
            cart.segmentHint = location.segmentIndex
            cart.racePosition = slot + 1
            carts.append(cart)

            if !entry.isPlayer {
                aiProfiles[entryIndex] = AIProfile(
                    racer: entry.racer,
                    difficulty: configuration.difficulty,
                    random: &random
                )
            }
            inputs[entryIndex] = .idle
            itemButtonDown[entryIndex] = false
            rocketCharge[entryIndex] = 0
        }

        carts.sort { $0.id < $1.id }
    }

    private func buildPickups() {
        // Static scenery is projected onto the centreline once here; the AI reads
        // these cached offsets every tick and must not re-project them.
        obstacleLocations = configuration.track.definition.obstacles.map {
            geometry.location(of: $0.position)
        }

        for spawn in configuration.track.definition.itemBoxes {
            let location = geometry.location(of: spawn.position)
            itemBoxes.append(
                ItemBoxRuntime(
                    id: nextObjectID,
                    spawn: spawn,
                    trackDistance: location.distance,
                    trackLateral: location.lateral
                )
            )
            nextObjectID += 1
        }
        for spawn in configuration.track.definition.tokens {
            tokens.append(TokenRuntime(id: nextObjectID, spawn: spawn))
            nextObjectID += 1
        }
    }

    // MARK: - Public interface

    public var playerCart: CartState? {
        carts.first { $0.isPlayer }
    }

    public var playerCartID: Int? {
        carts.first { $0.isPlayer }?.id
    }

    public var totalLaps: Int { configuration.laps }

    public var trackLength: Double { geometry.totalLength }

    /// Field ordered by race position.
    public var standings: [CartState] {
        carts.sorted { $0.racePosition < $1.racePosition }
    }

    public func cart(id: Int) -> CartState? {
        carts.first { $0.id == id }
    }

    public func setInput(_ input: DriverInput, forCart id: Int) {
        inputs[id] = input
    }

    /// Hands the player's cart to the AI. Used by the headless harness and by
    /// the attract-mode demo on the main menu.
    public func installAutopilot() {
        for cart in carts where aiProfiles[cart.id] == nil {
            aiProfiles[cart.id] = AIProfile(
                racer: cart.racer,
                difficulty: configuration.difficulty,
                random: &random
            )
        }
    }

    /// Convenience for the single-player case.
    public func setPlayerInput(_ input: DriverInput) {
        if let id = playerCartID { inputs[id] = input }
    }

    public func drainEvents() -> [RaceEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    func emit(_ event: RaceEvent) {
        pendingEvents.append(event)
    }

    /// Advances the world by a wall-clock delta, breaking it into fixed steps.
    public func update(deltaTime: Double) {
        guard phase != .complete else { return }
        // A long stall (app backgrounded, debugger paused) must not turn into a
        // hundred catch-up steps.
        accumulator += min(max(deltaTime, 0), 0.5)
        var steps = 0
        while accumulator >= tuning.fixedTimeStep && steps < tuning.maxSubstepsPerFrame {
            step(tuning.fixedTimeStep)
            accumulator -= tuning.fixedTimeStep
            steps += 1
            if phase == .complete { break }
        }
        if steps == tuning.maxSubstepsPerFrame {
            accumulator = 0
        }
    }

    /// One fixed step. Exposed so tests can run a race far faster than realtime.
    public func step(_ delta: Double) {
        guard phase != .complete else { return }
        elapsedTime += delta

        switch phase {
        case .countdown(let remaining):
            advanceCountdown(remaining: remaining, delta: delta)
        case .racing:
            raceClock += delta
            advanceRacing(delta: delta)
        case .complete:
            return
        }
    }

    // MARK: - Countdown

    private func advanceCountdown(remaining: Double, delta: Double) {
        let next = remaining - delta

        let beep = Int(ceil(max(next, 0)))
        if beep < lastBeepAnnounced, beep >= 1 {
            lastBeepAnnounced = beep
            emit(.countdownBeep(count: beep))
        }

        // Rocket start: feathering the throttle as the lights go out pays off,
        // flooring it from the very beginning floods the wheels.
        for cart in carts {
            let input = inputs[cart.id] ?? .idle
            if input.throttle > 0.5 {
                rocketCharge[cart.id, default: 0] += delta
            }
        }

        if next <= 0 {
            phase = .racing
            emit(.raceStarted)
            startRocketStarts()
            for index in carts.indices {
                carts[index].lapStartTime = 0
            }
        } else {
            phase = .countdown(remaining: next)
        }
    }

    private func startRocketStarts() {
        for index in carts.indices {
            let cart = carts[index]
            if cart.isPlayer {
                let charge = rocketCharge[cart.id] ?? 0
                if charge > 0.9 {
                    carts[index].stallTimer = 0.85
                    emit(.floodedEngine(cartID: cart.id))
                } else if charge > 0.06 {
                    applyBoost(to: index, duration: 1.15, strength: 1.25)
                    emit(.rocketStart(cartID: cart.id))
                }
            } else {
                // The AI nails the start about as often as its skill suggests.
                let skill = aiProfiles[cart.id]?.skill ?? 0.5
                if random.nextBool(probability: skill * 0.75) {
                    applyBoost(to: index, duration: 1.0, strength: 1.2)
                    emit(.rocketStart(cartID: cart.id))
                }
            }
        }
    }

    // MARK: - Racing

    private func advanceRacing(delta: Double) {
        updatePerformanceScales()

        for index in carts.indices {
            let cart = carts[index]
            // A cart drives itself if it has an AI profile, which is also how the
            // headless harness puts the player under autopilot.
            var input = aiProfiles[cart.id] == nil ? (inputs[cart.id] ?? .idle) : aiInput(for: index)
            if cart.hasFinished {
                // Finished carts coast to a stop out of everyone's way.
                input = DriverInput(throttle: -0.25, steer: input.steer * 0.4)
            }
            carts[index].lastInput = input
            integrate(cartIndex: index, input: input, delta: delta)
        }

        for index in carts.indices {
            resolveTrackBounds(cartIndex: index, delta: delta)
        }

        resolveCartCollisions()
        resolveObstacleCollisions()
        updateProjectiles(delta: delta)
        updateHazards(delta: delta)
        updatePickups(delta: delta)
        handleItemButtons()
        updateProgressAndFinishing()
        updateRanking()

        let playerIsHome = configuration.endsWhenPlayerFinishes && (playerCart?.hasFinished ?? false)
        if carts.allSatisfy(\.hasFinished) || playerIsHome {
            phase = .complete
            emit(.raceComplete)
        }
    }

    private func updatePerformanceScales() {
        guard let player = playerCart else { return }
        let banding = configuration.difficulty.rubberBanding
        let skill = configuration.difficulty.aiSkill
        for index in carts.indices where !carts[index].isPlayer {
            let gap = player.travelled - carts[index].travelled
            // Positive gap: the AI is behind and gets a nudge; ahead and it eases off.
            let elastic = Scalar.clamp(gap / 120, -1, 1) * banding
            carts[index].performanceScale = (0.9 + 0.11 * skill) + elastic
        }
    }

    private func updateProgressAndFinishing() {
        let length = trackLength
        for index in carts.indices where !carts[index].hasFinished {
            let cart = carts[index]
            let completed = cart.lapsCompleted(trackLength: length)
            guard completed > cart.lapTimes.count else { continue }

            let lapTime = raceClock - cart.lapStartTime
            carts[index].lapTimes.append(lapTime)
            carts[index].lapStartTime = raceClock
            emit(.lapCompleted(cartID: cart.id, lap: carts[index].lapTimes.count, lapTime: lapTime))

            if carts[index].lapTimes.count >= configuration.laps {
                finishedCount += 1
                carts[index].finishTime = raceClock
                carts[index].racePosition = finishedCount
                carts[index].heldItem = nil
                emit(.finished(cartID: cart.id, racePosition: finishedCount, totalTime: raceClock))
            }
        }
    }

    private func updateRanking() {
        let ordered = carts.indices.sorted { lhs, rhs in
            let a = carts[lhs]
            let b = carts[rhs]
            switch (a.finishTime, b.finishTime) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: break
            }
            if abs(a.travelled - b.travelled) > 1e-9 { return a.travelled > b.travelled }
            return a.id < b.id
        }
        for (rank, index) in ordered.enumerated() {
            carts[index].racePosition = rank + 1
        }
    }

    // MARK: - Results

    public func result() -> RaceResult {
        RaceResult(
            trackID: configuration.track.id,
            trackName: configuration.track.name,
            laps: configuration.laps,
            difficulty: configuration.difficulty,
            standings: standings.map { cart in
                RaceResult.Standing(
                    cartID: cart.id,
                    racerID: cart.racer.id,
                    racerName: cart.racer.name,
                    isPlayer: cart.isPlayer,
                    position: cart.racePosition,
                    totalTime: cart.finishTime,
                    bestLapTime: cart.bestLapTime,
                    lapTimes: cart.lapTimes,
                    tokens: cart.tokens
                )
            }
        )
    }
}
