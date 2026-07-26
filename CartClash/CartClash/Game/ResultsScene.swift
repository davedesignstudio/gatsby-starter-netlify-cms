import SpriteKit
import UIKit

final class ResultsScene: SKScene {
    private let results: [RaceResult]

    init(size: CGSize, results: [RaceResult]) {
        self.results = results
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "CHECKOUT RESULTS"
        title.fontSize = 28
        title.fontColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height - 60)
        addChild(title)

        let playerResult = results.first(where: \.isPlayer)
        let banner = SKLabelNode(fontNamed: "AvenirNext-Bold")
        if let playerResult {
            switch playerResult.place {
            case 1: banner.text = "You cleaned house!"
            case 2: banner.text = "So close to the crown."
            case 3: banner.text = "Podium cart. Respect."
            default: banner.text = "Back to the parking lot…"
            }
        }
        banner.fontSize = 16
        banner.fontColor = UIColor(white: 1, alpha: 0.8)
        banner.position = CGPoint(x: size.width / 2, y: size.height - 92)
        addChild(banner)

        let startY = size.height * 0.72
        for (i, result) in results.enumerated() {
            let row = makeRow(result: result, index: i)
            row.position = CGPoint(x: size.width / 2, y: startY - CGFloat(i) * 58)
            row.alpha = 0
            row.position.x += 40
            addChild(row)
            row.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.12 * Double(i)),
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.25),
                    SKAction.moveBy(x: -40, y: 0, duration: 0.25)
                ])
            ]))
        }

        let again = SKShapeNode(rectOf: CGSize(width: 190, height: 50), cornerRadius: 12)
        again.fillColor = UIColor(red: 1, green: 0.78, blue: 0.15, alpha: 1)
        again.strokeColor = UIColor(white: 0.1, alpha: 1)
        again.lineWidth = 2
        again.position = CGPoint(x: size.width / 2 - 100, y: 64)
        again.name = "again"
        addChild(again)
        let againText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        againText.text = "RACE AGAIN"
        againText.fontSize = 16
        againText.fontColor = UIColor(white: 0.1, alpha: 1)
        againText.verticalAlignmentMode = .center
        againText.name = "again"
        again.addChild(againText)

        let menu = SKShapeNode(rectOf: CGSize(width: 160, height: 50), cornerRadius: 12)
        menu.fillColor = UIColor(white: 1, alpha: 0.12)
        menu.strokeColor = UIColor(white: 1, alpha: 0.4)
        menu.lineWidth = 2
        menu.position = CGPoint(x: size.width / 2 + 100, y: 64)
        menu.name = "menu"
        addChild(menu)
        let menuText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        menuText.text = "MENU"
        menuText.fontSize = 16
        menuText.fontColor = .white
        menuText.verticalAlignmentMode = .center
        menuText.name = "menu"
        menu.addChild(menuText)
    }

    private func makeRow(result: RaceResult, index: Int) -> SKNode {
        let node = SKNode()
        let width = min(size.width - 48, 360)

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 50), cornerRadius: 10)
        bg.fillColor = result.isPlayer
            ? UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 0.25)
            : UIColor(white: 0, alpha: 0.28)
        bg.strokeColor = result.isPlayer
            ? UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 0.9)
            : UIColor(white: 1, alpha: 0.15)
        bg.lineWidth = 2
        node.addChild(bg)

        let place = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        place.text = "\(result.place)"
        place.fontSize = 22
        place.fontColor = placeColor(result.place)
        place.horizontalAlignmentMode = .left
        place.verticalAlignmentMode = .center
        place.position = CGPoint(x: -width / 2 + 18, y: 0)
        node.addChild(place)

        let swatch = SKShapeNode(rectOf: CGSize(width: 28, height: 28), cornerRadius: 6)
        swatch.fillColor = result.profile.cartColor
        swatch.strokeColor = result.profile.accentColor
        swatch.lineWidth = 2
        swatch.position = CGPoint(x: -width / 2 + 58, y: 0)
        node.addChild(swatch)

        let cargo = SKLabelNode(text: result.profile.cargo)
        cargo.fontSize = 14
        cargo.verticalAlignmentMode = .center
        cargo.position = swatch.position
        node.addChild(cargo)

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = result.isPlayer ? "\(result.profile.name) (YOU)" : result.profile.name
        name.fontSize = 13
        name.fontColor = .white
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: -width / 2 + 82, y: 0)
        node.addChild(name)

        let time = SKLabelNode(fontNamed: "AvenirNext-Medium")
        time.text = formatTime(result.finishTime)
        time.fontSize = 13
        time.fontColor = UIColor(white: 1, alpha: 0.7)
        time.horizontalAlignmentMode = .right
        time.verticalAlignmentMode = .center
        time.position = CGPoint(x: width / 2 - 16, y: 0)
        node.addChild(time)

        return node
    }

    private func placeColor(_ place: Int) -> UIColor {
        switch place {
        case 1: return UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        case 2: return UIColor(red: 0.8, green: 0.85, blue: 0.9, alpha: 1)
        case 3: return UIColor(red: 0.9, green: 0.55, blue: 0.25, alpha: 1)
        default: return .white
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - floor(t)) * 100)
        return String(format: "%d:%02d.%02d", m, s, ms)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for node in nodes(at: loc) {
            if node.name == "again" || node.parent?.name == "again" {
                let select = CharacterSelectScene(size: size)
                select.scaleMode = .resizeFill
                view?.presentScene(select, transition: .fade(withDuration: 0.35))
                return
            }
            if node.name == "menu" || node.parent?.name == "menu" {
                let menu = MenuScene(size: size)
                menu.scaleMode = .resizeFill
                view?.presentScene(menu, transition: .fade(withDuration: 0.35))
                return
            }
        }
    }
}
