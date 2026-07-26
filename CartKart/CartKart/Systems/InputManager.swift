import SpriteKit

final class VirtualJoystick: SKNode {
    private let base = SKShapeNode(circleOfRadius: 52)
    private let stick = SKShapeNode(circleOfRadius: 24)
    private var touch: UITouch?
    private(set) var vector = CGVector(dx: 0, dy: 0)

    override init() {
        super.init()
        isUserInteractionEnabled = false

        base.fillColor = SKColor(white: 1, alpha: 0.12)
        base.strokeColor = SKColor(white: 1, alpha: 0.35)
        base.lineWidth = 2
        addChild(base)

        stick.fillColor = SKColor(white: 1, alpha: 0.55)
        stick.strokeColor = SKColor(white: 1, alpha: 0.8)
        stick.lineWidth = 2
        addChild(stick)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleTouches(_ touches: Set<UITouch>, in scene: SKScene, began: Bool, moved: Bool, ended: Bool) {
        for touch in touches {
            let location = touch.location(in: self)
            if began {
                if hypot(location.x, location.y) < 80 {
                    self.touch = touch
                }
            }

            if touch == self.touch {
                if ended {
                    self.touch = nil
                    vector = .zero
                    stick.position = .zero
                } else if moved || began {
                    let clamped = clamp(location, maxRadius: 52)
                    stick.position = clamped
                    vector = CGVector(dx: clamped.x / 52, dy: clamped.y / 52)
                }
            }
        }
    }

    private func clamp(_ point: CGPoint, maxRadius: CGFloat) -> CGPoint {
        let length = hypot(point.x, point.y)
        guard length > maxRadius else { return point }
        let scale = maxRadius / length
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }
}

final class ActionButton: SKNode {
    let label: SKLabelNode
    private let background = SKShapeNode(circleOfRadius: 38)
    private(set) var isPressed = false

    init(text: String, color: SKColor) {
        label = SKLabelNode(text: text)
        super.init()

        background.fillColor = color.withAlphaComponent(0.35)
        background.strokeColor = color
        background.lineWidth = 3
        addChild(background)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        addChild(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPressed(_ pressed: Bool) {
        isPressed = pressed
        alpha = pressed ? 0.75 : 1.0
        setScale(pressed ? 0.92 : 1.0)
    }
}

final class InputManager {
    let joystick = VirtualJoystick()
    let accelerateButton = ActionButton(text: "GO", color: SKColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 1))
    let driftButton = ActionButton(text: "DRIFT", color: SKColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1))
    let itemButton = ActionButton(text: "ITEM", color: SKColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1))

    private var itemTapPending = false

    func layout(in size: CGSize) {
        joystick.position = CGPoint(x: -size.width / 2 + 90, y: -size.height / 2 + 110)
        accelerateButton.position = CGPoint(x: size.width / 2 - 70, y: -size.height / 2 + 110)
        driftButton.position = CGPoint(x: size.width / 2 - 150, y: -size.height / 2 + 60)
        itemButton.position = CGPoint(x: size.width / 2 - 70, y: -size.height / 2 + 190)
    }

    func handleTouches(_ touches: Set<UITouch>, in scene: SKScene, phase: UITouch.Phase) {
        let began = phase == .began
        let moved = phase == .moved
        let ended = phase == .ended || phase == .cancelled

        joystick.handleTouches(touches, in: scene, began: began, moved: moved, ended: ended)

        for touch in touches {
            let scenePoint = touch.location(in: scene)
            let nodes = scene.nodes(at: scenePoint)

            if began {
                if nodes.contains(where: { $0 === accelerateButton || $0.parent === accelerateButton }) {
                    accelerateButton.setPressed(true)
                }
                if nodes.contains(where: { $0 === driftButton || $0.parent === driftButton }) {
                    driftButton.setPressed(true)
                }
                if nodes.contains(where: { $0 === itemButton || $0.parent === itemButton }) {
                    itemTapPending = true
                    itemButton.setPressed(true)
                }
            }

            if ended {
                accelerateButton.setPressed(false)
                driftButton.setPressed(false)
                itemButton.setPressed(false)
            }
        }
    }

    func consumeItemTap() -> Bool {
        defer { itemTapPending = false }
        return itemTapPending
    }

    var steer: CGFloat {
        joystick.vector.x
    }

    var accelerate: Bool {
        accelerateButton.isPressed || joystick.vector.dy > 0.35
    }

    var brake: Bool {
        joystick.vector.dy < -0.35
    }

    var drift: Bool {
        driftButton.isPressed
    }
}
