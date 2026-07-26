import SpriteKit

final class HUDNode: SKNode {
    private let placeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let itemLabel = SKLabelNode(fontNamed: "AppleColorEmoji")
    private let itemBg = SKShapeNode(rectOf: CGSize(width: 64, height: 64), cornerRadius: 12)
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let boostMeterBg = SKShapeNode(rectOf: CGSize(width: 120, height: 12), cornerRadius: 4)
    private let boostMeterFill = SKShapeNode(rectOf: CGSize(width: 120, height: 12), cornerRadius: 4)
    private var screenSize: CGSize = .zero

    func setup(size: CGSize) {
        screenSize = size
        zPosition = 500
        removeAllChildren()

        placeLabel.fontSize = 28
        placeLabel.fontColor = GameTheme.hudCream
        placeLabel.horizontalAlignmentMode = .left
        placeLabel.position = CGPoint(x: 24, y: size.height - 52)
        placeLabel.text = "1st"
        addChild(placeLabel)

        lapLabel.fontSize = 18
        lapLabel.fontColor = GameTheme.hudCream.withAlphaComponent(0.9)
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.position = CGPoint(x: 24, y: size.height - 78)
        lapLabel.text = "Lap 1/3"
        addChild(lapLabel)

        itemBg.fillColor = UIColor(white: 0, alpha: 0.35)
        itemBg.strokeColor = GameTheme.checkoutYellow
        itemBg.lineWidth = 2
        itemBg.position = CGPoint(x: size.width - 52, y: size.height - 62)
        addChild(itemBg)

        itemLabel.fontSize = 32
        itemLabel.verticalAlignmentMode = .center
        itemLabel.horizontalAlignmentMode = .center
        itemLabel.position = itemBg.position
        itemLabel.text = ""
        addChild(itemLabel)

        let itemHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        itemHint.text = "TAP ITEM"
        itemHint.fontSize = 9
        itemHint.fontColor = UIColor(white: 1, alpha: 0.5)
        itemHint.position = CGPoint(x: itemBg.position.x, y: itemBg.position.y - 42)
        addChild(itemHint)

        messageLabel.fontSize = 42
        messageLabel.fontColor = GameTheme.checkoutYellow
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        messageLabel.alpha = 0
        addChild(messageLabel)

        // Steer hints
        let leftHint = makeZoneHint("◀", at: CGPoint(x: size.width * 0.18, y: 56))
        let rightHint = makeZoneHint("▶", at: CGPoint(x: size.width * 0.82, y: 56))
        addChild(leftHint)
        addChild(rightHint)

        boostMeterBg.fillColor = UIColor(white: 0, alpha: 0.35)
        boostMeterBg.strokeColor = UIColor(white: 1, alpha: 0.2)
        boostMeterBg.lineWidth = 1
        boostMeterBg.position = CGPoint(x: size.width / 2, y: 36)
        addChild(boostMeterBg)

        boostMeterFill.fillColor = GameTheme.accentOrange
        boostMeterFill.strokeColor = .clear
        boostMeterFill.position = boostMeterBg.position
        addChild(boostMeterFill)

        let boostHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        boostHint.text = "HOLD CENTER TO COAST · EDGES TO STEER"
        boostHint.fontSize = 10
        boostHint.fontColor = UIColor(white: 1, alpha: 0.45)
        boostHint.position = CGPoint(x: size.width / 2, y: 18)
        addChild(boostHint)
    }

    private func makeZoneHint(_ text: String, at pos: CGPoint) -> SKNode {
        let n = SKNode()
        n.position = pos
        n.alpha = 0.35
        let c = SKShapeNode(circleOfRadius: 28)
        c.fillColor = UIColor(white: 0, alpha: 0.25)
        c.strokeColor = UIColor(white: 1, alpha: 0.3)
        c.lineWidth = 1.5
        let l = SKLabelNode(fontNamed: "AvenirNext-Bold")
        l.text = text
        l.fontSize = 22
        l.fontColor = .white
        l.verticalAlignmentMode = .center
        n.addChild(c)
        n.addChild(l)
        n.name = "hint"
        return n
    }

    func update(player: CartNode, place: Int, totalLaps: Int, boostCharge: CGFloat) {
        placeLabel.text = Self.ordinal(place)
        lapLabel.text = "Lap \(min(player.lap + 1, totalLaps))/\(totalLaps)"
        itemLabel.text = player.heldItem?.emoji ?? ""
        itemBg.strokeColor = player.heldItem != nil ? GameTheme.checkoutYellow : UIColor(white: 1, alpha: 0.25)

        let w = max(4, 120 * min(1, boostCharge))
        boostMeterFill.path = CGPath(roundedRect: CGRect(x: -60, y: -6, width: w, height: 12), cornerWidth: 4, cornerHeight: 4, transform: nil)
        boostMeterFill.fillColor = boostCharge >= 1 ? GameTheme.checkoutYellow : GameTheme.accentOrange
    }

    func showMessage(_ text: String, duration: TimeInterval = 1.2) {
        messageLabel.removeAllActions()
        messageLabel.text = text
        messageLabel.setScale(0.6)
        messageLabel.alpha = 1
        messageLabel.run(.sequence([
            .group([.fadeIn(withDuration: 0.08), .scale(to: 1.05, duration: 0.12)]),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.25)
        ]))
    }

    func hideHints() {
        children.filter { $0.name == "hint" }.forEach {
            $0.run(.fadeOut(withDuration: 1.5))
        }
    }

    func itemButtonContains(_ point: CGPoint) -> Bool {
        itemBg.contains(convert(point, from: parent ?? self))
            || itemBg.frame.insetBy(dx: -20, dy: -20).contains(convert(point, from: parent ?? self))
    }

    /// Point in scene/HUD parent space.
    func isItemTap(at scenePoint: CGPoint) -> Bool {
        let local = CGPoint(x: scenePoint.x, y: scenePoint.y)
        let dx = local.x - itemBg.position.x
        let dy = local.y - itemBg.position.y
        return hypot(dx, dy) < 48
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}
