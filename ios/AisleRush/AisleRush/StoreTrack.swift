import SpriteKit

enum StoreTrack {
    static let outerBounds = CGRect(x: -1_120, y: -650, width: 2_240, height: 1_300)
    static let innerBounds = CGRect(x: -720, y: -240, width: 1_440, height: 480)

    static let route: [CGPoint] = [
        CGPoint(x: 0, y: -440),
        CGPoint(x: 760, y: -440),
        CGPoint(x: 970, y: -230),
        CGPoint(x: 970, y: 230),
        CGPoint(x: 760, y: 440),
        CGPoint(x: 0, y: 440),
        CGPoint(x: -760, y: 440),
        CGPoint(x: -970, y: 230),
        CGPoint(x: -970, y: -230),
        CGPoint(x: -760, y: -440)
    ]

    // Racers must visit these in order. The start line is last so a lap
    // cannot be earned by reversing over it.
    static let checkpoints: [CGPoint] = [
        CGPoint(x: 970, y: 0),
        CGPoint(x: 0, y: 440),
        CGPoint(x: -970, y: 0),
        CGPoint(x: 0, y: -440)
    ]

    static func build(in world: SKNode) {
        let storeFloor = SKShapeNode(rect: CGRect(x: -1_450, y: -900, width: 2_900, height: 1_800))
        storeFloor.fillColor = SKColor(red: 0.13, green: 0.16, blue: 0.20, alpha: 1)
        storeFloor.strokeColor = .clear
        storeFloor.zPosition = -50
        world.addChild(storeFloor)

        addFloorTiles(to: world)

        let track = SKShapeNode(rect: outerBounds, cornerRadius: 150)
        track.fillColor = SKColor(red: 0.35, green: 0.38, blue: 0.42, alpha: 1)
        track.strokeColor = SKColor(red: 0.98, green: 0.73, blue: 0.12, alpha: 1)
        track.lineWidth = 18
        track.zPosition = -30
        world.addChild(track)

        let infield = SKShapeNode(rect: innerBounds, cornerRadius: 42)
        infield.fillColor = SKColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
        infield.strokeColor = SKColor(red: 0.82, green: 0.85, blue: 0.88, alpha: 1)
        infield.lineWidth = 10
        infield.zPosition = -20
        world.addChild(infield)

        addRouteGuide(to: world)
        addStartLine(to: world)
        addShelves(to: world)
        addDepartmentSigns(to: world)
        addWalls(to: world)
    }

    static func progress(at point: CGPoint) -> CGFloat {
        var lengths: [CGFloat] = []
        var totalLength: CGFloat = 0

        for index in route.indices {
            let nextIndex = (index + 1) % route.count
            let length = distance(route[index], route[nextIndex])
            lengths.append(length)
            totalLength += length
        }

        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestProgress: CGFloat = 0
        var traversed: CGFloat = 0

        for index in route.indices {
            let start = route[index]
            let end = route[(index + 1) % route.count]
            let segment = CGPoint(x: end.x - start.x, y: end.y - start.y)
            let lengthSquared = segment.x * segment.x + segment.y * segment.y
            let offset = CGPoint(x: point.x - start.x, y: point.y - start.y)
            let projection = max(0, min(1, (offset.x * segment.x + offset.y * segment.y) / lengthSquared))
            let closest = CGPoint(x: start.x + segment.x * projection, y: start.y + segment.y * projection)
            let candidateDistance = distance(point, closest)

            if candidateDistance < bestDistance {
                bestDistance = candidateDistance
                bestProgress = (traversed + lengths[index] * projection) / totalLength
            }

            traversed += lengths[index]
        }

        return bestProgress
    }

    static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func addFloorTiles(to world: SKNode) {
        for x in stride(from: -1_400, through: 1_400, by: 100) {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: 1_800))
            line.fillColor = SKColor(white: 1, alpha: 0.025)
            line.strokeColor = .clear
            line.position.x = CGFloat(x)
            line.zPosition = -45
            world.addChild(line)
        }

        for y in stride(from: -850, through: 850, by: 100) {
            let line = SKShapeNode(rectOf: CGSize(width: 2_900, height: 2))
            line.fillColor = SKColor(white: 1, alpha: 0.025)
            line.strokeColor = .clear
            line.position.y = CGFloat(y)
            line.zPosition = -45
            world.addChild(line)
        }
    }

    private static func addRouteGuide(to world: SKNode) {
        let path = CGMutablePath()
        path.move(to: route[0])
        for point in route.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()

        let guide = SKShapeNode(path: path)
        guide.strokeColor = SKColor(white: 1, alpha: 0.12)
        guide.lineWidth = 5
        guide.lineJoin = .round
        guide.zPosition = -10
        world.addChild(guide)
    }

    private static func addStartLine(to world: SKNode) {
        for row in 0..<9 {
            for column in 0..<2 {
                let square = SKShapeNode(rectOf: CGSize(width: 24, height: 24))
                square.fillColor = (row + column).isMultiple(of: 2) ? .white : .black
                square.strokeColor = .clear
                square.position = CGPoint(x: CGFloat(column * 24 - 12), y: CGFloat(row * 24 - 536))
                square.zPosition = -5
                world.addChild(square)
            }
        }
    }

    private static func addShelves(to world: SKNode) {
        let colors: [SKColor] = [.systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]
        for (index, y) in [-170, 0, 170].enumerated() {
            let shelf = SKShapeNode(rectOf: CGSize(width: 1_160, height: 92), cornerRadius: 14)
            shelf.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.15, alpha: 1)
            shelf.strokeColor = SKColor(red: 0.72, green: 0.55, blue: 0.32, alpha: 1)
            shelf.lineWidth = 8
            shelf.position = CGPoint(x: 0, y: CGFloat(y))
            shelf.zPosition = -10
            world.addChild(shelf)

            for productIndex in 0..<15 {
                let product = SKShapeNode(rectOf: CGSize(width: 48, height: 56), cornerRadius: 5)
                product.fillColor = colors[(productIndex + index) % colors.count]
                product.strokeColor = SKColor(white: 1, alpha: 0.35)
                product.lineWidth = 2
                product.position = CGPoint(x: CGFloat(productIndex * 76 - 532), y: CGFloat(y))
                product.zPosition = -8
                world.addChild(product)
            }
        }
    }

    private static func addDepartmentSigns(to world: SKNode) {
        let signs: [(String, CGPoint, SKColor)] = [
            ("FROZEN", CGPoint(x: 0, y: 700), .systemBlue),
            ("PRODUCE", CGPoint(x: -1_210, y: 0), .systemGreen),
            ("CHECKOUT", CGPoint(x: 0, y: -700), .systemOrange),
            ("SNACKS", CGPoint(x: 1_210, y: 0), .systemPink)
        ]

        for (text, position, color) in signs {
            let sign = SKShapeNode(rectOf: CGSize(width: 250, height: 70), cornerRadius: 16)
            sign.fillColor = color.withAlphaComponent(0.85)
            sign.strokeColor = .white
            sign.lineWidth = 4
            sign.position = position
            sign.zPosition = -10

            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = text
            label.fontSize = 28
            label.verticalAlignmentMode = .center
            sign.addChild(label)
            world.addChild(sign)
        }
    }

    private static func addWalls(to world: SKNode) {
        let outerWall = SKNode()
        outerWall.name = "outerWall"
        outerWall.physicsBody = SKPhysicsBody(edgeLoopFrom: outerBounds)
        outerWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        outerWall.physicsBody?.collisionBitMask = PhysicsCategory.cart
        outerWall.physicsBody?.friction = 0.25
        world.addChild(outerWall)

        let innerWall = SKNode()
        innerWall.name = "innerWall"
        innerWall.physicsBody = SKPhysicsBody(edgeLoopFrom: innerBounds)
        innerWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        innerWall.physicsBody?.collisionBitMask = PhysicsCategory.cart
        innerWall.physicsBody?.friction = 0.25
        world.addChild(innerWall)
    }
}
