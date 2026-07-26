import SpriteKit

/// Post-race standings with buttons to race again or return to the menu.
final class ResultsScene: SKScene {

    private let results: [RaceResult]
    private let raceAgainName = "raceAgain"
    private let menuName = "menu"

    init(size: CGSize, results: [RaceResult]) {
        self.results = results
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let playerPlace = results.first(where: { $0.isPlayer })?.place ?? results.count
        let headline: String
        switch playerPlace {
        case 1: headline = "CHECKOUT CHAMPION!"
        case 2: headline = "SO CLOSE — 2ND!"
        case 3: headline = "PODIUM FINISH!"
        default: headline = "BETTER LUCK NEXT AISLE"
        }

        let title = SKLabelNode(text: headline)
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 44
        title.fontColor = playerPlace == 1
            ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
            : .white
        title.position = CGPoint(x: 0, y: 210)
        addChild(title)

        for (i, result) in results.enumerated() {
            addResultRow(result, y: 130 - CGFloat(i) * 52)
        }

        addButton(text: "RACE AGAIN", name: raceAgainName,
                  position: CGPoint(x: -140, y: -210),
                  color: SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1))
        addButton(text: "MENU", name: menuName,
                  position: CGPoint(x: 140, y: -210),
                  color: SKColor(white: 0.4, alpha: 1))
    }

    private func addResultRow(_ result: RaceResult, y: CGFloat) {
        let row = SKNode()
        row.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 640, height: 44), cornerRadius: 10)
        bg.fillColor = result.isPlayer
            ? SKColor(white: 1, alpha: 0.14)
            : SKColor(white: 1, alpha: 0.06)
        bg.strokeColor = result.isPlayer ? result.tint : .clear
        bg.lineWidth = 2
        row.addChild(bg)

        let place = SKLabelNode(text: "\(result.place)")
        place.fontName = "AvenirNext-Heavy"
        place.fontSize = 26
        place.fontColor = medalColor(for: result.place)
        place.horizontalAlignmentMode = .center
        place.verticalAlignmentMode = .center
        place.position = CGPoint(x: -290, y: 0)
        row.addChild(place)

        let swatch = SKShapeNode(rectOf: CGSize(width: 22, height: 22), cornerRadius: 4)
        swatch.fillColor = result.tint
        swatch.strokeColor = .white
        swatch.position = CGPoint(x: -245, y: 0)
        row.addChild(swatch)

        let name = SKLabelNode(text: result.name)
        name.fontName = "AvenirNext-Bold"
        name.fontSize = 22
        name.fontColor = .white
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: -215, y: 0)
        row.addChild(name)

        let time = SKLabelNode(text: result.finished ? formatRaceTime(result.time) : "DNF")
        time.fontName = "AvenirNext-Medium"
        time.fontSize = 20
        time.fontColor = SKColor(white: 0.85, alpha: 1)
        time.horizontalAlignmentMode = .right
        time.verticalAlignmentMode = .center
        time.position = CGPoint(x: 300, y: 0)
        row.addChild(time)

        addChild(row)
    }

    private func medalColor(for place: Int) -> SKColor {
        switch place {
        case 1: return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
        case 2: return SKColor(white: 0.75, alpha: 1)
        case 3: return SKColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)
        default: return SKColor(white: 0.6, alpha: 1)
        }
    }

    private func addButton(text: String, name: String, position: CGPoint, color: SKColor) {
        let button = SKShapeNode(rectOf: CGSize(width: 220, height: 60), cornerRadius: 14)
        button.fillColor = color
        button.strokeColor = .white
        button.lineWidth = 2
        button.position = position
        button.name = name

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        addChild(button)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location).compactMap { $0.name }

        if tapped.contains(raceAgainName) {
            let scene = GameScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: .fade(withDuration: 0.5))
        } else if tapped.contains(menuName) {
            let scene = MenuScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: .fade(withDuration: 0.5))
        }
    }
}
