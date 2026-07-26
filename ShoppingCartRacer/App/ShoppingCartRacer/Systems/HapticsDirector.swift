import UIKit

/// Thin wrapper over the standard feedback generators, mapping race events to
/// taps. Generators are prepared up front because a cold generator has a
/// noticeable delay, which would make a crash feel late.
final class HapticsDirector {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private var isEnabled = true
    /// Scrapes fire constantly while sliding along shelving; rate limit them.
    private var lastContinuousTap = Date.distantPast

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
    }

    func handle(events: [RaceEvent], playerID: Int?) {
        guard isEnabled else { return }
        for event in events {
            switch event {
            case .countdownBeep:
                light.impactOccurred(intensity: 0.6)
            case .raceStarted:
                medium.impactOccurred()
            case .rocketStart(let cartID) where cartID == playerID:
                heavy.impactOccurred()
            case .miniTurbo(let cartID, let tier) where cartID == playerID:
                medium.impactOccurred(intensity: CGFloat(min(1.0, 0.5 + 0.2 * Double(tier))))
            case .spunOut(let cartID) where cartID == playerID:
                notification.notificationOccurred(.error)
            case .slipped(let cartID, _) where cartID == playerID:
                notification.notificationOccurred(.warning)
            case .obstacleHit(let cartID, let kind, _) where cartID == playerID:
                if kind.isSoft {
                    light.impactOccurred(intensity: 0.7)
                } else {
                    heavy.impactOccurred()
                }
            case .cartBump(let cartID, _, let intensity, _) where cartID == playerID:
                medium.impactOccurred(intensity: CGFloat(max(0.2, min(1, intensity))))
            case .wallScrape(let cartID, let intensity, _) where cartID == playerID:
                throttledTap(intensity: intensity)
            case .itemCollected(let cartID, _) where cartID == playerID:
                light.impactOccurred(intensity: 0.5)
            case .lapCompleted(let cartID, _, _) where cartID == playerID:
                notification.notificationOccurred(.success)
            case .finished(let cartID, let racePosition, _) where cartID == playerID:
                notification.notificationOccurred(racePosition <= 3 ? .success : .warning)
            default:
                break
            }
        }
    }

    func tapSelection() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.5)
    }

    private func throttledTap(intensity: Double) {
        guard Date().timeIntervalSince(lastContinuousTap) > 0.18 else { return }
        lastContinuousTap = Date()
        light.impactOccurred(intensity: CGFloat(max(0.2, min(1, intensity))))
    }
}
