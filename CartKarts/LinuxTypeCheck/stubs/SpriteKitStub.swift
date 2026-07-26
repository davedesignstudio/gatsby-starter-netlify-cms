// Minimal SpriteKit stand-in for type-checking on Linux. Signatures mirror
// the real SpriteKit APIs used by the game. Never linked into the app.
@_exported import UIKit
import Foundation

// MARK: - Node hierarchy

open class SKNode: UIResponder {
    public override init() { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init() }
    open var position: CGPoint = .zero
    open var zPosition: CGFloat = 0
    open var zRotation: CGFloat = 0
    open var alpha: CGFloat = 1
    open var name: String?
    open var physicsBody: SKPhysicsBody?
    open func addChild(_ node: SKNode) {}
    open func removeFromParent() {}
    open func removeAllActions() {}
    open func run(_ action: SKAction) {}
    open func run(_ action: SKAction, withKey key: String) {}
    open func setScale(_ scale: CGFloat) {}
    open func nodes(at p: CGPoint) -> [SKNode] { [] }
}

open class SKCameraNode: SKNode {}

open class SKSpriteNode: SKNode {
    public override init() { super.init() }
    public init(texture: SKTexture?, color: UIColor, size: CGSize) {
        super.init()
        self.texture = texture
        self.size = size
    }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public convenience init(texture: SKTexture?) {
        self.init(texture: texture, color: .white, size: .zero)
    }
    public convenience init(color: UIColor, size: CGSize) {
        self.init(texture: nil, color: color, size: size)
    }
    open var texture: SKTexture?
    open var size: CGSize = .zero
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    open var color: UIColor = .white
}

public enum SKLabelVerticalAlignmentMode {
    case baseline, center, top, bottom
}

public enum SKLabelHorizontalAlignmentMode {
    case center, left, right
}

open class SKLabelNode: SKNode {
    public convenience init(fontNamed fontName: String?) { self.init() }
    open var text: String?
    open var fontName: String?
    open var fontSize: CGFloat = 32
    open var fontColor: UIColor?
    open var verticalAlignmentMode: SKLabelVerticalAlignmentMode = .baseline
    open var horizontalAlignmentMode: SKLabelHorizontalAlignmentMode = .center
}

open class SKShapeNode: SKNode {
    public convenience init(rectOf size: CGSize, cornerRadius: CGFloat) { self.init() }
    public convenience init(rect: CGRect, cornerRadius: CGFloat) { self.init() }
    public convenience init(circleOfRadius radius: CGFloat) { self.init() }
    open var fillColor: UIColor = .white
    open var strokeColor: UIColor = .white
    open var lineWidth: CGFloat = 1
}

open class SKEmitterNode: SKNode {
    open var particleTexture: SKTexture?
    open var particleBirthRate: CGFloat = 0
    open var particleLifetime: CGFloat = 0
    open var particleAlpha: CGFloat = 1
    open var particleAlphaSpeed: CGFloat = 0
    open var particleScale: CGFloat = 1
    open var particleScaleSpeed: CGFloat = 0
    open var particleSpeed: CGFloat = 0
    open var particleSpeedRange: CGFloat = 0
    open var emissionAngle: CGFloat = 0
    open var emissionAngleRange: CGFloat = 0
    open var particleColor: UIColor = .white
    open var particleColorBlendFactor: CGFloat = 0
    open weak var targetNode: SKNode?
}

// MARK: - Textures

open class SKTexture {
    public init(image: UIImage) {}
    open func size() -> CGSize { .zero }
}

// MARK: - Physics

open class SKPhysicsBody {
    public init(circleOfRadius r: CGFloat) {}
    public init(rectangleOf s: CGSize) {}
    open var mass: CGFloat = 1
    open var friction: CGFloat = 0.2
    open var restitution: CGFloat = 0.2
    open var linearDamping: CGFloat = 0.1
    open var angularDamping: CGFloat = 0.1
    open var allowsRotation = true
    open var isDynamic = true
    open var categoryBitMask: UInt32 = 0xFFFFFFFF
    open var collisionBitMask: UInt32 = 0xFFFFFFFF
    open var contactTestBitMask: UInt32 = 0
    open var velocity = CGVector(dx: 0, dy: 0)
    open var node: SKNode? { nil }
}

open class SKPhysicsContact {
    open var bodyA: SKPhysicsBody { SKPhysicsBody(circleOfRadius: 0) }
    open var bodyB: SKPhysicsBody { SKPhysicsBody(circleOfRadius: 0) }
}

public protocol SKPhysicsContactDelegate: AnyObject {
    func didBegin(_ contact: SKPhysicsContact)
    func didEnd(_ contact: SKPhysicsContact)
}

extension SKPhysicsContactDelegate {
    public func didBegin(_ contact: SKPhysicsContact) {}
    public func didEnd(_ contact: SKPhysicsContact) {}
}

open class SKPhysicsWorld {
    open var gravity = CGVector(dx: 0, dy: -9.8)
    open weak var contactDelegate: SKPhysicsContactDelegate?
}

// MARK: - Scenes & view

public enum SKSceneScaleMode {
    case fill, aspectFill, aspectFit, resizeFill
}

open class SKScene: SKNode {
    public init(size: CGSize) {
        super.init()
        self.size = size
    }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    open var size: CGSize = .zero
    open var scaleMode: SKSceneScaleMode = .fill
    open var backgroundColor: UIColor = .white
    open var anchorPoint: CGPoint = .zero
    open var camera: SKCameraNode?
    public let physicsWorld = SKPhysicsWorld()
    open var view: SKView? { nil }
    open func didMove(to view: SKView) {}
    open func didChangeSize(_ oldSize: CGSize) {}
    open func update(_ currentTime: TimeInterval) {}
}

open class SKTransition {
    public init() {}
    public class func fade(withDuration duration: TimeInterval) -> SKTransition { SKTransition() }
    public class func doorsOpenHorizontal(withDuration duration: TimeInterval) -> SKTransition { SKTransition() }
}

open class SKView: UIView {
    open var ignoresSiblingOrder = false
    open var showsFPS = false
    open var showsNodeCount = false
    open func presentScene(_ scene: SKScene?) {}
    open func presentScene(_ scene: SKScene, transition: SKTransition) {}
}

// MARK: - Actions

open class SKAction {
    public init() {}
    public class func repeatForever(_ action: SKAction) -> SKAction { SKAction() }
    public class func `repeat`(_ action: SKAction, count: Int) -> SKAction { SKAction() }
    public class func sequence(_ actions: [SKAction]) -> SKAction { SKAction() }
    public class func group(_ actions: [SKAction]) -> SKAction { SKAction() }
    public class func rotate(toAngle angle: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func rotate(byAngle angle: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func fadeAlpha(to alpha: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func fadeOut(withDuration duration: TimeInterval) -> SKAction { SKAction() }
    public class func fadeIn(withDuration duration: TimeInterval) -> SKAction { SKAction() }
    public class func scale(to scale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func scaleX(to xScale: CGFloat, y yScale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func moveBy(x deltaX: CGFloat, y deltaY: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public class func wait(forDuration duration: TimeInterval) -> SKAction { SKAction() }
    public class func run(_ block: @escaping () -> Void) -> SKAction { SKAction() }
    public class func removeFromParent() -> SKAction { SKAction() }
}

// MARK: - Touch helpers

extension UITouch {
    public func location(in node: SKNode) -> CGPoint { .zero }
}
