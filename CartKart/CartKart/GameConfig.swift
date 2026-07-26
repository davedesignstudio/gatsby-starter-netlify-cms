import CoreGraphics

/// Central tuning values for CartKart: Aisle Rush.
///
/// Keeping the numbers in one place makes it easy to balance the racing feel
/// without hunting through the scene code.
enum GameConfig {

    // MARK: Race rules
    static let totalLaps = 3
    static let racerCount = 4          // 1 player + 3 AI opponents.

    // MARK: Cart physics
    /// Points/second the player can reach on the smooth store floor.
    static let maxSpeedOnTrack: CGFloat = 520
    /// Reduced top speed while driving over carpet / off the polished aisle.
    static let maxSpeedOffTrack: CGFloat = 200
    /// Forward acceleration in points/second^2.
    static let acceleration: CGFloat = 700
    /// How quickly a cart slows when not accelerating.
    static let drag: CGFloat = 2.2
    /// Radians/second the cart can rotate at full steer.
    static let turnRate: CGFloat = 3.1
    /// Boost pad / energy-drink multiplier applied to max speed.
    static let boostMultiplier: CGFloat = 1.65
    static let boostDuration: TimeInterval = 1.6

    // MARK: Items
    /// Seconds a cart is stuck spinning after hitting spilled milk.
    static let spinOutDuration: TimeInterval = 1.3
    static let projectileSpeed: CGFloat = 900

    // MARK: Track geometry
    static let trackWidth: CGFloat = 300
    static let worldSize = CGSize(width: 2600, height: 1800)

    // MARK: Rendering depths
    enum ZPosition {
        static let background: CGFloat = 0
        static let track: CGFloat = 1
        static let trackDecor: CGFloat = 2
        static let itemBox: CGFloat = 5
        static let projectile: CGFloat = 8
        static let cart: CGFloat = 10
        static let hazard: CGFloat = 9
        static let camera: CGFloat = 100
        static let hud: CGFloat = 200
        static let overlay: CGFloat = 300
    }
}
