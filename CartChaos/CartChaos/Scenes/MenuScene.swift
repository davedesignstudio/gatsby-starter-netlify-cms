import SpriteKit
import UIKit

final class MenuScene: SKScene {
    private var selectedCart: CartArchetype = .speedy
    private var cartButtons: [SKLabelNode] = []
    private var previewNode: SKNode?
    private var taglineLabel: SKLabelNode?

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1)
        removeAllChildren()
        buildAtmosphere()
        buildTitle()
        buildCartPicker()
        buildStartButton()
        updatePreview()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil else { return }
        didMove(to: view!)
    }

    private func buildAtmosphere() {
        let floor = SKSpriteNode(color: UIColor(red: 0.22, green: 0.26, blue: 0.22, alpha: 1), size: CGSize(width: size.width, height: size.height * 0.45))
        floor.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        floor.zPosition = -2
        addChild(floor)

        for i in 0..<8 {
            let stripe = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.35), size: CGSize(width: 18, height: size.height * 0.45))
            stripe.position = CGPoint(x: CGFloat(i) * (size.width / 7.0), y: size.height * 0.22)
            stripe.zRotation = -.pi / 2.4
            stripe.zPosition = -1
            addChild(stripe)
        }

        let shelfL = SKSpriteNode(color: UIColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1), size: CGSize(width: size.width * 0.18, height: size.height))
        shelfL.anchorPoint = CGPoint(x: 0, y: 0.5)
        shelfL.position = CGPoint(x: 0, y: size.height / 2)
        shelfL.zPosition = -1
        addChild(shelfL)

        let shelfR = SKSpriteNode(color: UIColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1), size: CGSize(width: size.width * 0.18, height: size.height))
        shelfR.anchorPoint = CGPoint(x: 1, y: 0.5)
        shelfR.position = CGPoint(x: size.width, y: size.height / 2)
        shelfR.zPosition = -1
        addChild(shelfR)

        for side in [0.08, 0.92] as [CGFloat] {
            for row in 0..<5 {
                let can = SKShapeNode(rectOf: CGSize(width: 22, height: 28), cornerRadius: 4)
                can.fillColor = [UIColor.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemTeal][row]
                can.strokeColor = .clear
                can.position = CGPoint(x: size.width * side, y: size.height * (0.25 + CGFloat(row) * 0.12))
                can.zPosition = 0
                addChild(can)
            }
        }
    }

    private func buildTitle() {
        let brand = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        brand.text = "CART CHAOS"
        brand.fontSize = min(54, size.width * 0.08)
        brand.fontColor = UIColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1)
        brand.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        brand.zPosition = 10
        addChild(brand)

        brand.run(.repeatForever(.sequence([
            .scale(to: 1.04, duration: 0.7),
            .scale(to: 1.0, duration: 0.7)
        ])))

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Aisle Racers"
        subtitle.fontSize = min(26, size.width * 0.04)
        subtitle.fontColor = UIColor(white: 0.92, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.74)
        subtitle.zPosition = 10
        addChild(subtitle)

        let blurb = SKLabelNode(fontNamed: "AvenirNext-Regular")
        blurb.text = "Rogue shopping carts. One MegaMart. Three laps of aisle mayhem."
        blurb.fontSize = min(14, size.width * 0.025)
        blurb.fontColor = UIColor(white: 0.75, alpha: 1)
        blurb.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        blurb.zPosition = 10
        addChild(blurb)
    }

    private func buildCartPicker() {
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = "PICK YOUR CART"
        title.fontSize = 16
        title.fontColor = UIColor(white: 0.85, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        title.zPosition = 10
        addChild(title)

        let names = CartArchetype.allCases
        let spacing = min(110, size.width * 0.16)
        let startX = size.width / 2 - spacing * CGFloat(names.count - 1) / 2

        for (i, cart) in names.enumerated() {
            let button = SKLabelNode(fontNamed: "AvenirNext-Bold")
            button.text = cart.displayName.uppercased()
            button.fontSize = 13
            button.fontColor = cart == selectedCart ? cart.accent : UIColor(white: 0.7, alpha: 1)
            button.position = CGPoint(x: startX + CGFloat(i) * spacing, y: size.height * 0.52)
            button.name = "cart_\(cart.rawValue)"
            button.zPosition = 10
            addChild(button)
            cartButtons.append(button)
        }

        taglineLabel = SKLabelNode(fontNamed: "AvenirNext-Italic")
        taglineLabel?.fontSize = 13
        taglineLabel?.fontColor = UIColor(white: 0.8, alpha: 1)
        taglineLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.46)
        taglineLabel?.zPosition = 10
        if let taglineLabel { addChild(taglineLabel) }
    }

    private func buildStartButton() {
        let go = SKShapeNode(rectOf: CGSize(width: 220, height: 52), cornerRadius: 10)
        go.fillColor = UIColor(red: 0.92, green: 0.55, blue: 0.12, alpha: 1)
        go.strokeColor = UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1)
        go.lineWidth = 2
        go.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        go.name = "start"
        go.zPosition = 20
        addChild(go)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "START RACE"
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = "start"
        go.addChild(label)

        go.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.55),
            .moveBy(x: 0, y: -4, duration: 0.55)
        ])))

        let help = SKLabelNode(fontNamed: "AvenirNext-Regular")
        help.text = "Steer with left / right • Hold GAS • Tap USE for power-ups"
        help.fontSize = 11
        help.fontColor = UIColor(white: 0.65, alpha: 1)
        help.position = CGPoint(x: size.width / 2, y: size.height * 0.06)
        help.zPosition = 10
        addChild(help)
    }

    private func updatePreview() {
        previewNode?.removeFromParent()
        let preview = CartArt.makeCart(archetype: selectedCart, scale: 1.35)
        preview.position = CGPoint(x: size.width / 2, y: size.height * 0.32)
        preview.zPosition = 15
        preview.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.08, duration: 0.5),
            .rotate(byAngle: -0.16, duration: 1.0),
            .rotate(byAngle: 0.08, duration: 0.5)
        ])))
        addChild(preview)
        previewNode = preview
        taglineLabel?.text = selectedCart.tagline

        for button in cartButtons {
            let name = button.name?.replacingOccurrences(of: "cart_", with: "") ?? ""
            if name == selectedCart.rawValue {
                button.fontColor = selectedCart.accent
                button.fontSize = 15
            } else {
                button.fontColor = UIColor(white: 0.7, alpha: 1)
                button.fontSize = 13
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)

        for node in nodes {
            guard let name = node.name else { continue }
            if name == "start" {
                startRace()
                return
            }
            if name.hasPrefix("cart_"),
               let cart = CartArchetype(rawValue: String(name.dropFirst(5))) {
                selectedCart = cart
                updatePreview()
                return
            }
        }
    }

    private func startRace() {
        let race = GameScene(size: size)
        race.scaleMode = .resizeFill
        race.playerCart = selectedCart
        view?.presentScene(race, transition: .fade(with: .black, duration: 0.45))
    }
}
