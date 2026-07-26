import SpriteKit
import UIKit

final class RaceHUD {
    private let root = SKNode()
    private let placeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let lapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let itemFrame: SKShapeNode
    private let itemLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let itemName = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let minimap: SKShapeNode
    private var blips: [SKShapeNode] = []
    private let trackSize: CGSize

    let leftZone: SKNode
    let rightZone: SKNode
    let itemButton: SKShapeNode
    let brakeButton: SKShapeNode

    init(sceneSize: CGSize, trackSize: CGSize, racerCount: Int) {
        self.trackSize = trackSize
        root.zPosition = 500

        placeLabel.fontSize = 36
        placeLabel.fontColor = .white
        placeLabel.horizontalAlignmentMode = .left
        placeLabel.verticalAlignmentMode = .center
        placeLabel.position = CGPoint(x: 28, y: sceneSize.height - 48)
        placeLabel.text = "1st"
        root.addChild(placeLabel)

        lapLabel.fontSize = 18
        lapLabel.fontColor = UIColor(white: 1, alpha: 0.9)
        lapLabel.horizontalAlignmentMode = .left
        lapLabel.position = CGPoint(x: 28, y: sceneSize.height - 78)
        lapLabel.text = "LAP 1/\(RaceConfig.lapCount)"
        root.addChild(lapLabel)

        itemFrame = SKShapeNode(rectOf: CGSize(width: 64, height: 64), cornerRadius: 12)
        itemFrame.fillColor = UIColor(white: 0, alpha: 0.45)
        itemFrame.strokeColor = UIColor(white: 1, alpha: 0.5)
        itemFrame.lineWidth = 2
        itemFrame.position = CGPoint(x: sceneSize.width - 52, y: sceneSize.height - 56)
        root.addChild(itemFrame)

        itemLabel.fontSize = 30
        itemLabel.verticalAlignmentMode = .center
        itemLabel.position = itemFrame.position
        itemLabel.text = ""
        root.addChild(itemLabel)

        itemName.fontSize = 11
        itemName.fontColor = UIColor(white: 1, alpha: 0.8)
        itemName.verticalAlignmentMode = .center
        itemName.position = CGPoint(x: itemFrame.position.x, y: itemFrame.position.y - 42)
        root.addChild(itemName)

        countdownLabel.fontSize = 72
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        countdownLabel.zPosition = 50
        root.addChild(countdownLabel)

        // Minimap
        let mapW: CGFloat = 120
        let mapH: CGFloat = mapW * (trackSize.height / trackSize.width)
        minimap = SKShapeNode(rectOf: CGSize(width: mapW, height: mapH), cornerRadius: 6)
        minimap.fillColor = UIColor(white: 0, alpha: 0.4)
        minimap.strokeColor = UIColor(white: 1, alpha: 0.35)
        minimap.position = CGPoint(x: sceneSize.width - 78, y: 90)
        root.addChild(minimap)

        for i in 0..<racerCount {
            let blip = SKShapeNode(circleOfRadius: i == 0 ? 4.5 : 3.5)
            blip.fillColor = i == 0 ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : .white
            blip.strokeColor = .clear
            blip.zPosition = 2
            minimap.addChild(blip)
            blips.append(blip)
        }

        // Touch zones / buttons
        leftZone = SKNode()
        leftZone.name = "steerLeft"
        leftZone.position = CGPoint(x: 70, y: 90)
        let leftVis = SKShapeNode(circleOfRadius: 42)
        leftVis.fillColor = UIColor(white: 0, alpha: 0.28)
        leftVis.strokeColor = UIColor(white: 1, alpha: 0.35)
        leftVis.name = "steerLeft"
        leftZone.addChild(leftVis)
        let leftArrow = SKLabelNode(text: "◀")
        leftArrow.fontSize = 28
        leftArrow.fontColor = .white
        leftArrow.verticalAlignmentMode = .center
        leftArrow.name = "steerLeft"
        leftZone.addChild(leftArrow)
        root.addChild(leftZone)

        rightZone = SKNode()
        rightZone.name = "steerRight"
        rightZone.position = CGPoint(x: 170, y: 90)
        let rightVis = SKShapeNode(circleOfRadius: 42)
        rightVis.fillColor = UIColor(white: 0, alpha: 0.28)
        rightVis.strokeColor = UIColor(white: 1, alpha: 0.35)
        rightVis.name = "steerRight"
        rightZone.addChild(rightVis)
        let rightArrow = SKLabelNode(text: "▶")
        rightArrow.fontSize = 28
        rightArrow.fontColor = .white
        rightArrow.verticalAlignmentMode = .center
        rightArrow.name = "steerRight"
        rightZone.addChild(rightArrow)
        root.addChild(rightZone)

        brakeButton = SKShapeNode(rectOf: CGSize(width: 88, height: 52), cornerRadius: 12)
        brakeButton.fillColor = UIColor(red: 0.75, green: 0.2, blue: 0.2, alpha: 0.55)
        brakeButton.strokeColor = UIColor(white: 1, alpha: 0.4)
        brakeButton.position = CGPoint(x: sceneSize.width - 70, y: 200)
        brakeButton.name = "brake"
        let brakeText = SKLabelNode(fontNamed: "AvenirNext-Bold")
        brakeText.text = "BRAKE"
        brakeText.fontSize = 14
        brakeText.fontColor = .white
        brakeText.verticalAlignmentMode = .center
        brakeText.name = "brake"
        brakeButton.addChild(brakeText)
        root.addChild(brakeButton)

        itemButton = SKShapeNode(rectOf: CGSize(width: 88, height: 52), cornerRadius: 12)
        itemButton.fillColor = UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 0.55)
        itemButton.strokeColor = UIColor(white: 1, alpha: 0.4)
        itemButton.position = CGPoint(x: sceneSize.width - 70, y: 265)
        itemButton.name = "useItem"
        let itemText = SKLabelNode(fontNamed: "AvenirNext-Bold")
        itemText.text = "ITEM"
        itemText.fontSize = 14
        itemText.fontColor = .white
        itemText.verticalAlignmentMode = .center
        itemText.name = "useItem"
        itemButton.addChild(itemText)
        root.addChild(itemButton)

        let tip = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tip.text = "Hold edges to steer · drift for boost"
        tip.fontSize = 11
        tip.fontColor = UIColor(white: 1, alpha: 0.55)
        tip.position = CGPoint(x: sceneSize.width / 2, y: 24)
        root.addChild(tip)
    }

    var node: SKNode { root }

    func setCountdown(_ text: String?) {
        countdownLabel.text = text
        countdownLabel.isHidden = text == nil
        if text != nil {
            countdownLabel.setScale(1.3)
            countdownLabel.run(SKAction.scale(to: 1.0, duration: 0.2))
        }
    }

    func update(player: CartNode, carts: [CartNode], raceTime: TimeInterval) {
        placeLabel.text = ordinal(player.place)
        lapLabel.text = "LAP \(min(player.currentLap + 1, RaceConfig.lapCount))/\(RaceConfig.lapCount)  ·  \(formatTime(raceTime))"

        if let item = player.heldItem {
            itemLabel.text = item.label
            itemName.text = item.name
        } else {
            itemLabel.text = ""
            itemName.text = "Empty"
        }

        let mapW = minimap.frame.width
        let mapH = minimap.frame.height
        for (i, cart) in carts.enumerated() where i < blips.count {
            let nx = (cart.position.x / trackSize.width - 0.5) * mapW * 0.9
            let ny = (cart.position.y / trackSize.height - 0.5) * mapH * 0.9
            blips[i].position = CGPoint(x: nx, y: ny)
            blips[i].fillColor = cart.isPlayer
                ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
                : cart.profile.cartColor
        }
    }

    func layout(size: CGSize) {
        placeLabel.position = CGPoint(x: 28, y: size.height - 48)
        lapLabel.position = CGPoint(x: 28, y: size.height - 78)
        itemFrame.position = CGPoint(x: size.width - 52, y: size.height - 56)
        itemLabel.position = itemFrame.position
        itemName.position = CGPoint(x: itemFrame.position.x, y: itemFrame.position.y - 42)
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        minimap.position = CGPoint(x: size.width - 78, y: 90)
        leftZone.position = CGPoint(x: 70, y: 90)
        rightZone.position = CGPoint(x: 170, y: 90)
        brakeButton.position = CGPoint(x: size.width - 70, y: 200)
        itemButton.position = CGPoint(x: size.width - 70, y: 265)
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - floor(t)) * 100)
        return String(format: "%d:%02d.%02d", m, s, ms)
    }
}
