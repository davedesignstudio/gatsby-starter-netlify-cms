// Minimal CoreGraphics stand-in so the game sources can be *type-checked* on
// Linux, where the real framework does not exist. Only the API surface used
// by the game is declared; bodies are inert. Never linked into the app.
@_exported import Foundation

public struct CGVector: Equatable {
    public var dx: CGFloat
    public var dy: CGFloat
    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }
    public static var zero: CGVector { CGVector(dx: 0, dy: 0) }
}

public final class CGColor {
    public init() {}
}

public final class CGPath {
    public init() {}
}

public final class CGContext {
    public init() {}
    public func setFillColor(_ color: CGColor) {}
    public func setStrokeColor(_ color: CGColor) {}
    public func setLineWidth(_ width: CGFloat) {}
    public func addPath(_ path: CGPath) {}
    public func fillPath() {}
    public func strokePath() {}
    public func fill(_ rect: CGRect) {}
    public func stroke(_ rect: CGRect) {}
    public func fillEllipse(in rect: CGRect) {}
    public func strokeEllipse(in rect: CGRect) {}
    public func move(to point: CGPoint) {}
    public func addLine(to point: CGPoint) {}
    public func saveGState() {}
    public func restoreGState() {}
    public func clip() {}
}
