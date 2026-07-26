import SpriteKit
import UIKit

final class CharacterSelectScene: SKScene {
    private var selectedIndex = 0
    private var cards: [SKNode] = []
    private var detailName: SKLabelNode!
    private var detailTag: SKLabelNode!
    private var detailStats: SKLabelNode!
    private var previewCart: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        cards.removeAll()

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "PICK YOUR CART"
        title.fontSize = 28
        title.fontColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height - 56)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Street carts. Store floors. No refunds."
        subtitle.fontSize = 13
        subtitle.fontColor = UIColor(white: 1, alpha: 0.6)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 82)
        addChild(subtitle)

        previewCart = SKNode()
        previewCart.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        previewCart.zPosition = 5
        addChild(previewCart)

        detailName = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        detailName.fontSize = 22
        detailName.fontColor = .white
        detailName.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
        addChild(detailName)

        detailTag = SKLabelNode(fontNamed: "AvenirNext-Medium")
        detailTag.fontSize = 13
        detailTag.fontColor = UIColor(white: 1, alpha: 0.75)
        detailTag.position = CGPoint(x: size.width / 2, y: size.height * 0.44)
        addChild(detailTag)

        detailStats = SKLabelNode(fontNamed: "AvenirNext-Bold")
        detailStats.fontSize = 12
        detailStats.fontColor = UIColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
        detailStats.position = CGPoint(x: size.width / 2, y: size.height * 0.40)
        addChild(detailStats)

        let roster = RacerProfile.roster
        let cardW: CGFloat = 72
        let spacing: CGFloat = 10
        let totalW = CGFloat(roster.count) * cardW + CGFloat(roster.count - 1) * spacing
        let startX = size.width / 2 - totalW / 2 + cardW / 2
        let y = size.height * 0.26

        for (i, profile) in roster.enumerated() {
            let card = makeCard(profile: profile, index: i, width: cardW)
            card.position = CGPoint(x: startX + CGFloat(i) * (cardW + spacing), y: y)
            card.name = "card-\(i)"
            addChild(card)
            cards.append(card)
        }

        let raceBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 52), cornerRadius: 12)
        raceBtn.fillColor = UIColor(red: 1, green: 0.78, blue: 0.15, alpha: 1)
        raceBtn.strokeColor = UIColor(white: 0.1, alpha: 1)
        raceBtn.lineWidth = 2
        raceBtn.position = CGPoint(x: size.width / 2, y: 56)
        raceBtn.name = "race"
        addChild(raceBtn)

        let raceText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        raceText.text = "LET'S ROLL"
        raceText.fontSize = 20
        raceText.fontColor = UIColor(white: 0.1, alpha: 1)
        raceText.verticalAlignmentMode = .center
        raceText.name = "race"
        raceBtn.addChild(raceText)

        let back = SKLabelNode(fontNamed: "AvenirNext-Bold")
        back.text = "← MENU"
        back.fontSize = 14
        back.fontColor = UIColor(white: 1, alpha: 0.7)
        back.horizontalAlignmentMode = .left
        back.position = CGPoint(x: 24, y: size.height - 40)
        back.name = "back"
        addChild(back)

        updateSelection()
    }

    private func makeCard(profile: RacerProfile, index: Int, width: CGFloat) -> SKNode {
        let node = SKNode()
        node.name = "card-\(index)"

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 88), cornerRadius: 10)
        bg.fillColor = UIColor(white: 0, alpha: 0.35)
        bg.strokeColor = UIColor(white: 1, alpha: 0.25)
        bg.lineWidth = 2
        bg.name = "card-\(index)"
        node.addChild(bg)

        let swatch = SKShapeNode(rectOf: CGSize(width: width - 16, height: 36), cornerRadius: 6)
        swatch.fillColor = profile.cartColor
        swatch.strokeColor = profile.accentColor
        swatch.lineWidth = 2
        swatch.position = CGPoint(x: 0, y: 16)
        swatch.name = "card-\(index)"
        node.addChild(swatch)

        let cargo = SKLabelNode(text: profile.cargo)
        cargo.fontSize = 18
        cargo.verticalAlignmentMode = .center
        cargo.position = swatch.position
        cargo.name = "card-\(index)"
        node.addChild(cargo)

        let short = SKLabelNode(fontNamed: "AvenirNext-Bold")
        short.text = profile.name.split(separator: " ").last.map(String.init) ?? profile.name
        short.fontSize = 10
        short.fontColor = .white
        short.verticalAlignmentMode = .center
        short.position = CGPoint(x: 0, y: -28)
        short.name = "card-\(index)"
        node.addChild(short)

        return node
    }

    private func updateSelection() {
        let profile = RacerProfile.roster[selectedIndex]
        detailName.text = profile.name
        detailTag.text = profile.tagline
        detailStats.text = String(
            format: "SPD %.0f%%   HDL %.0f%%",
            profile.speed * 100,
            profile.handling * 100
        )

        previewCart.removeAllChildren()
        let body = SKShapeNode(rectOf: CGSize(width: 56, height: 74), cornerRadius: 8)
        body.fillColor = profile.cartColor
        body.strokeColor = profile.accentColor
        body.lineWidth = 3
        previewCart.addChild(body)
        let cargo = SKLabelNode(text: profile.cargo)
        cargo.fontSize = 28
        cargo.verticalAlignmentMode = .center
        cargo.position = CGPoint(x: 0, y: 8)
        previewCart.addChild(cargo)
        previewCart.run(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.12)
        ]))

        for (i, card) in cards.enumerated() {
            let selected = i == selectedIndex
            card.alpha = selected ? 1 : 0.55
            card.setScale(selected ? 1.08 : 1.0)
            if let bg = card.children.first as? SKShapeNode {
                bg.strokeColor = selected ? UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1) : UIColor(white: 1, alpha: 0.25)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for node in nodes(at: loc) {
            if let name = node.name, name.hasPrefix("card-"),
               let idx = Int(name.replacingOccurrences(of: "card-", with: "")) {
                selectedIndex = idx
                updateSelection()
                return
            }
            if node.name == "race" || node.parent?.name == "race" {
                startRace()
                return
            }
            if node.name == "back" {
                let menu = MenuScene(size: size)
                menu.scaleMode = .resizeFill
                view?.presentScene(menu, transition: .fade(withDuration: 0.35))
                return
            }
        }
    }

    private func startRace() {
        let profile = RacerProfile.roster[selectedIndex]
        let race = GameScene(size: size, playerProfile: profile)
        race.scaleMode = .resizeFill
        view?.presentScene(race, transition: .doorsCloseHorizontal(withDuration: 0.45))
    }
}
