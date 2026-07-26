import SpriteKit
import UIKit

/// Draws every texture in the game at load time with Core Graphics. Nothing here
/// ships as an image asset, which keeps each character's cart consistent with the
/// `CartArtPlan` the rest of the code reasons about.
final class ArtFactory {
    /// Texture resolution. A 2 m cart becomes a 128 px sprite.
    static let pixelsPerMetre: CGFloat = 64

    let palette: Palette
    private var cache: [String: SKTexture] = [:]

    init(palette: Palette) {
        self.palette = palette
    }

    // MARK: - Drawing helpers

    /// Renders into a context whose origin is the centre and whose y axis points
    /// up, matching the maths used everywhere else.
    private func texture(
        key: String,
        metres: CGSize,
        draw: (CGContext, CGSize) -> Void
    ) -> SKTexture {
        if let cached = cache[key] { return cached }

        let pixels = CGSize(
            width: max(2, metres.width * Self.pixelsPerMetre),
            height: max(2, metres.height * Self.pixelsPerMetre)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pixels, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: pixels.width / 2, y: pixels.height / 2)
            cgContext.scaleBy(x: Self.pixelsPerMetre, y: -Self.pixelsPerMetre)
            cgContext.setLineJoin(.round)
            cgContext.setLineCap(.round)
            draw(cgContext, metres)
        }
        let result = SKTexture(image: image)
        result.filteringMode = .linear
        cache[key] = result
        return result
    }

    private func fill(_ context: CGContext, rect: CGRect, color: RacerColor, alpha: CGFloat = 1, corner: CGFloat = 0) {
        context.setFillColor(UIColor(color, alpha: alpha).cgColor)
        if corner > 0 {
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
            context.fillPath()
        } else {
            context.fill(rect)
        }
    }

    private func stroke(
        _ context: CGContext,
        path: UIBezierPath,
        color: RacerColor,
        width: CGFloat,
        alpha: CGFloat = 1
    ) {
        context.setStrokeColor(UIColor(color, alpha: alpha).cgColor)
        context.setLineWidth(width)
        context.addPath(path.cgPath)
        context.strokePath()
    }

    private func ellipse(_ context: CGContext, centre: CGPoint, radius: CGFloat, color: RacerColor, alpha: CGFloat = 1) {
        context.setFillColor(UIColor(color, alpha: alpha).cgColor)
        context.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }

    // MARK: - Floor

    /// A 4 m square of shop floor, tileable, with grout lines and a few scuffs.
    func floorTileTexture() -> SKTexture {
        texture(key: "floor", metres: CGSize(width: 4, height: 4)) { context, size in
            let half = CGSize(width: size.width / 2, height: size.height / 2)
            self.fill(context, rect: CGRect(x: -half.width, y: -half.height, width: size.width, height: size.height),
                      color: self.palette.floorBase)

            // Chequerboard of 1 m tiles.
            for row in 0..<4 {
                for column in 0..<4 where (row + column) % 2 == 0 {
                    let rect = CGRect(
                        x: -half.width + CGFloat(column),
                        y: -half.height + CGFloat(row),
                        width: 1,
                        height: 1
                    )
                    self.fill(context, rect: rect, color: self.palette.floorAlternate)
                }
            }

            // Grout.
            let grout = UIBezierPath()
            for index in 0...4 {
                let offset = -half.width + CGFloat(index)
                grout.move(to: CGPoint(x: offset, y: -half.height))
                grout.addLine(to: CGPoint(x: offset, y: half.height))
                grout.move(to: CGPoint(x: -half.width, y: offset))
                grout.addLine(to: CGPoint(x: half.width, y: offset))
            }
            self.stroke(context, path: grout, color: self.palette.floorGrout, width: 0.03, alpha: 0.9)

            // A couple of trolley scuffs so the floor is not perfectly clean.
            var random = DeterministicRandom(seed: 0xF100)
            for _ in 0..<6 {
                let scuff = UIBezierPath()
                let start = CGPoint(
                    x: CGFloat(random.nextDouble(in: -2...2)),
                    y: CGFloat(random.nextDouble(in: -2...2))
                )
                scuff.move(to: start)
                scuff.addLine(
                    to: CGPoint(
                        x: start.x + CGFloat(random.nextDouble(in: -0.6...0.6)),
                        y: start.y + CGFloat(random.nextDouble(in: -0.6...0.6))
                    )
                )
                self.stroke(context, path: scuff, color: self.palette.floorGrout, width: 0.04, alpha: 0.35)
            }
        }
    }

    /// Chequered start/finish strip, drawn to span the aisle.
    func startLineTexture(width metres: CGFloat) -> SKTexture {
        let depth: CGFloat = 2.4
        return texture(key: "start-\(Int(metres * 10))", metres: CGSize(width: depth, height: metres)) { context, size in
            let squares = max(4, Int(metres / 1.1))
            let squareHeight = size.height / CGFloat(squares)
            for index in 0..<squares {
                for column in 0..<2 {
                    let isWhite = (index + column) % 2 == 0
                    let rect = CGRect(
                        x: -size.width / 2 + CGFloat(column) * size.width / 2,
                        y: -size.height / 2 + CGFloat(index) * squareHeight,
                        width: size.width / 2,
                        height: squareHeight
                    )
                    self.fill(
                        context,
                        rect: rect,
                        color: isWhite ? RacerColor(0.96, 0.96, 0.96) : RacerColor(0.12, 0.12, 0.14)
                    )
                }
            }
        }
    }

    /// Faint lane guide painted down the middle of the aisle.
    func centreDashTexture() -> SKTexture {
        texture(key: "dash", metres: CGSize(width: 2.2, height: 0.3)) { context, size in
            self.fill(
                context,
                rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                color: self.palette.lineMarking,
                alpha: 0.22,
                corner: 0.12
            )
        }
    }

    // MARK: - Carts

    /// One texture per character, drawn from their `CartArtPlan`.
    func cartTexture(for racer: Racer) -> SKTexture {
        let plan = CartArtPlan(racer: racer)
        // Leave room for the driver behind and the handle.
        let length = CGFloat(plan.length) + 1.4
        let width = CGFloat(plan.width) + 0.6
        return texture(key: "cart-\(racer.id)", metres: CGSize(width: length, height: width)) { context, _ in
            let basket = CGRect(
                x: CGFloat(-plan.length / 2),
                y: CGFloat(-plan.width / 2),
                width: CGFloat(plan.length),
                height: CGFloat(plan.width)
            )

            // Contact shadow.
            context.setFillColor(UIColor.black.withAlphaComponent(0.28).cgColor)
            context.fillEllipse(in: basket.insetBy(dx: -0.12, dy: -0.06).offsetBy(dx: -0.05, dy: -0.08))

            // Wheels first so the basket sits over them.
            for wheel in plan.wheels {
                let centre = CGPoint(x: CGFloat(wheel.offset.x), y: CGFloat(wheel.offset.y))
                self.ellipse(context, centre: centre, radius: CGFloat(wheel.radius) * 1.35,
                             color: RacerColor(0.09, 0.09, 0.11))
                self.ellipse(context, centre: centre, radius: CGFloat(wheel.radius) * 0.6,
                             color: RacerColor(0.62, 0.64, 0.7))
            }

            // Push handle.
            let handle = UIBezierPath()
            handle.move(to: CGPoint(x: CGFloat(plan.handleOffset.x), y: CGFloat(-plan.handleWidth / 2)))
            handle.addLine(to: CGPoint(x: CGFloat(plan.handleOffset.x), y: CGFloat(plan.handleWidth / 2)))
            self.stroke(context, path: handle, color: plan.trimColor, width: 0.14)

            // Basket body, tapering towards the nose.
            let taper = CGFloat(plan.taper) * CGFloat(plan.width) * 0.5
            let body = UIBezierPath()
            body.move(to: CGPoint(x: basket.minX, y: basket.minY))
            body.addLine(to: CGPoint(x: basket.maxX, y: basket.minY + taper))
            body.addLine(to: CGPoint(x: basket.maxX, y: basket.maxY - taper))
            body.addLine(to: CGPoint(x: basket.minX, y: basket.maxY))
            body.close()

            context.setFillColor(UIColor(plan.bodyColor, alpha: 0.95).cgColor)
            context.addPath(body.cgPath)
            context.fillPath()

            // Cargo piled in the basket.
            for piece in plan.cargo {
                let colour = plan.cargoColors[piece.colorIndex % plan.cargoColors.count]
                context.saveGState()
                context.translateBy(x: CGFloat(piece.offset.x), y: CGFloat(piece.offset.y))
                context.rotate(by: CGFloat(piece.rotation))
                let rect = CGRect(
                    x: CGFloat(-piece.size.x / 2),
                    y: CGFloat(-piece.size.y / 2),
                    width: CGFloat(piece.size.x),
                    height: CGFloat(piece.size.y)
                )
                switch piece.kind {
                case .bottle, .can:
                    self.ellipse(context, centre: .zero, radius: rect.width / 2, color: colour)
                    self.ellipse(context, centre: .zero, radius: rect.width / 4,
                                 color: colour.mixed(with: RacerColor(1, 1, 1), amount: 0.5))
                case .cabbage:
                    self.ellipse(context, centre: .zero, radius: rect.width / 2, color: RacerColor(hex: 0x8FBF5F))
                case .bread:
                    self.fill(context, rect: rect, color: RacerColor(hex: 0xC98A4B), corner: rect.height / 2)
                case .bag:
                    self.fill(context, rect: rect, color: colour, alpha: 0.9, corner: 0.05)
                case .box:
                    self.fill(context, rect: rect, color: colour, corner: 0.03)
                    self.stroke(
                        context,
                        path: UIBezierPath(rect: rect),
                        color: RacerColor(0, 0, 0),
                        width: 0.02,
                        alpha: 0.35
                    )
                }
                context.restoreGState()
            }

            // Wire mesh over the top of the load.
            if plan.meshBarCount > 0 {
                let mesh = UIBezierPath()
                for index in 0...plan.meshBarCount {
                    let t = CGFloat(index) / CGFloat(plan.meshBarCount)
                    let x = basket.minX + basket.width * t
                    let inset = taper * t
                    mesh.move(to: CGPoint(x: x, y: basket.minY + inset))
                    mesh.addLine(to: CGPoint(x: x, y: basket.maxY - inset))
                }
                self.stroke(context, path: mesh, color: RacerColor(0.92, 0.93, 0.96), width: 0.035, alpha: 0.75)
            }

            // Basket rim.
            self.stroke(context, path: body, color: RacerColor(0.97, 0.98, 1), width: 0.06, alpha: 0.9)

            // The driver, hanging off the back.
            self.ellipse(context, centre: CGPoint(x: CGFloat(plan.driverOffset.x), y: 0),
                         radius: CGFloat(plan.driverRadius), color: plan.trimColor)
            self.ellipse(context, centre: CGPoint(x: CGFloat(plan.driverOffset.x) + 0.06, y: 0),
                         radius: CGFloat(plan.driverRadius) * 0.55,
                         color: plan.trimColor.mixed(with: RacerColor(1, 1, 1), amount: 0.4))
        }
    }

    // MARK: - Scenery

    func propTexture(kind: TrackArtPlan.PropKind, colorIndex: Int) -> SKTexture {
        let stock = palette.shelfStock[colorIndex % palette.shelfStock.count]
        let footprint = CGFloat(kind.radius) * 2
        return texture(key: "prop-\(kind.rawValue)-\(colorIndex)", metres: CGSize(width: footprint, height: footprint)) { context, size in
            let full = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)

            // Everything gets a drop shadow to lift it off the floor.
            context.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            context.fill(full.insetBy(dx: full.width * 0.1, dy: full.height * 0.1).offsetBy(dx: 0.1, dy: -0.12))

            switch kind {
            case .shelfUnit, .freezerCabinet:
                let unit = full.insetBy(dx: full.width * 0.08, dy: full.height * 0.16)
                self.fill(context, rect: unit, color: self.palette.shelfBody, corner: 0.1)
                // Stock on the shelves, in rows.
                let rows = 3
                for row in 0..<rows {
                    let rowRect = CGRect(
                        x: unit.minX + 0.14,
                        y: unit.minY + unit.height * CGFloat(row) / CGFloat(rows) + 0.08,
                        width: unit.width - 0.28,
                        height: unit.height / CGFloat(rows) - 0.16
                    )
                    let tint = kind == .freezerCabinet
                        ? stock.mixed(with: RacerColor(1, 1, 1), amount: 0.4)
                        : stock
                    self.fill(context, rect: rowRect, color: tint, alpha: 0.9, corner: 0.05)
                }
                self.stroke(context, path: UIBezierPath(roundedRect: unit, cornerRadius: 0.1),
                            color: self.palette.shelfTrim, width: 0.07)
                if kind == .freezerCabinet {
                    // Glass sheen.
                    self.fill(context, rect: unit.insetBy(dx: 0.1, dy: 0.1),
                              color: RacerColor(0.8, 0.95, 1), alpha: 0.16, corner: 0.08)
                }

            case .palletStack:
                self.fill(context, rect: full.insetBy(dx: 0.18, dy: 0.18), color: RacerColor(hex: 0x8B6A45), corner: 0.05)
                for index in 0..<3 {
                    let boxRect = CGRect(
                        x: full.minX + 0.3,
                        y: full.minY + 0.3 + CGFloat(index) * (full.height - 0.6) / 3,
                        width: full.width - 0.6,
                        height: (full.height - 0.6) / 3 - 0.08
                    )
                    self.fill(context, rect: boxRect, color: RacerColor(hex: 0xC49A6C), corner: 0.03)
                }

            case .cardboardBox:
                self.fill(context, rect: full.insetBy(dx: 0.1, dy: 0.1), color: RacerColor(hex: 0xC49A6C), corner: 0.04)
                let tape = UIBezierPath()
                tape.move(to: CGPoint(x: 0, y: full.minY + 0.1))
                tape.addLine(to: CGPoint(x: 0, y: full.maxY - 0.1))
                self.stroke(context, path: tape, color: RacerColor(hex: 0x8A6A47), width: 0.06)

            case .promoSign:
                self.fill(context, rect: full.insetBy(dx: 0.12, dy: 0.3), color: self.palette.accent, corner: 0.06)
                self.fill(context, rect: CGRect(x: -0.05, y: full.minY + 0.1, width: 0.1, height: 0.4),
                          color: RacerColor(0.3, 0.3, 0.34))

            case .pottedPlant:
                self.ellipse(context, centre: .zero, radius: full.width * 0.34, color: RacerColor(hex: 0x4E7A3A))
                self.ellipse(context, centre: CGPoint(x: 0.08, y: 0.08), radius: full.width * 0.2,
                             color: RacerColor(hex: 0x6FA24C))
                self.ellipse(context, centre: .zero, radius: full.width * 0.14, color: RacerColor(hex: 0x8B5E3C))

            case .pillar:
                self.ellipse(context, centre: .zero, radius: full.width * 0.4, color: RacerColor(hex: 0x6B7280))
                self.ellipse(context, centre: .zero, radius: full.width * 0.3, color: RacerColor(hex: 0x9CA3AF))

            case .trolleyBay:
                self.fill(context, rect: full.insetBy(dx: 0.12, dy: 0.5), color: RacerColor(hex: 0x3F4551), corner: 0.08)
                for index in 0..<4 {
                    let x = full.minX + 0.4 + CGFloat(index) * (full.width - 0.8) / 4
                    self.fill(context, rect: CGRect(x: x, y: -0.35, width: 0.28, height: 0.7),
                              color: RacerColor(0.85, 0.87, 0.92), alpha: 0.85, corner: 0.05)
                }

            case .wheelieBin:
                self.fill(context, rect: full.insetBy(dx: 0.18, dy: 0.22), color: RacerColor(hex: 0x2F6B3F), corner: 0.08)
                self.fill(context, rect: CGRect(x: full.minX + 0.18, y: 0.1, width: full.width - 0.36, height: 0.3),
                          color: RacerColor(hex: 0x24522F), corner: 0.06)
            }
        }
    }

    func obstacleTexture(kind: Obstacle.Kind, radius: Double) -> SKTexture {
        let footprint = CGFloat(radius) * 2.2
        return texture(key: "obstacle-\(kind.rawValue)", metres: CGSize(width: footprint, height: footprint)) { context, size in
            let full = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            context.setFillColor(UIColor.black.withAlphaComponent(0.32).cgColor)
            context.fillEllipse(in: full.insetBy(dx: full.width * 0.14, dy: full.height * 0.14).offsetBy(dx: 0.08, dy: -0.1))

            switch kind {
            case .palletStack:
                self.fill(context, rect: full.insetBy(dx: 0.12, dy: 0.12), color: RacerColor(hex: 0x8B6A45), corner: 0.06)
                self.fill(context, rect: full.insetBy(dx: 0.3, dy: 0.3), color: RacerColor(hex: 0xD9B382), corner: 0.04)
                self.stroke(context, path: UIBezierPath(roundedRect: full.insetBy(dx: 0.12, dy: 0.12), cornerRadius: 0.06),
                            color: RacerColor(hex: 0x6B4F35), width: 0.06)

            case .displayTower:
                self.ellipse(context, centre: .zero, radius: full.width * 0.42, color: self.palette.accent)
                self.ellipse(context, centre: .zero, radius: full.width * 0.3, color: RacerColor(hex: 0xEF476F))
                self.ellipse(context, centre: .zero, radius: full.width * 0.16, color: RacerColor(0.98, 0.98, 1))

            case .wetFloorSign:
                let sign = UIBezierPath()
                sign.move(to: CGPoint(x: 0, y: full.maxY * 0.7))
                sign.addLine(to: CGPoint(x: full.maxX * 0.55, y: full.minY * 0.7))
                sign.addLine(to: CGPoint(x: full.minX * 0.55, y: full.minY * 0.7))
                sign.close()
                context.setFillColor(UIColor(RacerColor(hex: 0xFFC300)).cgColor)
                context.addPath(sign.cgPath)
                context.fillPath()
                self.stroke(context, path: sign, color: RacerColor(0.15, 0.12, 0.05), width: 0.05)

            case .mopBucket:
                self.fill(context, rect: full.insetBy(dx: 0.14, dy: 0.2), color: RacerColor(hex: 0xFFD166), corner: 0.1)
                self.ellipse(context, centre: .zero, radius: full.width * 0.2, color: RacerColor(hex: 0x9FD8F2))

            case .produceCrate:
                self.fill(context, rect: full.insetBy(dx: 0.14, dy: 0.14), color: RacerColor(hex: 0x2F6B3F), corner: 0.05)
                for index in 0..<3 {
                    self.ellipse(
                        context,
                        centre: CGPoint(x: CGFloat(index - 1) * 0.22, y: CGFloat(index % 2) * 0.14 - 0.05),
                        radius: 0.16,
                        color: RacerColor(hex: 0xE94F37)
                    )
                }

            case .trafficCone:
                let cone = UIBezierPath()
                cone.move(to: CGPoint(x: 0, y: full.maxY * 0.72))
                cone.addLine(to: CGPoint(x: full.maxX * 0.5, y: full.minY * 0.62))
                cone.addLine(to: CGPoint(x: full.minX * 0.5, y: full.minY * 0.62))
                cone.close()
                context.setFillColor(UIColor(RacerColor(hex: 0xF4713B)).cgColor)
                context.addPath(cone.cgPath)
                context.fillPath()
                self.fill(context, rect: CGRect(x: full.minX * 0.34, y: -0.04, width: full.width * 0.34, height: 0.12),
                          color: RacerColor(0.98, 0.98, 1))
            }
        }
    }

    // MARK: - Pickups and hazards

    /// Promo crate holding an item.
    func itemCrateTexture() -> SKTexture {
        texture(key: "crate", metres: CGSize(width: 2.4, height: 2.4)) { context, size in
            let box = CGRect(x: -0.9, y: -0.9, width: 1.8, height: 1.8)
            context.setFillColor(UIColor.black.withAlphaComponent(0.25).cgColor)
            context.fill(box.offsetBy(dx: 0.08, dy: -0.1))
            self.fill(context, rect: box, color: RacerColor(hex: 0xFFD166), corner: 0.18)
            self.stroke(context, path: UIBezierPath(roundedRect: box, cornerRadius: 0.18),
                        color: RacerColor(hex: 0xB07A12), width: 0.08)
            // A big question mark, drawn as a hook and a dot.
            let mark = UIBezierPath()
            mark.move(to: CGPoint(x: -0.22, y: 0.36))
            mark.addQuadCurve(to: CGPoint(x: 0.2, y: 0.12), controlPoint: CGPoint(x: 0.38, y: 0.52))
            mark.addQuadCurve(to: CGPoint(x: 0, y: -0.12), controlPoint: CGPoint(x: 0.02, y: 0.0))
            self.stroke(context, path: mark, color: RacerColor(hex: 0x5A3A00), width: 0.16)
            self.ellipse(context, centre: CGPoint(x: 0, y: -0.36), radius: 0.1, color: RacerColor(hex: 0x5A3A00))
        }
    }

    /// Loose change on the floor.
    func tokenTexture() -> SKTexture {
        texture(key: "token", metres: CGSize(width: 1.2, height: 1.2)) { context, _ in
            self.ellipse(context, centre: CGPoint(x: 0.04, y: -0.05), radius: 0.4, color: RacerColor(0, 0, 0), alpha: 0.25)
            self.ellipse(context, centre: .zero, radius: 0.4, color: RacerColor(hex: 0xE0A72C))
            self.ellipse(context, centre: .zero, radius: 0.29, color: RacerColor(hex: 0xFFD469))
            self.ellipse(context, centre: .zero, radius: 0.12, color: RacerColor(hex: 0xB98416))
        }
    }

    /// Air-curtain vent that hands out a boost.
    func boostPadTexture() -> SKTexture {
        texture(key: "boost-pad", metres: CGSize(width: 3.4, height: 3.4)) { context, _ in
            self.fill(context, rect: CGRect(x: -1.5, y: -1.5, width: 3, height: 3),
                      color: RacerColor(hex: 0x1E2430), alpha: 0.65, corner: 0.3)
            for index in 0..<3 {
                let chevron = UIBezierPath()
                let x = -0.8 + CGFloat(index) * 0.7
                chevron.move(to: CGPoint(x: x, y: -0.7))
                chevron.addLine(to: CGPoint(x: x + 0.5, y: 0))
                chevron.addLine(to: CGPoint(x: x, y: 0.7))
                self.stroke(
                    context,
                    path: chevron,
                    color: Palette.boostGlow,
                    width: 0.18,
                    alpha: 0.55 + 0.15 * CGFloat(index)
                )
            }
        }
    }

    /// Spilled cooking oil.
    func greaseTexture() -> SKTexture {
        texture(key: "grease", metres: CGSize(width: 3.6, height: 3.6)) { context, _ in
            var random = DeterministicRandom(seed: 0x9110)
            let blob = UIBezierPath()
            let points = 14
            for index in 0...points {
                let angle = CGFloat(index) / CGFloat(points) * 2 * .pi
                let radius = CGFloat(random.nextDouble(in: 1.15...1.55))
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.85)
                if index == 0 { blob.move(to: point) } else { blob.addLine(to: point) }
            }
            blob.close()
            context.setFillColor(UIColor(RacerColor(hex: 0x3B3222), alpha: 0.82).cgColor)
            context.addPath(blob.cgPath)
            context.fillPath()
            // Oily sheen.
            self.ellipse(context, centre: CGPoint(x: -0.25, y: 0.2), radius: 0.5,
                         color: RacerColor(hex: 0x8A7CF0), alpha: 0.35)
            self.ellipse(context, centre: CGPoint(x: 0.4, y: -0.3), radius: 0.3,
                         color: RacerColor(hex: 0x6FD6E8), alpha: 0.28)
        }
    }

    /// Shaken fizzy can, in flight.
    func canTexture() -> SKTexture {
        texture(key: "can", metres: CGSize(width: 1.0, height: 1.0)) { context, _ in
            self.fill(context, rect: CGRect(x: -0.3, y: -0.18, width: 0.6, height: 0.36),
                      color: RacerColor(hex: 0xEF476F), corner: 0.08)
            self.fill(context, rect: CGRect(x: -0.3, y: -0.05, width: 0.6, height: 0.1),
                      color: RacerColor(0.98, 0.98, 1), alpha: 0.85)
            self.ellipse(context, centre: CGPoint(x: 0.3, y: 0), radius: 0.12, color: RacerColor(0.8, 0.82, 0.88))
        }
    }

    /// A milk crate from the shield stack.
    func shieldCrateTexture() -> SKTexture {
        texture(key: "shield-crate", metres: CGSize(width: 1.1, height: 1.1)) { context, _ in
            let box = CGRect(x: -0.36, y: -0.36, width: 0.72, height: 0.72)
            self.fill(context, rect: box, color: RacerColor(hex: 0x2A9D8F), corner: 0.08)
            self.stroke(context, path: UIBezierPath(roundedRect: box, cornerRadius: 0.08),
                        color: RacerColor(hex: 0x14685E), width: 0.07)
            let grid = UIBezierPath()
            grid.move(to: CGPoint(x: 0, y: box.minY))
            grid.addLine(to: CGPoint(x: 0, y: box.maxY))
            grid.move(to: CGPoint(x: box.minX, y: 0))
            grid.addLine(to: CGPoint(x: box.maxX, y: 0))
            self.stroke(context, path: grid, color: RacerColor(hex: 0x14685E), width: 0.05)
        }
    }

    // MARK: - Effects

    /// Soft radial falloff, used for lighting, boost glow and shadows.
    func glowTexture() -> SKTexture {
        texture(key: "glow", metres: CGSize(width: 4, height: 4)) { context, _ in
            let colours = [
                UIColor.white.withAlphaComponent(0.95).cgColor,
                UIColor.white.withAlphaComponent(0.35).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours,
                locations: [0, 0.45, 1]
            ) else { return }
            context.drawRadialGradient(
                gradient,
                startCenter: .zero,
                startRadius: 0,
                endCenter: .zero,
                endRadius: 1.9,
                options: []
            )
        }
    }

    /// Strip light above the aisle.
    func stripLightTexture(length: CGFloat) -> SKTexture {
        texture(key: "strip-\(Int(length))", metres: CGSize(width: length, height: 1.6)) { context, size in
            self.fill(
                context,
                rect: CGRect(x: -size.width / 2 + 0.2, y: -0.22, width: size.width - 0.4, height: 0.44),
                color: self.palette.ceilingLight,
                alpha: 0.5,
                corner: 0.2
            )
        }
    }

    func smokeTexture() -> SKTexture {
        texture(key: "smoke", metres: CGSize(width: 1.6, height: 1.6)) { context, _ in
            self.ellipse(context, centre: .zero, radius: 0.7, color: RacerColor(0.85, 0.86, 0.9), alpha: 0.5)
            self.ellipse(context, centre: CGPoint(x: 0.1, y: 0.08), radius: 0.42,
                         color: RacerColor(0.95, 0.96, 1), alpha: 0.4)
        }
    }

    func sparkTexture() -> SKTexture {
        texture(key: "spark", metres: CGSize(width: 0.5, height: 0.5)) { context, _ in
            self.ellipse(context, centre: .zero, radius: 0.16, color: Palette.boostGlow)
            self.ellipse(context, centre: .zero, radius: 0.07, color: RacerColor(1, 1, 1))
        }
    }

    /// Splash of liquid, for driving through a spill.
    func splashTexture() -> SKTexture {
        texture(key: "splash", metres: CGSize(width: 1.0, height: 1.0)) { context, _ in
            self.ellipse(context, centre: .zero, radius: 0.3, color: RacerColor(hex: 0x9FD8F2), alpha: 0.75)
        }
    }
}
