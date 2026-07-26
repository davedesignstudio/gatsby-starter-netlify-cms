import SpriteKit

final class MenuScene: SKScene {
    private var selectedTrackIndex = 0
    private var selectedModeIndex = 0
    private var selectedRenderIndex = 0
    private var selectedGameModeIndex = 0
    private var selectedCupIndex = 0
    private var selectedCharacterIndex = 0
    private var selectedCharacterP2Index = 1

    private var trackLabel: SKLabelNode!
    private var modeLabel: SKLabelNode!
    private var renderLabel: SKLabelNode!
    private var gameModeLabel: SKLabelNode!
    private var cupLabel: SKLabelNode!
    private var characterLabel: SKLabelNode!
    private var characterP2Label: SKLabelNode!
    private var gcStatusLabel: SKLabelNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1)
        loadSelections()
        buildBackground()
        buildTitle()
        buildOptions()
        buildButtons()
        runIntroAnimation()
        SoundManager.shared.startAmbience()
        GameCenterManager.shared.authenticate()

        NotificationCenter.default.addObserver(forName: .cartKartOnlineMatchReady, object: nil, queue: .main) { [weak self] _ in
            self?.applySettings()
            self?.transitionToGame()
        }
    }

    private func loadSelections() {
        let s = GameSettings.shared
        selectedTrackIndex = TrackDefinition.all.firstIndex(where: { $0.id == s.selectedTrack.id }) ?? 0
        selectedModeIndex = PlayerMode.allCases.firstIndex(of: s.playerMode) ?? 0
        selectedRenderIndex = RenderMode.allCases.firstIndex(of: s.renderMode) ?? 0
        selectedGameModeIndex = GameMode.allCases.firstIndex(of: s.gameMode) ?? 0
        selectedCupIndex = CupDefinition.all.firstIndex(where: { $0.id == s.selectedCup.id }) ?? 0
        selectedCharacterIndex = CharacterDefinition.all.firstIndex(where: { $0.id == s.selectedCharacter.id }) ?? 0
        selectedCharacterP2Index = CharacterDefinition.all.firstIndex(where: { $0.id == s.selectedCharacterP2.id }) ?? 1
    }

    private func buildBackground() {
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.5))
        floor.fillColor = SKColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: 0, y: -size.height * 0.15)
        floor.zPosition = -5
        addChild(floor)

        let cartPreview = makePreviewCart()
        cartPreview.position = CGPoint(x: 0, y: size.height * 0.22)
        cartPreview.setScale(1.1)
        cartPreview.name = "previewCart"
        addChild(cartPreview)
    }

    private func makePreviewCart() -> SKNode {
        let character = CharacterDefinition.all[selectedCharacterIndex]
        let node = SKNode()
        let cart = SKShapeNode(rectOf: CGSize(width: 70, height: 50), cornerRadius: 8)
        cart.fillColor = character.cartColor
        cart.strokeColor = .darkGray
        cart.lineWidth = 3
        node.addChild(cart)

        let rider = SKShapeNode(circleOfRadius: 16)
        rider.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1)
        rider.position = CGPoint(x: 0, y: 28)
        node.addChild(rider)

        let beanie = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 4)
        beanie.fillColor = character.bodyColor
        beanie.position = CGPoint(x: 0, y: 40)
        node.addChild(beanie)

        let emoji = SKLabelNode(text: character.emoji)
        emoji.fontSize = 22
        emoji.position = CGPoint(x: 0, y: 55)
        node.addChild(emoji)

        return node
    }

    private func buildTitle() {
        let title = SKLabelNode(text: "CART KART")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 44
        title.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height * 0.38)
        title.name = "title"
        addChild(title)
    }

    private func buildOptions() {
        var y = size.height * 0.08
        gameModeLabel = makeOptionLabel(name: "gamemode", y: y); y -= 44
        characterLabel = makeOptionLabel(name: "character", y: y); y -= 44
        characterP2Label = makeOptionLabel(name: "characterp2", y: y); y -= 44
        cupLabel = makeOptionLabel(name: "cup", y: y); y -= 44
        trackLabel = makeOptionLabel(name: "track", y: y); y -= 44
        modeLabel = makeOptionLabel(name: "mode", y: y); y -= 44
        renderLabel = makeOptionLabel(name: "render", y: y); y -= 44
        gcStatusLabel = makeOptionLabel(name: "gcstatus", y: y)
        updateOptionLabels()
    }

    private func makeOptionLabel(name: String, y: CGFloat) -> SKLabelNode {
        let row = SKNode()
        row.name = name
        row.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 310, height: 38), cornerRadius: 9)
        bg.fillColor = SKColor(white: 1, alpha: 0.08)
        bg.strokeColor = SKColor(white: 1, alpha: 0.2)
        bg.lineWidth = 1.5
        bg.name = name
        row.addChild(bg)

        let label = SKLabelNode(text: "")
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        row.addChild(label)

        addChild(row)
        return label
    }

    private func updateOptionLabels() {
        let isCup = GameMode.allCases[selectedGameModeIndex] == .cup
        let is2P = PlayerMode.allCases[selectedModeIndex] == .localMultiplayer
        let isOnline = PlayerMode.allCases[selectedModeIndex] == .onlineMultiplayer

        gameModeLabel.text = "Mode: \(GameMode.allCases[selectedGameModeIndex].rawValue)"
        characterLabel.text = "P1: \(CharacterDefinition.all[selectedCharacterIndex].emoji) \(CharacterDefinition.all[selectedCharacterIndex].name)"
        characterP2Label.text = "P2: \(CharacterDefinition.all[selectedCharacterP2Index].emoji) \(CharacterDefinition.all[selectedCharacterP2Index].name)"
        characterP2Label.parent?.isHidden = !is2P

        cupLabel.text = "Cup: \(CupDefinition.all[selectedCupIndex].emoji) \(CupDefinition.all[selectedCupIndex].name)"
        cupLabel.parent?.isHidden = !isCup

        let track = TrackDefinition.all[selectedTrackIndex]
        trackLabel.text = "Track: \(track.emoji) \(track.name)"
        trackLabel.parent?.isHidden = isCup

        modeLabel.text = "Players: \(PlayerMode.allCases[selectedModeIndex].rawValue)"
        renderLabel.text = "Graphics: \(RenderMode.allCases[selectedRenderIndex].rawValue)"
        gcStatusLabel.text = "GC: \(GameCenterManager.shared.matchStatus)"

        childNode(withName: "previewCart")?.removeFromParent()
        let preview = makePreviewCart()
        preview.position = CGPoint(x: 0, y: size.height * 0.22)
        preview.setScale(1.1)
        preview.name = "previewCart"
        preview.zPosition = 1
        addChild(preview)
    }

    private func buildButtons() {
        let play = makeButton(text: "START RACE", name: "play", y: -size.height * 0.22, primary: true)
        addChild(play)

        let online = makeButton(text: "FIND ONLINE MATCH", name: "online", y: -size.height * 0.22 - 56, primary: false)
        addChild(online)

        let howTo = makeButton(text: "HOW TO PLAY", name: "howto", y: -size.height * 0.22 - 112, primary: false)
        addChild(howTo)

        let credits = SKLabelNode(text: "6 tracks • 5 characters • cups • 3D • Game Center")
        credits.fontName = "AvenirNext-Regular"
        credits.fontSize = 11
        credits.fontColor = SKColor(white: 1, alpha: 0.45)
        credits.position = CGPoint(x: 0, y: -size.height * 0.42)
        addChild(credits)
    }

    private func makeButton(text: String, name: String, y: CGFloat, primary: Bool) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 46), cornerRadius: 12)
        bg.fillColor = primary
            ? SKColor(red: 0.18, green: 0.62, blue: 0.95, alpha: 1)
            : SKColor(white: 1, alpha: 0.1)
        bg.strokeColor = SKColor(white: 1, alpha: 0.3)
        bg.lineWidth = 2
        bg.name = name
        button.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }

    private func runIntroAnimation() {
        childNode(withName: "previewCart")?.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 20, y: 0, duration: 1.0),
            SKAction.moveBy(x: -20, y: 0, duration: 1.0)
        ])))
        childNode(withName: "title")?.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))

        if nodes.contains(where: { $0.name == "play" }) {
            SoundManager.shared.play(.menuTap)
            applySettings()
            transitionToGame()
        } else if nodes.contains(where: { $0.name == "online" }) {
            SoundManager.shared.play(.menuTap)
            applySettings()
            GameSettings.shared.playerMode = .onlineMultiplayer
            GameCenterManager.shared.findMatch()
        } else if nodes.contains(where: { $0.name == "howto" }) {
            showHowToPlay()
        } else if nodes.contains(where: { $0.name == "gamemode" }) {
            selectedGameModeIndex = (selectedGameModeIndex + 1) % GameMode.allCases.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "character" }) {
            selectedCharacterIndex = (selectedCharacterIndex + 1) % CharacterDefinition.all.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "characterp2" }) {
            selectedCharacterP2Index = (selectedCharacterP2Index + 1) % CharacterDefinition.all.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "cup" }) {
            selectedCupIndex = (selectedCupIndex + 1) % CupDefinition.all.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "track" }) {
            selectedTrackIndex = (selectedTrackIndex + 1) % TrackDefinition.all.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "mode" }) {
            selectedModeIndex = (selectedModeIndex + 1) % PlayerMode.allCases.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        } else if nodes.contains(where: { $0.name == "render" }) {
            selectedRenderIndex = (selectedRenderIndex + 1) % RenderMode.allCases.count
            updateOptionLabels(); SoundManager.shared.play(.menuTap)
        }
    }

    private func applySettings() {
        let s = GameSettings.shared
        s.gameMode = GameMode.allCases[selectedGameModeIndex]
        s.selectedCharacter = CharacterDefinition.all[selectedCharacterIndex]
        s.selectedCharacterP2 = CharacterDefinition.all[selectedCharacterP2Index]
        s.selectedCup = CupDefinition.all[selectedCupIndex]
        s.selectedTrack = TrackDefinition.all[selectedTrackIndex]
        s.playerMode = PlayerMode.allCases[selectedModeIndex]
        s.renderMode = RenderMode.allCases[selectedRenderIndex]

        if s.gameMode == .cup {
            s.beginCup(s.selectedCup)
        } else {
            s.cupSession = nil
        }
    }

    private func transitionToGame() {
        SoundManager.shared.stopAmbience()
        if GameSettings.shared.renderMode == .sceneKit3D {
            NotificationCenter.default.post(name: .cartKartRenderModeChanged, object: nil)
            return
        }

        let track = GameSettings.shared.cupSession?.currentTrack ?? GameSettings.shared.selectedTrack
        let scene = GameScene(
            size: size,
            track: track,
            multiplayer: GameSettings.shared.playerMode == .localMultiplayer
        )
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: SKTransition.doorsOpenHorizontal(withDuration: 0.6))
    }

    private func showHowToPlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.9, height: 400), cornerRadius: 18)
        overlay.fillColor = SKColor(white: 0.05, alpha: 0.94)
        overlay.strokeColor = SKColor(white: 1, alpha: 0.25)
        overlay.lineWidth = 2
        overlay.name = "overlay"
        overlay.zPosition = 100
        addChild(overlay)

        let lines = [
            "🕹️ P1: left stick + right buttons",
            "🕹️ P2: right stick + left buttons",
            "🏆 Cup Mode: championship across multiple tracks",
            "👤 Characters have unique speed/handling stats",
            "🌐 Online: Game Center matchmaking",
            "🧊 6 tracks including Bakery, Liquor, Midnight",
            "🎵 Race theme + aisle ambience audio",
            "🎮 2D Classic or 3D Aisles graphics"
        ]

        for (index, line) in lines.enumerated() {
            let label = SKLabelNode(text: line)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = 13
            label.fontColor = .white
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: -size.width * 0.38, y: 120 - CGFloat(index) * 26)
            label.zPosition = 101
            label.name = "overlay"
            addChild(label)
        }

        let dismiss = SKLabelNode(text: "Tap anywhere to close")
        dismiss.fontName = "AvenirNext-DemiBold"
        dismiss.fontSize = 13
        dismiss.fontColor = SKColor(white: 1, alpha: 0.55)
        dismiss.position = CGPoint(x: 0, y: -170)
        dismiss.zPosition = 101
        dismiss.name = "overlay"
        addChild(dismiss)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        childNode(withName: "overlay")?.removeFromParent()
        enumerateChildNodes(withName: "overlay") { node, _ in node.removeFromParent() }
    }
}
