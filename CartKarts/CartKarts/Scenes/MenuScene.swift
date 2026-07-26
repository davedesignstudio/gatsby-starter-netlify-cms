import SpriteKit

final class MenuScene: SKScene {
    private var selectedIndex: Int {
        didSet { UserDefaults.standard.set(selectedIndex, forKey: "selectedCart") }
    }
    private let selectionRing = SKShapeNode(circleOfRadius: 62)
    private var cartNodes: [SKNode] = []
    private var statsNode: SKNode?

    override init(size: CGSize) {
        let saved = UserDefaults.standard.integer(forKey: "selectedCart")
        selectedIndex = (0..<CartCharacter.roster.count).contains(saved) ? saved : 0
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1)
        addFloatingJunk()
        addTitle()
        addRoster()
        addChild(HUD.button(text: "START RACE", name: "btn-start",
                            position: CGPoint(x: size.width / 2, y: 66),
                            color: UIColor(red: 0.85, green: 0.30, blue: 0.28, alpha: 1),
                            size: CGSize(width: 280, height: 66), fontSize: 30))
        select(index: selectedIndex)
    }

    private func addTitle() {
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = "CART KARTS"
        shadow.fontSize = 76
        shadow.fontColor = UIColor(red: 0.55, green: 0.15, blue: 0.15, alpha: 1)
        shadow.position = CGPoint(x: size.width / 2 + 4, y: size.height - 96)
        addChild(shadow)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "CART KARTS"
        title.fontSize = 76
        title.fontColor = UIColor(red: 0.98, green: 0.83, blue: 0.25, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height - 92)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        subtitle.text = "MIDNIGHT AT THE MEGAMART · 3 LAPS · 6 RUNAWAY CARTS"
        subtitle.fontSize = 20
        subtitle.fontColor = UIColor(white: 1, alpha: 0.75)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 128)
        addChild(subtitle)
    }

    private func addRoster() {
        selectionRing.strokeColor = UIColor(red: 0.98, green: 0.83, blue: 0.25, alpha: 1)
        selectionRing.lineWidth = 5
        selectionRing.fillColor = UIColor(white: 1, alpha: 0.06)
        addChild(selectionRing)

        let roster = CartCharacter.roster
        let spacing = min(size.width / CGFloat(roster.count + 1), 165)
        let startX = size.width / 2 - spacing * CGFloat(roster.count - 1) / 2
        let y = size.height * 0.55

        for (index, character) in roster.enumerated() {
            let container = SKNode()
            container.position = CGPoint(x: startX + CGFloat(index) * spacing, y: y)
            container.name = "cart-\(index)"

            let sprite = SKSpriteNode(texture: TextureFactory.cart(color: character.color,
                                                                   name: character.name))
            sprite.size = CGSize(width: 56, height: 84)
            sprite.name = "cart-\(index)"
            sprite.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.8 + Double(index) * 0.07),
                .moveBy(x: 0, y: -6, duration: 0.8 + Double(index) * 0.07),
            ])))
            container.addChild(sprite)

            let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
            name.text = character.name
            name.fontSize = 17
            name.fontColor = .white
            name.position = CGPoint(x: 0, y: -72)
            name.name = "cart-\(index)"
            container.addChild(name)

            addChild(container)
            cartNodes.append(container)
        }
    }

    private func select(index: Int) {
        selectedIndex = index
        let character = CartCharacter.roster[index]
        selectionRing.position = cartNodes[index].position

        statsNode?.removeFromParent()
        let stats = SKNode()
        let centerY = size.height * 0.30

        let bio = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        bio.text = "“\(character.bio)”"
        bio.fontSize = 19
        bio.fontColor = UIColor(white: 1, alpha: 0.85)
        bio.position = CGPoint(x: size.width / 2, y: centerY + 22)
        stats.addChild(bio)

        // Stat bars normalized against the roster extremes.
        let entries: [(String, CGFloat)] = [
            ("SPEED", (character.topSpeed - 560) / 120),
            ("PUSH", (character.acceleration - 1.4) / 1.4),
            ("GRIP", (character.steering - 2.7) / 1.4),
        ]
        let barWidth: CGFloat = 130
        let totalWidth = CGFloat(entries.count) * (barWidth + 60)
        var x = size.width / 2 - totalWidth / 2 + 30
        for (label, value) in entries {
            let text = SKLabelNode(fontNamed: "AvenirNext-Bold")
            text.text = label
            text.fontSize = 15
            text.fontColor = UIColor(white: 1, alpha: 0.6)
            text.horizontalAlignmentMode = .left
            text.position = CGPoint(x: x, y: centerY - 24)
            stats.addChild(text)

            let back = SKShapeNode(rect: CGRect(x: x + 58, y: centerY - 25, width: barWidth, height: 12),
                                   cornerRadius: 6)
            back.fillColor = UIColor(white: 1, alpha: 0.15)
            back.strokeColor = .clear
            stats.addChild(back)

            let fill = SKShapeNode(rect: CGRect(x: x + 58, y: centerY - 25,
                                                width: barWidth * clamp(value, 0.1, 1), height: 12),
                                   cornerRadius: 6)
            fill.fillColor = character.color
            fill.strokeColor = .clear
            stats.addChild(fill)

            x += barWidth + 60
        }

        addChild(stats)
        statsNode = stats
    }

    private func addFloatingJunk() {
        let textures = [TextureFactory.banana, TextureFactory.soupCan,
                        TextureFactory.colaCan, TextureFactory.itemBag]
        var rng = SeededRandom(seed: 5)
        for i in 0..<10 {
            let sprite = SKSpriteNode(texture: textures[i % textures.count])
            sprite.position = CGPoint(x: rng.range(30, size.width - 30),
                                      y: rng.range(30, size.height - 30))
            sprite.alpha = 0.16
            sprite.setScale(rng.range(1.0, 2.0))
            sprite.zPosition = -10
            sprite.run(.repeatForever(.rotate(byAngle: .pi * 2,
                                              duration: Double(rng.range(8, 20)))))
            addChild(sprite)
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let tapped = nodes(at: touch.location(in: self)).compactMap { $0.name }

        if tapped.contains("btn-start") {
            startRace()
            return
        }
        for name in tapped where name.hasPrefix("cart-") {
            if let index = Int(name.dropFirst(5)), index < CartCharacter.roster.count {
                select(index: index)
                return
            }
        }
    }

    private func startRace() {
        guard let view = view else { return }
        let scene = RaceScene(size: view.bounds.size, playerCharacterIndex: selectedIndex)
        view.presentScene(scene, transition: .doorsOpenHorizontal(withDuration: 0.7))
    }
}
