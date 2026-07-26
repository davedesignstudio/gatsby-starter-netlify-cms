import CartKartCore
import Foundation

/// Rasterises a course to a PPM image.
///
/// This is a level design aid: it shows the shape of the spline, where the
/// furniture ended up, and optionally the line the AI actually drove, without
/// needing to launch the game.
enum TrackMap {
    struct Pixel {
        var red: UInt8
        var green: UInt8
        var blue: UInt8

        init(_ colour: TrackTheme.RGB, shade: Double = 1) {
            red = UInt8(clamp(colour.red * shade, 0, 1) * 255)
            green = UInt8(clamp(colour.green * shade, 0, 1) * 255)
            blue = UInt8(clamp(colour.blue * shade, 0, 1) * 255)
        }

        init(red: UInt8, green: UInt8, blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// - Parameter trace: world positions to overlay, e.g. a driven racing line.
    static func render(track: Track, width: Int = 900, trace: [Vec2] = []) -> (pixels: [Pixel], width: Int, height: Int) {
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for sample in track.samples {
            minX = min(minX, sample.position.x)
            minY = min(minY, sample.position.y)
            maxX = max(maxX, sample.position.x)
            maxY = max(maxY, sample.position.y)
        }
        let margin = track.shoulderWidth + 320
        minX -= margin
        minY -= margin
        maxX += margin
        maxY += margin

        let worldWidth = maxX - minX
        let worldHeight = maxY - minY
        let scale = Double(width) / worldWidth
        let height = max(1, Int(worldHeight * scale))

        let background = Pixel(track.theme.shelf, shade: 0.35)
        var pixels = [Pixel](repeating: background, count: width * height)

        func world(atX x: Int, y: Int) -> Vec2 {
            // Image rows run top to bottom, world y runs bottom to top.
            Vec2(minX + (Double(x) + 0.5) / scale, maxY - (Double(y) + 0.5) / scale)
        }

        // Surfaces. The projection hint carries across the row, which keeps
        // this fast enough to be usable at a few hundred thousand pixels.
        for y in 0..<height {
            var hint: Int? = nil
            for x in 0..<width {
                let point = world(atX: x, y: y)
                let projection = track.project(point, hint: hint)
                hint = projection.sampleIndex
                let offset = abs(projection.lateralOffset)
                if offset <= projection.halfWidth {
                    // Fade the floor slightly towards the edges of the lane.
                    let edge = 1 - 0.12 * (offset / max(projection.halfWidth, 1))
                    pixels[y * width + x] = Pixel(track.theme.floor, shade: edge)
                } else if offset <= projection.halfWidth + track.shoulderWidth {
                    pixels[y * width + x] = Pixel(track.theme.rough)
                } else if offset <= projection.halfWidth + track.shoulderWidth + 90 {
                    pixels[y * width + x] = Pixel(track.theme.shelf)
                }
            }
        }

        func plot(_ position: Vec2, radius: Double, colour: Pixel) {
            let centreX = (position.x - minX) * scale
            let centreY = (maxY - position.y) * scale
            let pixelRadius = max(1.0, radius * scale)
            let minPX = max(0, Int(centreX - pixelRadius))
            let maxPX = min(width - 1, Int(centreX + pixelRadius))
            let minPY = max(0, Int(centreY - pixelRadius))
            let maxPY = min(height - 1, Int(centreY + pixelRadius))
            guard minPX <= maxPX, minPY <= maxPY else { return }
            for y in minPY...maxPY {
                for x in minPX...maxPX {
                    let dx = Double(x) - centreX
                    let dy = Double(y) - centreY
                    if dx * dx + dy * dy <= pixelRadius * pixelRadius {
                        pixels[y * width + x] = colour
                    }
                }
            }
        }

        for puddle in track.puddles {
            plot(puddle.position, radius: puddle.radius, colour: Pixel(red: 120, green: 200, blue: 245))
        }
        for pad in track.boostPads {
            plot(pad.position, radius: pad.radius, colour: Pixel(track.theme.accent))
        }
        for obstacle in track.obstacles {
            let colour = obstacle.isBreakable
                ? Pixel(red: 180, green: 140, blue: 85)
                : Pixel(red: 60, green: 45, blue: 35)
            plot(obstacle.position, radius: obstacle.radius, colour: colour)
        }
        for box in track.itemBoxes {
            plot(box.position, radius: box.radius, colour: Pixel(red: 250, green: 215, blue: 70))
        }

        // Finish line, drawn across the full width of the lane.
        let finish = track.sample(at: track.sampleIndex(atArcLength: track.finishArcLength))
        for step in stride(from: -finish.halfWidth, through: finish.halfWidth, by: 4) {
            plot(
                finish.position + finish.tangent.perpendicular * step,
                radius: 6,
                colour: Pixel(red: 245, green: 245, blue: 245)
            )
        }

        for point in trace {
            plot(point, radius: 7, colour: Pixel(red: 230, green: 40, blue: 90))
        }

        return (pixels, width, height)
    }

    static func writePPM(_ image: (pixels: [Pixel], width: Int, height: Int), to path: String) throws {
        var data = Data("P6\n\(image.width) \(image.height)\n255\n".utf8)
        data.reserveCapacity(data.count + image.pixels.count * 3)
        for pixel in image.pixels {
            data.append(pixel.red)
            data.append(pixel.green)
            data.append(pixel.blue)
        }
        try data.write(to: URL(fileURLWithPath: path))
    }
}
