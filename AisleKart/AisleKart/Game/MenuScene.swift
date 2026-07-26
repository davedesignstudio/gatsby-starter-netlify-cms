import SpriteKit

final class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.16, blue: 0.13, alpha: 1)
        removeAllChildren()

        // Atmospheric floor wash
        let wash = SKSpriteNode(color: UIColor(red: 0.18, green: 0.32, blue: 0.24, alpha: 1), size: size)
        wash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wash.zPosition = -10
        addChild(wash)

        // Soft radial vignette via overlapping shapes
        for i in 0..<6 {
            let ring = SKShapeNode(circleOfRadius: CGFloat(80 + i * 70))
            ring.fillColor = .clear
            ring.strokeColor = UIColor(red: 0.92, green: 0.55, blue: 0.18, alpha: 0.04)
            ring.lineWidth = 40
            ring.position = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
            ring.zPosition = -5
            addChild(ring)
        }

        // Decorative carts drifting
        for i in 0..<5 {
            let cart = makeDecorCart(color: GameTheme.cartColors[i % GameTheme.cartColors.count])
            cart.position = CGPoint(
                x: CGFloat.random(in: 40...(size.width - 40)),
                y: CGFloat.random(in: 80...(size.height * 0.45))
            )
            cart.alpha = 0.35
            cart.setScale(CGFloat.random(in: 0.7...1.2))
            cart.zPosition = -2
            addChild(cart)
            let dx = CGFloat.random(in: -40...40)
            cart.run(.repeatForever(.sequence([
                .moveBy(x: dx, y: CGFloat.random(in: 10...30), duration: TimeInterval.random(in: 2.5...4)),
                .moveBy(x: -dx, y: CGFloat.random(in: -30...(-10)), duration: TimeInterval.random(in: 2.5...4))
            ])))
        }

        let brand = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        brand.text = "AISLE KART"
        brand.fontSize = min(54, size.width * 0.12)
        brand.fontColor = GameTheme.checkoutYellow
        brand.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        brand.zPosition = 10
        addChild(brand)

        brand.setScale(0.85)
        brand.alpha = 0
        brand.run(.group([
            .fadeIn(withDuration: 0.35),
            .scale(to: 1.0, duration: 0.4)
        ]))

        let tag = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tag.text = "Stray carts. MegaMart. No mercy."
        tag.fontSize = 16
        tag.fontColor = GameTheme.hudCream.withAlphaComponent(0.85)
        tag.position = CGPoint(x: size.width / 2, y: size.height * 0.72 - 42)
        tag.zPosition = 10
        addChild(tag)

        let play = makeButton(title: "RACE", name: "play", width: 200)
        play.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        addChild(play)

        let how = makeButton(title: "HOW TO PLAY", name: "how", width: 200, secondary: true)
        how.position = CGPoint(x: size.width / 2, y: size.height * 0.38 - 70)
        addChild(how)

        let foot = SKLabelNode(fontNamed: "AvenirNext-Regular")
        foot.text = "3 laps · 4 carts · grocery mayhem"
        foot.fontSize = 12
        foot.fontColor = UIColor(white: 1, alpha: 0.4)
        foot.position = CGPoint(x: size.width / 2, y: 36)
        addChild(foot)
    }

    private func makeDecorCart(color: UIColor) -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 40), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = color.darker(by: 0.2)
        body.lineWidth = 1.5
        n.addChild(body)
        return n
    }

    private func makeButton(title: String, name: String, width: CGFloat, secondary: Bool = false) -> SKNode {
        let node = SKNode()
        node.name = name

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 52), cornerRadius: 10)
        bg.fillColor = secondary ? UIColor(white: 1, alpha: 0.08) : GameTheme.accentOrange
        bg.strokeColor = secondary ? UIColor(white: 1, alpha: 0.25) : GameTheme.accentOrange.darker(by: 0.15)
        bg.lineWidth = 2
        bg.name = name
        node.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 18
        label.fontColor = secondary ? GameTheme.hudCream : .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        node.addChild(label)

        node.zPosition = 20
        return node
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)

        if nodes.contains(where: { $0.name == "play" }) {
            startRace()
        } else if nodes.contains(where: { $0.name == "how" }) {
            showHowTo()
        } else if nodes.contains(where: { $0.name == "dismissHow" }) {
            childNode(withName: "howOverlay")?.removeFromParent()
        }
    }

    private func startRace() {
        let game = GameScene(size: size)
        game.scaleMode = .resizeFill
        view?.presentScene(game, transition: .doorsOpenHorizontal(withDuration: 0.45))
    }

    private func showHowTo() {
        childNode(withName: "howOverlay")?.removeFromParent()

        let overlay = SKNode()
        overlay.name = "howOverlay"
        overlay.zPosition = 100

        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.7), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dim.name = "dismissHow"
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: min(320, size.width - 40), height: 300), cornerRadius: 14)
        panel.fillColor = UIColor(red: 0.14, green: 0.18, blue: 0.16, alpha: 1)
        panel.strokeColor = GameTheme.checkoutYellow
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(panel)

        let lines = [
            "Steer with left / right side of screen",
            "Grab green ? bags for items",
            "🍌 peel · 🥫 slow · ⚡ boost",
            "🛡️ shield · 🦃 frozen turkey",
            "First cart through 3 checkouts wins",
            "",
            "Tap anywhere to close"
        ]
        for (i, line) in lines.enumerated() {
            let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
            l.text = line
            l.fontSize = 13
            l.fontColor = GameTheme.hudCream
            l.position = CGPoint(x: size.width / 2, y: size.height / 2 + 110 - CGFloat(i) * 28)
            l.name = "dismissHow"
            overlay.addChild(l)
        }

        addChild(overlay)
    }
}
