import SpriteKit

final class MenuScene: SKScene {
    private var selectedTrackIndex = 0
    private var selectedModeIndex = 0
    private var selectedRenderIndex = 0
    private var trackLabel: SKLabelNode!
    private var modeLabel: SKLabelNode!
    private var renderLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1)
        selectedTrackIndex = TrackDefinition.all.firstIndex(where: { $0.id == GameSettings.shared.selectedTrack.id }) ?? 0
        selectedModeIndex = PlayerMode.allCases.firstIndex(of: GameSettings.shared.playerMode) ?? 0
        selectedRenderIndex = RenderMode.allCases.firstIndex(of: GameSettings.shared.renderMode) ?? 0
        buildBackground()
        buildTitle()
        buildOptions()
        buildButtons()
        runIntroAnimation()
    }

    private func buildBackground() {
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.45))
        floor.fillColor = SKColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: 0, y: -size.height * 0.2)
        floor.zPosition = -5
        addChild(floor)

        for index in 0..<6 {
            let aisle = SKShapeNode(rectOf: CGSize(width: size.width, height: 18))
            aisle.fillColor = SKColor(white: 0.9, alpha: 0.25)
            aisle.strokeColor = .clear
            aisle.position = CGPoint(x: 0, y: -size.height * 0.35 + CGFloat(index) * 36)
            aisle.zPosition = -4
            addChild(aisle)
        }

        let cartPreview = makePreviewCart()
        cartPreview.position = CGPoint(x: 0, y: 60)
        cartPreview.setScale(1.2)
        cartPreview.name = "previewCart"
        addChild(cartPreview)
    }

    private func makePreviewCart() -> SKNode {
        let node = SKNode()
        let cart = SKShapeNode(rectOf: CGSize(width: 70, height: 50), cornerRadius: 8)
        cart.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
        cart.strokeColor = .darkGray
        cart.lineWidth = 3
        node.addChild(cart)

        let rider = SKShapeNode(circleOfRadius: 16)
        rider.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1)
        rider.position = CGPoint(x: 0, y: 28)
        node.addChild(rider)

        let beanie = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 4)
        beanie.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        beanie.position = CGPoint(x: 0, y: 40)
        node.addChild(beanie)

        return node
    }

    private func buildTitle() {
        let title = SKLabelNode(text: "CART KART")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 48
        title.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height * 0.34)
        title.name = "title"
        addChild(title)

        let subtitle = SKLabelNode(text: "Grocery Gauntlet")
        subtitle.fontName = "AvenirNext-DemiBold"
        subtitle.fontSize = 20
        subtitle.fontColor = SKColor(red: 0.85, green: 0.9, blue: 0.95, alpha: 1)
        subtitle.position = CGPoint(x: 0, y: size.height * 0.34 - 40)
        addChild(subtitle)
    }

    private func buildOptions() {
        trackLabel = makeOptionLabel(name: "track", y: size.height * 0.14)
        modeLabel = makeOptionLabel(name: "mode", y: size.height * 0.14 - 52)
        renderLabel = makeOptionLabel(name: "render", y: size.height * 0.14 - 104)
        updateOptionLabels()
    }

    private func makeOptionLabel(name: String, y: CGFloat) -> SKLabelNode {
        let row = SKNode()
        row.name = name
        row.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 300, height: 42), cornerRadius: 10)
        bg.fillColor = SKColor(white: 1, alpha: 0.08)
        bg.strokeColor = SKColor(white: 1, alpha: 0.2)
        bg.lineWidth = 1.5
        bg.name = name
        row.addChild(bg)

        let label = SKLabelNode(text: "")
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        row.addChild(label)

        addChild(row)
        return label
    }

    private func updateOptionLabels() {
        let track = TrackDefinition.all[selectedTrackIndex]
        trackLabel.text = "Track: \(track.emoji) \(track.name)"
        modeLabel.text = "Players: \(PlayerMode.allCases[selectedModeIndex].rawValue)"
        renderLabel.text = "Graphics: \(RenderMode.allCases[selectedRenderIndex].rawValue)"
    }

    private func buildButtons() {
        let play = makeButton(text: "START RACE", name: "play", y: -size.height * 0.08)
        addChild(play)

        let howTo = makeButton(text: "HOW TO PLAY", name: "howto", y: -size.height * 0.08 - 62)
        addChild(howTo)

        let credits = SKLabelNode(text: "3 tracks • 2-player • 2D + 3D modes")
        credits.fontName = "AvenirNext-Regular"
        credits.fontSize = 12
        credits.fontColor = SKColor(white: 1, alpha: 0.45)
        credits.position = CGPoint(x: 0, y: -size.height * 0.38)
        addChild(credits)
    }

    private func makeButton(text: String, name: String, y: CGFloat) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 260, height: 50), cornerRadius: 14)
        bg.fillColor = name == "play"
            ? SKColor(red: 0.18, green: 0.62, blue: 0.95, alpha: 1)
            : SKColor(white: 1, alpha: 0.12)
        bg.strokeColor = SKColor(white: 1, alpha: 0.35)
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

    private func runIntroAnimation() {
        let move = SKAction.sequence([
            SKAction.moveBy(x: 30, y: 0, duration: 1.2),
            SKAction.moveBy(x: -30, y: 0, duration: 1.2)
        ])
        childNode(withName: "previewCart")?.run(SKAction.repeatForever(move))

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        childNode(withName: "title")?.run(SKAction.repeatForever(pulse))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))

        if nodes.contains(where: { $0.name == "play" }) {
            SoundManager.shared.play(.menuTap)
            applySettings()
            transitionToGame()
        } else if nodes.contains(where: { $0.name == "howto" }) {
            showHowToPlay()
        } else if nodes.contains(where: { $0.name == "track" }) {
            cycleTrack()
        } else if nodes.contains(where: { $0.name == "mode" }) {
            cycleMode()
        } else if nodes.contains(where: { $0.name == "render" }) {
            cycleRenderMode()
        }
    }

    private func cycleTrack() {
        selectedTrackIndex = (selectedTrackIndex + 1) % TrackDefinition.all.count
        updateOptionLabels()
        SoundManager.shared.play(.menuTap)
    }

    private func cycleMode() {
        selectedModeIndex = (selectedModeIndex + 1) % PlayerMode.allCases.count
        updateOptionLabels()
        SoundManager.shared.play(.menuTap)
    }

    private func cycleRenderMode() {
        selectedRenderIndex = (selectedRenderIndex + 1) % RenderMode.allCases.count
        updateOptionLabels()
        SoundManager.shared.play(.menuTap)
    }

    private func applySettings() {
        GameSettings.shared.selectedTrack = TrackDefinition.all[selectedTrackIndex]
        GameSettings.shared.playerMode = PlayerMode.allCases[selectedModeIndex]
        GameSettings.shared.renderMode = RenderMode.allCases[selectedRenderIndex]
        NotificationCenter.default.post(name: .cartKartRenderModeChanged, object: nil)
    }

    private func transitionToGame() {
        if GameSettings.shared.renderMode == .sceneKit3D {
            NotificationCenter.default.post(name: .cartKartRenderModeChanged, object: nil)
            return
        }

        let scene = GameScene(
            size: size,
            track: GameSettings.shared.selectedTrack,
            multiplayer: GameSettings.shared.playerMode == .localMultiplayer
        )
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: SKTransition.doorsOpenHorizontal(withDuration: 0.6))
    }

    private func showHowToPlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.86, height: 380), cornerRadius: 18)
        overlay.fillColor = SKColor(white: 0.05, alpha: 0.92)
        overlay.strokeColor = SKColor(white: 1, alpha: 0.25)
        overlay.lineWidth = 2
        overlay.position = CGPoint(x: 0, y: 0)
        overlay.name = "overlay"
        overlay.zPosition = 100
        addChild(overlay)

        let lines = [
            "🕹️ P1: left stick + right buttons",
            "🕹️ P2: right stick + left buttons (2P mode)",
            "🟢 GO: accelerate  🟠 DRIFT: corner slide",
            "🟣 ITEM: use power-up",
            "🏁 Complete 3 laps on any track",
            "🧊 Tracks: Grocery, Frozen Fury, Produce Pit",
            "🎮 Modes: 2D Classic or 3D Aisles"
        ]

        for (index, line) in lines.enumerated() {
            let label = SKLabelNode(text: line)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = 14
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -size.width * 0.36, y: 110 - CGFloat(index) * 28)
            label.zPosition = 101
            label.name = "overlay"
            addChild(label)
        }

        let dismiss = SKLabelNode(text: "Tap anywhere to close")
        dismiss.fontName = "AvenirNext-DemiBold"
        dismiss.fontSize = 13
        dismiss.fontColor = SKColor(white: 1, alpha: 0.55)
        dismiss.position = CGPoint(x: 0, y: -150)
        dismiss.zPosition = 101
        dismiss.name = "overlay"
        addChild(dismiss)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        childNode(withName: "overlay")?.removeFromParent()
        enumerateChildNodes(withName: "overlay") { node, _ in node.removeFromParent() }
    }
}
