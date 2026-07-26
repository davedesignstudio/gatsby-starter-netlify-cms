import Foundation

/// Everything about one cart at one instant. The renderer reads this straight
/// out of the simulation; it is a value type so a frame can be snapshotted.
public struct CartState: Identifiable, Sendable {
    public let id: Int
    public let racer: Racer
    public let tuning: CartTuning
    public let isPlayer: Bool

    public var position: Vector2
    /// Direction the cart is pointing, in radians.
    public var heading: Double
    public var velocity: Vector2
    /// Extra spin applied while spun out, purely so it looks chaotic.
    public var spinRate: Double

    // MARK: Progress

    /// Arc length along the centreline, wrapped to one lap.
    public var distance: Double
    /// Signed offset from the centreline; positive is left of travel.
    public var lateral: Double
    /// Continuously accumulated distance since the grid. Starts negative
    /// because the grid sits behind the line, and is the single source of truth
    /// for lap counting and race position — you cannot skip arc length.
    public var travelled: Double
    public var surface: Surface
    public var isOffRoad: Bool
    public var segmentHint: Int
    public var racePosition: Int

    // MARK: Timing

    public var lapStartTime: Double
    public var lapTimes: [Double]
    public var finishTime: Double?

    // MARK: Condition

    public var boostTimer: Double
    public var boostStrength: Double
    public var spinoutTimer: Double
    public var stallTimer: Double
    public var slipTimer: Double
    public var invulnerabilityTimer: Double
    public var expressLaneTimer: Double
    public var shieldCharges: Int
    public var shieldAngle: Double
    public var heldItem: ItemKind?
    public var tokens: Int

    // MARK: Drift

    public var isDrifting: Bool
    public var driftCharge: Double
    /// +1 when sliding left, -1 when sliding right, 0 when not drifting.
    public var driftDirection: Double
    /// How long the driver has been fighting the slide. Held long enough, the
    /// drift is abandoned — being locked into a wrong-way slide is miserable.
    public var counterSteerTimer: Double

    // MARK: Bookkeeping

    public var stuckTimer: Double
    /// Decays after a scrape; the renderer uses it for sparks.
    public var scrapeIntensity: Double
    /// AI-only handicap multiplier applied to top speed.
    public var performanceScale: Double
    public var lastInput: DriverInput

    public init(id: Int, racer: Racer, isPlayer: Bool, position: Vector2, heading: Double, startDistance: Double) {
        self.id = id
        self.racer = racer
        self.tuning = CartTuning(racer: racer)
        self.isPlayer = isPlayer
        self.position = position
        self.heading = heading
        self.velocity = .zero
        self.spinRate = 0
        self.distance = startDistance
        self.lateral = 0
        // Negative: the grid is behind the start line.
        self.travelled = startDistance
        self.surface = .polishedTile
        self.isOffRoad = false
        self.segmentHint = 0
        self.racePosition = id + 1
        self.lapStartTime = 0
        self.lapTimes = []
        self.finishTime = nil
        self.boostTimer = 0
        self.boostStrength = 0
        self.spinoutTimer = 0
        self.stallTimer = 0
        self.slipTimer = 0
        self.invulnerabilityTimer = 0
        self.expressLaneTimer = 0
        self.shieldCharges = 0
        self.shieldAngle = 0
        self.heldItem = nil
        self.tokens = 0
        self.isDrifting = false
        self.driftCharge = 0
        self.driftDirection = 0
        self.counterSteerTimer = 0
        self.stuckTimer = 0
        self.scrapeIntensity = 0
        self.performanceScale = 1
        self.lastInput = .idle
    }

    public var forward: Vector2 { Vector2(angle: heading) }

    /// Speed along the cart's own nose, which can be negative when reversing.
    public var forwardSpeed: Double { velocity.dot(forward) }

    /// Sideways speed; the thing that makes a drift look like a drift.
    public var lateralSpeed: Double { velocity.dot(forward.perpendicular) }

    public var speed: Double { velocity.length }

    public var isBoosting: Bool { boostTimer > 0 || expressLaneTimer > 0 }

    public var isDisabled: Bool { spinoutTimer > 0 }

    public var hasFinished: Bool { finishTime != nil }

    public var bestLapTime: Double? { lapTimes.min() }

    /// Laps fully completed. The grid crossing does not count.
    public func lapsCompleted(trackLength: Double) -> Int {
        max(0, Int(floor(travelled / trackLength)))
    }

    /// 1-based lap number to show on the HUD.
    public func displayLap(trackLength: Double, totalLaps: Int) -> Int {
        min(totalLaps, lapsCompleted(trackLength: trackLength) + 1)
    }

    /// 0...1 progress through the current lap, for the minimap and lap bar.
    public func lapProgress(trackLength: Double) -> Double {
        let laps = Double(lapsCompleted(trackLength: trackLength))
        return Scalar.clamp((travelled - laps * trackLength) / trackLength, 0, 1)
    }

    /// Which mini-turbo tier the current drift charge has reached, 0 when none.
    public func miniTurboTier(tuning simulation: SimulationTuning) -> Int {
        var tier = 0
        for (index, threshold) in simulation.miniTurboThresholds.enumerated() where driftCharge >= threshold {
            tier = index + 1
        }
        return tier
    }
}
