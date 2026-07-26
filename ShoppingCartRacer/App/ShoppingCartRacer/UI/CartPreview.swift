import SwiftUI

/// Draws a cart from its `CartArtPlan` with SwiftUI's Canvas, so the menus show
/// the same vehicle the race does without spinning up a SpriteKit scene.
struct CartPreview: View {
    let racer: Racer
    /// Radians; 0 points the cart to the right.
    var heading: Double = 0
    var showsShadow = true

    var body: some View {
        Canvas { context, size in
            let plan = CartArtPlan(racer: racer)
            // Fit the cart into the available space with a little breathing room.
            let extent = max(plan.length + 1.2, plan.width + 0.8)
            let scale = min(size.width, size.height) / extent
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: -scale)
            context.rotate(by: .radians(-heading))

            if showsShadow {
                let shadow = CGRect(
                    x: -plan.length / 2 - 0.1,
                    y: -plan.width / 2 - 0.05,
                    width: plan.length + 0.2,
                    height: plan.width + 0.1
                )
                context.fill(Path(ellipseIn: shadow.offsetBy(dx: 0.06, dy: -0.1)), with: .color(.black.opacity(0.3)))
            }

            for wheel in plan.wheels {
                let rect = CGRect(
                    x: wheel.offset.x - wheel.radius * 1.35,
                    y: wheel.offset.y - wheel.radius * 1.35,
                    width: wheel.radius * 2.7,
                    height: wheel.radius * 2.7
                )
                context.fill(Path(ellipseIn: rect), with: .color(Color(RacerColor(0.09, 0.09, 0.11))))
            }

            // Push handle.
            var handle = Path()
            handle.move(to: CGPoint(x: plan.handleOffset.x, y: -plan.handleWidth / 2))
            handle.addLine(to: CGPoint(x: plan.handleOffset.x, y: plan.handleWidth / 2))
            context.stroke(handle, with: .color(Color(plan.trimColor)), lineWidth: 0.14)

            // Tapered basket.
            let taper = plan.taper * plan.width * 0.5
            var body = Path()
            body.move(to: CGPoint(x: -plan.length / 2, y: -plan.width / 2))
            body.addLine(to: CGPoint(x: plan.length / 2, y: -plan.width / 2 + taper))
            body.addLine(to: CGPoint(x: plan.length / 2, y: plan.width / 2 - taper))
            body.addLine(to: CGPoint(x: -plan.length / 2, y: plan.width / 2))
            body.closeSubpath()
            context.fill(body, with: .color(Color(plan.bodyColor)))

            for piece in plan.cargo {
                let colour = plan.cargoColors[piece.colorIndex % plan.cargoColors.count]
                let rect = CGRect(
                    x: piece.offset.x - piece.size.x / 2,
                    y: piece.offset.y - piece.size.y / 2,
                    width: piece.size.x,
                    height: piece.size.y
                )
                switch piece.kind {
                case .bottle, .can, .cabbage:
                    context.fill(Path(ellipseIn: rect), with: .color(Color(colour)))
                case .bread:
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: piece.size.y / 2),
                        with: .color(Color(RacerColor(hex: 0xC98A4B)))
                    )
                default:
                    context.fill(Path(roundedRect: rect, cornerRadius: 0.03), with: .color(Color(colour)))
                }
            }

            if plan.meshBarCount > 0 {
                var mesh = Path()
                for index in 0...plan.meshBarCount {
                    let t = Double(index) / Double(plan.meshBarCount)
                    let x = -plan.length / 2 + plan.length * t
                    let inset = taper * t
                    mesh.move(to: CGPoint(x: x, y: -plan.width / 2 + inset))
                    mesh.addLine(to: CGPoint(x: x, y: plan.width / 2 - inset))
                }
                context.stroke(mesh, with: .color(.white.opacity(0.7)), lineWidth: 0.035)
            }

            context.stroke(body, with: .color(.white.opacity(0.9)), lineWidth: 0.06)

            // Driver.
            let driver = CGRect(
                x: plan.driverOffset.x - plan.driverRadius,
                y: -plan.driverRadius,
                width: plan.driverRadius * 2,
                height: plan.driverRadius * 2
            )
            context.fill(Path(ellipseIn: driver), with: .color(Color(plan.trimColor)))
        }
    }
}
