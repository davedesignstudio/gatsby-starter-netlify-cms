// Stand-ins for the Apple frameworks, used only by Tools/typecheck.sh.
//
// Swift on Linux cannot import UIKit, SpriteKit, CoreGraphics, AVFoundation,
// CoreMotion or GameController, so the game's rendering and audio code could
// otherwise only be compiled on a Mac. These declarations mirror the parts of
// those frameworks the game actually touches, which lets the real compiler
// type-check the drawing maths, the scene wiring and the audio synthesis.
//
// They are deliberately *not* part of the app target (the Xcode project only
// picks up App/ShoppingCartRacer and Sources/), and they prove nothing about
// whether a signature matches Apple's — only that the game's own code is
// internally consistent. On a Mac, the real SDK is the authority.

import Foundation

// MARK: - Core Graphics
//
// CGFloat, CGPoint, CGSize and CGRect already come from Foundation on Linux.

public final class CGColor {}

/// Core Foundation's array type is not available on Linux; the game only ever
/// hands one to `CGGradient`, so an opaque box is enough for type-checking.
public typealias CFArray = AnyObject

public enum CGLineJoin {
    case miter, round, bevel
}

public enum CGLineCap {
    case butt, round, square
}

public final class CGColorSpace {}

public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace { CGColorSpace() }

public final class CGGradient {
    public init?(colorsSpace: CGColorSpace?, colors: CFArray, locations: [CGFloat]?) {}
}

public struct CGGradientDrawingOptions: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

public class CGPath {}

public final class CGMutablePath: CGPath {
    public override init() {}
    public func move(to point: CGPoint) {}
    public func addLine(to point: CGPoint) {}
    public func closeSubpath() {}
}

public final class CGContext {
    public func translateBy(x: CGFloat, y: CGFloat) {}
    public func scaleBy(x: CGFloat, y: CGFloat) {}
    public func rotate(by angle: CGFloat) {}
    public func saveGState() {}
    public func restoreGState() {}
    public func setFillColor(_ color: CGColor) {}
    public func setStrokeColor(_ color: CGColor) {}
    public func setLineWidth(_ width: CGFloat) {}
    public func setLineJoin(_ join: CGLineJoin) {}
    public func setLineCap(_ cap: CGLineCap) {}
    public func fill(_ rect: CGRect) {}
    public func fillEllipse(in rect: CGRect) {}
    public func addPath(_ path: CGPath) {}
    public func fillPath() {}
    public func strokePath() {}
    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {}
}

// MARK: - UIKit

public class UIColor {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(white: CGFloat, alpha: CGFloat) {}
    public var cgColor: CGColor { CGColor() }
    public func withAlphaComponent(_ alpha: CGFloat) -> UIColor { self }
    public static let white = UIColor(white: 1, alpha: 1)
    public static let black = UIColor(white: 0, alpha: 1)
    public static let clear = UIColor(white: 0, alpha: 0)
}

public final class UIBezierPath {
    public init() {}
    public init(rect: CGRect) {}
    public init(roundedRect: CGRect, cornerRadius: CGFloat) {}
    public var cgPath: CGPath { CGPath() }
    public func move(to point: CGPoint) {}
    public func addLine(to point: CGPoint) {}
    public func addQuadCurve(to point: CGPoint, controlPoint: CGPoint) {}
    public func close() {}
}

public final class UIImage {}

public final class UIGraphicsImageRendererFormat {
    public init() {}
    public var scale: CGFloat = 1
    public var opaque = false
}

public final class UIGraphicsImageRendererContext {
    public var cgContext = CGContext()
}

public final class UIGraphicsImageRenderer {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) {}
    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        actions(UIGraphicsImageRendererContext())
        return UIImage()
    }
}

public enum UIImpactFeedbackStyle {
    case light, medium, heavy, rigid, soft
}

public class UIFeedbackGenerator {
    public func prepare() {}
}

public final class UIImpactFeedbackGenerator: UIFeedbackGenerator {
    public init(style: UIImpactFeedbackStyle) {}
    public func impactOccurred() {}
    public func impactOccurred(intensity: CGFloat) {}
}

public final class UINotificationFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackType {
        case success, warning, error
    }

    public override init() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}

// MARK: - SpriteKit

public enum SKBlendMode {
    case alpha, add, subtract, multiply, replace
}

public enum SKTextureFilteringMode {
    case nearest, linear
}

public enum SKSceneScaleMode {
    case fill, aspectFill, aspectFit, resizeFill
}

public final class SKTexture {
    public init(image: UIImage) {}
    public var filteringMode: SKTextureFilteringMode = .linear
    public func size() -> CGSize { CGSize(width: 64, height: 64) }
}

public final class SKAction {
    public static func wait(forDuration duration: TimeInterval) -> SKAction { SKAction() }
    public static func removeFromParent() -> SKAction { SKAction() }
    public static func sequence(_ actions: [SKAction]) -> SKAction { SKAction() }
    public static func group(_ actions: [SKAction]) -> SKAction { SKAction() }
    public static func repeatForever(_ action: SKAction) -> SKAction { SKAction() }
    public static func fadeAlpha(to alpha: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public static func fadeOut(withDuration duration: TimeInterval) -> SKAction { SKAction() }
    public static func rotate(byAngle radians: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public static func scale(to scale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public static func scaleX(to scale: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
    public static func moveBy(x deltaX: CGFloat, y deltaY: CGFloat, duration: TimeInterval) -> SKAction { SKAction() }
}

public class SKNode {
    public init() {}
    public required init?(coder aDecoder: NSCoder) {}
    public var position = CGPoint.zero
    public var zPosition: CGFloat = 0
    public var zRotation: CGFloat = 0
    public var alpha: CGFloat = 1
    public var isHidden = false
    public var isPaused = false
    public var xScale: CGFloat = 1
    public var yScale: CGFloat = 1
    public private(set) var children: [SKNode] = []
    public private(set) weak var parent: SKNode?
    public func addChild(_ node: SKNode) {
        children.append(node)
        node.parent = self
    }
    public func removeFromParent() {}
    public func removeAllChildren() {}
    public func setScale(_ scale: CGFloat) {
        xScale = scale
        yScale = scale
    }
    public func run(_ action: SKAction) {}
}

public class SKSpriteNode: SKNode {
    public init(texture: SKTexture?) { super.init() }
    public init(color: UIColor, size: CGSize) {
        self.size = size
        super.init()
    }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public var texture: SKTexture?
    public var size = CGSize.zero
    public var color = UIColor.white
    public var colorBlendFactor: CGFloat = 0
    public var blendMode: SKBlendMode = .alpha
}

public class SKShapeNode: SKNode {
    public init(path: CGPath) { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public var path: CGPath?
    public var fillColor = UIColor.clear
    public var strokeColor = UIColor.white
    public var lineWidth: CGFloat = 1
    public var lineCap: CGLineCap = .butt
    public var blendMode: SKBlendMode = .alpha
}

public class SKLabelNode: SKNode {
    public init(text: String?) { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public var text: String?
    public var fontName: String?
    public var fontSize: CGFloat = 32
    public var fontColor: UIColor?
}

public class SKCameraNode: SKNode {
    public override init() { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
}

public class SKEmitterNode: SKNode {
    public override init() { super.init() }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public var particleTexture: SKTexture?
    public var particleBirthRate: CGFloat = 0
    public var numParticlesToEmit: Int = 0
    public var particleLifetime: CGFloat = 0
    public var particleLifetimeRange: CGFloat = 0
    public var particleSize = CGSize.zero
    public var particleAlpha: CGFloat = 1
    public var particleAlphaSpeed: CGFloat = 0
    public var particleScale: CGFloat = 1
    public var particleScaleRange: CGFloat = 0
    public var particleScaleSpeed: CGFloat = 0
    public var particleSpeed: CGFloat = 0
    public var particleSpeedRange: CGFloat = 0
    public var emissionAngle: CGFloat = 0
    public var emissionAngleRange: CGFloat = 0
    public var particleColor = UIColor.white
    public var particleColorBlendFactor: CGFloat = 0
    public var particleBlendMode: SKBlendMode = .alpha
    public weak var targetNode: SKNode?
    public func resetSimulation() {}
}

public class SKView {}

public class SKScene: SKNode {
    public init(size: CGSize) {
        self.size = size
        super.init()
    }
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    public var size: CGSize
    public var scaleMode: SKSceneScaleMode = .fill
    public var backgroundColor = UIColor.black
    public var camera: SKCameraNode?
    public func didMove(to view: SKView) {}
    public func update(_ currentTime: TimeInterval) {}
    public func didChangeSize(_ oldSize: CGSize) {}
}

// MARK: - AVFoundation

public class AVAudioNode {}

public final class AVAudioFormat {
    public init?(standardFormatWithSampleRate sampleRate: Double, channels: UInt32) {
        self.sampleRate = sampleRate
    }
    public let sampleRate: Double
}

public typealias AVAudioFrameCount = UInt32

public final class AVAudioPCMBuffer {
    public init?(pcmFormat format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {}
    public var frameLength: AVAudioFrameCount = 0
    public var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { nil }
}

public struct AVAudioPlayerNodeBufferOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    public static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
}

public final class AVAudioTime {}

public class AVAudioPlayerNode: AVAudioNode {
    public override init() {}
    public var volume: Float = 1
    public func scheduleBuffer(
        _ buffer: AVAudioPCMBuffer,
        at when: AVAudioTime?,
        options: AVAudioPlayerNodeBufferOptions
    ) {}
    public func play() {}
    public func stop() {}
}

public class AVAudioMixerNode: AVAudioNode {
    public override init() {}
    public var outputVolume: Float = 1
}

public class AVAudioUnitVarispeed: AVAudioNode {
    public override init() {}
    public var rate: Float = 1
}

public final class AVAudioEngine {
    public init() {}
    public var mainMixerNode = AVAudioMixerNode()
    public func attach(_ node: AVAudioNode) {}
    public func connect(_ from: AVAudioNode, to: AVAudioNode, format: AVAudioFormat?) {}
    public func start() throws {}
    public func stop() {}
}

public final class AVAudioSession {
    public struct Category {
        public static let ambient = Category()
        public static let playback = Category()
    }

    public struct Mode {
        public static let `default` = Mode()
    }

    public struct CategoryOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1)
    }

    public static func sharedInstance() -> AVAudioSession { AVAudioSession() }
    public func setCategory(_ category: Category, mode: Mode, options: CategoryOptions) throws {}
    public func setActive(_ active: Bool) throws {}
}

// MARK: - Core Motion

public final class CMAttitude {
    public var roll: Double = 0
    public var pitch: Double = 0
    public var yaw: Double = 0
}

public final class CMDeviceMotion {
    public var attitude = CMAttitude()
}

public final class CMMotionManager {
    public init() {}
    public var deviceMotionUpdateInterval: TimeInterval = 0
    public var isDeviceMotionAvailable = true
    public var isDeviceMotionActive = false
    public func startDeviceMotionUpdates(
        to queue: OperationQueue,
        withHandler handler: @escaping (CMDeviceMotion?, Error?) -> Void
    ) {}
    public func stopDeviceMotionUpdates() {}
}

// MARK: - GameController

public final class GCControllerButtonInput {
    public var isPressed = false
    public var value: Float = 0
}

public final class GCControllerAxisInput {
    public var value: Float = 0
}

public final class GCControllerDirectionPad {
    public var xAxis = GCControllerAxisInput()
    public var yAxis = GCControllerAxisInput()
    public var left = GCControllerButtonInput()
    public var right = GCControllerButtonInput()
    public var up = GCControllerButtonInput()
    public var down = GCControllerButtonInput()
}

public final class GCExtendedGamepad {
    public var leftThumbstick = GCControllerDirectionPad()
    public var rightThumbstick = GCControllerDirectionPad()
    public var dpad = GCControllerDirectionPad()
    public var buttonA = GCControllerButtonInput()
    public var buttonB = GCControllerButtonInput()
    public var buttonX = GCControllerButtonInput()
    public var buttonY = GCControllerButtonInput()
    public var leftShoulder = GCControllerButtonInput()
    public var rightShoulder = GCControllerButtonInput()
    public var leftTrigger = GCControllerButtonInput()
    public var rightTrigger = GCControllerButtonInput()
}

public final class GCController {
    public var extendedGamepad: GCExtendedGamepad?
    public static func controllers() -> [GCController] { [] }
}

extension NSNotification.Name {
    public static let GCControllerDidConnect = NSNotification.Name("GCControllerDidConnect")
    public static let GCControllerDidDisconnect = NSNotification.Name("GCControllerDidDisconnect")
}
