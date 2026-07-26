import CoreGraphics
import SpriteKit
import UIKit
import AisleRushCore

/// Every sprite in the game is drawn here with Core Graphics and cached as an
/// `SKTexture`. Nothing ships as a binary asset, so the art scales with the
/// device and recolours per character for free.
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]
    private static var imageCache: [String: UIImage] = [:]

    /// Texture pixels per metre of world space. Generous so carts stay sharp
    /// when the camera zooms in on a photo finish.
    static let pixelsPerMetre: CGFloat = 96

    static func texture(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let texture = SKTexture(image: render(size: size, draw: draw))
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    static func image(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> UIImage {
        if let cached = imageCache[key] { return cached }
        let rendered = render(size: size, draw: draw)
        imageCache[key] = rendered
        return rendered
    }

    /// Renders without caching the intermediate image, for callers that only
    /// want the texture.
    private static func render(size: CGSize, draw: (CGContext, CGSize) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            // UIGraphicsImageRenderer hands over a context flipped to match
            // UIKit. Every drawing routine below is written in Core Graphics'
            // own y-up convention, so put it back.
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            draw(context.cgContext, size)
        }
    }

    static func purgeCache() {
        cache.removeAll()
        imageCache.removeAll()
    }

    /// FNV-1a, so the same string always produces the same artwork.
    static func stableSeed(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01B3
        }
        return hash
    }

    // MARK: - Carts

    /// A shopping cart seen from directly above: basket mesh, handle, casters
    /// and a pile of shopping that says a lot about the driver.
    static func cart(for setup: CartSetup) -> SKTexture {
        let key = "cart-\(setup.character.id)-\(setup.frame.id)-\(setup.wheels.id)"
        let metres = CGSize(width: setup.frame.size.x * 2, height: setup.frame.size.y * 2)
        let size = CGSize(width: metres.width * pixelsPerMetre, height: metres.height * pixelsPerMetre)
        return texture(key, size: size) { context, size in
            drawCart(in: context, size: size, setup: setup)
        }
    }

    /// The same artwork as `cart(for:)`, for use in SwiftUI menus.
    static func cartImage(for setup: CartSetup) -> UIImage {
        let metres = CGSize(width: setup.frame.size.x * 2, height: setup.frame.size.y * 2)
        let size = CGSize(width: metres.width * pixelsPerMetre, height: metres.height * pixelsPerMetre)
        return image("cart-img-\(setup.character.id)-\(setup.frame.id)-\(setup.wheels.id)", size: size) { context, size in
            drawCart(in: context, size: size, setup: setup)
        }
    }

    private static func drawCart(in context: CGContext, size: CGSize, setup: CartSetup) {
        let primary = setup.character.primaryColor.uiColor
        let secondary = setup.character.secondaryColor.uiColor
        let metal = UIColor(white: 0.78, alpha: 1)
        let inset = size.height * 0.08

        // Casters, drawn first so the basket sits on top of them.
        let wheelSize = CGSize(width: size.width * 0.1, height: size.height * 0.13)
        let wheelColor: UIColor
        switch setup.wheels.id {
        case "rubber": wheelColor = UIColor(white: 0.16, alpha: 1)
        case "allterrain": wheelColor = UIColor(red: 0.22, green: 0.2, blue: 0.18, alpha: 1)
        case "glides": wheelColor = UIColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 1)
        default: wheelColor = UIColor(white: 0.35, alpha: 1)
        }
        context.setFillColor(wheelColor.cgColor)
        for x in [size.width * 0.22, size.width * 0.78] {
            for y in [inset * 0.6, size.height - inset * 0.6 - wheelSize.height] {
                let rect = CGRect(x: x - wheelSize.width / 2, y: y, width: wheelSize.width, height: wheelSize.height)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil))
            }
        }
        context.fillPath()

        // Basket: a trapezoid, wider at the back where the handle is.
        let body = CGMutablePath()
        let noseInset = size.height * 0.17
        body.move(to: CGPoint(x: size.width * 0.94, y: noseInset))
        body.addLine(to: CGPoint(x: size.width * 0.94, y: size.height - noseInset))
        body.addLine(to: CGPoint(x: size.width * 0.13, y: size.height - inset))
        body.addLine(to: CGPoint(x: size.width * 0.13, y: inset))
        body.closeSubpath()

        context.setFillColor(metal.cgColor)
        context.addPath(body)
        context.fillPath()

        context.setStrokeColor(primary.cgColor)
        context.setLineWidth(size.height * 0.075)
        context.addPath(body)
        context.strokePath()

        // The wire mesh.
        context.setStrokeColor(UIColor(white: 0.45, alpha: 0.55).cgColor)
        context.setLineWidth(max(1, size.height * 0.02))
        context.saveGState()
        context.addPath(body)
        context.clip()
        var x = size.width * 0.16
        while x < size.width * 0.95 {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: size.height))
            x += size.width * 0.075
        }
        var y = size.height * 0.12
        while y < size.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
            y += size.height * 0.16
        }
        context.strokePath()

        // The shopping. Seeded from the character id rather than `hashValue`,
        // which is salted per process and would reshuffle every launch.
        var random = SeededRandom(seed: stableSeed(setup.character.id))
        let palette = [primary, secondary, UIColor(red: 0.95, green: 0.86, blue: 0.4, alpha: 1),
                       UIColor(red: 0.85, green: 0.35, blue: 0.35, alpha: 1),
                       UIColor(red: 0.4, green: 0.6, blue: 0.85, alpha: 1)]
        for _ in 0..<9 {
            let blobWidth = size.width * CGFloat(random.double(in: 0.1...0.2))
            let blobHeight = size.height * CGFloat(random.double(in: 0.18...0.34))
            let cx = size.width * CGFloat(random.double(in: 0.22...0.85))
            let cy = size.height * CGFloat(random.double(in: 0.2...0.8))
            let color = palette[random.int(in: 0...(palette.count - 1))]
            context.setFillColor(color.withAlphaComponent(0.92).cgColor)
            let rect = CGRect(x: cx - blobWidth / 2, y: cy - blobHeight / 2, width: blobWidth, height: blobHeight)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil))
            context.fillPath()
        }
        context.restoreGState()

        // Handle bar across the back.
        context.setFillColor(secondary.cgColor)
        let handle = CGRect(
            x: size.width * 0.04,
            y: size.height * 0.12,
            width: size.width * 0.07,
            height: size.height * 0.76
        )
        context.addPath(CGPath(roundedRect: handle, cornerWidth: handle.width / 2, cornerHeight: handle.width / 2, transform: nil))
        context.fillPath()

        // Front bumper flash, so you can tell which way it is pointing.
        context.setFillColor(primary.cgColor)
        let bumper = CGRect(
            x: size.width * 0.9,
            y: size.height * 0.2,
            width: size.width * 0.06,
            height: size.height * 0.6
        )
        context.addPath(CGPath(roundedRect: bumper, cornerWidth: 2, cornerHeight: 2, transform: nil))
        context.fillPath()
    }

    static func cartShadow() -> SKTexture {
        texture("cart-shadow", size: CGSize(width: 128, height: 96)) { context, size in
            let colors = [
                UIColor(white: 0, alpha: 0.42).cgColor,
                UIColor(white: 0, alpha: 0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) else { return }
            context.saveGState()
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: 1, y: size.height / size.width)
            context.drawRadialGradient(
                gradient,
                startCenter: .zero,
                startRadius: 0,
                endCenter: .zero,
                endRadius: size.width / 2,
                options: []
            )
            context.restoreGState()
        }
    }

    // MARK: - Floors and fittings

    /// One square of supermarket floor, tiled across the aisles.
    static func floorTile(theme: TrackTheme) -> SKTexture {
        let key = "floor-\(theme.floorTint.hexKey)"
        let tileMetres: CGFloat = 2
        let tilesPerTexture = 6
        let pixels = tileMetres * pixelsPerMetre * 0.5
        let size = CGSize(width: pixels * CGFloat(tilesPerTexture), height: pixels * CGFloat(tilesPerTexture))
        return texture(key, size: size) { context, size in
            context.setFillColor(theme.floorTint.uiColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            var random = SeededRandom(seed: 0xF100)
            let step = size.width / CGFloat(tilesPerTexture)
            for row in 0..<tilesPerTexture {
                for column in 0..<tilesPerTexture {
                    // Vary each tile a shade so the floor is not a flat colour.
                    let shade = CGFloat(random.double(in: -0.035...0.035))
                    context.setFillColor(theme.floorTint.uiColor.adjusted(by: shade).cgColor)
                    context.fill(CGRect(
                        x: CGFloat(column) * step + 1,
                        y: CGFloat(row) * step + 1,
                        width: step - 2,
                        height: step - 2
                    ))
                }
            }

            context.setStrokeColor(theme.groutTint.uiColor.cgColor)
            context.setLineWidth(2)
            for index in 0...tilesPerTexture {
                let offset = CGFloat(index) * step
                context.move(to: CGPoint(x: offset, y: 0))
                context.addLine(to: CGPoint(x: offset, y: size.height))
                context.move(to: CGPoint(x: 0, y: offset))
                context.addLine(to: CGPoint(x: size.width, y: offset))
            }
            context.strokePath()
        }
    }

    /// A run of shelving seen from above: uprights, and rows of product.
    static func shelfSegment(theme: TrackTheme, variant: Int) -> SKTexture {
        let key = "shelf-\(theme.shelfTint.hexKey)-\(variant)"
        let size = CGSize(width: 2 * pixelsPerMetre * 0.5, height: 3 * pixelsPerMetre * 0.5)
        return texture(key, size: size) { context, size in
            let base = theme.shelfTint.uiColor
            context.setFillColor(base.adjusted(by: -0.08).cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            var random = SeededRandom(seed: UInt64(variant) &+ 17)
            let rows = 4
            let rowHeight = size.height / CGFloat(rows)
            for row in 0..<rows {
                let inset: CGFloat = 3
                let y = CGFloat(row) * rowHeight + inset
                var x = inset
                while x < size.width - inset {
                    let width = CGFloat(random.double(in: 6...16))
                    let hue = CGFloat(random.double(in: 0...1))
                    let color = UIColor(
                        hue: hue,
                        saturation: CGFloat(random.double(in: 0.35...0.7)),
                        brightness: CGFloat(random.double(in: 0.6...0.95)),
                        alpha: 1
                    )
                    context.setFillColor(color.cgColor)
                    context.fill(CGRect(x: x, y: y, width: min(width, size.width - inset - x), height: rowHeight - inset * 2))
                    x += width + 2
                }
            }

            // Frame, to read as a physical unit rather than a colour field.
            context.setStrokeColor(base.adjusted(by: 0.12).cgColor)
            context.setLineWidth(4)
            context.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2))
        }
    }

    static func itemCrate() -> SKTexture {
        let side = 3 * pixelsPerMetre * 0.5
        return texture("item-crate", size: CGSize(width: side, height: side)) { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.08)
            let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.18, cornerHeight: rect.width * 0.18, transform: nil)
            context.setFillColor(UIColor(red: 0.98, green: 0.78, blue: 0.25, alpha: 0.95).cgColor)
            context.addPath(path)
            context.fillPath()
            context.setStrokeColor(UIColor(red: 0.62, green: 0.38, blue: 0.08, alpha: 1).cgColor)
            context.setLineWidth(rect.width * 0.08)
            context.addPath(path)
            context.strokePath()

            // Packing tape cross.
            context.setStrokeColor(UIColor(white: 1, alpha: 0.75).cgColor)
            context.setLineWidth(rect.width * 0.09)
            context.move(to: CGPoint(x: rect.minX, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            context.move(to: CGPoint(x: rect.midX, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            context.strokePath()
        }
    }

    static func startLine() -> SKTexture {
        texture("start-line", size: CGSize(width: 64, height: 512)) { context, size in
            let squares = 16
            let step = size.height / CGFloat(squares)
            for index in 0..<squares {
                context.setFillColor((index % 2 == 0 ? UIColor.white : UIColor(white: 0.12, alpha: 1)).cgColor)
                context.fill(CGRect(x: 0, y: CGFloat(index) * step, width: size.width / 2, height: step))
                context.setFillColor((index % 2 == 0 ? UIColor(white: 0.12, alpha: 1) : UIColor.white).cgColor)
                context.fill(CGRect(x: size.width / 2, y: CGFloat(index) * step, width: size.width / 2, height: step))
            }
        }
    }

    static func boostStrip() -> SKTexture {
        texture("boost-strip", size: CGSize(width: 256, height: 128)) { context, size in
            context.setFillColor(UIColor(red: 0.16, green: 0.75, blue: 0.95, alpha: 0.55).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(UIColor(red: 1, green: 1, blue: 1, alpha: 0.85).cgColor)
            for index in 0..<3 {
                let x = size.width * (0.16 + CGFloat(index) * 0.26)
                let chevron = CGMutablePath()
                chevron.move(to: CGPoint(x: x, y: size.height * 0.1))
                chevron.addLine(to: CGPoint(x: x + size.width * 0.16, y: size.height * 0.5))
                chevron.addLine(to: CGPoint(x: x, y: size.height * 0.9))
                chevron.addLine(to: CGPoint(x: x + size.width * 0.06, y: size.height * 0.9))
                chevron.addLine(to: CGPoint(x: x + size.width * 0.22, y: size.height * 0.5))
                chevron.addLine(to: CGPoint(x: x + size.width * 0.06, y: size.height * 0.1))
                chevron.closeSubpath()
                context.addPath(chevron)
            }
            context.fillPath()
        }
    }

    static func spill() -> SKTexture {
        texture("spill", size: CGSize(width: 256, height: 256)) { context, size in
            var random = SeededRandom(seed: 0x5111)
            context.setFillColor(UIColor(white: 0.97, alpha: 0.92).cgColor)
            let blob = CGMutablePath()
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let steps = 22
            for index in 0...steps {
                let angle = CGFloat(index) / CGFloat(steps) * 2 * .pi
                let radius = size.width * CGFloat(random.double(in: 0.33...0.48))
                let point = CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
                if index == 0 { blob.move(to: point) } else { blob.addLine(to: point) }
            }
            blob.closeSubpath()
            context.addPath(blob)
            context.fillPath()

            context.setFillColor(UIColor(white: 1, alpha: 0.7).cgColor)
            context.fillEllipse(in: CGRect(x: size.width * 0.36, y: size.height * 0.52, width: size.width * 0.2, height: size.height * 0.1))
        }
    }

    static func skidMark() -> SKTexture {
        texture("skid", size: CGSize(width: 32, height: 12)) { context, size in
            context.setFillColor(UIColor(white: 0.1, alpha: 0.32).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func softDot() -> SKTexture {
        texture("soft-dot", size: CGSize(width: 64, height: 64)) { context, size in
            let colors = [UIColor.white.cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) else { return }
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
                endRadius: size.width / 2,
                options: []
            )
        }
    }

    // MARK: - Props

    static func prop(_ kind: StaticProp.Kind) -> SKTexture {
        let side = 3.5 * pixelsPerMetre * 0.5
        return texture("prop-\(kind.rawValue)", size: CGSize(width: side, height: side)) { context, size in
            switch kind {
            case .pallet:
                context.setFillColor(UIColor(red: 0.66, green: 0.5, blue: 0.31, alpha: 1).cgColor)
                context.fill(CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.06, dy: size.height * 0.12))
                context.setFillColor(UIColor(red: 0.45, green: 0.33, blue: 0.19, alpha: 1).cgColor)
                for index in 0..<5 {
                    let y = size.height * (0.16 + CGFloat(index) * 0.17)
                    context.fill(CGRect(x: size.width * 0.06, y: y, width: size.width * 0.88, height: size.height * 0.05))
                }
                context.setFillColor(UIColor(red: 0.82, green: 0.78, blue: 0.7, alpha: 0.9).cgColor)
                context.fill(CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.18, dy: size.height * 0.26))

            case .canPyramid:
                let rows = 3
                for row in 0..<rows {
                    let count = rows - row
                    let radius = size.width * 0.11
                    for column in 0..<count {
                        let x = size.width / 2 + (CGFloat(column) - CGFloat(count - 1) / 2) * radius * 2.2
                        let y = size.height * 0.26 + CGFloat(row) * radius * 1.7
                        context.setFillColor(UIColor(red: 0.85, green: 0.2, blue: 0.18, alpha: 1).cgColor)
                        context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                        context.setFillColor(UIColor(white: 0.95, alpha: 0.9).cgColor)
                        context.fillEllipse(in: CGRect(x: x - radius * 0.5, y: y - radius * 0.5, width: radius, height: radius))
                    }
                }

            case .wetFloorSign:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.86))
                path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.2))
                path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.2))
                path.closeSubpath()
                context.setFillColor(UIColor(red: 0.98, green: 0.79, blue: 0.1, alpha: 1).cgColor)
                context.addPath(path)
                context.fillPath()
                context.setStrokeColor(UIColor(white: 0.15, alpha: 0.8).cgColor)
                context.setLineWidth(size.width * 0.03)
                context.addPath(path)
                context.strokePath()

            case .moppingBucket:
                context.setFillColor(UIColor(red: 0.85, green: 0.79, blue: 0.2, alpha: 1).cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.2, dy: size.height * 0.2))
                context.setFillColor(UIColor(red: 0.45, green: 0.62, blue: 0.75, alpha: 1).cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.28, dy: size.height * 0.28))

            case .shoppingBasket:
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.22, dy: size.height * 0.3)
                context.setFillColor(UIColor(red: 0.2, green: 0.45, blue: 0.35, alpha: 1).cgColor)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
                context.fillPath()
                context.setStrokeColor(UIColor(white: 0.9, alpha: 0.5).cgColor)
                context.setLineWidth(2)
                context.stroke(rect.insetBy(dx: 4, dy: 4))
            }
        }
    }

    // MARK: - Items

    static func itemIcon(_ kind: ItemKind) -> SKTexture {
        let side: CGFloat = 128
        return texture("item-\(kind.rawValue)", size: CGSize(width: side, height: side)) { context, size in
            drawItem(kind, in: context, size: size)
        }
    }

    static func itemImage(_ kind: ItemKind) -> UIImage {
        image("item-img-\(kind.rawValue)", size: CGSize(width: 128, height: 128)) { context, size in
            drawItem(kind, in: context, size: size)
        }
    }

    static func unknownItemImage() -> UIImage {
        image("item-img-unknown", size: CGSize(width: 128, height: 128)) { context, size in
            context.setFillColor(UIColor(white: 1, alpha: 0.22).cgColor)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.16, dy: size.height * 0.16)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
            context.fillPath()

            // UIKit text drawing expects the flipped context we just undid.
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            let text = "?" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.5, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let bounds = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2),
                withAttributes: attributes
            )
            context.restoreGState()
        }
    }

    private static func drawItem(_ kind: ItemKind, in context: CGContext, size: CGSize) {
        let w = size.width
        let h = size.height
        func fill(_ color: UIColor) { context.setFillColor(color.cgColor) }

        switch kind {
        case .soupCan, .tripleCans:
            let count = kind == .tripleCans ? 3 : 1
            for index in 0..<count {
                let offset = count == 1 ? 0 : (CGFloat(index) - 1) * w * 0.26
                let rect = CGRect(x: w * 0.34 + offset, y: h * 0.22, width: w * 0.32, height: h * 0.56)
                fill(UIColor(red: 0.82, green: 0.19, blue: 0.16, alpha: 1))
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
                context.fillPath()
                fill(UIColor(white: 0.96, alpha: 1))
                context.fill(CGRect(x: rect.minX, y: rect.midY - h * 0.06, width: rect.width, height: h * 0.12))
                fill(UIColor(white: 0.75, alpha: 1))
                context.fill(CGRect(x: rect.minX, y: rect.maxY - h * 0.05, width: rect.width, height: h * 0.05))
            }

        case .rogueMelon:
            fill(UIColor(red: 0.19, green: 0.55, blue: 0.22, alpha: 1))
            context.fillEllipse(in: CGRect(x: w * 0.14, y: h * 0.14, width: w * 0.72, height: h * 0.72))
            context.setStrokeColor(UIColor(red: 0.1, green: 0.34, blue: 0.13, alpha: 1).cgColor)
            context.setLineWidth(w * 0.045)
            for index in 0..<4 {
                let angle = CGFloat(index) * .pi / 4
                context.saveGState()
                context.translateBy(x: w / 2, y: h / 2)
                context.rotate(by: angle)
                context.addEllipse(in: CGRect(x: -w * 0.1, y: -h * 0.36, width: w * 0.2, height: h * 0.72))
                context.strokePath()
                context.restoreGState()
            }

        case .milkSpill:
            fill(UIColor(white: 0.98, alpha: 1))
            let carton = CGMutablePath()
            carton.move(to: CGPoint(x: w * 0.3, y: h * 0.18))
            carton.addLine(to: CGPoint(x: w * 0.7, y: h * 0.18))
            carton.addLine(to: CGPoint(x: w * 0.7, y: h * 0.64))
            carton.addLine(to: CGPoint(x: w * 0.5, y: h * 0.84))
            carton.addLine(to: CGPoint(x: w * 0.3, y: h * 0.64))
            carton.closeSubpath()
            context.addPath(carton)
            context.fillPath()
            fill(UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1))
            context.fill(CGRect(x: w * 0.3, y: h * 0.32, width: w * 0.4, height: h * 0.16))

        case .energyDrink:
            fill(UIColor(red: 0.1, green: 0.75, blue: 0.85, alpha: 1))
            let can = CGRect(x: w * 0.34, y: h * 0.16, width: w * 0.32, height: h * 0.68)
            context.addPath(CGPath(roundedRect: can, cornerWidth: 8, cornerHeight: 8, transform: nil))
            context.fillPath()
            fill(UIColor(red: 0.95, green: 0.85, blue: 0.15, alpha: 1))
            let bolt = CGMutablePath()
            bolt.move(to: CGPoint(x: w * 0.54, y: h * 0.74))
            bolt.addLine(to: CGPoint(x: w * 0.4, y: h * 0.48))
            bolt.addLine(to: CGPoint(x: w * 0.5, y: h * 0.48))
            bolt.addLine(to: CGPoint(x: w * 0.45, y: h * 0.26))
            bolt.addLine(to: CGPoint(x: w * 0.62, y: h * 0.54))
            bolt.addLine(to: CGPoint(x: w * 0.51, y: h * 0.54))
            bolt.closeSubpath()
            context.addPath(bolt)
            context.fillPath()

        case .wetFloorSign:
            drawSignGlyph(in: context, size: size)

        case .cleanupCall:
            fill(UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1))
            let horn = CGMutablePath()
            horn.move(to: CGPoint(x: w * 0.26, y: h * 0.4))
            horn.addLine(to: CGPoint(x: w * 0.44, y: h * 0.4))
            horn.addLine(to: CGPoint(x: w * 0.74, y: h * 0.2))
            horn.addLine(to: CGPoint(x: w * 0.74, y: h * 0.8))
            horn.addLine(to: CGPoint(x: w * 0.44, y: h * 0.6))
            horn.addLine(to: CGPoint(x: w * 0.26, y: h * 0.6))
            horn.closeSubpath()
            context.addPath(horn)
            context.fillPath()
            context.setStrokeColor(UIColor(white: 1, alpha: 0.9).cgColor)
            context.setLineWidth(w * 0.035)
            for index in 1...2 {
                let radius = w * (0.08 + CGFloat(index) * 0.06)
                context.addArc(
                    center: CGPoint(x: w * 0.76, y: h * 0.5),
                    radius: radius,
                    startAngle: -0.7,
                    endAngle: 0.7,
                    clockwise: false
                )
                context.strokePath()
            }

        case .vipCard:
            let card = CGRect(x: w * 0.14, y: h * 0.28, width: w * 0.72, height: h * 0.44)
            fill(UIColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 1))
            context.addPath(CGPath(roundedRect: card, cornerWidth: 8, cornerHeight: 8, transform: nil))
            context.fillPath()
            fill(UIColor(red: 0.98, green: 0.8, blue: 0.25, alpha: 1))
            context.fill(CGRect(x: card.minX + 8, y: card.midY + 2, width: card.width - 16, height: h * 0.08))
            drawStar(in: context, centre: CGPoint(x: w * 0.5, y: h * 0.42), radius: w * 0.12, color: UIColor(red: 0.98, green: 0.8, blue: 0.25, alpha: 1))

        case .runawayCart:
            fill(UIColor(white: 0.85, alpha: 1))
            let basket = CGMutablePath()
            basket.move(to: CGPoint(x: w * 0.2, y: h * 0.34))
            basket.addLine(to: CGPoint(x: w * 0.84, y: h * 0.34))
            basket.addLine(to: CGPoint(x: w * 0.74, y: h * 0.66))
            basket.addLine(to: CGPoint(x: w * 0.3, y: h * 0.66))
            basket.closeSubpath()
            context.addPath(basket)
            context.fillPath()
            fill(UIColor(white: 0.4, alpha: 1))
            context.fillEllipse(in: CGRect(x: w * 0.3, y: h * 0.18, width: w * 0.12, height: h * 0.12))
            context.fillEllipse(in: CGRect(x: w * 0.62, y: h * 0.18, width: w * 0.12, height: h * 0.12))
            context.setStrokeColor(UIColor(red: 0.2, green: 0.7, blue: 0.95, alpha: 0.9).cgColor)
            context.setLineWidth(w * 0.04)
            for index in 0..<3 {
                let y = h * (0.4 + CGFloat(index) * 0.12)
                context.move(to: CGPoint(x: w * 0.04, y: y))
                context.addLine(to: CGPoint(x: w * 0.2, y: y))
            }
            context.strokePath()
        }
    }

    private static func drawSignGlyph(in context: CGContext, size: CGSize) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.86))
        path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.16))
        path.addLine(to: CGPoint(x: size.width * 0.2, y: size.height * 0.16))
        path.closeSubpath()
        context.setFillColor(UIColor(red: 0.98, green: 0.79, blue: 0.1, alpha: 1).cgColor)
        context.addPath(path)
        context.fillPath()
        context.setFillColor(UIColor(white: 0.12, alpha: 1).cgColor)
        context.fill(CGRect(x: size.width * 0.46, y: size.height * 0.36, width: size.width * 0.08, height: size.height * 0.28))
        context.fillEllipse(in: CGRect(x: size.width * 0.45, y: size.height * 0.24, width: size.width * 0.1, height: size.width * 0.1))
    }

    private static func drawStar(in context: CGContext, centre: CGPoint, radius: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        for index in 0..<10 {
            // Starting a quarter turn up puts a point at the top, y-up.
            let angle = CGFloat(index) * .pi / 5 + .pi / 2
            let length = index % 2 == 0 ? radius : radius * 0.45
            let point = CGPoint(x: centre.x + cos(angle) * length, y: centre.y + sin(angle) * length)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }
}

extension ColorRGB {
    var uiColor: UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }

    var hexKey: String {
        String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension UIColor {
    /// Nudges brightness, clamped, for cheap shading.
    func adjusted(by delta: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(
            red: min(max(red + delta, 0), 1),
            green: min(max(green + delta, 0), 1),
            blue: min(max(blue + delta, 0), 1),
            alpha: alpha
        )
    }
}
