import SpriteKit

final class RaceManager {
    static let totalLaps = 3

    private let waypoints: [TrackWaypoint]
    private var carts: [ShoppingCart] = []

    init(waypoints: [TrackWaypoint]) {
        self.waypoints = waypoints
    }

    func register(_ cart: ShoppingCart) {
        carts.append(cart)
    }

    func updatePositions() {
        let sorted = carts.sorted { a, b in
            a.raceProgress(waypoints: waypoints) > b.raceProgress(waypoints: waypoints)
        }
        for (index, cart) in sorted.enumerated() {
            cart.racePosition = index + 1
        }
    }

    func checkPlayerWaypoint(_ cart: ShoppingCart) {
        guard !waypoints.isEmpty else { return }
        let target = waypoints[cart.waypointIndex].position
        let dist = hypot(target.x - cart.position.x, target.y - cart.position.y)
        if dist < 45 {
            cart.advanceWaypoint(total: waypoints.count)
        }
    }

    func isRaceFinished() -> ShoppingCart? {
        return carts.first { $0.lap >= Self.totalLaps }
    }

    func standings() -> [ShoppingCart] {
        carts.sorted { a, b in
            a.raceProgress(waypoints: waypoints) > b.raceProgress(waypoints: waypoints)
        }
    }
}
