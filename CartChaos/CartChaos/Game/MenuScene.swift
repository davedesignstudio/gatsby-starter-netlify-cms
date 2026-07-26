import SpriteKit

final class MenuScene: SKScene {
    private var cartPreview: CartNode?
    private var bobTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        removeAllChildren()
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        drawAtmosphere()
        drawTitle()
        drawButtons()
        spawnPreviewCart()
    }

    private func drawAtmosphere() {
        // Store-night gradient blocks
        let top = SKSpriteNode(color: UIColor(red: 0.18, green: 0.22, blue: 0.32, alpha: 1), size: CGSize(width: size.width, height: size.height * 0.55))
        top.anchorPoint = CGPoint(x: 0.5, y: 1)
        top.position = CGPoint(x: size.width / 2, y: size.height)
        top.zPosition = -2
        addChild(top)

        let floor = SKSpriteNode(color: UIColor(red: 0.85, green: 0.82, blue: 0.74, alpha: 1), size: CGSize(width: size.width, height: size.height * 0.5))
        floor.anchorPoint = CGPoint(x: 0.5, y: 0)
        floor.position = CGPoint(x: size.width / 2, y: 0)
        floor.zPosition = -2
        addChild(floor)

        for i in 0..<8 {
            let aisle = SKShapeNode(rectOf: CGSize(width: 40, height: size.height * 0.35), cornerRadius: 4)
            aisle.fillColor = [
                UIColor(red: 0.75, green: 0.25, blue: 0.25, alpha: 0.85),
                UIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.85),
                UIColor(red: 0.3, green: 0.6, blue: 0.35, alpha: 0.85),
                UIColor(red: 0.85, green: 0.55, blue: 0.2, alpha: 0.85)
            ][i % 4]
            aisle.strokeColor = .clear
            aisle.position = CGPoint(x: size.width * 0.12 + CGFloat(i) * size.width * 0.11, y: size.height * 0.28)
            aisle.zPosition = -1
            aisle.alpha = 0.55
            addChild(aisle)
        }

        // Fluorescent flicker bars
        for i in 0..<5 {
            let light = SKShapeNode(rectOf: CGSize(width: size.width * 0.14, height: 8), cornerRadius: 2)
            light.fillColor = UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 0.35)
            light.strokeColor = .clear
            light.position = CGPoint(x: size.width * (0.15 + CGFloat(i) * 0.18), y: size.height * 0.78)
            light.zPosition = 0
            addChild(light)
            light.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: 0.8 + Double(i) * 0.1),
                .fadeAlpha(to: 0.45, duration: 0.6)
            ])))
        }
    }

    private func drawTitle() {
        let brand = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        brand.text = "CART CHAOS"
        brand.fontSize = min(54, size.width * 0.12)
        brand.fontColor = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        brand.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        brand.zPosition = 10
        addChild(brand)

        let shadow = brand.copy() as! SKLabelNode
        shadow.fontColor = UIColor(white: 0, alpha: 0.35)
        shadow.position = CGPoint(x: brand.position.x + 3, y: brand.position.y - 3)
        shadow.zPosition = 9
        addChild(shadow)

        let tag = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tag.text = "Rogue carts. Midnight MegaMart."
        tag.fontSize = 16
        tag.fontColor = UIColor(white: 0.9, alpha: 0.9)
        tag.position = CGPoint(x: size.width / 2, y: size.height * 0.66)
        tag.zPosition = 10
        addChild(tag)

        brand.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 1.2),
            .moveBy(x: 0, y: -4, duration: 1.2)
        ])))
    }

    private func drawButtons() {
        addButton(title: "RACE", name: "play", y: size.height * 0.22, color: UIColor(red: 0.90, green: 0.35, blue: 0.25, alpha: 1))
        addButton(title: "HOW TO PLAY", name: "howto", y: size.height * 0.12, color: UIColor(red: 0.25, green: 0.45, blue: 0.70, alpha: 1))
    }

    private func addButton(title: String, name: String, y: CGFloat, color: UIColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: min(260, size.width * 0.7), height: 52), cornerRadius: 12)
        btn.fillColor = color
        btn.strokeColor = UIColor(white: 1, alpha: 0.35)
        btn.lineWidth = 2
        btn.position = CGPoint(x: size.width / 2, y: y)
        btn.name = name
        btn.zPosition = 20
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    private func spawnPreviewCart() {
        let cart = CartNode(profile: CartProfile.roster[0], isPlayer: true)
        cart.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        cart.setScale(2.2)
        cart.zRotation = 0.15
        addChild(cart)
        cartPreview = cart
    }

    override func update(_ currentTime: TimeInterval) {
        bobTime += 1 / 60
        cartPreview?.position.y = size.height * 0.42 + sin(bobTime * 2) * 8
        cartPreview?.zRotation = 0.12 + sin(bobTime * 1.4) * 0.08
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)
        if nodes.contains(where: { $0.name == "play" }) {
            let next = CharacterSelectScene(size: size)
            next.scaleMode = .resizeFill
            view?.presentScene(next, transition: .push(with: .left, duration: 0.35))
        } else if nodes.contains(where: { $0.name == "howto" }) {
            showHowTo()
        }
    }

    private func showHowTo() {
        childNode(withName: "howtoPanel")?.removeFromParent()
        let panel = SKShapeNode(rectOf: CGSize(width: size.width * 0.85, height: size.height * 0.55), cornerRadius: 16)
        panel.fillColor = UIColor(white: 0.08, alpha: 0.94)
        panel.strokeColor = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.name = "howtoPanel"
        panel.zPosition = 50
        addChild(panel)

        let lines = [
            "Steer with LEFT / RIGHT",
            "Hold GAS to charge aisles",
            "Grab ? boxes for items",
            "BANANA · SODA · SOUP · COUPON",
            "3 laps — first cart wins!",
            "",
            "Tap to close"
        ]
        for (i, line) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = line
            label.fontSize = 15
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: 90 - CGFloat(i) * 28)
            label.verticalAlignmentMode = .center
            panel.addChild(label)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let panel = childNode(withName: "howtoPanel") {
            panel.removeFromParent()
        }
    }
}
