// Minimal UIKit stand-in for type-checking on Linux. Signatures mirror the
// real UIKit APIs used by the game. Never linked into the app.
@_exported import CoreGraphics
import Foundation

// MARK: - Colors, images, paths, fonts

open class UIColor {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(white: CGFloat, alpha: CGFloat) {}
    public static let white = UIColor(white: 1, alpha: 1)
    public static let clear = UIColor(white: 0, alpha: 0)
    public static let gray = UIColor(white: 0.5, alpha: 1)
    public var cgColor: CGColor { CGColor() }
    public func withAlphaComponent(_ alpha: CGFloat) -> UIColor { self }
}

open class UIImage {}

open class UIBezierPath {
    public init() {}
    public init(roundedRect: CGRect, cornerRadius: CGFloat) {}
    public init(ovalIn rect: CGRect) {}
    public func move(to point: CGPoint) {}
    public func addLine(to point: CGPoint) {}
    public func addQuadCurve(to endPoint: CGPoint, controlPoint: CGPoint) {}
    public func close() {}
    public var cgPath: CGPath { CGPath() }
}

open class UIFont {
    public struct Weight {
        public static let heavy = Weight()
        public static let bold = Weight()
    }
    public static func systemFont(ofSize size: CGFloat, weight: Weight) -> UIFont { UIFont() }
    public init() {}
}

// MARK: - Text attributes

public enum NSTextAlignment: Int {
    case left, center, right
}

open class NSParagraphStyle {
    public init() {}
}

open class NSMutableParagraphStyle: NSParagraphStyle {
    public var alignment: NSTextAlignment = .left
    public override init() { super.init() }
}

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key(rawValue: "NSFont")
    public static let foregroundColor = NSAttributedString.Key(rawValue: "NSColor")
    public static let paragraphStyle = NSAttributedString.Key(rawValue: "NSParagraphStyle")
}

extension NSString {
    public func draw(in rect: CGRect, withAttributes attrs: [NSAttributedString.Key: Any]?) {}
}

// MARK: - Graphics renderer

open class UIGraphicsImageRendererFormat {
    public init() {}
    public var scale: CGFloat = 1
}

open class UIGraphicsImageRendererContext {
    public var cgContext: CGContext { CGContext() }
}

open class UIGraphicsImageRenderer {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) {}
    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage { UIImage() }
}

// MARK: - Responder chain & views

open class UIResponder: NSObject {
    public override init() { super.init() }
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}

open class UITouch: NSObject {}

open class UIEvent: NSObject {}

open class UIView: UIResponder {
    public var frame: CGRect
    public var bounds: CGRect
    public init(frame: CGRect) {
        self.frame = frame
        self.bounds = CGRect(origin: .zero, size: frame.size)
        super.init()
    }
}

open class UIWindow: UIView {
    public var rootViewController: UIViewController?
    public func makeKeyAndVisible() {}
}

open class UIViewController: UIResponder {
    public var view: UIView!
    public override init() { super.init() }
    open func loadView() {}
    open func viewDidLoad() {}
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    open var prefersStatusBarHidden: Bool { false }
    open var prefersHomeIndicatorAutoHidden: Bool { false }
}

public struct UIInterfaceOrientationMask: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let landscape = UIInterfaceOrientationMask(rawValue: 1)
    public static let all = UIInterfaceOrientationMask(rawValue: 2)
}

open class UIScreen {
    public static let main = UIScreen()
    public var bounds = CGRect.zero
    public init() {}
}

// MARK: - Application lifecycle

open class UIApplication {
    public struct LaunchOptionsKey: Hashable {}
}

public protocol UIApplicationDelegate: AnyObject {}

extension UIApplicationDelegate {
    public static func main() {}
}

// MARK: - Haptics

open class UIImpactFeedbackGenerator {
    public enum FeedbackStyle {
        case light, medium, heavy
    }
    public init(style: FeedbackStyle) {}
    public func impactOccurred() {}
}
