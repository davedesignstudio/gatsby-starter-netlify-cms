import SpriteKit

struct RacerProfile {
    let name: String
    let cartColor: SKColor
    let accentColor: SKColor
    let maxSpeed: CGFloat
    let acceleration: CGFloat
    let handling: CGFloat

    static let player = RacerProfile(
        name: "YOU",
        cartColor: SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1),
        accentColor: SKColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1),
        maxSpeed: 280,
        acceleration: 420,
        handling: 3.2
    )

    static let opponents: [RacerProfile] = [
        RacerProfile(
            name: "RUSTY",
            cartColor: SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1),
            accentColor: SKColor(red: 0.5, green: 0.15, blue: 0.1, alpha: 1),
            maxSpeed: 265,
            acceleration: 400,
            handling: 2.8
        ),
        RacerProfile(
            name: "WOBBLY",
            cartColor: SKColor(red: 0.3, green: 0.75, blue: 0.35, alpha: 1),
            accentColor: SKColor(red: 0.15, green: 0.45, blue: 0.2, alpha: 1),
            maxSpeed: 255,
            acceleration: 390,
            handling: 3.0
        ),
        RacerProfile(
            name: "LUCKY",
            cartColor: SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1),
            accentColor: SKColor(red: 0.65, green: 0.45, blue: 0.05, alpha: 1),
            maxSpeed: 270,
            acceleration: 410,
            handling: 2.9
        )
    ]
}
