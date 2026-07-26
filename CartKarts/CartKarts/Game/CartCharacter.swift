import UIKit

/// A playable shopping cart. Stats are tuned around Rusty as the baseline.
struct CartCharacter {
    let name: String
    let bio: String
    /// Accent color used for the tarp/junk piled in the basket.
    let color: UIColor
    /// Top speed in points per second.
    let topSpeed: CGFloat
    /// How quickly the cart approaches its target speed (1/s).
    let acceleration: CGFloat
    /// Steering rate at full effectiveness (radians per second).
    let steering: CGFloat
    /// Physics mass multiplier; heavy carts shrug off bumps.
    let weight: CGFloat

    static let roster: [CartCharacter] = [
        CartCharacter(
            name: "Rusty",
            bio: "Left in a rainy parking lot since '09. Squeaks with pride.",
            color: UIColor(red: 0.80, green: 0.42, blue: 0.16, alpha: 1),
            topSpeed: 620, acceleration: 2.0, steering: 3.4, weight: 1.0
        ),
        CartCharacter(
            name: "Squeaky",
            bio: "Three good wheels and a dream. Corners like a gossip.",
            color: UIColor(red: 0.16, green: 0.68, blue: 0.66, alpha: 1),
            topSpeed: 590, acceleration: 2.2, steering: 4.0, weight: 0.9
        ),
        CartCharacter(
            name: "Big Bertha",
            bio: "Fully loaded. Once flattened a display of paper towels.",
            color: UIColor(red: 0.55, green: 0.32, blue: 0.72, alpha: 1),
            topSpeed: 665, acceleration: 1.6, steering: 2.9, weight: 1.3
        ),
        CartCharacter(
            name: "Lil' Zip",
            bio: "Half cart, half caffeine. Launches off the line.",
            color: UIColor(red: 0.72, green: 0.78, blue: 0.18, alpha: 1),
            topSpeed: 600, acceleration: 2.6, steering: 3.7, weight: 0.85
        ),
        CartCharacter(
            name: "Boss Hog",
            bio: "Rules the loading dock. Do not touch the hubcaps.",
            color: UIColor(red: 0.82, green: 0.24, blue: 0.24, alpha: 1),
            topSpeed: 640, acceleration: 1.8, steering: 3.1, weight: 1.2
        ),
        CartCharacter(
            name: "Coupon Carl",
            bio: "Knows every shortcut and every expired deal in town.",
            color: UIColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1),
            topSpeed: 610, acceleration: 2.1, steering: 3.5, weight: 1.0
        ),
    ]
}
