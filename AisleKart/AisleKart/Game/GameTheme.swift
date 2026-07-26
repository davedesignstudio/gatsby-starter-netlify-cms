import SpriteKit
import UIKit

enum GameTheme {
    static let aisleFloor = UIColor(red: 0.86, green: 0.88, blue: 0.84, alpha: 1)
    static let aisleTile = UIColor(red: 0.78, green: 0.82, blue: 0.76, alpha: 1)
    static let shelfBrown = UIColor(red: 0.45, green: 0.28, blue: 0.16, alpha: 1)
    static let shelfFace = UIColor(red: 0.62, green: 0.38, blue: 0.22, alpha: 1)
    static let produceGreen = UIColor(red: 0.28, green: 0.55, blue: 0.32, alpha: 1)
    static let freezerBlue = UIColor(red: 0.35, green: 0.55, blue: 0.72, alpha: 1)
    static let checkoutYellow = UIColor(red: 0.92, green: 0.78, blue: 0.22, alpha: 1)
    static let accentOrange = UIColor(red: 0.92, green: 0.45, blue: 0.18, alpha: 1)
    static let ink = UIColor(red: 0.12, green: 0.14, blue: 0.13, alpha: 1)
    static let hudCream = UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)

    static let cartColors: [UIColor] = [
        UIColor(red: 0.85, green: 0.22, blue: 0.18, alpha: 1), // Rusty Red
        UIColor(red: 0.18, green: 0.45, blue: 0.78, alpha: 1), // Blue Basket
        UIColor(red: 0.20, green: 0.62, blue: 0.38, alpha: 1), // Green Grocer
        UIColor(red: 0.78, green: 0.55, blue: 0.15, alpha: 1)  // Gold Cart
    ]

    static let cartNames = ["Rusty", "Blue Basket", "Green Grocer", "Goldie"]
}

enum PhysicsCategory {
    static let cart: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let itemBox: UInt32 = 1 << 2
    static let hazard: UInt32 = 1 << 3
    static let projectile: UInt32 = 1 << 4
    static let checkpoint: UInt32 = 1 << 5
}
