import SpriteKit

final class ItemBoxNode: SKNode {
    private let boxBody: SKShapeNode

    init(position: CGPoint) {
        boxBody = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 6)
        super.init()
        self.position = position
        self.zPosition = 2
        self.name = "itemBox"

        boxBody.fillColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        boxBody.strokeColor = .orange
        boxBody.lineWidth = 3
        addChild(boxBody)

        let question = SKLabelNode(text: "?")
        question.fontName = "AvenirNext-Heavy"
        question.fontSize = 22
        question.fontColor = .orange
        question.verticalAlignmentMode = .center
        boxBody.addChild(question)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        boxBody.run(SKAction.repeatForever(pulse))

        physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 34, height: 34))
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.itemBox
        physicsBody?.contactTestBitMask = PhysicsCategory.cart
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func collect() -> RaceItem {
        let item = RaceItem.random()
        respawn(after: 4)
        return item
    }

    private func respawn(after delay: TimeInterval) {
        isHidden = true
        physicsBody?.categoryBitMask = PhysicsCategory.none
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                self?.isHidden = false
                self?.physicsBody?.categoryBitMask = PhysicsCategory.itemBox
            }
        ]))
    }
}
