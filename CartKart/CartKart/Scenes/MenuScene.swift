import SpriteKit

final class MenuScene: SKScene {
    private var titlePulse: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1)
        buildBackground()
        buildTitle()
        buildButtons()
        runIntroAnimation()
    }

    private func buildBackground() {
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.45))
        floor.fillColor = SKColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: 0, y: -size.height * 0.2)
        floor.zPosition = -5
        addChild(floor)

        for index in 0..<6 {
            let aisle = SKShapeNode(rectOf: CGSize(width: size.width, height: 18))
            aisle.fillColor = SKColor(white: 0.9, alpha: 0.25)
            aisle.strokeColor = .clear
            aisle.position = CGPoint(x: 0, y: -size.height * 0.35 + CGFloat(index) * 36)
            aisle.zPosition = -4
            addChild(aisle)
        }

        let cartPreview = makePreviewCart()
        cartPreview.position = CGPoint(x: 0, y: 40)
        cartPreview.setScale(1.4)
        cartPreview.name = "previewCart"
        addChild(cartPreview)
    }

    private func makePreviewCart() -> SKNode {
        let node = SKNode()
        let cart = SKShapeNode(rectOf: CGSize(width: 70, height: 50), cornerRadius: 8)
        cart.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
        cart.strokeColor = .darkGray
        cart.lineWidth = 3
        node.addChild(cart)

        let rider = SKShapeNode(circleOfRadius: 16)
        rider.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1)
        rider.position = CGPoint(x: 0, y: 28)
        node.addChild(rider)

        let beanie = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 4)
        beanie.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        beanie.position = CGPoint(x: 0, y: 40)
        node.addChild(beanie)

        return node
    }

    private func buildTitle() {
        let title = SKLabelNode(text: "CART KART")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 52
        title.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height * 0.28)
        title.name = "title"
        addChild(title)

        let subtitle = SKLabelNode(text: "Grocery Gauntlet")
        subtitle.fontName = "AvenirNext-DemiBold"
        subtitle.fontSize = 22
        subtitle.fontColor = SKColor(red: 0.85, green: 0.9, blue: 0.95, alpha: 1)
        subtitle.position = CGPoint(x: 0, y: size.height * 0.28 - 44)
        addChild(subtitle)

        let tagline = SKLabelNode(text: "Race wobbly carts through the aisles!")
        tagline.fontName = "AvenirNext-Medium"
        tagline.fontSize = 15
        tagline.fontColor = SKColor(white: 1, alpha: 0.7)
        tagline.position = CGPoint(x: 0, y: size.height * 0.28 - 74)
        addChild(tagline)
    }

    private func buildButtons() {
        let play = makeButton(text: "START RACE", name: "play", y: -size.height * 0.18)
        addChild(play)

        let howTo = makeButton(text: "HOW TO PLAY", name: "howto", y: -size.height * 0.18 - 70)
        addChild(howTo)

        let credits = SKLabelNode(text: "SpriteKit iOS • 4-player aisle chaos")
        credits.fontName = "AvenirNext-Regular"
        credits.fontSize = 12
        credits.fontColor = SKColor(white: 1, alpha: 0.45)
        credits.position = CGPoint(x: 0, y: -size.height * 0.42)
        addChild(credits)
    }

    private func makeButton(text: String, name: String, y: CGFloat) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 260, height: 54), cornerRadius: 14)
        bg.fillColor = name == "play"
            ? SKColor(red: 0.18, green: 0.62, blue: 0.95, alpha: 1)
            : SKColor(white: 1, alpha: 0.12)
        bg.strokeColor = SKColor(white: 1, alpha: 0.35)
        bg.lineWidth = 2
        bg.name = name
        button.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }

    private func runIntroAnimation() {
        let move = SKAction.sequence([
            SKAction.moveBy(x: 30, y: 0, duration: 1.2),
            SKAction.moveBy(x: -30, y: 0, duration: 1.2)
        ])
        childNode(withName: "previewCart")?.run(SKAction.repeatForever(move))

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        childNode(withName: "title")?.run(SKAction.repeatForever(pulse))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))

        if nodes.contains(where: { $0.name == "play" }) {
            transitionToGame()
        } else if nodes.contains(where: { $0.name == "howto" }) {
            showHowToPlay()
        }
    }

    private func transitionToGame() {
        let scene = GameScene(size: size)
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: SKTransition.doorsOpenHorizontal(withDuration: 0.6))
    }

    private func showHowToPlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.86, height: 320), cornerRadius: 18)
        overlay.fillColor = SKColor(white: 0.05, alpha: 0.92)
        overlay.strokeColor = SKColor(white: 1, alpha: 0.25)
        overlay.lineWidth = 2
        overlay.position = CGPoint(x: 0, y: 0)
        overlay.name = "overlay"
        overlay.zPosition = 100
        addChild(overlay)

        let lines = [
            "🕹️ Left stick: steer",
            "🟢 GO: accelerate",
            "🟠 DRIFT: slide around corners",
            "🟣 ITEM: use power-up",
            "🏁 Complete 3 laps through checkout checkpoints",
            "🛒 Bump rivals, dodge shelves, grab aisle items!"
        ]

        for (index, line) in lines.enumerated() {
            let label = SKLabelNode(text: line)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = 15
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -size.width * 0.36, y: 90 - CGFloat(index) * 28)
            label.zPosition = 101
            label.name = "overlay"
            addChild(label)
        }

        let dismiss = SKLabelNode(text: "Tap anywhere to close")
        dismiss.fontName = "AvenirNext-DemiBold"
        dismiss.fontSize = 13
        dismiss.fontColor = SKColor(white: 1, alpha: 0.55)
        dismiss.position = CGPoint(x: 0, y: -130)
        dismiss.zPosition = 101
        dismiss.name = "overlay"
        addChild(dismiss)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.01),
            SKAction.run { [weak self] in
                self?.isUserInteractionEnabled = true
            }
        ]))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        childNode(withName: "overlay")?.removeFromParent()
        enumerateChildNodes(withName: "overlay") { node, _ in node.removeFromParent() }
    }
}
