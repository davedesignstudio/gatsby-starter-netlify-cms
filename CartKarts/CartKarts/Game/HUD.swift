import SpriteKit

/// Screen-fixed UI. Added as a child of the camera, so (0,0) is screen center.
final class HUD: SKNode {
    private let positionLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let announceLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let itemIcon = SKSpriteNode()
    private let itemButton = SKSpriteNode(texture: TextureFactory.itemButton)
    private let leftArrow = SKSpriteNode(texture: TextureFactory.steerArrow(pointingLeft: true))
    private let rightArrow = SKSpriteNode(texture: TextureFactory.steerArrow(pointingLeft: false))
    private var resultsPanel: SKNode?
    private let size: CGSize

    /// Screen-space radius of the item button, for touch routing.
    var itemButtonCenter: CGPoint { itemButton.position }
    let itemButtonRadius: CGFloat = 75

    init(size: CGSize) {
        self.size = size
        super.init()
        zPosition = 1000

        positionLabel.fontSize = 46
        positionLabel.fontColor = .white
        positionLabel.horizontalAlignmentMode = .left
        positionLabel.verticalAlignmentMode = .top
        positionLabel.position = CGPoint(x: -size.width / 2 + 24, y: size.height / 2 - 20)
        addChild(positionLabel)

        lapLabel.fontSize = 34
        lapLabel.fontColor = .white
        lapLabel.horizontalAlignmentMode = .right
        lapLabel.verticalAlignmentMode = .top
        lapLabel.position = CGPoint(x: size.width / 2 - 24, y: size.height / 2 - 26)
        addChild(lapLabel)

        announceLabel.fontSize = 110
        announceLabel.fontColor = .white
        announceLabel.verticalAlignmentMode = .center
        announceLabel.position = CGPoint(x: 0, y: 40)
        announceLabel.alpha = 0
        addChild(announceLabel)

        leftArrow.position = CGPoint(x: -size.width / 2 + 95, y: -size.height / 2 + 80)
        rightArrow.position = CGPoint(x: size.width / 2 - 95, y: -size.height / 2 + 80)
        addChild(leftArrow)
        addChild(rightArrow)

        itemButton.position = CGPoint(x: 0, y: -size.height / 2 + 78)
        addChild(itemButton)
        itemIcon.alpha = 0
        itemButton.addChild(itemIcon)

        setItem(nil)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Race info

    func set(position: Int) {
        positionLabel.text = HUD.ordinal(position)
        positionLabel.fontColor = position == 1
            ? UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1) : .white
    }

    func set(lap: Int, totalLaps: Int) {
        lapLabel.text = "LAP \(min(lap, totalLaps))/\(totalLaps)"
    }

    func setItem(_ item: ItemKind?) {
        if let item = item {
            itemIcon.texture = item.icon
            itemIcon.size = item.icon.size()
            itemIcon.setScale(1.6)
            itemIcon.alpha = 1
            itemButton.alpha = 1
        } else {
            itemIcon.alpha = 0
            itemButton.alpha = 0.45
        }
    }

    func steeringFeedback(_ steer: CGFloat) {
        leftArrow.alpha = steer > 0.5 ? 1.0 : 0.55
        rightArrow.alpha = steer < -0.5 ? 1.0 : 0.55
    }

    // MARK: - Announcements (countdown, GO!, FINISH)

    func announce(_ text: String, color: UIColor, hold: TimeInterval = 0.55) {
        announceLabel.removeAllActions()
        announceLabel.text = text
        announceLabel.fontColor = color
        announceLabel.setScale(1.6)
        announceLabel.alpha = 1
        announceLabel.run(.sequence([
            .scale(to: 1.0, duration: 0.18),
            .wait(forDuration: hold),
            .group([.fadeOut(withDuration: 0.25), .scale(to: 0.7, duration: 0.25)]),
        ]))
    }

    // MARK: - Results

    struct ResultRow {
        let place: Int
        let name: String
        let detail: String
        let isPlayer: Bool
    }

    func showResults(_ rows: [ResultRow]) {
        hideResults()
        let panel = SKNode()
        panel.zPosition = 10

        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.72),
                               size: CGSize(width: size.width + 40, height: size.height + 40))
        panel.addChild(dim)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "RACE RESULTS"
        title.fontSize = 44
        title.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height / 2 - 80)
        panel.addChild(title)

        let rowHeight: CGFloat = 34
        let top = size.height / 2 - 130
        for row in rows {
            let label = SKLabelNode(fontNamed: row.isPlayer ? "AvenirNext-Heavy" : "AvenirNext-Bold")
            label.fontSize = 26
            label.fontColor = row.isPlayer ? UIColor(red: 0.4, green: 0.95, blue: 0.6, alpha: 1) : .white
            label.text = "\(HUD.ordinal(row.place))   \(row.name)\(row.isPlayer ? "  (YOU)" : "")   —   \(row.detail)"
            label.position = CGPoint(x: 0, y: top - CGFloat(row.place - 1) * rowHeight)
            panel.addChild(label)
        }

        let buttonY = -size.height / 2 + 70
        panel.addChild(HUD.button(text: "REMATCH", name: "btn-rematch",
                                  position: CGPoint(x: -140, y: buttonY),
                                  color: UIColor(red: 0.30, green: 0.72, blue: 0.40, alpha: 1)))
        panel.addChild(HUD.button(text: "GARAGE", name: "btn-garage",
                                  position: CGPoint(x: 140, y: buttonY),
                                  color: UIColor(red: 0.35, green: 0.50, blue: 0.85, alpha: 1)))

        panel.alpha = 0
        panel.run(.fadeIn(withDuration: 0.3))
        addChild(panel)
        resultsPanel = panel
    }

    func hideResults() {
        resultsPanel?.removeFromParent()
        resultsPanel = nil
    }

    static func button(text: String, name: String, position: CGPoint, color: UIColor,
                       size: CGSize = CGSize(width: 220, height: 62), fontSize: CGFloat = 28) -> SKNode {
        let shape = SKShapeNode(rectOf: size, cornerRadius: 14)
        shape.fillColor = color
        shape.strokeColor = UIColor(white: 1, alpha: 0.7)
        shape.lineWidth = 3
        shape.position = position
        shape.name = name
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        shape.addChild(label)
        return shape
    }

    static func ordinal(_ place: Int) -> String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }
}
