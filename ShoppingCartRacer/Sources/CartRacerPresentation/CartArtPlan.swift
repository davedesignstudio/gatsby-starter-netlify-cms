import Foundation

/// How to draw one cart, derived from its racer. All measurements are in metres
/// in cart space: +x is forwards, +y is to the cart's left.
///
/// The renderer builds every cart out of these primitives, so there are no image
/// assets to ship and each character still looks distinct.
public struct CartArtPlan: Sendable {
    public struct Wheel: Sendable {
        public let offset: Vector2
        public let radius: Double
        /// Castors swivel; fixed wheels do not.
        public let isCastor: Bool
    }

    public struct Cargo: Sendable {
        public enum Kind: String, Sendable {
            case box
            case bottle
            case bag
            case can
            case cabbage
            case bread
        }

        public let kind: Kind
        public let offset: Vector2
        public let size: Vector2
        public let rotation: Double
        public let colorIndex: Int
    }

    public let racerID: String
    /// Overall basket footprint.
    public let length: Double
    public let width: Double
    /// How much narrower the front of the basket is, 0...1.
    public let taper: Double
    /// Vertical bars drawn across the basket to read as wire mesh.
    public let meshBarCount: Int
    public let wheels: [Wheel]
    public let cargo: [Cargo]
    /// Where the push handle sits, at the back.
    public let handleOffset: Vector2
    public let handleWidth: Double
    /// The driver, riding on the back axle.
    public let driverOffset: Vector2
    public let driverRadius: Double
    public let bodyColor: RacerColor
    public let trimColor: RacerColor
    public let cargoColors: [RacerColor]

    public init(racer: Racer) {
        racerID = racer.id
        bodyColor = racer.primaryColor
        trimColor = racer.secondaryColor
        cargoColors = [
            racer.primaryColor.mixed(with: RacerColor(1, 1, 1), amount: 0.35),
            racer.secondaryColor,
            RacerColor(hex: 0xEF476F),
            RacerColor(hex: 0xFFD166),
            RacerColor(hex: 0x06D6A0),
            RacerColor(hex: 0x8D6E5B)
        ]

        let tuning = CartTuning(racer: racer)
        var random = DeterministicRandom(seed: CartArtPlan.seed(for: racer.id))

        switch racer.silhouette {
        case .handBasket:
            length = 1.15
            width = 0.85
            taper = 0.1
            meshBarCount = 3
        case .standardTrolley:
            length = 1.75
            width = 1.05
            taper = 0.22
            meshBarCount = 6
        case .stockCart:
            length = 1.9
            width = 1.2
            taper = 0.05
            meshBarCount = 4
        case .nestedPair:
            length = 2.35
            width = 1.1
            taper = 0.25
            meshBarCount = 8
        case .janitorRig:
            length = 1.6
            width = 1.15
            taper = 0.0
            meshBarCount = 2
        case .flatbed:
            length = 2.1
            width = 1.3
            taper = 0.0
            meshBarCount = 0
        }

        let axleX = length * 0.32
        let trackWidth = width * 0.46
        let wheelRadius = max(0.1, tuning.radius * 0.16)
        wheels = [
            Wheel(offset: Vector2(axleX, trackWidth), radius: wheelRadius, isCastor: true),
            Wheel(offset: Vector2(axleX, -trackWidth), radius: wheelRadius, isCastor: true),
            Wheel(offset: Vector2(-axleX, trackWidth), radius: wheelRadius, isCastor: false),
            Wheel(offset: Vector2(-axleX, -trackWidth), radius: wheelRadius, isCastor: false)
        ]

        handleOffset = Vector2(-length * 0.5 - 0.12, 0)
        handleWidth = width * 0.78
        driverOffset = Vector2(-length * 0.5 - 0.34, 0)
        driverRadius = Scalar.lerp(0.24, 0.34, racer.stats.weight)

        // Pile the basket high. More cargo on the heavier carts, and the amount is
        // fixed per racer so a character always looks like themselves.
        let cargoCount = Int(Scalar.lerp(3, 8, racer.stats.weight).rounded())
        var pieces: [Cargo] = []
        let kinds: [Cargo.Kind] = [.box, .bottle, .bag, .can, .cabbage, .bread]
        for index in 0..<cargoCount {
            let alongFraction = Double(index) / Double(max(cargoCount - 1, 1))
            let along = Scalar.lerp(-length * 0.3, length * 0.32, alongFraction)
            let lateralRoom = width * 0.5 * (1 - taper * (alongFraction * 0.8)) - 0.16
            let kind = kinds[Int(random.nextDouble(in: 0...Double(kinds.count) - 0.01))]
            pieces.append(
                Cargo(
                    kind: kind,
                    offset: Vector2(along, random.nextDouble(in: -lateralRoom...lateralRoom)),
                    size: CartArtPlan.size(for: kind, random: &random),
                    rotation: random.nextDouble(in: -0.5...0.5),
                    colorIndex: Int(random.nextDouble(in: 0...5.99))
                )
            )
        }
        cargo = pieces
    }

    private static func size(for kind: Cargo.Kind, random: inout DeterministicRandom) -> Vector2 {
        let jitter = random.nextDouble(in: 0.9...1.15)
        switch kind {
        case .box: return Vector2(0.34, 0.28) * jitter
        case .bottle: return Vector2(0.16, 0.16) * jitter
        case .bag: return Vector2(0.32, 0.24) * jitter
        case .can: return Vector2(0.13, 0.13) * jitter
        case .cabbage: return Vector2(0.2, 0.2) * jitter
        case .bread: return Vector2(0.38, 0.18) * jitter
        }
    }

    /// Stable per-racer seed so the junk in the basket never shuffles about.
    private static func seed(for racerID: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in racerID.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001B3
        }
        return hash
    }
}
