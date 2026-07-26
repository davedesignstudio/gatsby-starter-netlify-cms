import SpriteKit

final class MenuScene: SKScene {
    private var startButton: SKShapeNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        buildBackground()
        buildTitle()
        buildStartButton()
        buildInstructions()
        animateCarts()
    }

    private func buildBackground() {
        for i in 0..<8 {
            let shelf = SKShapeNode(rectOf: CGSize(width: 300, height: 30), cornerRadius: 3)
            shelf.position = CGPoint(x: size.width / 2, y: CGFloat(i) * 90 + 60)
            shelf.fillColor = SKColor(red: 0.35, green: 0.25, blue: 0.18, alpha: 0.4)
            shelf.strokeColor = .clear
            shelf.zPosition = -5
            addChild(shelf)
        }
    }

    private func buildTitle() {
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "CART CHAOS"
        title.fontSize = 48
        title.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Shopping Cart Grand Prix"
        subtitle.fontSize = 18
        subtitle.fontColor = SKColor(white: 0.8, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        addChild(subtitle)

        let tagline = SKLabelNode(fontNamed: "AvenirNext-Italic")
        tagline.text = "Race dented carts through the grocery aisles!"
        tagline.fontSize = 14
        tagline.fontColor = SKColor(white: 0.6, alpha: 1)
        tagline.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        addChild(tagline)
    }

    private func buildStartButton() {
        startButton = SKShapeNode(rectOf: CGSize(width: 240, height: 56), cornerRadius: 14)
        startButton.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        startButton.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.35, alpha: 1)
        startButton.strokeColor = SKColor(red: 0.1, green: 0.5, blue: 0.25, alpha: 1)
        startButton.lineWidth = 3
        startButton.name = "startButton"
        addChild(startButton)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "START RACE"
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = "startButton"
        startButton.addChild(label)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        startButton.run(SKAction.repeatForever(pulse))
    }

    private func buildInstructions() {
        let lines = [
            "Left thumb: Steer",
            "Right thumb: Gas & Brake",
            "Tap USE ITEM to deploy power-ups",
            "Complete 3 laps to win!"
        ]

        for (i, line) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.text = line
            label.fontSize = 14
            label.fontColor = SKColor(white: 0.7, alpha: 1)
            label.position = CGPoint(x: size.width / 2, y: size.height * 0.22 - CGFloat(i) * 24)
            addChild(label)
        }
    }

    private func animateCarts() {
        let colors: [SKColor] = [
            SKColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1),
            SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1),
            SKColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        ]

        for (i, color) in colors.enumerated() {
            let cart = SKShapeNode(rectOf: CGSize(width: 28, height: 34), cornerRadius: 3)
            cart.fillColor = color
            cart.strokeColor = .black
            cart.lineWidth = 1
            cart.position = CGPoint(x: size.width * 0.25 + CGFloat(i) * 80, y: size.height * 0.75)
            cart.zPosition = 2
            addChild(cart)

            let move = SKAction.sequence([
                SKAction.moveBy(x: 40, y: 0, duration: 1.2),
                SKAction.moveBy(x: -40, y: 0, duration: 1.2)
            ])
            cart.run(SKAction.repeatForever(move))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)

        if nodes.contains(where: { $0.name == "startButton" }) {
            startButton.fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.28, alpha: 1)
            transitionToRace()
        }
    }

    private func transitionToRace() {
        let race = RaceScene(size: size)
        race.scaleMode = scaleMode
        let transition = SKTransition.doorsOpenHorizontal(withDuration: 0.8)
        view?.presentScene(race, transition: transition)
    }
}
