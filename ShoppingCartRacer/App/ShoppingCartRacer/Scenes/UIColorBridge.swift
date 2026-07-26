import UIKit

/// Bridges the kit's framework-free colours into UIKit, for the Core Graphics
/// drawing and SpriteKit nodes. The SwiftUI equivalent lives in `Theme.swift`.
extension UIColor {
    convenience init(_ racerColor: RacerColor, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat(racerColor.red),
            green: CGFloat(racerColor.green),
            blue: CGFloat(racerColor.blue),
            alpha: alpha
        )
    }
}
