import SpriteKit

struct CharacterDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let tagline: String
    let bodyColor: SKColor
    let cartColor: SKColor
    let speedMultiplier: CGFloat
    let accelerationMultiplier: CGFloat
    let turnMultiplier: CGFloat
    let weight: CGFloat

    func apply(to racer: CartRacer) {
        racer.maxSpeed *= speedMultiplier
        racer.acceleration *= accelerationMultiplier
        racer.turnRate *= turnMultiplier
        racer.weight = weight
    }
}

extension CharacterDefinition {
    static let wobblyWill = CharacterDefinition(
        id: "will",
        name: "Wobbly Will",
        emoji: "🧢",
        tagline: "Balanced aisle cruiser",
        bodyColor: SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1),
        cartColor: .lightGray,
        speedMultiplier: 1.0,
        accelerationMultiplier: 1.0,
        turnMultiplier: 1.0,
        weight: 1.0
    )

    static let speedySal = CharacterDefinition(
        id: "sal",
        name: "Speedy Sal",
        emoji: "⚡",
        tagline: "Fast but wobbly steering",
        bodyColor: SKColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1),
        cartColor: SKColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1),
        speedMultiplier: 1.15,
        accelerationMultiplier: 1.1,
        turnMultiplier: 0.85,
        weight: 0.9
    )

    static let driftKing = CharacterDefinition(
        id: "king",
        name: "Drift King",
        emoji: "👑",
        tagline: "Corners like a pro",
        bodyColor: SKColor(red: 0.75, green: 0.35, blue: 0.85, alpha: 1),
        cartColor: SKColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1),
        speedMultiplier: 0.95,
        accelerationMultiplier: 0.95,
        turnMultiplier: 1.25,
        weight: 1.0
    )

    static let tankTanya = CharacterDefinition(
        id: "tanya",
        name: "Tank Tanya",
        emoji: "💪",
        tagline: "Slow, heavy, unstoppable",
        bodyColor: SKColor(red: 0.25, green: 0.7, blue: 0.35, alpha: 1),
        cartColor: SKColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 1),
        speedMultiplier: 0.88,
        accelerationMultiplier: 0.85,
        turnMultiplier: 0.9,
        weight: 1.35
    )

    static let couponCarla = CharacterDefinition(
        id: "carla",
        name: "Coupon Carla",
        emoji: "🏷️",
        tagline: "Quick off the line",
        bodyColor: SKColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1),
        cartColor: .gray,
        speedMultiplier: 1.0,
        accelerationMultiplier: 1.2,
        turnMultiplier: 1.05,
        weight: 0.95
    )

    static let all: [CharacterDefinition] = [.wobblyWill, .speedySal, .driftKing, .tankTanya, .couponCarla]
}
