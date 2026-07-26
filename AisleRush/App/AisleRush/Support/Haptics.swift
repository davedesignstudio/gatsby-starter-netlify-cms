import UIKit

/// Thin wrapper so the rest of the game can fire haptics without worrying
/// about generator lifetimes or the user's preference.
enum Haptics {
    static var isEnabled = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        switch style {
        case .light, .soft: light.impactOccurred()
        case .heavy, .rigid: heavy.impactOccurred()
        default: medium.impactOccurred()
        }
    }

    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }
}
