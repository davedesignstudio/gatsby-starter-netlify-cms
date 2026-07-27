import SceneKit
import SpriteKit

enum GroceryLootKind: CaseIterable {
    case cereal
    case soup
    case chips
    case milk
    case banana
    case can
    case bread
    case wine

    var primaryColor: UIColor {
        switch self {
        case .cereal: return UIColor(red: 0.95, green: 0.72, blue: 0.2, alpha: 1)
        case .soup: return UIColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)
        case .chips: return UIColor(red: 0.2, green: 0.55, blue: 0.9, alpha: 1)
        case .milk: return UIColor(white: 0.95, alpha: 1)
        case .banana: return UIColor(red: 1.0, green: 0.88, blue: 0.2, alpha: 1)
        case .can: return UIColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1)
        case .bread: return UIColor(red: 0.82, green: 0.62, blue: 0.35, alpha: 1)
        case .wine: return UIColor(red: 0.45, green: 0.1, blue: 0.2, alpha: 1)
        }
    }
}

enum Item3DModels {
  // MARK: - Power-up items

    static func makePowerUp(_ type: PowerUpType, scale: Float = 1) -> SCNNode {
        let node: SCNNode
        switch type {
        case .bananaPeel: node = makeBananaPeel()
        case .couponBoost: node = makeCouponTag()
        case .spilledMilk: node = makeMilkCarton()
        case .canPyramid: node = makeCanPyramid()
        }
        node.name = "powerUp_\(type)"
        node.scale = SCNVector3(scale, scale, scale)
        return node
    }

    static func makeBananaPeel() -> SCNNode {
        let root = SCNNode()
        let peel = SCNCapsule(capRadius: 1.8, height: 10)
        peel.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.86, blue: 0.18, alpha: 1)
        peel.firstMaterial?.roughness.contents = 0.55
        let body = SCNNode(geometry: peel)
        body.eulerAngles = SCNVector3(0, 0, Float.pi / 2.4)
        root.addChildNode(body)

        let peel2 = body.clone()
        peel2.eulerAngles = SCNVector3(0.2, 0.5, -Float.pi / 2.8)
        peel2.position = SCNVector3(2, 0.5, -1)
        root.addChildNode(peel2)
        return root
    }

    static func makeCouponTag() -> SCNNode {
        let root = SCNNode()
        let tag = SCNBox(width: 10, height: 7, length: 0.6, chamferRadius: 0.8)
        tag.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1)
        tag.firstMaterial?.metalness.contents = 0.15
        let tagNode = SCNNode(geometry: tag)
        root.addChildNode(tagNode)

        let hole = SCNTorus(ringRadius: 1.2, pipeRadius: 0.25)
        hole.firstMaterial?.diffuse.contents = UIColor.darkGray
        let holeNode = SCNNode(geometry: hole)
        holeNode.position = SCNVector3(-3.5, 2.5, 0)
        holeNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        root.addChildNode(holeNode)

        let stripe = SCNBox(width: 8, height: 1.2, length: 0.7, chamferRadius: 0.2)
        stripe.firstMaterial?.diffuse.contents = UIColor.white
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, -1.5, 0)
        root.addChildNode(stripeNode)
        return root
    }

    static func makeMilkCarton() -> SCNNode {
        let root = SCNNode()
        let carton = SCNBox(width: 6, height: 10, length: 6, chamferRadius: 0.5)
        carton.firstMaterial?.diffuse.contents = UIColor(white: 0.96, alpha: 1)
        carton.firstMaterial?.roughness.contents = 0.7
        let cartonNode = SCNNode(geometry: carton)
        cartonNode.position = SCNVector3(0, 5, 0)
        root.addChildNode(cartonNode)

        let roof = SCNPyramid(width: 6.4, height: 3, length: 6.4)
        roof.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 11.5, 0)
        root.addChildNode(roofNode)
        return root
    }

    static func makeCan(radius: CGFloat = 2.2, height: CGFloat = 5.5, color: UIColor? = nil) -> SCNNode {
        let can = SCNCylinder(radius: radius, height: height)
        can.firstMaterial?.diffuse.contents = color ?? UIColor(red: 0.82, green: 0.28, blue: 0.18, alpha: 1)
        can.firstMaterial?.metalness.contents = 0.75
        can.firstMaterial?.roughness.contents = 0.25
        let node = SCNNode(geometry: can)
        node.position = SCNVector3(0, Float(height / 2), 0)
        return node
    }

    static func makeCanPyramid() -> SCNNode {
        let root = SCNNode()
        let offsets: [(Float, Float, UIColor)] = [
            (0, 0, UIColor(red: 0.85, green: 0.25, blue: 0.15, alpha: 1)),
            (-2.8, -2.2, UIColor(red: 0.75, green: 0.2, blue: 0.12, alpha: 1)),
            (2.8, -2.2, UIColor(red: 0.9, green: 0.3, blue: 0.18, alpha: 1)),
            (0, -4.2, UIColor(red: 0.7, green: 0.18, blue: 0.1, alpha: 1)),
        ]
        for (index, offset) in offsets.enumerated() {
            let can = makeCan(radius: 2.1, height: 5, color: offset.2)
            can.position = SCNVector3(offset.0, Float(index) * 0.3, offset.1)
            root.addChildNode(can)
        }
        return root
    }

    // MARK: - Track hazards (deployed items)

    static func makeBananaHazard() -> SCNNode {
        let node = makeBananaPeel()
        node.name = "hazard_banana"
        node.scale = SCNVector3(1.4, 1.4, 1.4)
        return node
    }

    static func makeMilkPuddle() -> SCNNode {
        let root = SCNNode()
        root.name = "hazard_milk"

        let puddle = SCNCylinder(radius: 14, height: 0.4)
        puddle.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.65)
        puddle.firstMaterial?.transparency = 0.35
        puddle.firstMaterial?.isDoubleSided = true
        let puddleNode = SCNNode(geometry: puddle)
        puddleNode.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(puddleNode)

        let splash = SCNTorus(ringRadius: 16, pipeRadius: 0.8)
        splash.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.5)
        let splashNode = SCNNode(geometry: splash)
        splashNode.position = SCNVector3(0, 0.3, 0)
        splashNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        root.addChildNode(splashNode)
        return root
    }

    static func makeCanHazard() -> SCNNode {
        let node = makeCanPyramid()
        node.name = "hazard_cans"
        node.scale = SCNVector3(1.2, 1.2, 1.2)
        return node
    }

    // MARK: - Item box pickup

    static func makeItemBox(pulse: Bool = true) -> SCNNode {
        let root = SCNNode()
        root.name = "itemBox"

        let crate = SCNBox(width: 18, height: 18, length: 18, chamferRadius: 2)
        crate.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1)
        crate.firstMaterial?.metalness.contents = 0.2
        let crateNode = SCNNode(geometry: crate)
        crateNode.position = SCNVector3(0, 9, 0)
        root.addChildNode(crateNode)

        let strapV = SCNBox(width: 2, height: 18.5, length: 18.5, chamferRadius: 0.3)
        strapV.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.4, blue: 0.05, alpha: 1)
        let strapVNode = SCNNode(geometry: strapV)
        strapVNode.position = SCNVector3(0, 9, 0)
        root.addChildNode(strapVNode)

        let question = SCNText(string: "?", extrusionDepth: 1.2)
        question.font = UIFont(name: "AvenirNext-Heavy", size: 12)
        question.firstMaterial?.diffuse.contents = UIColor.white
        question.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.4)
        let qNode = SCNNode(geometry: question)
        qNode.scale = SCNVector3(0.5, 0.5, 0.5)
        qNode.position = SCNVector3(-2.5, 11, 9.2)
        root.addChildNode(qNode)

        if pulse {
            let spin = CABasicAnimation(keyPath: "rotation")
            spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
            spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
            spin.duration = 4
            spin.repeatCount = .infinity
            root.addAnimation(spin, forKey: "spin")

            let bob = CABasicAnimation(keyPath: "position.y")
            bob.fromValue = 0
            bob.toValue = 2
            bob.duration = 1.2
            bob.autoreverses = true
            bob.repeatCount = .infinity
            root.addAnimation(bob, forKey: "bob")
        }
        return root
    }

    // MARK: - Grocery loot for cart basket

    static func makeGroceryLoot(_ kind: GroceryLootKind, scale: Float = 1) -> SCNNode {
        let root = SCNNode()
        root.name = "loot_\(kind)"

        switch kind {
        case .cereal, .soup, .chips, .bread:
            let box = SCNBox(width: 7, height: 9, length: 4, chamferRadius: 0.6)
            box.firstMaterial?.diffuse.contents = kind.primaryColor
            let boxNode = SCNNode(geometry: box)
            boxNode.position = SCNVector3(0, 4.5, 0)
            root.addChildNode(boxNode)

            let label = SCNBox(width: 5.5, height: 3, length: 0.2, chamferRadius: 0.2)
            label.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.85)
            let labelNode = SCNNode(geometry: label)
            labelNode.position = SCNVector3(0, 5, 2.1)
            root.addChildNode(labelNode)

        case .milk:
            let milk = makeMilkCarton()
            milk.scale = SCNVector3(0.45, 0.45, 0.45)
            root.addChildNode(milk)

        case .banana:
            let banana = makeBananaPeel()
            banana.scale = SCNVector3(0.55, 0.55, 0.55)
            root.addChildNode(banana)

        case .can:
            root.addChildNode(makeCan(radius: 1.8, height: 4.5, color: kind.primaryColor))

        case .wine:
            let bottle = SCNCylinder(radius: 1.6, height: 10)
            bottle.firstMaterial?.diffuse.contents = kind.primaryColor
            bottle.firstMaterial?.metalness.contents = 0.4
            let bottleNode = SCNNode(geometry: bottle)
            bottleNode.position = SCNVector3(0, 5, 0)
            root.addChildNode(bottleNode)

            let neck = SCNCylinder(radius: 0.7, height: 3)
            neck.firstMaterial?.diffuse.contents = kind.primaryColor.darker(by: 0.1)
            let neckNode = SCNNode(geometry: neck)
            neckNode.position = SCNVector3(0, 11.5, 0)
            root.addChildNode(neckNode)
        }

        root.scale = SCNVector3(scale, scale, scale)
        return root
    }

    static func makeBasketLoot(seed: String, count: Int = 5) -> SCNNode {
        let root = SCNNode()
        root.name = "basketLoot"
        let kinds = GroceryLootKind.allCases
        var hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }

        let positions: [SCNVector3] = [
            SCNVector3(-6, 2, -2), SCNVector3(5, 2, -1), SCNVector3(-2, 2, 3),
            SCNVector3(6, 5, 1), SCNVector3(-5, 5, 2), SCNVector3(0, 6, -1),
            SCNVector3(3, 7, -2),
        ]

        for index in 0..<min(count, positions.count) {
            hash = (hash &* 31 &+ index) % 10_000
            let kind = kinds[hash % kinds.count]
            let item = makeGroceryLoot(kind, scale: 0.85 + Float(hash % 20) / 100)
            item.position = positions[index]
            item.eulerAngles = SCNVector3(0, Float(hash % 628) / 100, 0)
            root.addChildNode(item)
        }
        return root
    }
}

private extension UIColor {
    func darker(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - amount, 0), green: max(g - amount, 0), blue: max(b - amount, 0), alpha: a)
    }
}
