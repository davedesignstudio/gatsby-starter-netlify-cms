import SpriteKit
import UIKit

final class MenuScene: SKScene {
    private var titleLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!
    private var playButton: SKShapeNode!
    private var howLabel: SKLabelNode!
    private var cartPreview: [SKShapeNode] = []
    private var elapsed: TimeInterval = 0

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        buildBackground()
        buildUI()
        buildPreviewCarts()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutUI()
    }

    private func buildBackground() {
        // Store-floor gradient feel via layered shapes
        let floor = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
        floor.fillColor = UIColor(red: 0.72, green: 0.68, blue: 0.60, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -20
        floor.position = CGPoint(x: 0, y: -120)
        addChild(floor)

        for i in 0..<12 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 2000, height: 3))
            stripe.fillColor = UIColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 0.25)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: 0, y: -300 + CGFloat(i) * 55)
            stripe.zPosition = -19
            addChild(stripe)
        }

        let vignette = SKShapeNode(circleOfRadius: 420)
        vignette.fillColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 0.55)
        vignette.strokeColor = .clear
        vignette.setScale(2.2)
        vignette.zPosition = -10
        addChild(vignette)

        // Shelf silhouettes
        for x in [-220, 220] as [CGFloat] {
            let shelf = SKShapeNode(rectOf: CGSize(width: 90, height: 260), cornerRadius: 4)
            shelf.fillColor = UIColor(red: 0.40, green: 0.32, blue: 0.24, alpha: 0.85)
            shelf.strokeColor = UIColor(white: 0.1, alpha: 1)
            shelf.position = CGPoint(x: x, y: 40)
            shelf.zPosition = -5
            addChild(shelf)
        }
    }

    private func buildUI() {
        titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = "CARTKART"
        titleLabel.fontSize = 54
        titleLabel.fontColor = UIColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 10
        addChild(titleLabel)

        let brandGlow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        brandGlow.text = "CARTKART"
        brandGlow.fontSize = 54
        brandGlow.fontColor = UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 0.35)
        brandGlow.verticalAlignmentMode = .center
        brandGlow.position = CGPoint(x: 3, y: -3)
        brandGlow.zPosition = -1
        titleLabel.addChild(brandGlow)

        subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitleLabel.text = "Homeless Shopping Cart Racers"
        subtitleLabel.fontSize = 16
        subtitleLabel.fontColor = UIColor(white: 1, alpha: 0.85)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.zPosition = 10
        addChild(subtitleLabel)

        let tag = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tag.name = "tag"
        tag.text = "Tear through Mega Mart before security shows up"
        tag.fontSize = 13
        tag.fontColor = UIColor(white: 1, alpha: 0.55)
        tag.verticalAlignmentMode = .center
        tag.zPosition = 10
        addChild(tag)

        playButton = SKShapeNode(rectOf: CGSize(width: 220, height: 56), cornerRadius: 14)
        playButton.fillColor = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
        playButton.strokeColor = UIColor(white: 1, alpha: 0.5)
        playButton.lineWidth = 2
        playButton.name = "play"
        playButton.zPosition = 10

        let playText = SKLabelNode(fontNamed: "AvenirNext-Bold")
        playText.text = "START RACE"
        playText.fontSize = 22
        playText.fontColor = UIColor(white: 0.1, alpha: 1)
        playText.verticalAlignmentMode = .center
        playText.name = "play"
        playButton.addChild(playText)
        addChild(playButton)

        howLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        howLabel.text = "Steer ◀ ▶   •   Boost   •   Tap ITEM for power-ups"
        howLabel.fontSize = 12
        howLabel.fontColor = UIColor(white: 1, alpha: 0.45)
        howLabel.verticalAlignmentMode = .center
        howLabel.zPosition = 10
        addChild(howLabel)

        let roster = SKLabelNode(fontNamed: "AvenirNext-Medium")
        roster.name = "roster"
        roster.text = "Rusty  •  Tinny  •  Squeaky  •  Dumpster"
        roster.fontSize = 12
        roster.fontColor = UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.7)
        roster.verticalAlignmentMode = .center
        roster.zPosition = 10
        addChild(roster)

        layoutUI()

        // Idle pulse on play button
        playButton.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.7),
            SKAction.scale(to: 1.0, duration: 0.7)
        ])))
    }

    private func layoutUI() {
        titleLabel?.position = CGPoint(x: 0, y: size.height * 0.28)
        subtitleLabel?.position = CGPoint(x: 0, y: size.height * 0.28 - 44)
        childNode(withName: "tag")?.position = CGPoint(x: 0, y: size.height * 0.28 - 68)
        playButton?.position = CGPoint(x: 0, y: -size.height * 0.18)
        howLabel?.position = CGPoint(x: 0, y: -size.height * 0.18 - 50)
        childNode(withName: "roster")?.position = CGPoint(x: 0, y: -size.height * 0.18 - 78)
    }

    private func buildPreviewCarts() {
        let colors = RacerProfile.roster.map(\.cartColor)
        for (i, color) in colors.enumerated() {
            let cart = SKShapeNode(rectOf: CGSize(width: 28, height: 40), cornerRadius: 3)
            cart.fillColor = color
            cart.strokeColor = UIColor(white: 0.15, alpha: 1)
            cart.lineWidth = 1.5
            cart.zPosition = 5
            let x = CGFloat(i - 1) * 70 - 35
            cart.position = CGPoint(x: x, y: -20)
            addChild(cart)
            cartPreview.append(cart)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        elapsed = currentTime
        for (i, cart) in cartPreview.enumerated() {
            let bob = sin(currentTime * 3 + Double(i)) * 6
            let baseX = CGFloat(i - 1) * 70 - 35
            cart.position = CGPoint(x: baseX + CGFloat(sin(currentTime * 1.5 + Double(i))) * 8, y: -20 + CGFloat(bob))
            cart.zRotation = CGFloat(sin(currentTime * 2 + Double(i))) * 0.15
        }
        titleLabel?.zRotation = CGFloat(sin(currentTime * 1.2)) * 0.02
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        let node = atPoint(p)
        if node.name == "play" || node.parent?.name == "play" {
            playButton.run(SKAction.sequence([
                SKAction.scale(to: 0.92, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.08),
                SKAction.run { [weak self] in self?.startRace() }
            ]))
        }
    }

    private func startRace() {
        let race = RaceScene(size: size)
        race.scaleMode = .resizeFill
        view?.presentScene(race, transition: .doorsOpenVertical(withDuration: 0.55))
    }
}
