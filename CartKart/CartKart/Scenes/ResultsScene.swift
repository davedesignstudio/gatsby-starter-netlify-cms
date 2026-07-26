import SpriteKit

final class ResultsScene: SKScene {
    var finishOrder: [CartRacer] = []
    var raceTime: TimeInterval = 0
    private let track: TrackDefinition
    private let multiplayer: Bool
    var cupInterim: CupSession?

    init(size: CGSize, track: TrackDefinition = GameSettings.shared.selectedTrack, multiplayer: Bool = GameSettings.shared.playerMode == .localMultiplayer, cupInterim: CupSession? = nil) {
        self.track = track
        self.multiplayer = multiplayer
        self.cupInterim = cupInterim
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.track = .grocery
        self.multiplayer = false
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        buildResults()
    }

    private func buildResults() {
        let title = SKLabelNode(text: cupInterim != nil ? "CUP RACE \(cupInterim!.currentRaceIndex)/\(cupInterim!.cup.raceCount)" : "RACE RESULTS")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 36
        title.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height * 0.32)
        addChild(title)

        let humanRacers = finishOrder.filter(\.isPlayer)
        let playerPosition = humanRacers.first.map { finishOrder.firstIndex(of: $0).map { $0 + 1 } ?? finishOrder.count } ?? finishOrder.count
        let headline: String
        if multiplayer, humanRacers.count > 1 {
            let p1Pos = finishOrder.firstIndex(of: humanRacers[0]).map { $0 + 1 } ?? 4
            let p2Pos = finishOrder.firstIndex(of: humanRacers[1]).map { $0 + 1 } ?? 4
            headline = "P1: \(ordinal(p1Pos)) • P2: \(ordinal(p2Pos))"
        } else {
            switch playerPosition {
            case 1: headline = "🏆 Aisle Champion!"
            case 2: headline = "🥈 Runner-up Roller!"
            case 3: headline = "🥉 Third Wheel!"
            default: headline = "🛒 Better luck next shift!"
            }
        }

        let result = SKLabelNode(text: headline)
        result.fontName = "AvenirNext-DemiBold"
        result.fontSize = 22
        result.fontColor = .white
        result.position = CGPoint(x: 0, y: size.height * 0.32 - 48)
        addChild(result)

        for (index, racer) in finishOrder.enumerated() {
            let row = makeStandingRow(position: index + 1, racer: racer)
            row.position = CGPoint(x: 0, y: size.height * 0.14 - CGFloat(index) * 58)
            addChild(row)
        }

        let timeLabel = SKLabelNode(text: "Your time: \(formatTime(raceTime))")
        timeLabel.fontName = "AvenirNext-Medium"
        timeLabel.fontSize = 16
        timeLabel.fontColor = SKColor(white: 1, alpha: 0.7)
        timeLabel.position = CGPoint(x: 0, y: -size.height * 0.18)
        addChild(timeLabel)

        let menuButton = makeButton(text: "MAIN MENU", name: "menu")
        menuButton.position = CGPoint(x: 0, y: -size.height * 0.28)
        addChild(menuButton)

        let retryButton = makeButton(text: cupInterim != nil ? "NEXT RACE" : "RACE AGAIN", name: "retry")
        retryButton.position = CGPoint(x: 0, y: -size.height * 0.28 - 70)
        addChild(retryButton)

        if let session = cupInterim {
            let standings = session.sortedStandings.prefix(4).map { "\($0.name): \($0.points)" }.joined(separator: "  ")
            let cupLabel = SKLabelNode(text: "Cup pts — \(standings)")
            cupLabel.fontName = "AvenirNext-Medium"
            cupLabel.fontSize = 11
            cupLabel.fontColor = SKColor(white: 1, alpha: 0.55)
            cupLabel.position = CGPoint(x: 0, y: -size.height * 0.22)
            addChild(cupLabel)
        }
    }

    private func makeStandingRow(position: Int, racer: CartRacer) -> SKNode {
        let row = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 0.82, height: 46), cornerRadius: 10)
        bg.fillColor = racer.isPlayer
            ? SKColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.35)
            : SKColor(white: 1, alpha: 0.08)
        bg.strokeColor = racer.isPlayer ? SKColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.8) : SKColor(white: 1, alpha: 0.15)
        bg.lineWidth = 2
        row.addChild(bg)

        let positionLabel = SKLabelNode(text: ordinal(position))
        positionLabel.fontName = "AvenirNext-Heavy"
        positionLabel.fontSize = 20
        positionLabel.fontColor = .white
        positionLabel.horizontalAlignmentMode = .left
        positionLabel.position = CGPoint(x: -size.width * 0.36, y: -7)
        row.addChild(positionLabel)

        let nameLabel = SKLabelNode(text: racer.racerName)
        nameLabel.fontName = racer.isPlayer ? "AvenirNext-Bold" : "AvenirNext-Medium"
        nameLabel.fontSize = 18
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -size.width * 0.22, y: -7)
        row.addChild(nameLabel)

        let timeLabel = SKLabelNode(text: formatTime(racer.finishTime))
        timeLabel.fontName = "AvenirNext-Medium"
        timeLabel.fontSize = 14
        timeLabel.fontColor = SKColor(white: 1, alpha: 0.75)
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.position = CGPoint(x: size.width * 0.36, y: -7)
        row.addChild(timeLabel)

        return row
    }

    private func makeButton(text: String, name: String) -> SKNode {
        let button = SKNode()
        button.name = name

        let bg = SKShapeNode(rectOf: CGSize(width: 240, height: 50), cornerRadius: 12)
        bg.fillColor = name == "retry"
            ? SKColor(red: 0.18, green: 0.62, blue: 0.95, alpha: 1)
            : SKColor(white: 1, alpha: 0.12)
        bg.strokeColor = SKColor(white: 1, alpha: 0.3)
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

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let nodes = nodes(at: touch.location(in: self))

        if nodes.contains(where: { $0.name == "menu" }) {
            let menu = MenuScene(size: size)
            menu.scaleMode = .resizeFill
            view?.presentScene(menu, transition: SKTransition.crossFade(withDuration: 0.5))
        } else if nodes.contains(where: { $0.name == "retry" }) {
            if let session = cupInterim, GameSettings.shared.advanceCupOrFinish() {
                let nextTrack = session.currentTrack
                if GameSettings.shared.renderMode == .sceneKit3D {
                    NotificationCenter.default.post(name: .cartKartRenderModeChanged, object: nil)
                } else {
                    let game = GameScene(size: size, track: nextTrack, multiplayer: multiplayer)
                    game.scaleMode = .resizeFill
                    view?.presentScene(game, transition: SKTransition.doorsOpenVertical(withDuration: 0.5))
                }
            } else if GameSettings.shared.renderMode == .sceneKit3D {
                NotificationCenter.default.post(name: .cartKartRenderModeChanged, object: nil)
            } else {
                let game = GameScene(size: size, track: track, multiplayer: multiplayer)
                game.scaleMode = .resizeFill
                view?.presentScene(game, transition: SKTransition.doorsOpenVertical(withDuration: 0.5))
            }
        }
    }
}
