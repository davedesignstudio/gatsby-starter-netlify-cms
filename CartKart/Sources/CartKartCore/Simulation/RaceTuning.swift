import Foundation

/// Every hand-tuned number in the driving model lives here so the feel of the
/// game can be adjusted without hunting through the simulation.
///
/// World units are roughly "one centimetre of supermarket floor"; a cart is
/// about 50 units long and a wide aisle is about 400 units across.
public struct RaceTuning: Sendable {
    // Cart body
    public var cartRadius: Double = 26
    public var baseTopSpeed: Double = 620
    public var baseAcceleration: Double = 540
    public var baseGrip: Double = 9.0
    public var brakeForce: Double = 900
    public var reverseTopSpeed: Double = 200
    /// Drag applied to forward motion when coasting.
    public var rollingDrag: Double = 0.65

    // Steering
    public var maxSteerRate: Double = 2.9
    /// Below this speed the cart barely turns, as with a real trolley.
    public var steerSpeedFloor: Double = 60
    public var steerSpeedFalloff: Double = 0.35

    // Drifting
    public var driftSteerBias: Double = 0.55
    public var driftGripMultiplier: Double = 0.42
    public var driftSteerMultiplier: Double = 1.35
    public var driftMinimumSpeed: Double = 240
    /// Seconds of drifting needed for each mini-turbo tier.
    public var miniTurboThresholds: [Double] = [0.85, 1.7, 2.8]
    public var miniTurboBoostDurations: [Double] = [0.7, 1.15, 1.7]

    // Boost
    public var boostSpeedMultiplier: Double = 1.42
    public var boostAcceleration: Double = 1500
    public var boostPadDuration: Double = 1.1
    public var energyDrinkDuration: Double = 1.9
    public var rocketStartDuration: Double = 1.5

    // Surfaces
    public var slickGripMultiplier: Double = 0.28
    public var slickSpeedMultiplier: Double = 1.05

    // Contact
    public var wallRestitution: Double = 0.32
    public var wallSpeedLoss: Double = 0.45
    public var cartRestitution: Double = 0.55
    public var obstacleSpeedLoss: Double = 0.6

    // Spin outs
    public var spinOutDuration: Double = 1.35
    public var slipDuration: Double = 1.1
    public var squashDuration: Double = 1.6
    public var invulnerabilityAfterHit: Double = 1.2

    // Star-equivalent
    public var bulkBuyDuration: Double = 6.0
    public var bulkBuySpeedMultiplier: Double = 1.28

    // Race flow
    public var countdownDuration: Double = 3.6
    /// Window around "GO" in which holding throttle grants a rocket start.
    public var rocketStartWindow: ClosedRange<Double> = 0.25...0.65
    public var itemBoxRespawn: Double = 4.0
    public var fixedTimeStep: Double = 1.0 / 120.0

    /// Catch-up assist for trailing racers, MK-style.
    public var rubberBandMaxBonus: Double = 0.11
    public var rubberBandRange: Double = 2600

    public init() {}

    public static let `default` = RaceTuning()
}
