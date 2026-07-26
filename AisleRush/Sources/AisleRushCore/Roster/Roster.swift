import Foundation

/// Final numbers the physics reads. Everything else in this file exists to
/// produce one of these.
public struct CartStats: Sendable {
    /// m/s on clean linoleum with no boost.
    public var topSpeed: Double
    /// m/s^2 at a standstill.
    public var acceleration: Double
    /// How fast sideways velocity bleeds off, 1/s. High grip means it sticks.
    public var grip: Double
    /// rad/s at the speed where steering is most effective.
    public var turnRate: Double
    /// Relative mass, used for shoves and bumps.
    public var mass: Double
    /// Fraction of grip retained mid-drift. Lower slides wider.
    public var driftGrip: Double
    /// 0...1, biases the item roulette towards the good stuff.
    public var luck: Double
    /// 0...1, how much of the off-track penalty is ignored.
    public var offTrackResistance: Double

    public init(
        topSpeed: Double,
        acceleration: Double,
        grip: Double,
        turnRate: Double,
        mass: Double,
        driftGrip: Double,
        luck: Double,
        offTrackResistance: Double
    ) {
        self.topSpeed = topSpeed
        self.acceleration = acceleration
        self.grip = grip
        self.turnRate = turnRate
        self.mass = mass
        self.driftGrip = driftGrip
        self.luck = luck
        self.offTrackResistance = offTrackResistance
    }
}

/// Per-part deltas. Kept separate from `CartStats` so parts can be tuned
/// without every one of them having to restate the whole stat block.
public struct StatModifier: Sendable {
    public var topSpeed: Double = 0
    public var acceleration: Double = 0
    public var grip: Double = 0
    public var turnRate: Double = 0
    public var mass: Double = 0
    public var driftGrip: Double = 0
    public var luck: Double = 0
    public var offTrackResistance: Double = 0

    public init(
        topSpeed: Double = 0,
        acceleration: Double = 0,
        grip: Double = 0,
        turnRate: Double = 0,
        mass: Double = 0,
        driftGrip: Double = 0,
        luck: Double = 0,
        offTrackResistance: Double = 0
    ) {
        self.topSpeed = topSpeed
        self.acceleration = acceleration
        self.grip = grip
        self.turnRate = turnRate
        self.mass = mass
        self.driftGrip = driftGrip
        self.luck = luck
        self.offTrackResistance = offTrackResistance
    }
}

public struct CharacterProfile: Sendable, Identifiable {
    public var id: String
    public var name: String
    public var role: String
    /// One-line flavour shown on the select screen.
    public var quip: String
    public var primaryColor: ColorRGB
    public var secondaryColor: ColorRGB
    public var modifier: StatModifier
}

public struct CartFrame: Sendable, Identifiable {
    public var id: String
    public var name: String
    public var blurb: String
    /// Half-length and half-width of the chassis, metres.
    public var size: Vector2
    public var modifier: StatModifier
}

public struct WheelSet: Sendable, Identifiable {
    public var id: String
    public var name: String
    public var blurb: String
    public var modifier: StatModifier
}

/// A character plus the two parts they picked.
public struct CartSetup: Sendable {
    public var character: CharacterProfile
    public var frame: CartFrame
    public var wheels: WheelSet

    public init(character: CharacterProfile, frame: CartFrame, wheels: WheelSet) {
        self.character = character
        self.frame = frame
        self.wheels = wheels
    }

    public var stats: CartStats {
        var stats = Roster.baseStats
        for modifier in [character.modifier, frame.modifier, wheels.modifier] {
            stats.topSpeed += modifier.topSpeed
            stats.acceleration += modifier.acceleration
            stats.grip += modifier.grip
            stats.turnRate += modifier.turnRate
            stats.mass += modifier.mass
            stats.driftGrip += modifier.driftGrip
            stats.luck += modifier.luck
            stats.offTrackResistance += modifier.offTrackResistance
        }
        stats.topSpeed = clamp(stats.topSpeed, 12, 34)
        stats.acceleration = clamp(stats.acceleration, 5, 22)
        stats.grip = clamp(stats.grip, 3, 16)
        stats.turnRate = clamp(stats.turnRate, 1.4, 4.2)
        stats.mass = clamp(stats.mass, 60, 180)
        stats.driftGrip = clamp(stats.driftGrip, 0.12, 0.7)
        stats.luck = clamp(stats.luck, 0, 1)
        stats.offTrackResistance = clamp(stats.offTrackResistance, 0, 0.9)
        return stats
    }

    /// 0...5 bars for the select screen.
    public var displayBars: [(label: String, value: Int)] {
        let s = stats
        func bar(_ value: Double, _ low: Double, _ high: Double) -> Int {
            Int((clamp((value - low) / (high - low), 0, 1) * 4).rounded()) + 1
        }
        return [
            ("Speed", bar(s.topSpeed, 19, 29)),
            ("Boost", bar(s.acceleration, 8, 17)),
            ("Grip", bar(s.grip, 5.5, 12)),
            ("Turn", bar(s.turnRate, 1.9, 3.4)),
            ("Weight", bar(s.mass, 75, 145))
        ]
    }
}

public enum Roster {
    public static let baseStats = CartStats(
        topSpeed: 23.5,
        acceleration: 12.0,
        grip: 8.5,
        turnRate: 2.6,
        mass: 100,
        driftGrip: 0.34,
        luck: 0.5,
        offTrackResistance: 0.1
    )

    public static let characters: [CharacterProfile] = [
        CharacterProfile(
            id: "tina",
            name: "Trolley Tina",
            role: "Cart Wrangler",
            quip: "Has returned nine carts at once. On foot.",
            primaryColor: .hex(0xE8453C),
            secondaryColor: .hex(0xFFD166),
            modifier: StatModifier()
        ),
        CharacterProfile(
            id: "gus",
            name: "Big Gus",
            role: "Butcher",
            quip: "Cannot be shoved. Physically will not move.",
            primaryColor: .hex(0xB3402F),
            secondaryColor: .hex(0xF2E8D5),
            modifier: StatModifier(topSpeed: 2.2, acceleration: -2.6, grip: 0.8, turnRate: -0.35, mass: 34)
        ),
        CharacterProfile(
            id: "sue",
            name: "Sample Sue",
            role: "Demo Station",
            quip: "Free meatballs. Toothpick not included.",
            primaryColor: .hex(0xF29E38),
            secondaryColor: .hex(0xFFF3C4),
            modifier: StatModifier(topSpeed: -1.4, acceleration: 2.8, turnRate: 0.28, mass: -20, luck: 0.1)
        ),
        CharacterProfile(
            id: "bruno",
            name: "Bag Boy Bruno",
            role: "Front End",
            quip: "Paper or plastic? He already decided.",
            primaryColor: .hex(0x3E8E7E),
            secondaryColor: .hex(0xD7F2E3),
            modifier: StatModifier(acceleration: 2.0, grip: 0.6, turnRate: 0.15, mass: -12)
        ),
        CharacterProfile(
            id: "carla",
            name: "Coupon Carla",
            role: "Loyalty Member",
            quip: "Expired coupons are a state of mind.",
            primaryColor: .hex(0xC64F8E),
            secondaryColor: .hex(0xFFE0F0),
            modifier: StatModifier(topSpeed: -0.6, acceleration: 0.4, turnRate: 0.1, mass: -6, luck: 0.35)
        ),
        CharacterProfile(
            id: "mopbot",
            name: "Mop-Bot 3000",
            role: "Floor Care",
            quip: "CLEANUP DETECTED. ACCELERATING TOWARD IT.",
            primaryColor: .hex(0x4A7FE8),
            secondaryColor: .hex(0xCADCFF),
            modifier: StatModifier(topSpeed: -0.4, grip: 1.9, turnRate: -0.1, mass: 14, driftGrip: 0.05, offTrackResistance: 0.25)
        ),
        CharacterProfile(
            id: "stocky",
            name: "Night-Crew Stocky",
            role: "Overnight Stocker",
            quip: "Awake since Tuesday. Knows every shortcut.",
            primaryColor: .hex(0x6C5CE7),
            secondaryColor: .hex(0xDDD6FF),
            modifier: StatModifier(topSpeed: 0.9, acceleration: -0.6, grip: -0.5, turnRate: 0.2, mass: 8, driftGrip: -0.05)
        ),
        CharacterProfile(
            id: "meg",
            name: "Manager Meg",
            role: "Store Manager",
            quip: "Will absolutely speak to your manager.",
            primaryColor: .hex(0x2D3E50),
            secondaryColor: .hex(0xF7C948),
            modifier: StatModifier(topSpeed: 1.5, acceleration: -0.8, grip: 0.4, mass: 16, luck: -0.1)
        )
    ]

    public static let frames: [CartFrame] = [
        CartFrame(
            id: "rusty",
            name: "Rusty Classic",
            blurb: "One wobbly wheel, decades of character.",
            size: Vector2(1.55, 0.95),
            modifier: StatModifier()
        ),
        CartFrame(
            id: "jumbo",
            name: "Jumbo Family",
            blurb: "Fits a month of groceries and one child.",
            size: Vector2(1.95, 1.15),
            modifier: StatModifier(topSpeed: 1.4, acceleration: -1.5, grip: 0.7, turnRate: -0.3, mass: 22)
        ),
        CartFrame(
            id: "sprinter",
            name: "Half-Basket Sprinter",
            blurb: "For people buying exactly two things, fast.",
            size: Vector2(1.25, 0.85),
            modifier: StatModifier(topSpeed: -1.0, acceleration: 2.4, turnRate: 0.35, mass: -18, driftGrip: -0.04)
        ),
        CartFrame(
            id: "flatbed",
            name: "Flatbed Trolley",
            blurb: "Technically for lumber. Nobody has stopped us.",
            size: Vector2(2.1, 1.05),
            modifier: StatModifier(topSpeed: 2.0, acceleration: -2.0, grip: -0.6, turnRate: -0.15, mass: 26, driftGrip: 0.06)
        )
    ]

    public static let wheels: [WheelSet] = [
        WheelSet(
            id: "casters",
            name: "Squeaky Casters",
            blurb: "Standard issue. Audible from three aisles away.",
            modifier: StatModifier()
        ),
        WheelSet(
            id: "rubber",
            name: "Gum Rubber",
            blurb: "Sticks to the floor like the floor owes it money.",
            modifier: StatModifier(topSpeed: -0.5, grip: 1.6, turnRate: 0.1, driftGrip: 0.05)
        ),
        WheelSet(
            id: "allterrain",
            name: "All-Terrain Knobbies",
            blurb: "Built for the parking lot and the garden centre.",
            modifier: StatModifier(topSpeed: -0.3, acceleration: 0.4, grip: 0.3, mass: 6, offTrackResistance: 0.45)
        ),
        WheelSet(
            id: "glides",
            name: "Freezer Glides",
            blurb: "Frictionless. Steering is more of a suggestion.",
            modifier: StatModifier(topSpeed: 1.6, acceleration: 0.6, grip: -1.6, turnRate: 0.15, driftGrip: -0.08)
        )
    ]

    public static func character(id: String) -> CharacterProfile {
        characters.first { $0.id == id } ?? characters[0]
    }

    public static func frame(id: String) -> CartFrame {
        frames.first { $0.id == id } ?? frames[0]
    }

    public static func wheels(id: String) -> WheelSet {
        wheels.first { $0.id == id } ?? wheels[0]
    }

    public static func defaultSetup(for character: CharacterProfile) -> CartSetup {
        CartSetup(character: character, frame: frames[0], wheels: wheels[0])
    }
}
