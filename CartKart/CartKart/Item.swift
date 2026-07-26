import SpriteKit

/// Power-ups a racer can pick up from an item box, in the spirit of a kart racer.
enum ItemType: CaseIterable {
    /// Energy drink: instant speed boost for the user.
    case energyDrink
    /// Spilled milk: drops a slick hazard behind the cart; anyone who touches it spins out.
    case spilledMilk
    /// Canned goods: launched forward to knock out the racer ahead.
    case cannedGoods

    var displayName: String {
        switch self {
        case .energyDrink: return "Energy Drink"
        case .spilledMilk: return "Spilled Milk"
        case .cannedGoods: return "Canned Goods"
        }
    }

    var symbol: String {
        switch self {
        case .energyDrink: return "⚡️"
        case .spilledMilk: return "🥛"
        case .cannedGoods: return "🥫"
        }
    }

    var tint: SKColor {
        switch self {
        case .energyDrink: return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        case .spilledMilk: return SKColor(white: 0.95, alpha: 1)
        case .cannedGoods: return SKColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1)
        }
    }

    static func random() -> ItemType {
        allCases.randomElement() ?? .energyDrink
    }
}

/// Small factory for the visual nodes tied to items. Keeps GameScene lean.
enum ItemNodeFactory {

    /// A spinning box that grants a random item when driven into.
    static func makeItemBox() -> SKShapeNode {
        let box = SKShapeNode(rectOf: CGSize(width: 46, height: 46), cornerRadius: 8)
        box.fillColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.9)
        box.strokeColor = .white
        box.lineWidth = 3
        box.zPosition = GameConfig.ZPosition.itemBox

        let mark = SKLabelNode(text: "?")
        mark.fontName = "AvenirNext-Heavy"
        mark.fontSize = 30
        mark.fontColor = .white
        mark.verticalAlignmentMode = .center
        box.addChild(mark)

        box.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))
        return box
    }

    /// A puddle of spilled milk that spins out any cart that touches it.
    static func makeMilkPuddle(at position: CGPoint) -> SKShapeNode {
        let puddle = SKShapeNode(ellipseOf: CGSize(width: 64, height: 48))
        puddle.fillColor = SKColor(white: 0.95, alpha: 0.85)
        puddle.strokeColor = SKColor(white: 0.7, alpha: 0.6)
        puddle.lineWidth = 2
        puddle.position = position
        puddle.zPosition = GameConfig.ZPosition.hazard
        puddle.setScale(0.1)
        puddle.run(.scale(to: 1.0, duration: 0.2))
        return puddle
    }

    /// A can of goods flung forward to bonk an opponent.
    static func makeCan() -> SKShapeNode {
        let can = SKShapeNode(rectOf: CGSize(width: 22, height: 30), cornerRadius: 4)
        can.fillColor = SKColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1)
        can.strokeColor = .white
        can.lineWidth = 2
        can.zPosition = GameConfig.ZPosition.projectile
        return can
    }
}
