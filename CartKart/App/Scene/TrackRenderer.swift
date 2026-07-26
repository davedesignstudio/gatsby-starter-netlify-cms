import CartKartCore
import SpriteKit

/// Draw order for everything in the race scene.
enum Layer {
    static let floor: CGFloat = 0
    static let markings: CGFloat = 1
    static let puddle: CGFloat = 2
    static let boostPad: CGFloat = 3
    static let hazard: CGFloat = 4
    static let shadow: CGFloat = 5
    static let obstacle: CGFloat = 6
    static let itemBox: CGFloat = 7
    static let cart: CGFloat = 10
    static let effect: CGFloat = 14
    static let projectile: CGFloat = 16
    static let shelf: CGFloat = 20
}

/// Builds the static scenery for a course: floor, shoulders, shelving,
/// markings and props. Everything here is created once when a race loads.
enum TrackRenderer {
    static func buildWorld(for track: Track) -> SKNode {
        let world = SKNode()
        world.addChild(shoulderNode(track))
        world.addChild(floorNode(track))
        world.addChild(markingsNode(track))
        world.addChild(finishLineNode(track))
        for puddle in track.puddles {
            world.addChild(puddleNode(puddle, theme: track.theme))
        }
        for pad in track.boostPads {
            world.addChild(boostPadNode(pad, track: track))
        }
        world.addChild(shelvingNode(track))
        return world
    }

    // MARK: - Surfaces

    private static func edgePath(_ track: Track, inset: Double) -> CGPath {
        let path = CGMutablePath()
        let samples = track.samples
        // Out along the left edge...
        for (index, sample) in samples.enumerated() {
            let point = sample.position + sample.tangent.perpendicular * (sample.halfWidth + inset)
            if index == 0 {
                path.move(to: point.cgPoint)
            } else {
                path.addLine(to: point.cgPoint)
            }
        }
        // ...and back along the right one.
        for sample in samples.reversed() {
            let point = sample.position - sample.tangent.perpendicular * (sample.halfWidth + inset)
            path.addLine(to: point.cgPoint)
        }
        path.closeSubpath()
        return path
    }

    private static func floorNode(_ track: Track) -> SKShapeNode {
        let node = SKShapeNode(path: edgePath(track, inset: 0))
        node.fillTexture = TextureFactory.floorTile(theme: track.theme)
        node.fillColor = .white
        node.strokeColor = track.theme.floor.shaded(0.85)
        node.lineWidth = 5
        node.zPosition = Layer.floor
        node.isAntialiased = true
        return node
    }

    private static func shoulderNode(_ track: Track) -> SKShapeNode {
        let node = SKShapeNode(path: edgePath(track, inset: track.shoulderWidth))
        node.fillColor = track.theme.rough.uiColor
        node.strokeColor = track.theme.rough.shaded(0.8)
        node.lineWidth = 4
        node.zPosition = Layer.floor - 1
        return node
    }

    /// Direction chevrons painted on the floor, so it is always obvious which
    /// way round the aisle you are supposed to be going.
    private static func markingsNode(_ track: Track) -> SKNode {
        let node = SKNode()
        node.zPosition = Layer.markings
        let spacing = 520.0
        var distance = 140.0
        while distance < track.trackLength {
            let index = track.sampleIndex(atArcLength: distance)
            let sample = track.sample(at: index)
            let chevron = SKShapeNode(path: chevronPath())
            chevron.position = sample.position.cgPoint
            chevron.zRotation = sample.tangent.angle
            chevron.strokeColor = track.theme.floor.shaded(0.82)
            chevron.lineWidth = 9
            chevron.lineCap = .round
            chevron.alpha = 0.5
            node.addChild(chevron)
            distance += spacing
        }
        return node
    }

    private static func chevronPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -26, y: -32))
        path.addLine(to: CGPoint(x: 26, y: 0))
        path.addLine(to: CGPoint(x: -26, y: 32))
        return path
    }

    private static func finishLineNode(_ track: Track) -> SKNode {
        let sample = track.sample(at: track.sampleIndex(atArcLength: track.finishArcLength))
        let banner = SKSpriteNode(texture: TextureFactory.finishLine)
        banner.size = CGSize(width: 46, height: sample.halfWidth * 2)
        banner.position = sample.position.cgPoint
        banner.zRotation = sample.tangent.angle
        banner.zPosition = Layer.markings + 0.5
        return banner
    }

    private static func puddleNode(_ puddle: TrackFeature, theme: TrackTheme) -> SKNode {
        let node = SKShapeNode(circleOfRadius: puddle.radius)
        node.position = puddle.position.cgPoint
        node.fillColor = theme.accent.uiColor.withAlphaComponent(0.32)
        node.strokeColor = UIColor.white.withAlphaComponent(0.35)
        node.lineWidth = 3
        node.zPosition = Layer.puddle
        // A slow shimmer so wet floor reads as wet.
        node.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.75, duration: 1.6),
            .fadeAlpha(to: 1.0, duration: 1.6)
        ])))
        return node
    }

    private static func boostPadNode(_ pad: TrackFeature, track: Track) -> SKNode {
        let projection = track.project(pad.position)
        let sprite = SKSpriteNode(texture: TextureFactory.boostPad(theme: track.theme))
        sprite.size = CGSize(width: pad.radius * 3.4, height: pad.radius * 2.6)
        sprite.position = pad.position.cgPoint
        sprite.zRotation = projection.tangent.angle
        sprite.zPosition = Layer.boostPad
        sprite.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.5),
            .fadeAlpha(to: 1.0, duration: 0.5)
        ])))
        return sprite
    }

    /// Shelving units lining both sides of the aisle.
    private static func shelvingNode(_ track: Track) -> SKNode {
        let node = SKNode()
        node.zPosition = Layer.shelf
        let texture = TextureFactory.shelf(theme: track.theme)
        let unitLength = 96.0
        var distance = 0.0
        while distance < track.trackLength {
            let index = track.sampleIndex(atArcLength: distance)
            let sample = track.sample(at: index)
            let offset = sample.halfWidth + track.shoulderWidth + 46
            for side in [1.0, -1.0] {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = CGSize(width: unitLength + 6, height: 92)
                sprite.position = (sample.position + sample.tangent.perpendicular * (offset * side)).cgPoint
                sprite.zRotation = sample.tangent.angle
                node.addChild(sprite)
            }
            distance += unitLength
        }
        return node
    }

    // MARK: - Props

    static func obstacleNode(_ obstacle: TrackObstacle, theme: TrackTheme) -> SKNode {
        let sprite = SKSpriteNode(texture: TextureFactory.obstacle(style: obstacle.style, theme: theme))
        sprite.size = CGSize(width: obstacle.radius * 2.3, height: obstacle.radius * 2.3)
        sprite.position = obstacle.position.cgPoint
        sprite.zPosition = Layer.obstacle
        let shadow = SKSpriteNode(texture: TextureFactory.shadow)
        shadow.size = CGSize(width: obstacle.radius * 3, height: obstacle.radius * 3)
        shadow.zPosition = -1
        sprite.addChild(shadow)
        return sprite
    }

    static func itemBoxNode(_ box: ItemBoxState) -> SKNode {
        let sprite = SKSpriteNode(texture: TextureFactory.itemBox)
        sprite.size = CGSize(width: box.radius * 2.4, height: box.radius * 2.4)
        sprite.position = box.position.cgPoint
        sprite.zPosition = Layer.itemBox
        sprite.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.7),
            .scale(to: 0.94, duration: 0.7)
        ])))
        return sprite
    }
}
