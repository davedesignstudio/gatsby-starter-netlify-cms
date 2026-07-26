import SpriteKit

/// Title screen. Tap anywhere to drop the flag on a new race.
final class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addFloorBackdrop()

        let title = SKLabelNode(text: "CART KART")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 84
        title.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: 90)
        title.zPosition = 10
        addChild(title)

        let subtitle = SKLabelNode(text: "AISLE RUSH")
        subtitle.fontName = "AvenirNext-Bold"
        subtitle.fontSize = 34
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: 0, y: 40)
        subtitle.zPosition = 10
        addChild(subtitle)

        let tagline = SKLabelNode(text: "Runaway shopping carts. One store. No brakes.")
        tagline.fontName = "AvenirNext-Medium"
        tagline.fontSize = 20
        tagline.fontColor = SKColor(white: 0.8, alpha: 1)
        tagline.position = CGPoint(x: 0, y: -10)
        tagline.zPosition = 10
        addChild(tagline)

        let controls = SKLabelNode(text: "◀ ▶ steer  •  auto-accelerate  •  tap ITEM to use pickups")
        controls.fontName = "AvenirNext-Medium"
        controls.fontSize = 16
        controls.fontColor = SKColor(white: 0.65, alpha: 1)
        controls.position = CGPoint(x: 0, y: -80)
        controls.zPosition = 10
        addChild(controls)

        let prompt = SKLabelNode(text: "TAP TO RACE")
        prompt.fontName = "AvenirNext-Bold"
        prompt.fontSize = 28
        prompt.fontColor = SKColor(red: 0.2, green: 0.85, blue: 1.0, alpha: 1)
        prompt.position = CGPoint(x: 0, y: -160)
        prompt.zPosition = 10
        prompt.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))
        addChild(prompt)

        // A cheeky mascot cart rolling across.
        let cart = Cart(name: "P1", tint: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), isPlayer: false)
        cart.setScale(1.3)
        cart.position = CGPoint(x: -frame.width / 2 - 100, y: -240)
        cart.zPosition = 20
        addChild(cart)
        cart.run(.repeatForever(.sequence([
            .moveTo(x: frame.width / 2 + 120, duration: 4),
            .moveTo(x: -frame.width / 2 - 100, duration: 0)
        ])))
    }

    private func addFloorBackdrop() {
        let tile: CGFloat = 90
        let cols = Int(frame.width / tile) + 2
        let rows = Int(frame.height / tile) + 2
        for r in 0..<rows {
            for c in 0..<cols where (r + c) % 2 == 0 {
                let square = SKSpriteNode(color: SKColor(white: 1, alpha: 0.03),
                                          size: CGSize(width: tile, height: tile))
                square.position = CGPoint(x: -frame.width / 2 + CGFloat(c) * tile,
                                          y: -frame.height / 2 + CGFloat(r) * tile)
                addChild(square)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: .doorway(withDuration: 0.6))
    }
}
