import SpriteKit

final class GameOverScene: SKScene {
    private let winner: ShoppingCart
    private let standings: [ShoppingCart]
    private let playerWon: Bool

    init(size: CGSize, winner: ShoppingCart, standings: [ShoppingCart], playerWon: Bool) {
        self.winner = winner
        self.standings = standings
        self.playerWon = playerWon
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.16, alpha: 1)
        buildResults()
        buildButtons()
    }

    private func buildResults() {
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = playerWon ? "YOU WIN!" : "RACE OVER"
        title.fontSize = 42
        title.fontColor = playerWon
            ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
            : SKColor(red: 0.9, green: 0.4, blue: 0.35, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        addChild(title)

        let winnerLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        winnerLabel.text = "Winner: \(winner.profile.name)"
        winnerLabel.fontSize = 20
        winnerLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        winnerLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        addChild(winnerLabel)

        let standingsTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        standingsTitle.text = "FINAL STANDINGS"
        standingsTitle.fontSize = 16
        standingsTitle.fontColor = SKColor(white: 0.6, alpha: 1)
        standingsTitle.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        addChild(standingsTitle)

        for (index, cart) in standings.enumerated() {
            let row = SKLabelNode(fontNamed: "AvenirNext-Medium")
            let medal = index == 0 ? "🛒" : "  "
            row.text = "\(medal) \(index + 1). \(cart.profile.name)"
            row.fontSize = 18
            row.fontColor = cart.isPlayer
                ? SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1)
                : SKColor(white: 0.8, alpha: 1)
            row.position = CGPoint(x: size.width / 2, y: size.height * 0.50 - CGFloat(index) * 30)
            addChild(row)
        }

        if playerWon {
            spawnConfetti()
        }
    }

    private func spawnConfetti() {
        let colors: [SKColor] = [
            .red, .green, .yellow, .cyan, .magenta, .orange
        ]

        for i in 0..<30 {
            let piece = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            piece.fillColor = colors[i % colors.count]
            piece.strokeColor = .clear
            piece.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: size.height + 20
            )
            piece.zPosition = 50
            addChild(piece)

            let fall = SKAction.moveTo(
                y: -20,
                duration: Double.random(in: 2...4)
            )
            let spin = SKAction.rotate(byAngle: .pi * 4, duration: 2)
            piece.run(SKAction.group([fall, spin]))
        }
    }

    private func buildButtons() {
        let retryButton = makeButton(
            text: "RACE AGAIN",
            position: CGPoint(x: size.width / 2, y: size.height * 0.18),
            name: "retryButton",
            color: SKColor(red: 0.2, green: 0.7, blue: 0.35, alpha: 1)
        )
        addChild(retryButton)

        let menuButton = makeButton(
            text: "MAIN MENU",
            position: CGPoint(x: size.width / 2, y: size.height * 0.10),
            name: "menuButton",
            color: SKColor(red: 0.35, green: 0.4, blue: 0.5, alpha: 1)
        )
        addChild(menuButton)
    }

    private func makeButton(text: String, position: CGPoint, name: String, color: SKColor) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 48), cornerRadius: 12)
        button.position = position
        button.fillColor = color
        button.strokeColor = color.withAlphaComponent(0.6)
        button.lineWidth = 2
        button.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))

        if nodes.contains(where: { $0.name == "retryButton" }) {
            let race = RaceScene(size: size)
            race.scaleMode = scaleMode
            view?.presentScene(race, transition: SKTransition.fade(withDuration: 0.5))
        }

        if nodes.contains(where: { $0.name == "menuButton" }) {
            let menu = MenuScene(size: size)
            menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: SKTransition.fade(withDuration: 0.5))
        }
    }
}
