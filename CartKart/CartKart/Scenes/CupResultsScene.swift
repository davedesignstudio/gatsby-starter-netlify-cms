import SpriteKit

final class CupResultsScene: SKScene {
    private let session: CupSession

    init(size: CGSize, session: CupSession) {
        self.session = session
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        SoundManager.shared.play(.raceFinish)
        buildResults()
    }

    private func buildResults() {
        let title = SKLabelNode(text: "\(session.cup.emoji) \(session.cup.name.uppercased())")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 28
        title.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height * 0.32)
        addChild(title)

        let subtitle = SKLabelNode(text: "Final Standings")
        subtitle.fontName = "AvenirNext-DemiBold"
        subtitle.fontSize = 18
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: 0, y: size.height * 0.32 - 36)
        addChild(subtitle)

        for (index, standing) in session.sortedStandings.enumerated() {
            let row = makeStandingRow(position: index + 1, standing: standing)
            row.position = CGPoint(x: 0, y: size.height * 0.16 - CGFloat(index) * 54)
            addChild(row)
        }

        let menuButton = makeButton(text: "MAIN MENU", name: "menu")
        menuButton.position = CGPoint(x: 0, y: -size.height * 0.28)
        addChild(menuButton)
    }

    private func makeStandingRow(position: Int, standing: CupStanding) -> SKNode {
        let row = SKNode()
        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 0.82, height: 44), cornerRadius: 10)
        bg.fillColor = standing.isHuman
            ? SKColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.35)
            : SKColor(white: 1, alpha: 0.08)
        bg.strokeColor = standing.isHuman ? SKColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.8) : SKColor(white: 1, alpha: 0.15)
        bg.lineWidth = 2
        row.addChild(bg)

        let pos = SKLabelNode(text: ordinal(position))
        pos.fontName = "AvenirNext-Heavy"
        pos.fontSize = 18
        pos.fontColor = .white
        pos.horizontalAlignmentMode = .left
        pos.position = CGPoint(x: -size.width * 0.36, y: -6)
        row.addChild(pos)

        let name = SKLabelNode(text: standing.name)
        name.fontName = standing.isHuman ? "AvenirNext-Bold" : "AvenirNext-Medium"
        name.fontSize = 16
        name.fontColor = .white
        name.horizontalAlignmentMode = .left
        name.position = CGPoint(x: -size.width * 0.22, y: -6)
        row.addChild(name)

        let pts = SKLabelNode(text: "\(standing.points) pts")
        pts.fontName = "AvenirNext-Medium"
        pts.fontSize = 14
        pts.fontColor = SKColor(white: 1, alpha: 0.75)
        pts.horizontalAlignmentMode = .right
        pts.position = CGPoint(x: size.width * 0.36, y: -6)
        row.addChild(pts)

        return row
    }

    private func makeButton(text: String, name: String) -> SKNode {
        let button = SKNode()
        button.name = name
        let bg = SKShapeNode(rectOf: CGSize(width: 240, height: 50), cornerRadius: 12)
        bg.fillColor = SKColor(white: 1, alpha: 0.12)
        bg.strokeColor = SKColor(white: 1, alpha: 0.3)
        bg.lineWidth = 2
        bg.name = name
        button.addChild(bg)
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 17
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)
        return button
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if nodes(at: touch.location(in: self)).contains(where: { $0.name == "menu" }) {
            GameSettings.shared.cupSession = nil
            GameSettings.shared.gameMode = .quickRace
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: SKTransition.crossFade(withDuration: 0.5))
        }
    }
}
