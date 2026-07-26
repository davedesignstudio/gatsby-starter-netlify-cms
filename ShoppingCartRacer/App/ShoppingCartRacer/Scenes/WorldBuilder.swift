import SpriteKit

/// Builds the static parts of the shop: floor, the aisle the race runs down, the
/// shelving that lines it and the scenery beyond. Everything comes from
/// `TrackArtPlan`, so what gets drawn is exactly what the tests assert about.
struct WorldBuilder {
    let track: Track
    let plan: TrackArtPlan
    let factory: ArtFactory
    /// Scene points per simulation metre.
    let metre: CGFloat

    func point(_ world: Vector2) -> CGPoint {
        CGPoint(x: CGFloat(world.x) * metre, y: CGFloat(world.y) * metre)
    }

    /// Layer ordering, low to high.
    enum Layer: CGFloat {
        case floor = 0
        case shoulder = 5
        case surface = 10
        case markings = 15
        case pads = 18
        case props = 30
        case obstacles = 35
        case hazards = 20
        case pickups = 40
        case lights = 80
        case vignette = 90
    }

    // MARK: - Floor

    /// Tiles the whole shop floor, with a margin so the edges are never visible.
    func buildFloor() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.floor.rawValue

        let texture = factory.floorTileTexture()
        let tileMetres: CGFloat = 4
        let tileSize = CGSize(width: tileMetres * metre, height: tileMetres * metre)
        let margin: CGFloat = 24

        let minX = CGFloat(plan.bounds.min.x) - margin
        let maxX = CGFloat(plan.bounds.max.x) + margin
        let minY = CGFloat(plan.bounds.min.y) - margin
        let maxY = CGFloat(plan.bounds.max.y) + margin

        // A dark backdrop so gaps between tiles never flash through.
        let backdrop = SKSpriteNode(color: UIColor(plan.palette.backdrop), size: CGSize(
            width: (maxX - minX) * metre,
            height: (maxY - minY) * metre
        ))
        backdrop.position = CGPoint(x: (minX + maxX) / 2 * metre, y: (minY + maxY) / 2 * metre)
        backdrop.zPosition = -1
        container.addChild(backdrop)

        var y = minY
        while y < maxY {
            var x = minX
            while x < maxX {
                let tile = SKSpriteNode(texture: texture)
                tile.size = tileSize
                tile.position = CGPoint(x: (x + tileMetres / 2) * metre, y: (y + tileMetres / 2) * metre)
                container.addChild(tile)
                x += tileMetres
            }
            y += tileMetres
        }
        return container
    }

    // MARK: - Aisle ribbon

    /// The racing surface, drawn as one filled shape per run of identical floor
    /// so the wet patches and carpet read as distinct areas.
    func buildRacingSurface() -> SKNode {
        let container = SKNode()

        let shoulder = SKShapeNode(path: ribbonPath(useShoulder: true))
        shoulder.fillColor = UIColor(plan.palette.shoulder, alpha: 0.95)
        shoulder.strokeColor = .clear
        shoulder.zPosition = Layer.shoulder.rawValue
        container.addChild(shoulder)

        for run in surfaceRuns() {
            let shape = SKShapeNode(path: ribbonPath(useShoulder: false, range: run.range))
            shape.fillColor = UIColor(Palette.tint(for: run.surface))
            shape.strokeColor = .clear
            shape.zPosition = Layer.surface.rawValue
            container.addChild(shape)

            if run.surface == .wetFloor || run.surface == .freezerFrost {
                // A brighter sheen on top so slippery ground is obvious at a glance.
                let sheen = SKShapeNode(path: ribbonPath(useShoulder: false, range: run.range))
                sheen.fillColor = UIColor(RacerColor(0.9, 0.98, 1), alpha: 0.28)
                sheen.strokeColor = .clear
                sheen.zPosition = Layer.surface.rawValue + 1
                sheen.blendMode = .add
                container.addChild(sheen)
            }
        }
        return container
    }

    private struct SurfaceRun {
        let surface: Surface
        let range: Range<Int>
    }

    /// Groups consecutive slices that share a floor type.
    private func surfaceRuns() -> [SurfaceRun] {
        guard !plan.slices.isEmpty else { return [] }
        var runs: [SurfaceRun] = []
        var startIndex = 0
        for index in 1...plan.slices.count {
            let ended = index == plan.slices.count || plan.slices[index].surface != plan.slices[startIndex].surface
            if ended {
                // Overlap by one slice so there is no seam between runs.
                let end = min(index + 1, plan.slices.count)
                runs.append(SurfaceRun(surface: plan.slices[startIndex].surface, range: startIndex..<end))
                startIndex = index
            }
        }
        // Close the loop back onto the first slice.
        if let last = runs.last, last.range.upperBound == plan.slices.count {
            runs[runs.count - 1] = SurfaceRun(surface: last.surface, range: last.range)
        }
        return runs
    }

    /// Builds a closed polygon down one side of the aisle and back up the other.
    private func ribbonPath(useShoulder: Bool, range: Range<Int>? = nil) -> CGPath {
        let path = CGMutablePath()
        let slices = plan.slices
        guard !slices.isEmpty else { return path }

        let indices: [Int]
        if let range {
            indices = Array(range).map { $0 % slices.count }
        } else {
            indices = Array(slices.indices) + [0]
        }
        guard indices.count > 1 else { return path }

        var started = false
        for index in indices {
            let slice = slices[index]
            let world = useShoulder ? slice.shoulderLeft : slice.left
            let scenePoint = point(world)
            if started {
                path.addLine(to: scenePoint)
            } else {
                path.move(to: scenePoint)
                started = true
            }
        }
        for index in indices.reversed() {
            let slice = slices[index]
            let world = useShoulder ? slice.shoulderRight : slice.right
            path.addLine(to: point(world))
        }
        path.closeSubpath()
        return path
    }

    /// Shelving walls, drawn as a thick stroke just outside the run-off so the
    /// aisle feels enclosed.
    func buildAisleWalls() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.props.rawValue - 1

        for side in [true, false] {
            let path = CGMutablePath()
            var started = false
            for slice in plan.slices {
                let world = side ? slice.shoulderLeft : slice.shoulderRight
                let scenePoint = point(world)
                if started { path.addLine(to: scenePoint) } else { path.move(to: scenePoint); started = true }
            }
            if let first = plan.slices.first {
                path.addLine(to: point(side ? first.shoulderLeft : first.shoulderRight))
            }

            let wall = SKShapeNode(path: path)
            wall.strokeColor = UIColor(plan.palette.shelfBody)
            wall.lineWidth = metre * 1.1
            wall.lineCap = .round
            wall.fillColor = .clear
            wall.zPosition = 0
            container.addChild(wall)

            let trim = SKShapeNode(path: path)
            trim.strokeColor = UIColor(plan.palette.shelfTrim, alpha: 0.8)
            trim.lineWidth = metre * 0.22
            trim.fillColor = .clear
            trim.zPosition = 1
            container.addChild(trim)
        }
        return container
    }

    // MARK: - Markings

    func buildMarkings() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.markings.rawValue

        let dash = factory.centreDashTexture()
        for marking in plan.centreMarkings {
            let node = SKSpriteNode(texture: dash)
            node.size = CGSize(
                width: dash.size().width / ArtFactory.pixelsPerMetre * metre,
                height: dash.size().height / ArtFactory.pixelsPerMetre * metre
            )
            node.position = point(marking.position)
            node.zRotation = CGFloat(marking.rotation)
            node.alpha = 0.7
            container.addChild(node)
        }

        let startWidth = CGFloat(plan.startLine.halfWidth * 2)
        let start = SKSpriteNode(texture: factory.startLineTexture(width: startWidth))
        start.size = CGSize(width: 2.4 * metre, height: startWidth * metre)
        start.position = point(plan.startLine.position)
        start.zRotation = CGFloat(plan.startLine.rotation)
        start.zPosition = 1
        container.addChild(start)

        return container
    }

    // MARK: - Scenery

    func buildProps() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.props.rawValue
        for prop in plan.props {
            let texture = factory.propTexture(kind: prop.kind, colorIndex: prop.colorIndex)
            let node = SKSpriteNode(texture: texture)
            let footprint = CGFloat(prop.kind.radius * 2 * prop.scale) * metre
            node.size = CGSize(width: footprint, height: footprint)
            node.position = point(prop.position)
            node.zRotation = CGFloat(prop.rotation)
            container.addChild(node)
        }
        return container
    }

    func buildObstacles() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.obstacles.rawValue
        for obstacle in track.definition.obstacles {
            let texture = factory.obstacleTexture(kind: obstacle.kind, radius: obstacle.radius)
            let node = SKSpriteNode(texture: texture)
            let footprint = CGFloat(obstacle.radius * 2.2) * metre
            node.size = CGSize(width: footprint, height: footprint)
            node.position = point(obstacle.position)
            node.zRotation = CGFloat(track.geometry.location(of: obstacle.position).tangentAngle)
            container.addChild(node)
        }
        return container
    }

    func buildBoostPads() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.pads.rawValue
        let texture = factory.boostPadTexture()
        for pad in track.definition.boostPads {
            let node = SKSpriteNode(texture: texture)
            let footprint = CGFloat(pad.radius * 2.4) * metre
            node.size = CGSize(width: footprint, height: footprint)
            node.position = point(pad.position)
            node.zRotation = CGFloat(track.geometry.location(of: pad.position).tangentAngle)
            // A slow pulse so they read as active.
            node.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.65, duration: 0.6),
                .fadeAlpha(to: 1.0, duration: 0.6)
            ])))
            container.addChild(node)
        }
        return container
    }

    /// Overhead strip lights, added additively for a bit of shop glare.
    func buildLighting() -> SKNode {
        let container = SKNode()
        container.zPosition = Layer.lights.rawValue
        container.alpha = 0.5

        for light in plan.lights {
            let texture = factory.stripLightTexture(length: CGFloat(light.length))
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(
                width: CGFloat(light.length) * metre,
                height: 1.6 * metre
            )
            node.position = point(light.position)
            node.zRotation = CGFloat(light.rotation)
            node.blendMode = .add
            container.addChild(node)
        }
        return container
    }
}
