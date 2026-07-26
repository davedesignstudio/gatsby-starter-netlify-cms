import SpriteKit
import UIKit

final class ResultsScene: SKScene {
    private let place: Int
    private let cart: CartArchetype
    private let standings: [(String, Int)]

    init(size: CGSize, place: Int, cart: CartArchetype, standings: [(String, Int)]) {
        self.place = place
        self.cart = cart
        self.standings = standings
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.place = 1
        self.cart = .speedy
        self.standings = []
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.14, blue: 0.12, alpha: 1)
        removeAllChildren()

        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = place == 1 ? "AISLE CHAMPION!" : "RACE OVER"
        banner.fontSize = min(40, size.width * 0.07)
        banner.fontColor = place == 1
            ? UIColor(red: 1, green: 0.84, blue: 0.25, alpha: 1)
            : UIColor(white: 0.92, alpha: 1)
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.86)
        addChild(banner)

        let placeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        placeLabel.text = "\(cart.displayName) finished \(ordinal(place))"
        placeLabel.fontSize = 20
        placeLabel.fontColor = cart.accent
        placeLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        addChild(placeLabel)

        let preview = CartArt.makeCart(archetype: cart, scale: 1.4)
        preview.position = CGPoint(x: size.width * 0.28, y: size.height * 0.48)
        addChild(preview)
        preview.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.12, duration: 0.6),
            .rotate(byAngle: -0.24, duration: 1.2),
            .rotate(byAngle: 0.12, duration: 0.6)
        ])))

        let boardTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        boardTitle.text = "STANDINGS"
        boardTitle.fontSize = 16
        boardTitle.fontColor = UIColor(white: 0.8, alpha: 1)
        boardTitle.horizontalAlignmentMode = .left
        boardTitle.position = CGPoint(x: size.width * 0.52, y: size.height * 0.64)
        addChild(boardTitle)

        for (index, row) in standings.prefix(5).enumerated() {
            let line = SKLabelNode(fontNamed: "AvenirNext-Medium")
            line.text = "\(ordinal(row.1))  \(row.0)"
            line.fontSize = 15
            line.fontColor = row.0 == cart.displayName ? cart.accent : UIColor(white: 0.85, alpha: 1)
            line.horizontalAlignmentMode = .left
            line.position = CGPoint(x: size.width * 0.52, y: size.height * 0.58 - CGFloat(index) * 28)
            addChild(line)
        }

        addButton(name: "retry", title: "RACE AGAIN", x: size.width * 0.35, y: size.height * 0.14, color: UIColor(red: 0.15, green: 0.55, blue: 0.3, alpha: 1))
        addButton(name: "menu", title: "MAIN MENU", x: size.width * 0.65, y: size.height * 0.14, color: UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1))
    }

    private func addButton(name: String, title: String, x: CGFloat, y: CGFloat, color: UIColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: 160, height: 46), cornerRadius: 10)
        btn.fillColor = color
        btn.strokeColor = UIColor(white: 1, alpha: 0.25)
        btn.position = CGPoint(x: x, y: y)
        btn.name = name
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))
        for node in nodes {
            if node.name == "retry" {
                let race = GameScene(size: size)
                race.scaleMode = .resizeFill
                race.playerCart = cart
                view?.presentScene(race, transition: .fade(withDuration: 0.4))
                return
            }
            if node.name == "menu" {
                let menu = MenuScene(size: size)
                menu.scaleMode = .resizeFill
                view?.presentScene(menu, transition: .fade(withDuration: 0.4))
                return
            }
        }
    }
}
