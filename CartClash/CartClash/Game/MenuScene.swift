import SpriteKit
import UIKit

final class MenuScene: SKScene {
    private var startButton: SKShapeNode!
    private var titleNode: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        removeAllChildren()
        buildBackground()
        buildTitle()
        buildButtons()
        animateEntrance()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren()
        buildBackground()
        buildTitle()
        buildButtons()
    }

    private func buildBackground() {
        // Store floor vibe
        let floor = SKShapeNode(rectOf: size)
        floor.fillColor = UIColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(floor)

        for i in 0..<8 {
            let aisle = SKShapeNode(rectOf: CGSize(width: 36, height: size.height * 0.7))
            aisle.fillColor = [
                UIColor(red: 0.75, green: 0.25, blue: 0.22, alpha: 0.55),
                UIColor(red: 0.22, green: 0.45, blue: 0.75, alpha: 0.55),
                UIColor(red: 0.25, green: 0.65, blue: 0.35, alpha: 0.55),
                UIColor(red: 0.85, green: 0.6, blue: 0.15, alpha: 0.55)
            ][i % 4]
            aisle.strokeColor = .clear
            aisle.position = CGPoint(x: size.width * 0.12 + CGFloat(i) * size.width * 0.11, y: size.height * 0.42)
            aisle.zPosition = 1
            aisle.alpha = 0.35
            addChild(aisle)
        }

        // Rolling cart decorations
        for i in 0..<5 {
            let cart = makeDecorCart(color: RacerProfile.roster[i % RacerProfile.roster.count].cartColor)
            cart.position = CGPoint(x: -80 - CGFloat(i) * 40, y: 70 + CGFloat(i % 3) * 28)
            cart.zPosition = 2
            cart.setScale(0.7 + CGFloat(i % 3) * 0.1)
            addChild(cart)
            let pathWidth = size.width + 200
            let move = SKAction.sequence([
                SKAction.moveBy(x: pathWidth, y: CGFloat.random(in: -10...10), duration: Double(7 + i)),
                SKAction.run { [weak cart] in cart?.position.x = -80 }
            ])
            cart.run(SKAction.repeatForever(move))
        }
    }

    private func makeDecorCart(color: UIColor) -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: 40, height: 54), cornerRadius: 5)
        body.fillColor = color
        body.strokeColor = UIColor(white: 0.1, alpha: 1)
        body.lineWidth = 1.5
        n.addChild(body)
        let cargo = SKLabelNode(text: ["🥫", "🧣", "🍾", "🗑️", "📦"][Int.random(in: 0...4)])
        cargo.fontSize = 16
        cargo.verticalAlignmentMode = .center
        cargo.position = CGPoint(x: 0, y: 6)
        n.addChild(cargo)
        return n
    }

    private func buildTitle() {
        titleNode = SKNode()
        titleNode.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        titleNode.zPosition = 10
        addChild(titleNode)

        let badge = SKShapeNode(rectOf: CGSize(width: min(size.width - 40, 340), height: 36), cornerRadius: 8)
        badge.fillColor = UIColor(red: 0.9, green: 0.2, blue: 0.22, alpha: 1)
        badge.strokeColor = .clear
        badge.position = CGPoint(x: 0, y: 70)
        titleNode.addChild(badge)

        let store = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        store.text = "MEGA MART SPEEDWAY"
        store.fontSize = 14
        store.fontColor = .white
        store.verticalAlignmentMode = .center
        store.position = badge.position
        titleNode.addChild(store)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "CART CLASH"
        title.fontSize = min(52, size.width * 0.12)
        title.fontColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 18)
        titleNode.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Shopping carts. Zero chill. One checkout."
        subtitle.fontSize = 15
        subtitle.fontColor = UIColor(white: 1, alpha: 0.8)
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: 0, y: -28)
        titleNode.addChild(subtitle)
    }

    private func buildButtons() {
        startButton = SKShapeNode(rectOf: CGSize(width: 220, height: 56), cornerRadius: 14)
        startButton.fillColor = UIColor(red: 1, green: 0.78, blue: 0.15, alpha: 1)
        startButton.strokeColor = UIColor(white: 0.1, alpha: 1)
        startButton.lineWidth = 2
        startButton.position = CGPoint(x: size.width / 2, y: size.height * 0.34)
        startButton.name = "start"
        startButton.zPosition = 10
        addChild(startButton)

        let startText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        startText.text = "RACE"
        startText.fontSize = 24
        startText.fontColor = UIColor(white: 0.1, alpha: 1)
        startText.verticalAlignmentMode = .center
        startText.name = "start"
        startButton.addChild(startText)

        let how = SKLabelNode(fontNamed: "AvenirNext-Medium")
        how.text = "Steer · Drift boost · Banana peels · Bean turbo"
        how.fontSize = 12
        how.fontColor = UIColor(white: 1, alpha: 0.55)
        how.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        how.zPosition = 10
        addChild(how)
    }

    private func animateEntrance() {
        titleNode.setScale(0.85)
        titleNode.alpha = 0
        titleNode.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.45),
            SKAction.scale(to: 1, duration: 0.45)
        ]))
        startButton.setScale(0.9)
        startButton.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.scale(to: 1, duration: 0.25)
        ]))
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.7),
            SKAction.scale(to: 1.0, duration: 0.7)
        ])
        startButton.run(SKAction.repeatForever(pulse))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)
        if nodes.contains(where: { $0.name == "start" || $0.parent?.name == "start" }) {
            startButton.run(SKAction.sequence([
                SKAction.scale(to: 0.94, duration: 0.08),
                SKAction.run { [weak self] in self?.goToCharacterSelect() }
            ]))
        }
    }

    private func goToCharacterSelect() {
        let next = CharacterSelectScene(size: size)
        next.scaleMode = .resizeFill
        view?.presentScene(next, transition: .fade(withDuration: 0.4))
    }
}
