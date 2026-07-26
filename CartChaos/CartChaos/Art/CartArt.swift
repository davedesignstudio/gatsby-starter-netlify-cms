import SpriteKit
import UIKit

enum CartArt {
    static func makeCart(archetype: CartArchetype, scale: CGFloat = 1.0) -> SKNode {
        let root = SKNode()
        root.name = "cart"

        let basket = SKShapeNode(rectOf: CGSize(width: 70 * scale, height: 42 * scale), cornerRadius: 4 * scale)
        basket.fillColor = archetype.accent
        basket.strokeColor = UIColor(white: 0.15, alpha: 1)
        basket.lineWidth = 2
        basket.position = CGPoint(x: 0, y: 8 * scale)
        root.addChild(basket)

        // Wire mesh look
        for i in -2...2 {
            let bar = SKShapeNode(rectOf: CGSize(width: 2 * scale, height: 34 * scale))
            bar.fillColor = UIColor(white: 0.85, alpha: 0.55)
            bar.strokeColor = .clear
            bar.position = CGPoint(x: CGFloat(i) * 12 * scale, y: 8 * scale)
            root.addChild(bar)
        }

        let handle = SKShapeNode(rectOf: CGSize(width: 54 * scale, height: 6 * scale), cornerRadius: 3 * scale)
        handle.fillColor = UIColor(white: 0.2, alpha: 1)
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: 34 * scale)
        root.addChild(handle)

        let leftWheel = SKShapeNode(circleOfRadius: 10 * scale)
        leftWheel.fillColor = UIColor(white: 0.12, alpha: 1)
        leftWheel.strokeColor = UIColor(white: 0.45, alpha: 1)
        leftWheel.lineWidth = 2
        leftWheel.position = CGPoint(x: -22 * scale, y: -18 * scale)
        leftWheel.name = "wheelL"
        root.addChild(leftWheel)

        let rightWheel = SKShapeNode(circleOfRadius: 10 * scale)
        rightWheel.fillColor = UIColor(white: 0.12, alpha: 1)
        rightWheel.strokeColor = UIColor(white: 0.45, alpha: 1)
        rightWheel.lineWidth = 2
        rightWheel.position = CGPoint(x: 22 * scale, y: -18 * scale)
        rightWheel.name = "wheelR"
        root.addChild(rightWheel)

        // Rider blob
        let body = SKShapeNode(circleOfRadius: 10 * scale)
        body.fillColor = UIColor(red: 1.0, green: 0.86, blue: 0.7, alpha: 1)
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 22 * scale)
        root.addChild(body)

        let hat = SKShapeNode(rectOf: CGSize(width: 18 * scale, height: 8 * scale), cornerRadius: 2)
        hat.fillColor = UIColor(red: 0.15, green: 0.35, blue: 0.55, alpha: 1)
        hat.strokeColor = .clear
        hat.position = CGPoint(x: 0, y: 30 * scale)
        root.addChild(hat)

        // Cargo flair per cart
        switch archetype {
        case .rusty:
            let dent = SKShapeNode(circleOfRadius: 5 * scale)
            dent.fillColor = UIColor(white: 0.35, alpha: 0.6)
            dent.strokeColor = .clear
            dent.position = CGPoint(x: 18 * scale, y: 4 * scale)
            root.addChild(dent)
        case .speedy:
            let stripe = SKShapeNode(rectOf: CGSize(width: 60 * scale, height: 6 * scale))
            stripe.fillColor = .white
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: 0, y: 2 * scale)
            root.addChild(stripe)
        case .jumbo:
            let bag = SKShapeNode(rectOf: CGSize(width: 28 * scale, height: 22 * scale), cornerRadius: 3)
            bag.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
            bag.strokeColor = .clear
            bag.position = CGPoint(x: 0, y: 10 * scale)
            root.addChild(bag)
        case .zigzag:
            let z = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            z.text = "Z"
            z.fontSize = 18 * scale
            z.fontColor = .white
            z.verticalAlignmentMode = .center
            z.position = CGPoint(x: 0, y: 8 * scale)
            root.addChild(z)
        case .glitter:
            for _ in 0..<5 {
                let spark = SKShapeNode(circleOfRadius: 2.5 * scale)
                spark.fillColor = .white
                spark.strokeColor = .clear
                spark.position = CGPoint(
                    x: CGFloat.random(in: -28...28) * scale,
                    y: CGFloat.random(in: -5...25) * scale
                )
                spark.alpha = 0.85
                root.addChild(spark)
                spark.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.2, duration: 0.35),
                    .fadeAlpha(to: 0.9, duration: 0.35)
                ])))
            }
        }

        return root
    }
}
