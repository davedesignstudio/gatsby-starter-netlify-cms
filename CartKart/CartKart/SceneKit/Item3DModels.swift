import SceneKit
import SpriteKit

enum CartBelongingCategory: CaseIterable {
    case bedding
    case clothing
    case weatherProtection
    case bagsContainers
    case recyclables
    case waterFood
    case hygiene
    case cardboard
}

enum CartBelongingKind: CaseIterable {
    case blanket
    case sleepingBag
    case pillow
    case jacket
    case spareShoes
    case tarp
    case plasticSheeting
    case umbrella
    case duffelBag
    case plasticBin
    case recycleCan
    case recycleBottle
    case waterBottle
    case snackBag
    case wipesPack
    case toiletryBag
    case cardboardSheet
    case cardboardSign

    var category: CartBelongingCategory {
        switch self {
        case .blanket, .sleepingBag, .pillow: return .bedding
        case .jacket, .spareShoes: return .clothing
        case .tarp, .plasticSheeting, .umbrella: return .weatherProtection
        case .duffelBag, .plasticBin: return .bagsContainers
        case .recycleCan, .recycleBottle: return .recyclables
        case .waterBottle, .snackBag: return .waterFood
        case .wipesPack, .toiletryBag: return .hygiene
        case .cardboardSheet, .cardboardSign: return .cardboard
        }
    }

    var primaryColor: UIColor {
        switch self {
        case .blanket: return UIColor(red: 0.35, green: 0.45, blue: 0.62, alpha: 1)
        case .sleepingBag: return UIColor(red: 0.2, green: 0.35, blue: 0.28, alpha: 1)
        case .pillow: return UIColor(red: 0.75, green: 0.72, blue: 0.65, alpha: 1)
        case .jacket: return UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)
        case .spareShoes: return UIColor(red: 0.25, green: 0.2, blue: 0.18, alpha: 1)
        case .tarp: return UIColor(red: 0.15, green: 0.42, blue: 0.28, alpha: 1)
        case .plasticSheeting: return UIColor(white: 0.92, alpha: 0.55)
        case .umbrella: return UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
        case .duffelBag: return UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
        case .plasticBin: return UIColor(red: 0.2, green: 0.55, blue: 0.75, alpha: 1)
        case .recycleCan: return UIColor(red: 0.78, green: 0.22, blue: 0.15, alpha: 1)
        case .recycleBottle: return UIColor(red: 0.25, green: 0.65, blue: 0.35, alpha: 0.7)
        case .waterBottle: return UIColor(red: 0.4, green: 0.75, blue: 0.95, alpha: 0.85)
        case .snackBag: return UIColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1)
        case .wipesPack: return UIColor(red: 0.85, green: 0.9, blue: 0.95, alpha: 1)
        case .toiletryBag: return UIColor(red: 0.6, green: 0.75, blue: 0.85, alpha: 1)
        case .cardboardSheet: return UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1)
        case .cardboardSign: return UIColor(red: 0.68, green: 0.52, blue: 0.32, alpha: 1)
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

    // MARK: - Cart belongings (realistic homeless cart contents)

    static func makeCartBelonging(_ kind: CartBelongingKind, scale: Float = 1) -> SCNNode {
        let root = SCNNode()
        root.name = "belonging_\(kind)"

        switch kind {
        case .blanket:
            let fold = SCNBox(width: 9, height: 2.5, length: 7, chamferRadius: 0.8)
            fold.materials = [fabricMaterial(kind.primaryColor)]
            let node = SCNNode(geometry: fold)
            node.position = SCNVector3(0, 1.2, 0)
            root.addChildNode(node)

        case .sleepingBag:
            let roll = SCNCylinder(radius: 2.8, height: 11)
            roll.materials = [fabricMaterial(kind.primaryColor)]
            let node = SCNNode(geometry: roll)
            node.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            node.position = SCNVector3(0, 2.8, 0)
            root.addChildNode(node)
            let strap = SCNBox(width: 11.5, height: 0.4, length: 0.8, chamferRadius: 0.1)
            strap.firstMaterial?.diffuse.contents = UIColor.darkGray
            let strapNode = SCNNode(geometry: strap)
            strapNode.position = SCNVector3(0, 2.8, 0)
            root.addChildNode(strapNode)

        case .pillow:
            let pillow = SCNBox(width: 7, height: 3, length: 5, chamferRadius: 1.2)
            pillow.materials = [fabricMaterial(kind.primaryColor)]
            let node = SCNNode(geometry: pillow)
            node.position = SCNVector3(0, 1.5, 0)
            root.addChildNode(node)

        case .jacket:
            let body = SCNBox(width: 8, height: 1.5, length: 6, chamferRadius: 0.5)
            body.materials = [fabricMaterial(kind.primaryColor)]
            let bodyNode = SCNNode(geometry: body)
            bodyNode.position = SCNVector3(0, 1.2, 0)
            root.addChildNode(bodyNode)
            let sleeve = SCNBox(width: 3, height: 1, length: 5, chamferRadius: 0.4)
            sleeve.materials = [fabricMaterial(darken(kind.primaryColor, by: 0.05))]
            let sleeveNode = SCNNode(geometry: sleeve)
            sleeveNode.position = SCNVector3(4.5, 1, 0)
            root.addChildNode(sleeveNode)

        case .spareShoes:
            for x in [-2.2, 2.2] as [Float] {
                let shoe = SCNBox(width: 3.2, height: 1.8, length: 5.5, chamferRadius: 0.5)
                shoe.materials = [fabricMaterial(kind.primaryColor)]
                let shoeNode = SCNNode(geometry: shoe)
                shoeNode.position = SCNVector3(x, 0.9, 0)
                root.addChildNode(shoeNode)
            }

        case .tarp:
            let tarp = SCNBox(width: 12, height: 0.25, length: 9, chamferRadius: 0.2)
            tarp.materials = [plasticMaterial(kind.primaryColor, alpha: 0.9)]
            let node = SCNNode(geometry: tarp)
            node.position = SCNVector3(0, 0.2, 0)
            node.eulerAngles = SCNVector3(0.15, 0.3, 0)
            root.addChildNode(node)

        case .plasticSheeting:
            let sheet = SCNBox(width: 10, height: 0.12, length: 8, chamferRadius: 0.1)
            sheet.materials = [plasticMaterial(kind.primaryColor, alpha: 0.45)]
            let node = SCNNode(geometry: sheet)
            node.eulerAngles = SCNVector3(0.1, -0.2, 0.05)
            root.addChildNode(node)

        case .umbrella:
            let shaft = SCNCylinder(radius: 0.35, height: 14)
            shaft.firstMaterial?.diffuse.contents = UIColor.darkGray
            shaft.firstMaterial?.metalness.contents = 0.8
            let shaftNode = SCNNode(geometry: shaft)
            shaftNode.position = SCNVector3(0, 7, 0)
            root.addChildNode(shaftNode)
            let canopy = SCNCone(topRadius: 0, bottomRadius: 5, height: 2.5)
            canopy.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(0, 13.5, 0)
            root.addChildNode(canopyNode)

        case .duffelBag:
            let bag = SCNCapsule(capRadius: 3.5, height: 9)
            bag.materials = [fabricMaterial(kind.primaryColor)]
            let bagNode = SCNNode(geometry: bag)
            bagNode.position = SCNVector3(0, 3.5, 0)
            root.addChildNode(bagNode)
            let strap = SCNTorus(ringRadius: 2.2, pipeRadius: 0.25)
            strap.firstMaterial?.diffuse.contents = UIColor.darkGray
            let strapNode = SCNNode(geometry: strap)
            strapNode.position = SCNVector3(0, 6.5, 0)
            strapNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            root.addChildNode(strapNode)

        case .plasticBin:
            let bin = SCNBox(width: 8, height: 5, length: 6, chamferRadius: 0.6)
            bin.materials = [plasticMaterial(kind.primaryColor, alpha: 0.85)]
            let binNode = SCNNode(geometry: bin)
            binNode.position = SCNVector3(0, 2.5, 0)
            root.addChildNode(binNode)
            let lid = SCNBox(width: 8.4, height: 0.5, length: 6.4, chamferRadius: 0.3)
            lid.materials = [plasticMaterial(darken(kind.primaryColor, by: 0.08), alpha: 0.9)]
            let lidNode = SCNNode(geometry: lid)
            lidNode.position = SCNVector3(0, 5.2, 0)
            root.addChildNode(lidNode)

        case .recycleCan:
            root.addChildNode(makeCan(radius: 1.6, height: 4.2, color: kind.primaryColor))

        case .recycleBottle:
            let bottle = SCNCylinder(radius: 1.4, height: 7)
            bottle.materials = [plasticMaterial(kind.primaryColor, alpha: 0.75)]
            let bottleNode = SCNNode(geometry: bottle)
            bottleNode.position = SCNVector3(0, 3.5, 0)
            root.addChildNode(bottleNode)
            let cap = SCNCylinder(radius: 1.5, height: 0.8)
            cap.firstMaterial?.diffuse.contents = UIColor.white
            let capNode = SCNNode(geometry: cap)
            capNode.position = SCNVector3(0, 7.2, 0)
            root.addChildNode(capNode)

        case .waterBottle:
            let bottle = SCNCylinder(radius: 1.3, height: 6.5)
            bottle.materials = [plasticMaterial(kind.primaryColor, alpha: 0.8)]
            let bottleNode = SCNNode(geometry: bottle)
            bottleNode.position = SCNVector3(0, 3.2, 0)
            root.addChildNode(bottleNode)

        case .snackBag:
            let bag = SCNBox(width: 5, height: 7, length: 2.5, chamferRadius: 0.5)
            bag.materials = [fabricMaterial(kind.primaryColor)]
            let bagNode = SCNNode(geometry: bag)
            bagNode.position = SCNVector3(0, 3.5, 0)
            root.addChildNode(bagNode)
            let crimp = SCNBox(width: 5.2, height: 0.8, length: 2.7, chamferRadius: 0.2)
            crimp.firstMaterial?.diffuse.contents = darken(kind.primaryColor, by: 0.12)
            let crimpNode = SCNNode(geometry: crimp)
            crimpNode.position = SCNVector3(0, 7.2, 0)
            root.addChildNode(crimpNode)

        case .wipesPack:
            let pack = SCNBox(width: 5.5, height: 1.2, length: 3.5, chamferRadius: 0.4)
            pack.materials = [plasticMaterial(kind.primaryColor, alpha: 0.95)]
            let packNode = SCNNode(geometry: pack)
            packNode.position = SCNVector3(0, 0.6, 0)
            root.addChildNode(packNode)
            let lid = SCNBox(width: 4.5, height: 0.3, length: 2.8, chamferRadius: 0.2)
            lid.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 0.55, blue: 0.85, alpha: 1)
            let lidNode = SCNNode(geometry: lid)
            lidNode.position = SCNVector3(0, 1.2, 0)
            root.addChildNode(lidNode)

        case .toiletryBag:
            let pouch = SCNBox(width: 5, height: 3, length: 2, chamferRadius: 0.8)
            pouch.materials = [plasticMaterial(kind.primaryColor, alpha: 0.9)]
            let pouchNode = SCNNode(geometry: pouch)
            pouchNode.position = SCNVector3(0, 1.5, 0)
            root.addChildNode(pouchNode)
            let zip = SCNBox(width: 4.2, height: 0.2, length: 0.3, chamferRadius: 0.05)
            zip.firstMaterial?.diffuse.contents = UIColor.darkGray
            let zipNode = SCNNode(geometry: zip)
            zipNode.position = SCNVector3(0, 2.8, 0)
            root.addChildNode(zipNode)

        case .cardboardSheet:
            let sheet = SCNBox(width: 10, height: 0.35, length: 8, chamferRadius: 0.15)
            sheet.materials = [cardboardMaterial(kind.primaryColor)]
            let node = SCNNode(geometry: sheet)
            node.eulerAngles = SCNVector3(0.05, 0.15, 0)
            root.addChildNode(node)

        case .cardboardSign:
            let board = SCNBox(width: 7, height: 5, length: 0.35, chamferRadius: 0.15)
            board.materials = [cardboardMaterial(kind.primaryColor)]
            let boardNode = SCNNode(geometry: board)
            boardNode.position = SCNVector3(0, 2.5, 0)
            root.addChildNode(boardNode)
            let post = SCNCylinder(radius: 0.25, height: 5)
            post.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1)
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(-2.8, 2.5, 0)
            postNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            root.addChildNode(postNode)
        }

        root.scale = SCNVector3(scale, scale, scale)
        return root
    }

    static func makeBasketLoot(seed: String, count: Int = 8) -> SCNNode {
        let root = SCNNode()
        root.name = "basketLoot"
        var hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }

        // Ensure at least one item from each category when count allows
        var selected: [CartBelongingKind] = []
        for category in CartBelongingCategory.allCases {
            let options = CartBelongingKind.allCases.filter { $0.category == category }
            hash = (hash &* 37 &+ category.hashValue) % 10_000
            if !options.isEmpty {
                let pick = options[hash % options.count]
                selected.append(pick)
            }
        }
        while selected.count < count {
            hash = (hash &* 31 &+ selected.count) % 10_000
            let kind = CartBelongingKind.allCases[hash % CartBelongingKind.allCases.count]
            selected.append(kind)
        }

        let positions: [SCNVector3] = [
            SCNVector3(-7, 1.5, -2), SCNVector3(6, 1.5, -1), SCNVector3(-3, 1.5, 3),
            SCNVector3(7, 4, 1), SCNVector3(-6, 4.5, 2), SCNVector3(0, 5.5, -1),
            SCNVector3(4, 6.5, -2), SCNVector3(-2, 7, 0), SCNVector3(5, 8, 1),
            SCNVector3(-5, 8.5, -1),
        ]

        for index in 0..<min(count, positions.count) {
            hash = (hash &* 31 &+ index) % 10_000
            let kind = selected[index]
            let item = makeCartBelonging(kind, scale: 0.8 + Float(hash % 18) / 100)
            item.position = positions[index]
            item.eulerAngles = SCNVector3(
                Float(hash % 40) / 200,
                Float(hash % 628) / 100,
                Float(hash % 30) / 200
            )
            root.addChildNode(item)
        }
        return root
    }

    static func makeExteriorAttachments(seed: String) -> SCNNode {
        let root = SCNNode()
        root.name = "exteriorLoot"
        var hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }

        // Tarp draped over cart side
        let tarp = SCNBox(width: 14, height: 0.2, length: 20, chamferRadius: 0.2)
        tarp.materials = [plasticMaterial(UIColor(red: 0.12, green: 0.38, blue: 0.25, alpha: 1), alpha: 0.85)]
        let tarpNode = SCNNode(geometry: tarp)
        tarpNode.position = SCNVector3(14, 12, -8)
        tarpNode.eulerAngles = SCNVector3(0.1, 0, -0.35)
        root.addChildNode(tarpNode)

        hash = (hash &* 17) % 10_000
        if hash % 2 == 0 {
            let umbrella = makeCartBelonging(.umbrella, scale: 0.7)
            umbrella.position = SCNVector3(-14, 10, -6)
            umbrella.eulerAngles = SCNVector3(0.2, 0.4, -0.15)
            root.addChildNode(umbrella)
        } else {
            let cardboard = makeCartBelonging(.cardboardSheet, scale: 0.75)
            cardboard.position = SCNVector3(-13, 11, -10)
            cardboard.eulerAngles = SCNVector3(0, 0.5, 0.1)
            root.addChildNode(cardboard)
        }

        let bag = makeCartBelonging(.duffelBag, scale: 0.65)
        bag.position = SCNVector3(0, 6, 16)
        root.addChildNode(bag)

        return root
    }

    private static func fabricMaterial(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = 0.85
        material.metalness.contents = 0.02
        return material
    }

    private static func plasticMaterial(_ color: UIColor, alpha: CGFloat = 1) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(alpha)
        material.roughness.contents = 0.35
        material.metalness.contents = 0.1
        material.transparency = alpha < 1 ? 1 - alpha : 0
        material.isDoubleSided = alpha < 0.9
        return material
    }

    private static func cardboardMaterial(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = 0.95
        material.metalness.contents = 0
        return material
    }

    private static func darken(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - amount, 0), green: max(g - amount, 0), blue: max(b - amount, 0), alpha: a)
    }

    // Legacy alias for shelf props
    static func makeGroceryLoot(_ kind: CartBelongingKind, scale: Float = 1) -> SCNNode {
        makeCartBelonging(kind, scale: scale)
    }
}
