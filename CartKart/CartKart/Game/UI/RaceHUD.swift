import SpriteKit
import UIKit

final class RaceHUD {
    private let root = SKNode()
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let placeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let itemPanel = SKShapeNode(rectOf: CGSize(width: 72, height: 72), cornerRadius: 12)
    private let itemLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let itemEmoji = SKLabelNode(fontNamed: "AppleColorEmoji")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let speedLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    // Touch zones (visual)
    let leftZone = SKShapeNode()
    let rightZone = SKShapeNode()
    let itemButton = SKShapeNode(rectOf: CGSize(width: 80, height: 80), cornerRadius: 40)
    let boostButton = SKShapeNode(rectOf: CGSize(width: 90, height: 54), cornerRadius: 14)

    func attach(to camera: SKCameraNode) {
        root.zPosition = 500
        // HUD must live on the camera so it stays fixed on screen.
        camera.addChild(root)

        lapLabel.fontSize = 18
        lapLabel.fontColor = .white
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.verticalAlignmentMode = .center
        root.addChild(lapLabel)

        placeLabel.fontSize = 28
        placeLabel.fontColor = UIColor(red: 1, green: 0.85, blue: 0.25, alpha: 1)
        placeLabel.horizontalAlignmentMode = .left
        placeLabel.verticalAlignmentMode = .center
        root.addChild(placeLabel)

        speedLabel.fontSize = 14
        speedLabel.fontColor = UIColor(white: 1, alpha: 0.75)
        speedLabel.horizontalAlignmentMode = .left
        root.addChild(speedLabel)

        itemPanel.fillColor = UIColor(white: 0, alpha: 0.45)
        itemPanel.strokeColor = UIColor(white: 1, alpha: 0.35)
        itemPanel.lineWidth = 2
        root.addChild(itemPanel)

        itemEmoji.fontSize = 28
        itemEmoji.verticalAlignmentMode = .center
        itemPanel.addChild(itemEmoji)

        itemLabel.fontSize = 9
        itemLabel.fontColor = UIColor(white: 1, alpha: 0.8)
        itemLabel.verticalAlignmentMode = .center
        itemLabel.position = CGPoint(x: 0, y: -26)
        itemPanel.addChild(itemLabel)

        countdownLabel.fontSize = 96
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.zPosition = 50
        root.addChild(countdownLabel)

        messageLabel.fontSize = 36
        messageLabel.fontColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        messageLabel.verticalAlignmentMode = .center
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.zPosition = 50
        messageLabel.alpha = 0
        root.addChild(messageLabel)

        configureControls(size: scene.size)
        layout(size: scene.size)
    }

    private func configureControls(size: CGSize) {
        leftZone.fillColor = UIColor(white: 1, alpha: 0.06)
        leftZone.strokeColor = UIColor(white: 1, alpha: 0.12)
        leftZone.lineWidth = 1
        leftZone.zPosition = 1
        root.addChild(leftZone)

        rightZone.fillColor = UIColor(white: 1, alpha: 0.06)
        rightZone.strokeColor = UIColor(white: 1, alpha: 0.12)
        rightZone.lineWidth = 1
        rightZone.zPosition = 1
        root.addChild(rightZone)

        let leftArrow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        leftArrow.text = "◀"
        leftArrow.fontSize = 28
        leftArrow.fontColor = UIColor(white: 1, alpha: 0.45)
        leftArrow.verticalAlignmentMode = .center
        leftZone.addChild(leftArrow)

        let rightArrow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        rightArrow.text = "▶"
        rightArrow.fontSize = 28
        rightArrow.fontColor = UIColor(white: 1, alpha: 0.45)
        rightArrow.verticalAlignmentMode = .center
        rightZone.addChild(rightArrow)

        itemButton.fillColor = UIColor(white: 0, alpha: 0.4)
        itemButton.strokeColor = UIColor(white: 1, alpha: 0.4)
        itemButton.lineWidth = 2
        itemButton.name = "itemButton"
        let itemHint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        itemHint.text = "ITEM"
        itemHint.fontSize = 12
        itemHint.fontColor = UIColor(white: 1, alpha: 0.7)
        itemHint.verticalAlignmentMode = .center
        itemButton.addChild(itemHint)
        root.addChild(itemButton)

        boostButton.fillColor = UIColor(red: 0.15, green: 0.55, blue: 0.85, alpha: 0.55)
        boostButton.strokeColor = UIColor(white: 1, alpha: 0.5)
        boostButton.lineWidth = 2
        boostButton.name = "boostButton"
        let boostHint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        boostHint.text = "BOOST"
        boostHint.fontSize = 14
        boostHint.fontColor = .white
        boostHint.verticalAlignmentMode = .center
        boostButton.addChild(boostHint)
        root.addChild(boostButton)
    }

    func layout(size: CGSize) {
        let top = size.height / 2 - 48
        let left = -size.width / 2 + 24

        placeLabel.position = CGPoint(x: left, y: top)
        lapLabel.position = CGPoint(x: left, y: top - 30)
        speedLabel.position = CGPoint(x: left, y: top - 52)
        itemPanel.position = CGPoint(x: size.width / 2 - 52, y: top - 10)
        countdownLabel.position = .zero
        messageLabel.position = CGPoint(x: 0, y: 60)

        let zoneH: CGFloat = 120
        let zoneW = size.width * 0.28
        let zoneY = -size.height / 2 + zoneH / 2 + 16

        leftZone.path = CGPath(roundedRect: CGRect(x: -zoneW / 2, y: -zoneH / 2, width: zoneW, height: zoneH), cornerWidth: 16, cornerHeight: 16, transform: nil)
        leftZone.position = CGPoint(x: -size.width / 2 + zoneW / 2 + 16, y: zoneY)

        rightZone.path = CGPath(roundedRect: CGRect(x: -zoneW / 2, y: -zoneH / 2, width: zoneW, height: zoneH), cornerWidth: 16, cornerHeight: 16, transform: nil)
        rightZone.position = CGPoint(x: size.width / 2 - zoneW / 2 - 16, y: zoneY)

        itemButton.position = CGPoint(x: size.width / 2 - 56, y: zoneY + 70)
        boostButton.position = CGPoint(x: 0, y: -size.height / 2 + 50)
    }

    func update(player: ShoppingCart, place: Int, totalLaps: Int, raceState: RaceState, countdown: Int?) {
        let lapDisplay = min(player.currentLap + 1, totalLaps)
        lapLabel.text = "LAP \(lapDisplay)/\(totalLaps)"
        placeLabel.text = ordinal(place)
        speedLabel.text = "\(Int(player.speed)) u/s"

        if let item = player.heldItem {
            itemEmoji.text = item.emoji
            itemLabel.text = item.displayName
            itemPanel.strokeColor = item.tint
        } else {
            itemEmoji.text = "—"
            itemLabel.text = "Empty"
            itemPanel.strokeColor = UIColor(white: 1, alpha: 0.35)
        }

        if let countdown {
            countdownLabel.text = countdown > 0 ? "\(countdown)" : "GO!"
            countdownLabel.alpha = 1
            countdownLabel.setScale(countdown == 0 ? 1.3 : 1.0)
        } else {
            countdownLabel.alpha = 0
        }

        let racing = raceState == .racing
        leftZone.alpha = racing ? 1 : 0.35
        rightZone.alpha = racing ? 1 : 0.35
        itemButton.alpha = racing ? 1 : 0.35
        boostButton.alpha = racing ? 1 : 0.35
    }

    func showMessage(_ text: String, duration: TimeInterval = 2.0) {
        messageLabel.text = text
        messageLabel.removeAllActions()
        messageLabel.alpha = 1
        messageLabel.setScale(0.6)
        messageLabel.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.15)
            ]),
            SKAction.wait(forDuration: duration),
            SKAction.fadeOut(withDuration: 0.35)
        ]))
    }

    func setControlsVisible(_ visible: Bool) {
        leftZone.isHidden = !visible
        rightZone.isHidden = !visible
        itemButton.isHidden = !visible
        boostButton.isHidden = !visible
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    func containsLeft(_ point: CGPoint) -> Bool {
        hitTest(leftZone, point: point)
    }

    func containsRight(_ point: CGPoint) -> Bool {
        hitTest(rightZone, point: point)
    }

    func containsItem(_ point: CGPoint) -> Bool {
        hitTest(itemButton, point: point)
    }

    func containsBoost(_ point: CGPoint) -> Bool {
        hitTest(boostButton, point: point)
    }

    private func hitTest(_ node: SKNode, point: CGPoint) -> Bool {
        // `point` is in camera space; HUD root is a child of the camera at origin.
        let local = CGPoint(x: point.x - node.position.x, y: point.y - node.position.y)
        if let shape = node as? SKShapeNode, let path = shape.path {
            return path.contains(local)
        }
        let frame = node.calculateAccumulatedFrame()
        return frame.contains(point)
    }
}
