import SpriteKit

final class CharacterSelectScene: SKScene {
    private var index = 0
    private var preview: CartNode?
    private var nameLabel: SKLabelNode!
    private var mottoLabel: SKLabelNode!
    private var statsLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)
        removeAllChildren()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "PICK YOUR CART"
        title.fontSize = 28
        title.fontColor = UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        addChild(title)

        nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.fontSize = 24
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        addChild(nameLabel)

        mottoLabel = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        mottoLabel.fontSize = 15
        mottoLabel.fontColor = UIColor(white: 0.8, alpha: 1)
        mottoLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.53)
        addChild(mottoLabel)

        statsLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        statsLabel.fontSize = 14
        statsLabel.fontColor = UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1)
        statsLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.47)
        addChild(statsLabel)

        addNavButton(title: "‹", name: "prev", x: size.width * 0.18)
        addNavButton(title: "›", name: "next", x: size.width * 0.82)

        let race = SKShapeNode(rectOf: CGSize(width: min(240, size.width * 0.65), height: 54), cornerRadius: 12)
        race.fillColor = UIColor(red: 0.90, green: 0.35, blue: 0.25, alpha: 1)
        race.strokeColor = .white
        race.lineWidth = 2
        race.position = CGPoint(x: size.width / 2, y: size.height * 0.16)
        race.name = "race"
        addChild(race)

        let raceLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        raceLabel.text = "LET'S ROLL"
        raceLabel.fontSize = 20
        raceLabel.fontColor = .white
        raceLabel.verticalAlignmentMode = .center
        raceLabel.name = "race"
        race.addChild(raceLabel)

        let back = SKLabelNode(fontNamed: "AvenirNext-Medium")
        back.text = "← Menu"
        back.fontSize = 16
        back.fontColor = UIColor(white: 0.75, alpha: 1)
        back.position = CGPoint(x: 60, y: size.height - 50)
        back.name = "back"
        addChild(back)

        refresh()
    }

    private func addNavButton(title: String, name: String, x: CGFloat) {
        let btn = SKShapeNode(circleOfRadius: 28)
        btn.fillColor = UIColor(white: 0.25, alpha: 1)
        btn.strokeColor = .white
        btn.lineWidth = 2
        btn.position = CGPoint(x: x, y: size.height * 0.72)
        btn.name = name
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 28
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    private func refresh() {
        preview?.removeFromParent()
        let profile = CartProfile.roster[index]
        let cart = CartNode(profile: profile, isPlayer: true)
        cart.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        cart.setScale(2.6)
        addChild(cart)
        preview = cart

        nameLabel.text = profile.name
        mottoLabel.text = "“\(profile.motto)”"
        statsLabel.text = String(
            format: "SPD %.0f  HAND %.0f  WGT %.0f",
            profile.speed * 100,
            profile.handling * 100,
            profile.weight * 100
        )
        RaceSession.shared.selectedCart = profile
    }

    override func update(_ currentTime: TimeInterval) {
        preview?.zRotation = sin(currentTime * 1.5) * 0.12
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let hit = nodes(at: touch.location(in: self))
        if hit.contains(where: { $0.name == "prev" }) {
            index = (index - 1 + CartProfile.roster.count) % CartProfile.roster.count
            refresh()
        } else if hit.contains(where: { $0.name == "next" }) {
            index = (index + 1) % CartProfile.roster.count
            refresh()
        } else if hit.contains(where: { $0.name == "race" }) {
            let game = GameScene(size: size)
            game.scaleMode = .resizeFill
            view?.presentScene(game, transition: .doorsCloseHorizontal(withDuration: 0.4))
        } else if hit.contains(where: { $0.name == "back" }) {
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: .push(with: .right, duration: 0.3))
        }
    }
}
