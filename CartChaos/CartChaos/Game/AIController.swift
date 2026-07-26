import SpriteKit

final class AIController {
    private let track: TrackBuilder
    private var aggression: CGFloat

    init(track: TrackBuilder, aggression: CGFloat = 1.0) {
        self.track = track
        self.aggression = aggression
    }

    func steer(for cart: CartNode) -> (throttle: CGFloat, steer: CGFloat, useItem: Bool) {
        let n = track.centerline.count
        let lookAhead = 2
        let targetIndex = (cart.checkpointIndex + lookAhead) % n
        let target = track.centerline[targetIndex]

        // Slight lane offset so AI carts don't stack
        let hash = CGFloat(cart.profile.id.hashValue % 7) - 3
        let offsetTarget = CGPoint(x: target.x + hash * 8, y: target.y + hash * 5)

        let desired = atan2(offsetTarget.y - cart.position.y, offsetTarget.x - cart.position.x)
        var delta = desired - cart.heading
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }

        let steer = max(-1, min(1, delta * 1.8))
        var throttle: CGFloat = 1.0 * aggression

        // Slow for sharp turns
        if abs(delta) > 0.7 {
            throttle *= 0.65
        }

        // Off-track recovery
        if !track.isOnTrack(cart.position) {
            throttle = 0.4
        }

        // Use items opportunistically
        var use = false
        if let item = cart.heldItem {
            switch item {
            case .soda, .coupon:
                use = Bool.random() && Int.random(in: 0...40) == 0
            case .banana:
                use = Int.random(in: 0...55) == 0
            case .soup:
                use = abs(delta) < 0.35 && Int.random(in: 0...35) == 0
            }
        }

        return (throttle, steer, use)
    }
}
