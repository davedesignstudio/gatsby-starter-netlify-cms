// Compiled together with the game sources (against the Linux stubs) to sanity
// check the track geometry: the racing line, item boxes, and starting grid
// must all clear the shelving, checkout counters, pallets, and outer walls
// with enough margin for a kart. Run via check.sh.
import Foundation
import SpriteKit

@main
struct TrackValidation {
    static func main() {
        let track = Track()
        let kartRadius: CGFloat = 26
        let margin: CGFloat = 8
        var failures: [String] = []

        // Solid geometry: placed obstacles plus the four outer walls.
        var solids: [CGRect] = track.obstacles.map { $0.rect }
        let world = Track.worldSize
        let t = Track.wallThickness
        solids.append(CGRect(x: 0, y: 0, width: world.width, height: t))
        solids.append(CGRect(x: 0, y: world.height - t, width: world.width, height: t))
        solids.append(CGRect(x: 0, y: 0, width: t, height: world.height))
        solids.append(CGRect(x: world.width - t, y: 0, width: t, height: world.height))

        func firstHit(_ point: CGPoint, inflate: CGFloat) -> CGRect? {
            solids.first { $0.insetBy(dx: -inflate, dy: -inflate).contains(point) }
        }

        func checkSegment(_ a: CGPoint, _ b: CGPoint, inflate: CGFloat, label: String) {
            let steps = max(2, Int(a.distance(to: b) / 8))
            for s in 0...steps {
                let p = a + (b - a) * (CGFloat(s) / CGFloat(steps))
                if let rect = firstHit(p, inflate: inflate) {
                    failures.append("\(label): blocked at (\(Int(p.x)), \(Int(p.y))) by rect \(rect)")
                    return
                }
            }
        }

        // 1. Consecutive racing-line segments must be drivable and reasonably short.
        let wps = track.waypoints
        for i in wps.indices {
            let a = wps[i].position
            let b = wps[(i + 1) % wps.count].position
            checkSegment(a, b, inflate: kartRadius + margin,
                         label: "waypoint segment \(i) -> \((i + 1) % wps.count)")
            let length = a.distance(to: b)
            if length > 620 {
                failures.append("waypoint segment \(i): too long (\(Int(length)) pt) for AI radius-advance")
            }
        }

        // 2. Waypoints themselves must sit in open floor.
        for (i, wp) in wps.enumerated() {
            if let rect = firstHit(wp.position, inflate: kartRadius) {
                failures.append("waypoint \(i) at \(wp.position) is inside rect \(rect)")
            }
        }

        // 3. Item boxes and puddles must be reachable open floor.
        for (i, p) in track.itemBoxPositions.enumerated() {
            if firstHit(p, inflate: 20) != nil {
                failures.append("item box \(i) at \(p) overlaps an obstacle")
            }
        }
        for (i, p) in track.puddlePositions.enumerated() {
            if firstHit(p, inflate: 10) != nil {
                failures.append("puddle \(i) at \(p) overlaps an obstacle")
            }
        }

        // 4. Starting grid slots must be clear, mutually spaced, and have a
        //    clear run to the first waypoint.
        let grid = track.gridPositions(count: 6)
        for (i, g) in grid.enumerated() {
            if let rect = firstHit(g, inflate: kartRadius + 4) {
                failures.append("grid slot \(i) at \(g) overlaps rect \(rect)")
            }
            checkSegment(g, wps[0].position, inflate: kartRadius,
                         label: "grid slot \(i) run to waypoint 0")
            for j in (i + 1)..<grid.count where g.distance(to: grid[j]) < 70 {
                failures.append("grid slots \(i) and \(j) are only \(Int(g.distance(to: grid[j]))) pt apart")
            }
        }

        // 5. Headless lap simulation: a real Kart driven by a real AIDriver
        //    around the real Track (stub physics: velocity is integrated
        //    manually, no collisions). Proves the driving model and waypoint
        //    tuning can complete laps without stalling or clipping shelving.
        for (rosterIndex, character) in CartCharacter.roster.enumerated() {
            let kart = Kart(character: character, isPlayer: false)
            kart.position = grid[rosterIndex % grid.count]
            kart.zRotation = track.startRotation
            kart.waypointCount = wps.count
            kart.throttleInput = 1
            let driver = AIDriver(kart: kart, seed: rosterIndex + 1)

            let dt: TimeInterval = 1.0 / 60.0
            var time: TimeInterval = 0
            var excursions = 0
            let target = wps.count * 2 // two full laps

            while kart.totalWaypointsPassed < target && time < 300 {
                _ = driver.update(dt: dt, track: track)
                kart.update(dt: dt)
                if let v = kart.physicsBody?.velocity {
                    kart.position = kart.position + CGPoint(x: v.dx, y: v.dy) * CGFloat(dt)
                }
                let wp = wps[kart.nextWaypointIndex % wps.count]
                if kart.position.distance(to: wp.position) < wp.radius {
                    kart.nextWaypointIndex = (kart.nextWaypointIndex + 1) % wps.count
                    kart.totalWaypointsPassed += 1
                }
                if firstHit(kart.position, inflate: 0) != nil {
                    excursions += 1
                }
                time += dt
            }

            if kart.totalWaypointsPassed < target {
                failures.append("simulated \(character.name) stalled after "
                    + "\(kart.totalWaypointsPassed)/\(target) waypoints in \(Int(time))s "
                    + "near \(kart.position)")
            } else if excursions > 0 {
                failures.append("simulated \(character.name) spent \(excursions) frames "
                    + "inside solid geometry")
            } else {
                let lapTime = time / 2
                print("simulated \(character.name): 2 clean laps, ~\(String(format: "%.1f", lapTime))s per lap")
            }
        }

        if failures.isEmpty {
            print("Track validation passed: \(wps.count) waypoints, \(solids.count) solids, "
                + "\(track.itemBoxPositions.count) item boxes, \(grid.count) grid slots.")
        } else {
            for failure in failures {
                print("FAIL: \(failure)")
            }
            exit(1)
        }
    }
}
