import SpriteKit
import UIKit

/// Draws every sprite in the game with CoreGraphics so the project needs no
/// bundled image assets. Textures are cached by key.
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    private static func texture(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            draw(ctx.cgContext, size)
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: - Shopping cart (top-down, front faces +y)

    static func cart(color: UIColor, name: String) -> SKTexture {
        texture("cart-\(name)", size: CGSize(width: 64, height: 96)) { c, _ in
            // Wheels: rear pair larger, front casters angled slightly.
            c.setFillColor(UIColor(white: 0.13, alpha: 1).cgColor)
            for (x, y, w, h) in [(4, 8, 12, 22), (48, 8, 12, 22), (7, 66, 10, 18), (47, 66, 10, 18)] {
                let rect = CGRect(x: x, y: y, width: w, height: h)
                c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 4).cgPath)
            }
            c.fillPath()

            // Basket: trapezoid, slightly narrower at the front (top).
            let basket = UIBezierPath()
            basket.move(to: CGPoint(x: 10, y: 16))
            basket.addLine(to: CGPoint(x: 54, y: 16))
            basket.addLine(to: CGPoint(x: 50, y: 86))
            basket.addLine(to: CGPoint(x: 14, y: 86))
            basket.close()
            c.setFillColor(UIColor(white: 0.72, alpha: 1).cgColor)
            c.addPath(basket.cgPath)
            c.fillPath()

            // Cargo: a tarp in the character color plus assorted junk.
            c.saveGState()
            c.addPath(basket.cgPath)
            c.clip()
            c.setFillColor(color.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 14, y: 24, width: 36, height: 40), cornerRadius: 12).cgPath)
            c.fillPath()
            c.setFillColor(color.withAlphaComponent(0.6).cgColor)
            c.addPath(UIBezierPath(ovalIn: CGRect(x: 20, y: 56, width: 24, height: 22)).cgPath)
            c.fillPath()
            // Bedroll and a bottle poking out of the pile.
            c.setFillColor(UIColor(red: 0.35, green: 0.55, blue: 0.35, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 16, y: 30, width: 12, height: 30), cornerRadius: 6).cgPath)
            c.fillPath()
            c.setFillColor(UIColor(red: 0.45, green: 0.75, blue: 0.42, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 38, y: 40, width: 8, height: 20), cornerRadius: 4).cgPath)
            c.fillPath()
            c.restoreGState()

            // Basket grid.
            c.setStrokeColor(UIColor(white: 0.35, alpha: 0.55).cgColor)
            c.setLineWidth(1.5)
            c.saveGState()
            c.addPath(basket.cgPath)
            c.clip()
            for i in 1...3 {
                let x = 10 + CGFloat(i) * 11
                c.move(to: CGPoint(x: x, y: 16))
                c.addLine(to: CGPoint(x: x, y: 86))
            }
            for i in 1...4 {
                let y = 16 + CGFloat(i) * 14
                c.move(to: CGPoint(x: 10, y: y))
                c.addLine(to: CGPoint(x: 54, y: y))
            }
            c.strokePath()
            c.restoreGState()

            // Basket rim.
            c.setStrokeColor(UIColor(white: 0.30, alpha: 1).cgColor)
            c.setLineWidth(3)
            c.addPath(basket.cgPath)
            c.strokePath()

            // Handle bar across the rear (bottom).
            c.setFillColor(UIColor(white: 0.22, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 8, y: 4, width: 48, height: 9), cornerRadius: 4).cgPath)
            c.fillPath()

            // Tiny pennant flag on the front corner.
            c.setFillColor(color.cgColor)
            let flag = UIBezierPath()
            flag.move(to: CGPoint(x: 14, y: 86))
            flag.addLine(to: CGPoint(x: 4, y: 94))
            flag.addLine(to: CGPoint(x: 16, y: 93))
            flag.close()
            c.addPath(flag.cgPath)
            c.fillPath()
        }
    }

    // MARK: - Store surfaces

    static var floorTile: SKTexture {
        texture("floor", size: CGSize(width: 128, height: 128)) { c, size in
            c.setFillColor(UIColor(red: 0.87, green: 0.86, blue: 0.83, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // Grout lines along two edges so the tiling reads as a grid.
            c.setStrokeColor(UIColor(red: 0.76, green: 0.75, blue: 0.72, alpha: 1).cgColor)
            c.setLineWidth(3)
            c.move(to: CGPoint(x: 0, y: 1.5))
            c.addLine(to: CGPoint(x: size.width, y: 1.5))
            c.move(to: CGPoint(x: 1.5, y: 0))
            c.addLine(to: CGPoint(x: 1.5, y: size.height))
            c.strokePath()
            // Speckles.
            var rng = SeededRandom(seed: 7)
            c.setFillColor(UIColor(white: 0.7, alpha: 0.35).cgColor)
            for _ in 0..<26 {
                let r = rng.range(1, 2.5)
                c.fillEllipse(in: CGRect(x: rng.range(4, 124), y: rng.range(4, 124), width: r, height: r))
            }
        }
    }

    static func shelf(size: CGSize, seed: UInt64) -> SKTexture {
        texture("shelf-\(Int(size.width))x\(Int(size.height))-\(seed)", size: size) { c, size in
            c.setFillColor(UIColor(red: 0.42, green: 0.40, blue: 0.44, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8).cgPath)
            c.fillPath()

            // Two product lanes (one per shopping face of the gondola).
            let palette: [UIColor] = [
                UIColor(red: 0.85, green: 0.33, blue: 0.30, alpha: 1),
                UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1),
                UIColor(red: 0.36, green: 0.62, blue: 0.86, alpha: 1),
                UIColor(red: 0.45, green: 0.72, blue: 0.42, alpha: 1),
                UIColor(red: 0.90, green: 0.88, blue: 0.84, alpha: 1),
                UIColor(red: 0.66, green: 0.44, blue: 0.75, alpha: 1),
            ]
            var rng = SeededRandom(seed: seed)
            let laneHeight = size.height * 0.32
            for laneY in [size.height * 0.10, size.height * 0.58] {
                var x: CGFloat = 10
                while x < size.width - 26 {
                    let w = rng.range(14, 30)
                    let color = palette[rng.int(palette.count)]
                    c.setFillColor(color.cgColor)
                    let rect = CGRect(x: x, y: laneY + rng.range(0, 4), width: w, height: laneHeight - rng.range(0, 6))
                    c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 3).cgPath)
                    c.fillPath()
                    x += w + rng.range(3, 8)
                }
            }

            // Center spine.
            c.setFillColor(UIColor(white: 0.25, alpha: 1).cgColor)
            c.fill(CGRect(x: 4, y: size.height / 2 - 3, width: size.width - 8, height: 6))
        }
    }

    static func checkoutCounter(size: CGSize) -> SKTexture {
        texture("checkout-\(Int(size.width))x\(Int(size.height))", size: size) { c, size in
            c.setFillColor(UIColor(red: 0.56, green: 0.58, blue: 0.62, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10).cgPath)
            c.fillPath()
            // Conveyor belt.
            c.setFillColor(UIColor(white: 0.15, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: size.width * 0.16, y: size.height * 0.25,
                                                       width: size.width * 0.5, height: size.height * 0.5),
                                   cornerRadius: 6).cgPath)
            c.fillPath()
            // Register.
            c.setFillColor(UIColor(red: 0.80, green: 0.78, blue: 0.72, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: size.width * 0.72, y: size.height * 0.2,
                                                       width: size.width * 0.2, height: size.height * 0.6),
                                   cornerRadius: 5).cgPath)
            c.fillPath()
            // Lane light pole dot.
            c.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: size.width * 0.05, y: size.height / 2 - 7, width: 14, height: 14))
        }
    }

    static func palletStack(size: CGSize) -> SKTexture {
        texture("pallet-\(Int(size.width))", size: size) { c, size in
            // Wood pallet base.
            c.setFillColor(UIColor(red: 0.62, green: 0.47, blue: 0.30, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            c.setStrokeColor(UIColor(red: 0.45, green: 0.33, blue: 0.20, alpha: 1).cgColor)
            c.setLineWidth(3)
            for i in 1...4 {
                let y = size.height * CGFloat(i) / 5
                c.move(to: CGPoint(x: 0, y: y))
                c.addLine(to: CGPoint(x: size.width, y: y))
            }
            c.strokePath()
            // Cardboard boxes on top.
            c.setFillColor(UIColor(red: 0.76, green: 0.60, blue: 0.40, alpha: 1).cgColor)
            c.fill(CGRect(x: size.width * 0.08, y: size.height * 0.08, width: size.width * 0.52, height: size.height * 0.52))
            c.fill(CGRect(x: size.width * 0.5, y: size.height * 0.45, width: size.width * 0.42, height: size.height * 0.42))
            c.setStrokeColor(UIColor(red: 0.55, green: 0.42, blue: 0.26, alpha: 1).cgColor)
            c.setLineWidth(2)
            c.stroke(CGRect(x: size.width * 0.08, y: size.height * 0.08, width: size.width * 0.52, height: size.height * 0.52))
            c.stroke(CGRect(x: size.width * 0.5, y: size.height * 0.45, width: size.width * 0.42, height: size.height * 0.42))
        }
    }

    static func startLine(size: CGSize) -> SKTexture {
        texture("startline-\(Int(size.height))", size: size) { c, size in
            let square = size.width / 2
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                for col in 0..<2 {
                    let dark = (row + col) % 2 == 0
                    c.setFillColor(dark ? UIColor(white: 0.1, alpha: 1).cgColor : UIColor(white: 0.95, alpha: 1).cgColor)
                    c.fill(CGRect(x: CGFloat(col) * square, y: y, width: square, height: square))
                }
                y += square
                row += 1
            }
        }
    }

    // MARK: - Items & hazards

    static var itemBag: SKTexture {
        texture("itembag", size: CGSize(width: 56, height: 60)) { c, _ in
            // Paper grocery bag.
            c.setFillColor(UIColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 6, y: 4, width: 44, height: 46), cornerRadius: 6).cgPath)
            c.fillPath()
            c.setFillColor(UIColor(red: 0.65, green: 0.50, blue: 0.32, alpha: 1).cgColor)
            c.fill(CGRect(x: 6, y: 42, width: 44, height: 8))
            // Celery poking out the top.
            c.setFillColor(UIColor(red: 0.45, green: 0.72, blue: 0.35, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 12, y: 44, width: 7, height: 14), cornerRadius: 3).cgPath)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 20, y: 46, width: 7, height: 12), cornerRadius: 3).cgPath)
            c.fillPath()
            // Question mark.
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            ("?" as NSString).draw(in: CGRect(x: 6, y: 10, width: 44, height: 36), withAttributes: attrs)
        }
    }

    static var banana: SKTexture {
        texture("banana", size: CGSize(width: 44, height: 40)) { c, _ in
            let peel = UIBezierPath()
            peel.move(to: CGPoint(x: 6, y: 26))
            peel.addQuadCurve(to: CGPoint(x: 22, y: 6), controlPoint: CGPoint(x: 6, y: 8))
            peel.addQuadCurve(to: CGPoint(x: 38, y: 26), controlPoint: CGPoint(x: 38, y: 8))
            peel.addQuadCurve(to: CGPoint(x: 22, y: 18), controlPoint: CGPoint(x: 30, y: 14))
            peel.addQuadCurve(to: CGPoint(x: 6, y: 26), controlPoint: CGPoint(x: 14, y: 14))
            peel.close()
            c.setFillColor(UIColor(red: 0.98, green: 0.85, blue: 0.25, alpha: 1).cgColor)
            c.addPath(peel.cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(red: 0.72, green: 0.58, blue: 0.12, alpha: 1).cgColor)
            c.setLineWidth(2)
            c.addPath(peel.cgPath)
            c.strokePath()
            // Peel flaps.
            c.setFillColor(UIColor(red: 0.94, green: 0.78, blue: 0.20, alpha: 1).cgColor)
            c.addPath(UIBezierPath(ovalIn: CGRect(x: 10, y: 22, width: 10, height: 14)).cgPath)
            c.addPath(UIBezierPath(ovalIn: CGRect(x: 24, y: 22, width: 10, height: 14)).cgPath)
            c.fillPath()
            // Brown tip.
            c.setFillColor(UIColor(red: 0.45, green: 0.32, blue: 0.12, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 19, y: 4, width: 6, height: 6))
        }
    }

    static var soupCan: SKTexture {
        texture("soupcan", size: CGSize(width: 34, height: 34)) { c, _ in
            c.setFillColor(UIColor(white: 0.8, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 1, y: 1, width: 32, height: 32))
            c.setFillColor(UIColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 4, y: 4, width: 26, height: 26))
            c.setFillColor(UIColor(white: 0.88, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 9, y: 9, width: 16, height: 16))
            c.setStrokeColor(UIColor(white: 0.45, alpha: 1).cgColor)
            c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x: 1, y: 1, width: 32, height: 32))
        }
    }

    static var colaCan: SKTexture {
        texture("colacan", size: CGSize(width: 30, height: 44)) { c, _ in
            c.setFillColor(UIColor(red: 0.20, green: 0.75, blue: 0.45, alpha: 1).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 4, y: 3, width: 22, height: 38), cornerRadius: 8).cgPath)
            c.fillPath()
            c.setFillColor(UIColor(white: 0.85, alpha: 1).cgColor)
            c.fill(CGRect(x: 4, y: 36, width: 22, height: 5))
            c.fill(CGRect(x: 4, y: 3, width: 22, height: 4))
            // Lightning bolt.
            let bolt = UIBezierPath()
            bolt.move(to: CGPoint(x: 18, y: 32))
            bolt.addLine(to: CGPoint(x: 10, y: 20))
            bolt.addLine(to: CGPoint(x: 15, y: 20))
            bolt.addLine(to: CGPoint(x: 12, y: 10))
            bolt.addLine(to: CGPoint(x: 21, y: 23))
            bolt.addLine(to: CGPoint(x: 16, y: 23))
            bolt.close()
            c.setFillColor(UIColor(red: 0.98, green: 0.9, blue: 0.3, alpha: 1).cgColor)
            c.addPath(bolt.cgPath)
            c.fillPath()
        }
    }

    static var puddle: SKTexture {
        texture("puddle", size: CGSize(width: 150, height: 110)) { c, size in
            var rng = SeededRandom(seed: 21)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let blob = UIBezierPath()
            let steps = 14
            var points: [CGPoint] = []
            for i in 0..<steps {
                let a = CGFloat(i) / CGFloat(steps) * 2 * .pi
                let rx = size.width * 0.42 * rng.range(0.75, 1.0)
                let ry = size.height * 0.42 * rng.range(0.75, 1.0)
                points.append(CGPoint(x: center.x + cos(a) * rx, y: center.y + sin(a) * ry))
            }
            blob.move(to: points[0])
            for i in 1...steps {
                let p = points[i % steps]
                let prev = points[i - 1]
                let mid = CGPoint(x: (p.x + prev.x) / 2, y: (p.y + prev.y) / 2)
                blob.addQuadCurve(to: mid, controlPoint: prev)
            }
            blob.close()
            c.setFillColor(UIColor(white: 1.0, alpha: 0.9).cgColor)
            c.addPath(blob.cgPath)
            c.fillPath()
            c.setFillColor(UIColor(white: 0.88, alpha: 0.9).cgColor)
            c.fillEllipse(in: CGRect(x: center.x - 26, y: center.y - 16, width: 52, height: 32))
        }
    }

    static var wetFloorCone: SKTexture {
        texture("cone", size: CGSize(width: 30, height: 38)) { c, _ in
            let cone = UIBezierPath()
            cone.move(to: CGPoint(x: 15, y: 36))
            cone.addLine(to: CGPoint(x: 27, y: 4))
            cone.addLine(to: CGPoint(x: 3, y: 4))
            cone.close()
            c.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1).cgColor)
            c.addPath(cone.cgPath)
            c.fillPath()
            c.setFillColor(UIColor(white: 0.15, alpha: 1).cgColor)
            c.fill(CGRect(x: 8, y: 14, width: 14, height: 6))
            c.setFillColor(UIColor(red: 0.85, green: 0.6, blue: 0.1, alpha: 1).cgColor)
            c.fill(CGRect(x: 1, y: 2, width: 28, height: 4))
        }
    }

    // MARK: - Effects & UI

    static var softDot: SKTexture {
        texture("softdot", size: CGSize(width: 32, height: 32)) { c, _ in
            // Layered circles approximate a radial-gradient puff.
            let steps = 8
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                let radius = 16 * (1 - t)
                c.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
                c.fillEllipse(in: CGRect(x: 16 - radius, y: 16 - radius,
                                         width: radius * 2, height: radius * 2))
            }
        }
    }

    static func steerArrow(pointingLeft: Bool) -> SKTexture {
        texture("steer-\(pointingLeft ? "l" : "r")", size: CGSize(width: 130, height: 110)) { c, size in
            c.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4),
                                   cornerRadius: 22).cgPath)
            c.fillPath()
            c.setStrokeColor(UIColor(white: 1, alpha: 0.45).cgColor)
            c.setLineWidth(3)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4),
                                   cornerRadius: 22).cgPath)
            c.strokePath()
            let arrow = UIBezierPath()
            if pointingLeft {
                arrow.move(to: CGPoint(x: 40, y: 55))
                arrow.addLine(to: CGPoint(x: 88, y: 26))
                arrow.addLine(to: CGPoint(x: 88, y: 84))
            } else {
                arrow.move(to: CGPoint(x: 90, y: 55))
                arrow.addLine(to: CGPoint(x: 42, y: 26))
                arrow.addLine(to: CGPoint(x: 42, y: 84))
            }
            arrow.close()
            c.setFillColor(UIColor(white: 1, alpha: 0.75).cgColor)
            c.addPath(arrow.cgPath)
            c.fillPath()
        }
    }

    static var itemButton: SKTexture {
        texture("itembutton", size: CGSize(width: 110, height: 110)) { c, size in
            c.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
            c.fillEllipse(in: CGRect(x: 3, y: 3, width: size.width - 6, height: size.height - 6))
            c.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor)
            c.setLineWidth(4)
            c.strokeEllipse(in: CGRect(x: 3, y: 3, width: size.width - 6, height: size.height - 6))
        }
    }
}
