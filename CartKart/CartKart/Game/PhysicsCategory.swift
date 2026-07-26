import Foundation

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let cart: UInt32 = 0b1
    static let wall: UInt32 = 0b10
    static let itemBox: UInt32 = 0b100
    static let projectile: UInt32 = 0b1000
    static let hazard: UInt32 = 0b10000
    static let boostPad: UInt32 = 0b100000
    static let checkpoint: UInt32 = 0b1000000
}
