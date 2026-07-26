import CartKartCore
import SpriteKit
import UIKit

/// Draws every sprite in the game at runtime with Core Graphics.
///
/// Keeping the art procedural means the repository stays text only, the carts
/// can be tinted per racer, and everything scales cleanly on any display.
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    private static func texture(
        key: String,
        size: CGSize,
        scale: CGFloat = 3,
        draw: (CGContext, CGSize) -> Void
    ) -> SKTexture {
        if let cached = cache[key] { return cached }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            draw(context.cgContext, size)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    // MARK: - Carts

    /// A shopping cart seen from above, nose pointing along +x.
    static func cart(for profile: RacerProfile) -> SKTexture {
        let size = CGSize(width: 72, height: 48)
        return texture(key: "cart-\(profile.id)", size: size) { context, size in
            let body = profile.bodyColor.uiColor
            let trim = profile.trimColor.uiColor

            // Basket: slightly wider at the handle end, like the real thing.
            let basket = CGMutablePath()
            basket.move(to: CGPoint(x: 60, y: 12))
            basket.addLine(to: CGPoint(x: 60, y: 36))
            basket.addLine(to: CGPoint(x: 16, y: 44))
            basket.addLine(to: CGPoint(x: 16, y: 4))
            basket.closeSubpath()

            context.setFillColor(body.cgColor)
            context.addPath(basket)
            context.fillPath()

            // Wire mesh.
            context.saveGState()
            context.addPath(basket)
            context.clip()
            context.setStrokeColor(profile.bodyColor.shaded(0.7).cgColor)
            context.setLineWidth(1.6)
            for x in stride(from: 18.0, through: 60.0, by: 7.0) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 4.0, through: 44.0, by: 7.0) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.strokePath()

            // A few groceries poking out of the basket.
            let groceries: [(CGPoint, CGFloat, UIColor)] = [
                (CGPoint(x: 30, y: 18), 6, UIColor(red: 0.85, green: 0.28, blue: 0.3, alpha: 1)),
                (CGPoint(x: 42, y: 28), 5, UIColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
                (CGPoint(x: 50, y: 18), 4.5, UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1)),
                (CGPoint(x: 36, y: 34), 4, UIColor(red: 0.6, green: 0.45, blue: 0.85, alpha: 1))
            ]
            for (centre, radius, colour) in groceries {
                context.setFillColor(colour.cgColor)
                context.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            }
            context.restoreGState()

            // Basket rim.
            context.setStrokeColor(trim.cgColor)
            context.setLineWidth(3)
            context.addPath(basket)
            context.strokePath()

            // Push handle at the back.
            context.setStrokeColor(trim.cgColor)
            context.setLineWidth(4)
            context.move(to: CGPoint(x: 11, y: 6))
            context.addLine(to: CGPoint(x: 11, y: 42))
            context.strokePath()

            // Castor wheels.
            context.setFillColor(UIColor(white: 0.15, alpha: 1).cgColor)
            for point in [CGPoint(x: 21, y: 6), CGPoint(x: 21, y: 42), CGPoint(x: 55, y: 12), CGPoint(x: 55, y: 36)] {
                let rect = CGRect(x: point.x - 4, y: point.y - 3, width: 8, height: 6)
                context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 2.5).cgPath)
                context.fillPath()
            }
        }
    }

    /// Soft dark blob drawn under carts and props.
    static var shadow: SKTexture {
        texture(key: "shadow", size: CGSize(width: 64, height: 64)) { context, size in
            let colours = [
                UIColor(white: 0, alpha: 0.38).cgColor,
                UIColor(white: 0, alpha: 0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours,
                locations: [0, 1]
            ) else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            context.drawRadialGradient(
                gradient,
                startCenter: centre,
                startRadius: 0,
                endCenter: centre,
                endRadius: size.width / 2,
                options: []
            )
        }
    }

    // MARK: - Floor

    /// Repeating shop floor tile, used as the fill pattern for the course.
    static func floorTile(theme: TrackTheme) -> SKTexture {
        texture(key: "floor-\(theme.tagline)", size: CGSize(width: 96, height: 96), scale: 2) { context, size in
            context.setFillColor(theme.floor.uiColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.setStrokeColor(theme.floor.shaded(0.9).cgColor)
            context.setLineWidth(2)
            for offset in stride(from: 0.0, through: Double(size.width), by: 48) {
                context.move(to: CGPoint(x: offset, y: 0))
                context.addLine(to: CGPoint(x: offset, y: size.height))
                context.move(to: CGPoint(x: 0, y: offset))
                context.addLine(to: CGPoint(x: size.width, y: offset))
            }
            context.strokePath()
            // A faint scuff so large areas of floor are not perfectly flat.
            context.setFillColor(theme.floor.shaded(0.96).cgColor)
            context.fillEllipse(in: CGRect(x: 18, y: 60, width: 26, height: 12))
        }
    }

    /// Shelving unit seen from above, drawn along the edges of the course.
    static func shelf(theme: TrackTheme) -> SKTexture {
        texture(key: "shelf-\(theme.tagline)", size: CGSize(width: 60, height: 40)) { context, size in
            let base = theme.shelf.uiColor
            context.setFillColor(base.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(theme.shelf.shaded(1.25).cgColor)
            context.fill(CGRect(x: 3, y: 3, width: size.width - 6, height: 10))
            context.setFillColor(theme.shelf.shaded(0.7).cgColor)
            context.fill(CGRect(x: 3, y: 26, width: size.width - 6, height: 11))
            // Boxes on the shelf, alternating shades so the row reads as stock.
            for (index, x) in stride(from: 6.0, through: 48.0, by: 12.0).enumerated() {
                let shade = [0.75, 1.15, 0.95, 1.3][index % 4]
                context.setFillColor(theme.accent.shaded(shade).cgColor)
                context.fill(CGRect(x: x, y: 15, width: 9, height: 9))
            }
        }
    }

    static func boostPad(theme: TrackTheme) -> SKTexture {
        texture(key: "boost-\(theme.tagline)", size: CGSize(width: 96, height: 96)) { context, size in
            context.setFillColor(theme.accent.uiColor.withAlphaComponent(0.22).cgColor)
            context.fillEllipse(in: CGRect(origin: .zero, size: size))
            context.setStrokeColor(theme.accent.uiColor.cgColor)
            context.setLineWidth(6)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            // Three chevrons pointing along +x.
            for offset in [0.0, 24.0, 48.0] {
                context.move(to: CGPoint(x: 18 + offset, y: 26))
                context.addLine(to: CGPoint(x: 32 + offset, y: 48))
                context.addLine(to: CGPoint(x: 18 + offset, y: 70))
            }
            context.strokePath()
        }
    }

    static var itemBox: SKTexture {
        texture(key: "item-box", size: CGSize(width: 72, height: 72)) { context, size in
            let rect = CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
            context.setFillColor(UIColor(red: 0.98, green: 0.86, blue: 0.32, alpha: 0.92).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
            context.setStrokeColor(UIColor(red: 0.55, green: 0.35, blue: 0.05, alpha: 1).cgColor)
            context.setLineWidth(4)
            context.addPath(path.cgPath)
            context.strokePath()

            let question = NSAttributedString(
                string: "?",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 34, weight: .black),
                    .foregroundColor: UIColor(red: 0.45, green: 0.28, blue: 0.02, alpha: 1)
                ]
            )
            let bounds = question.size()
            question.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2))
        }
    }

    static func obstacle(style: TrackObstacle.Style, theme: TrackTheme) -> SKTexture {
        texture(key: "obstacle-\(style.rawValue)-\(theme.tagline)", size: CGSize(width: 96, height: 96)) { context, size in
            let full = CGRect(origin: .zero, size: size)
            switch style {
            case .pallet:
                context.setFillColor(UIColor(red: 0.55, green: 0.40, blue: 0.22, alpha: 1).cgColor)
                context.fill(full.insetBy(dx: 6, dy: 6))
                context.setStrokeColor(UIColor(red: 0.35, green: 0.24, blue: 0.12, alpha: 1).cgColor)
                context.setLineWidth(4)
                for y in stride(from: 14.0, through: 82.0, by: 17.0) {
                    context.move(to: CGPoint(x: 8, y: y))
                    context.addLine(to: CGPoint(x: 88, y: y))
                }
                context.strokePath()
                context.setFillColor(UIColor(white: 0.85, alpha: 0.9).cgColor)
                context.fill(CGRect(x: 22, y: 22, width: 52, height: 52).insetBy(dx: 4, dy: 4))
            case .canPyramid:
                context.setFillColor(UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1).cgColor)
                context.fillEllipse(in: full.insetBy(dx: 8, dy: 8))
                context.setFillColor(UIColor(red: 0.86, green: 0.26, blue: 0.22, alpha: 1).cgColor)
                for centre in [CGPoint(x: 36, y: 36), CGPoint(x: 60, y: 36), CGPoint(x: 48, y: 60)] {
                    context.fillEllipse(in: CGRect(x: centre.x - 13, y: centre.y - 13, width: 26, height: 26))
                }
            case .freezer:
                context.setFillColor(UIColor(red: 0.78, green: 0.88, blue: 0.94, alpha: 1).cgColor)
                context.fill(full.insetBy(dx: 5, dy: 12))
                context.setStrokeColor(UIColor(red: 0.42, green: 0.58, blue: 0.72, alpha: 1).cgColor)
                context.setLineWidth(5)
                context.stroke(full.insetBy(dx: 5, dy: 12))
                context.setFillColor(UIColor.white.withAlphaComponent(0.75).cgColor)
                context.fill(CGRect(x: 14, y: 24, width: 68, height: 16))
            case .cardboardBin:
                context.setFillColor(UIColor(red: 0.72, green: 0.56, blue: 0.34, alpha: 1).cgColor)
                context.fill(full.insetBy(dx: 10, dy: 10))
                context.setStrokeColor(UIColor(red: 0.48, green: 0.36, blue: 0.20, alpha: 1).cgColor)
                context.setLineWidth(3)
                context.stroke(full.insetBy(dx: 10, dy: 10))
                context.move(to: CGPoint(x: 10, y: 48))
                context.addLine(to: CGPoint(x: 86, y: 48))
                context.strokePath()
            case .wetFloorSign:
                context.setFillColor(UIColor(red: 0.98, green: 0.78, blue: 0.10, alpha: 1).cgColor)
                let sign = CGMutablePath()
                sign.move(to: CGPoint(x: 48, y: 88))
                sign.addLine(to: CGPoint(x: 20, y: 12))
                sign.addLine(to: CGPoint(x: 76, y: 12))
                sign.closeSubpath()
                context.addPath(sign)
                context.fillPath()
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(x: 44, y: 34, width: 8, height: 26))
                context.fillEllipse(in: CGRect(x: 44, y: 22, width: 8, height: 8))
            }
        }
    }

    // MARK: - Items and hazards

    static func item(_ kind: ItemKind) -> SKTexture {
        emojiTexture(key: "item-\(kind.rawValue)", emoji: kind.emoji, size: 64)
    }

    static func hazard(_ kind: DroppedHazard.Kind) -> SKTexture {
        switch kind {
        case .grapeSpill:
            return emojiTexture(key: "hazard-grape", emoji: "🍇", size: 56)
        case .moppedFloor:
            return texture(key: "hazard-mop", size: CGSize(width: 128, height: 128)) { context, size in
                context.setFillColor(UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 0.45).cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size))
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor)
                context.setLineWidth(4)
                context.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 22))
            }
        case .flourCloud:
            return texture(key: "hazard-flour", size: CGSize(width: 128, height: 128)) { context, size in
                context.setFillColor(UIColor.white.withAlphaComponent(0.62).cgColor)
                for centre in [CGPoint(x: 44, y: 54), CGPoint(x: 78, y: 62), CGPoint(x: 60, y: 84), CGPoint(x: 62, y: 40)] {
                    context.fillEllipse(in: CGRect(x: centre.x - 30, y: centre.y - 30, width: 60, height: 60))
                }
                _ = size
            }
        }
    }

    static func projectile(_ kind: Projectile.Kind) -> SKTexture {
        switch kind {
        case .soupCan: return emojiTexture(key: "proj-can", emoji: "🥫", size: 48)
        case .runawayMelon: return emojiTexture(key: "proj-melon", emoji: "🍉", size: 72)
        }
    }

    /// Emoji are a compact way to get readable, colourful item icons with no
    /// asset pipeline at all.
    static func emojiTexture(key: String, emoji: String, size: CGFloat) -> SKTexture {
        texture(key: key, size: CGSize(width: size, height: size)) { _, canvas in
            let string = NSAttributedString(
                string: emoji,
                attributes: [.font: UIFont.systemFont(ofSize: size * 0.82)]
            )
            let bounds = string.size()
            string.draw(
                at: CGPoint(x: (canvas.width - bounds.width) / 2, y: (canvas.height - bounds.height) / 2)
            )
        }
    }

    /// Small soft puff used for drift sparks, boost trails and impact bursts.
    static func spark(named name: String, color: UIColor) -> SKTexture {
        texture(key: "spark-\(name)", size: CGSize(width: 32, height: 32)) { context, size in
            let colours = [color.withAlphaComponent(0.95).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours,
                locations: [0, 1]
            ) else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            context.drawRadialGradient(
                gradient,
                startCenter: centre,
                startRadius: 0,
                endCenter: centre,
                endRadius: size.width / 2,
                options: []
            )
        }
    }

    /// Checkered banner laid across the track at the finish line.
    static var finishLine: SKTexture {
        texture(key: "finish", size: CGSize(width: 32, height: 256), scale: 2) { context, size in
            let square: CGFloat = 16
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var column = 0
                var x: CGFloat = 0
                while x < size.width {
                    let dark = (row + column) % 2 == 0
                    context.setFillColor((dark ? UIColor.black : UIColor.white).cgColor)
                    context.fill(CGRect(x: x, y: y, width: square, height: square))
                    x += square
                    column += 1
                }
                y += square
                row += 1
            }
        }
    }
}
