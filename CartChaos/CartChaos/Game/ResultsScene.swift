import SpriteKit

final class ResultsScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        removeAllChildren()

        let place = RaceSession.shared.playerFinishPosition
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = place == 1 ? "YOU WON THE LOT!" : place == 0 ? "RACE OVER" : "FINISHED #\(place)"
        title.fontSize = min(36, size.width * 0.08)
        title.fontColor = place == 1
            ? UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1)
            : .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = place == 1 ? "MegaMart belongs to the carts tonight." : "The aisles remember."
        sub.fontSize = 15
        sub.fontColor = UIColor(white: 0.75, alpha: 1)
        sub.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        addChild(sub)

        let order = RaceSession.shared.finishingOrder
        for (i, name) in order.enumerated() {
            let row = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: 44), cornerRadius: 10)
            row.fillColor = i == 0
                ? UIColor(red: 0.45, green: 0.35, blue: 0.10, alpha: 0.9)
                : UIColor(white: 0.18, alpha: 0.85)
            row.strokeColor = UIColor(white: 1, alpha: 0.2)
            row.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - CGFloat(i) * 54)
            addChild(row)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            let isPlayer = name == RaceSession.shared.selectedCart.name
            label.text = "\(i + 1).  \(name)\(isPlayer ? "  (YOU)" : "")"
            label.fontSize = 17
            label.fontColor = isPlayer ? UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1) : .white
            label.verticalAlignmentMode = .center
            row.addChild(label)
        }

        addButton(title: "RACE AGAIN", name: "again", y: size.height * 0.18, color: UIColor(red: 0.90, green: 0.35, blue: 0.25, alpha: 1))
        addButton(title: "MAIN MENU", name: "menu", y: size.height * 0.09, color: UIColor(white: 0.28, alpha: 1))
    }

    private func addButton(title: String, name: String, y: CGFloat, color: UIColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: min(240, size.width * 0.65), height: 48), cornerRadius: 12)
        btn.fillColor = color
        btn.strokeColor = .white
        btn.lineWidth = 1.5
        btn.position = CGPoint(x: size.width / 2, y: y)
        btn.name = name
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        btn.addChild(label)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let hit = nodes(at: touch.location(in: self))
        if hit.contains(where: { $0.name == "again" }) {
            let select = CharacterSelectScene(size: size)
            select.scaleMode = .resizeFill
            view?.presentScene(select, transition: .push(with: .left, duration: 0.3))
        } else if hit.contains(where: { $0.name == "menu" }) {
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: .fade(withDuration: 0.35))
        }
    }
}
