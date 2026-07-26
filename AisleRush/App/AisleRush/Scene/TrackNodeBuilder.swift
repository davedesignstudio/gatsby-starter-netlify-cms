import SpriteKit
import UIKit
import AisleRushCore

/// Turns a `Track` into the static scenery: floor, shoulders, shelving,
/// markings, boost strips and props. Built once when the race loads.
enum TrackNodeBuilder {
    /// World points per metre.
    static let scale: CGFloat = 12

    struct Scenery {
        var floor: SKNode
        var markings: SKNode
        var shelving: SKNode
        var fittings: SKNode
        var lighting: SKNode
        /// Item crate sprites, in the same order as `track.itemBoxes`.
        var crates: [SKSpriteNode]
        /// Prop sprites, in the same order as `track.props`.
        var props: [SKSpriteNode]
        var bounds: CGRect
    }

    static func build(track: Track) -> Scenery {
        let theme = track.definition.theme
        let shelfDepth = 7.0

        let outerBand = ribbon(
            track: track,
            lower: { -track.wallDistance(atDistance: $0) },
            upper: { track.wallDistance(atDistance: $0) }
        )

        let floorRoot = SKNode()
        let mask = SKShapeNode(path: outerBand)
        mask.fillColor = .white
        mask.strokeColor = .clear
        mask.isAntialiased = false

        let bounds = outerBand.boundingBox
        let crop = SKCropNode()
        crop.maskNode = mask
        crop.addChild(tiledFloor(theme: theme, covering: bounds))
        floorRoot.addChild(crop)

        // The scuffed strip either side of the racing surface.
        let markings = SKNode()
        for side in [-1.0, 1.0] {
            let shoulder = ribbon(
                track: track,
                lower: { side < 0 ? -track.wallDistance(atDistance: $0) : track.halfWidth(atDistance: $0) },
                upper: { side < 0 ? -track.halfWidth(atDistance: $0) : track.wallDistance(atDistance: $0) }
            )
            let node = SKShapeNode(path: shoulder)
            node.fillColor = UIColor(white: 0.15, alpha: 0.16)
            node.strokeColor = .clear
            node.zPosition = 1
            markings.addChild(node)
        }

        // Aisle edge markings.
        for side in [-1.0, 1.0] {
            let line = edgeLine(track: track, side: side)
            line.strokeColor = theme.accentTint.uiColor.withAlphaComponent(0.55)
            line.lineWidth = 2.5
            line.zPosition = 2
            markings.addChild(line)
        }
        markings.addChild(surfacePatchOverlay(track: track))
        markings.addChild(startLineNode(track: track))

        let shelving = shelfNodes(track: track, depth: shelfDepth)
        let fittings = SKNode()

        // SpriteKit sorts on cumulative z, so these are relative to the
        // fittings node. Keeping them small leaves the carts on top.
        var crates: [SKSpriteNode] = []
        let crateTexture = TextureFactory.itemCrate()
        for box in track.itemBoxes {
            let sprite = SKSpriteNode(texture: crateTexture)
            sprite.size = CGSize(width: 2.6 * scale, height: 2.6 * scale)
            sprite.position = box.position.point
            sprite.zPosition = 1
            fittings.addChild(sprite)
            crates.append(sprite)
        }

        var props: [SKSpriteNode] = []
        for prop in track.props {
            let sprite = SKSpriteNode(texture: TextureFactory.prop(prop.kind))
            let side = CGFloat(prop.radius) * 2.6 * scale
            sprite.size = CGSize(width: side, height: side)
            sprite.position = prop.position.point
            sprite.zRotation = CGFloat(prop.angle)
            sprite.zPosition = 2
            fittings.addChild(sprite)
            props.append(sprite)
        }

        for zone in track.boostZones {
            let sprite = SKSpriteNode(texture: TextureFactory.boostStrip())
            sprite.size = CGSize(width: CGFloat(zone.length) * scale, height: CGFloat(zone.width) * scale)
            sprite.position = zone.position.point
            sprite.zRotation = CGFloat(zone.angle)
            sprite.zPosition = 0
            sprite.blendMode = .add
            sprite.alpha = 0.85
            sprite.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.6),
                .fadeAlpha(to: 0.95, duration: 0.6)
            ])))
            fittings.addChild(sprite)
        }

        return Scenery(
            floor: floorRoot,
            markings: markings,
            shelving: shelving,
            fittings: fittings,
            lighting: ceilingLights(track: track, theme: theme),
            crates: crates,
            props: props,
            bounds: bounds
        )
    }

    // MARK: - Pieces

    /// Distance between outline points, in metres. The centreline is sampled
    /// every metre, which would give a shape node over a thousand points long;
    /// at this spacing the chord error is under a centimetre and SpriteKit has
    /// a great deal less to rasterise.
    private static let outlineSpacing: Double = 2.5

    /// A closed band between two lateral offsets: down one edge and back along
    /// the other.
    static func ribbon(
        track: Track,
        lower: (Double) -> Double,
        upper: (Double) -> Double
    ) -> CGPath {
        let path = CGMutablePath()
        let steps = max(24, Int(track.length / outlineSpacing))
        let step = track.length / Double(steps)

        for index in 0...steps {
            let distance = Double(index % steps) * step
            let point = track.position(distance: distance, lateral: upper(distance))
            if index == 0 { path.move(to: point.point) } else { path.addLine(to: point.point) }
        }
        for index in 0...steps {
            let distance = Double((steps - index) % steps) * step
            path.addLine(to: track.position(distance: distance, lateral: lower(distance)).point)
        }
        path.closeSubpath()
        return path
    }

    private static func tiledFloor(theme: TrackTheme, covering bounds: CGRect) -> SKNode {
        let node = SKNode()
        let texture = TextureFactory.floorTile(theme: theme)
        let tileSide: CGFloat = 12 * scale
        let columns = Int(ceil(bounds.width / tileSide)) + 1
        let rows = Int(ceil(bounds.height / tileSide)) + 1
        for column in 0..<columns {
            for row in 0..<rows {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = CGSize(width: tileSide, height: tileSide)
                sprite.anchorPoint = .zero
                sprite.position = CGPoint(
                    x: bounds.minX + CGFloat(column) * tileSide,
                    y: bounds.minY + CGFloat(row) * tileSide
                )
                node.addChild(sprite)
            }
        }
        return node
    }

    private static func edgeLine(track: Track, side: Double) -> SKShapeNode {
        let path = CGMutablePath()
        let steps = max(24, Int(track.length / outlineSpacing))
        let step = track.length / Double(steps)
        for index in 0...steps {
            let distance = Double(index % steps) * step
            let point = track.position(distance: distance, lateral: side * track.halfWidth(atDistance: distance))
            if index == 0 { path.move(to: point.point) } else { path.addLine(to: point.point) }
        }
        let node = SKShapeNode(path: path)
        node.fillColor = .clear
        node.lineCap = .round
        return node
    }

    /// Tints the authored ice, wet and cardboard sections so the hazard is
    /// legible before you are sliding through it.
    private static func surfacePatchOverlay(track: Track) -> SKNode {
        let root = SKNode()
        for patch in track.definition.surfacePatches {
            let color: UIColor
            switch patch.surface {
            case .ice: color = UIColor(red: 0.65, green: 0.88, blue: 1, alpha: 0.4)
            case .wet: color = UIColor(red: 0.6, green: 0.75, blue: 0.95, alpha: 0.32)
            case .cardboard: color = UIColor(red: 0.72, green: 0.58, blue: 0.36, alpha: 0.4)
            case .scuffed: color = UIColor(white: 0.4, alpha: 0.2)
            default: continue
            }

            let start = patch.progress.lowerBound * track.length
            let end = min(patch.progress.upperBound, 1.0) * track.length
            let path = CGMutablePath()
            var distance = start
            var forward: [CGPoint] = []
            var backward: [CGPoint] = []
            while distance <= end {
                let half = track.halfWidth(atDistance: distance)
                forward.append(track.position(distance: distance, lateral: patch.lateralBand.upperBound * half).point)
                backward.append(track.position(distance: distance, lateral: patch.lateralBand.lowerBound * half).point)
                distance += track.sampleSpacing
            }
            guard forward.count > 1 else { continue }
            path.addLines(between: forward)
            path.addLines(between: backward.reversed())
            path.closeSubpath()

            let node = SKShapeNode(path: path)
            node.fillColor = color
            node.strokeColor = color.withAlphaComponent(0.65)
            node.lineWidth = 2
            node.zPosition = 2.5
            root.addChild(node)
        }
        return root
    }

    private static func startLineNode(track: Track) -> SKNode {
        let sprite = SKSpriteNode(texture: TextureFactory.startLine())
        let width = track.wallDistance(atDistance: 0) * 2
        sprite.size = CGSize(width: 2.2 * scale, height: CGFloat(width) * scale)
        sprite.position = track.point(atDistance: 0).point
        sprite.zRotation = CGFloat(track.tangent(atDistance: 0).angle)
        sprite.zPosition = 4
        sprite.alpha = 0.9
        return sprite
    }

    private static func shelfNodes(track: Track, depth: Double) -> SKNode {
        let root = SKNode()
        let theme = track.definition.theme

        for side in [-1.0, 1.0] {
            let band = ribbon(
                track: track,
                lower: { side < 0 ? -(track.wallDistance(atDistance: $0) + depth) : track.wallDistance(atDistance: $0) },
                upper: { side < 0 ? -track.wallDistance(atDistance: $0) : track.wallDistance(atDistance: $0) + depth }
            )
            let base = SKShapeNode(path: band)
            base.fillColor = theme.shelfTint.uiColor.adjusted(by: -0.12)
            base.strokeColor = theme.shelfTint.uiColor.adjusted(by: 0.08)
            base.lineWidth = 3
            base.zPosition = 20
            root.addChild(base)
        }

        // Product faces along the aisle, spaced to read as separate units.
        let spacing = 3.0
        var distance = 0.0
        var variant = 0
        while distance < track.length {
            for side in [-1.0, 1.0] {
                let lateral = side * (track.wallDistance(atDistance: distance) + depth * 0.42)
                let sprite = SKSpriteNode(texture: TextureFactory.shelfSegment(theme: theme, variant: variant % 6))
                sprite.size = CGSize(width: CGFloat(spacing) * scale * 1.02, height: CGFloat(depth) * 0.7 * scale)
                sprite.position = track.position(distance: distance, lateral: lateral).point
                sprite.zRotation = CGFloat(track.tangent(atDistance: distance).angle)
                sprite.zPosition = 21
                root.addChild(sprite)
                variant += 1
            }
            distance += spacing
        }

        // A soft drop shadow at the foot of the shelving sells the height.
        for side in [-1.0, 1.0] {
            let shadow = ribbon(
                track: track,
                lower: { side < 0 ? -track.wallDistance(atDistance: $0) : track.wallDistance(atDistance: $0) - 1.2 },
                upper: { side < 0 ? -(track.wallDistance(atDistance: $0) - 1.2) : track.wallDistance(atDistance: $0) }
            )
            let node = SKShapeNode(path: shadow)
            node.fillColor = UIColor(white: 0, alpha: 0.22)
            node.strokeColor = .clear
            node.zPosition = 19
            root.addChild(node)
        }

        return root
    }

    private static func ceilingLights(track: Track, theme: TrackTheme) -> SKNode {
        let root = SKNode()
        let texture = TextureFactory.softDot()
        var distance = 0.0
        while distance < track.length {
            let sprite = SKSpriteNode(texture: texture)
            let side = 26 * scale
            sprite.size = CGSize(width: side, height: side)
            sprite.position = track.point(atDistance: distance).point
            sprite.zPosition = 30
            sprite.blendMode = .add
            sprite.alpha = 0.09
            sprite.color = theme.ambientTint.uiColor
            sprite.colorBlendFactor = 1
            root.addChild(sprite)
            distance += 26
        }
        return root
    }
}

extension Vector2 {
    /// World metres to scene points.
    var point: CGPoint {
        CGPoint(x: CGFloat(x) * TrackNodeBuilder.scale, y: CGFloat(y) * TrackNodeBuilder.scale)
    }
}
