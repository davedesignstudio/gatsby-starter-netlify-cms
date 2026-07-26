import SpriteKit

final class VirtualJoystick: SKNode {
    private let base = SKShapeNode(circleOfRadius: 52)
    private let stick = SKShapeNode(circleOfRadius: 24)
    private var touch: UITouch?
    private(set) var vector = CGVector(dx: 0, dy: 0)
    let side: PlayerSide

    enum PlayerSide {
        case left
        case right
    }

    init(side: PlayerSide = .left) {
        self.side = side
        super.init()
        isUserInteractionEnabled = false

        let tint: SKColor = side == .left
            ? SKColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1)
            : SKColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1)

        base.fillColor = tint.withAlphaComponent(0.15)
        base.strokeColor = tint.withAlphaComponent(0.5)
        base.lineWidth = 2
        addChild(base)

        stick.fillColor = tint.withAlphaComponent(0.65)
        stick.strokeColor = tint.withAlphaComponent(0.9)
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
    private let background = SKShapeNode(circleOfRadius: 34)
    private(set) var isPressed = false

    init(text: String, color: SKColor) {
        label = SKLabelNode(text: text)
        super.init()

        background.fillColor = color.withAlphaComponent(0.35)
        background.strokeColor = color
        background.lineWidth = 3
        addChild(background)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = 12
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

struct PlayerInputState {
    let joystick: VirtualJoystick
    let accelerateButton: ActionButton
    let driftButton: ActionButton
    let itemButton: ActionButton
    private var itemTapPending = false

    init(slot: Int) {
        let accent: SKColor = slot == 0
            ? SKColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 1)
            : SKColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
        joystick = VirtualJoystick(side: slot == 0 ? .left : .right)
        accelerateButton = ActionButton(text: "GO", color: accent)
        driftButton = ActionButton(text: "DRIFT", color: SKColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1))
        itemButton = ActionButton(text: "ITEM", color: SKColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1))
    }

    mutating func handleTouches(_ touches: Set<UITouch>, in scene: SKScene, phase: UITouch.Phase) {
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

    mutating func consumeItemTap() -> Bool {
        defer { itemTapPending = false }
        return itemTapPending
    }

    var steer: CGFloat { joystick.vector.x }
    var accelerate: Bool { accelerateButton.isPressed || joystick.vector.dy > 0.35 }
    var brake: Bool { joystick.vector.dy < -0.35 }
    var drift: Bool { driftButton.isPressed }
}

final class InputManager {
    private var playerInputs: [PlayerInputState] = [PlayerInputState(slot: 0)]
    private let multiplayer: Bool

    init(multiplayer: Bool) {
        self.multiplayer = multiplayer
        if multiplayer {
            playerInputs.append(PlayerInputState(slot: 1))
        }
    }

    func layout(in size: CGSize) {
        layoutPlayer(0, in: size, multiplayer: multiplayer)
        if multiplayer {
            layoutPlayer(1, in: size, multiplayer: true)
        }
    }

    private func layoutPlayer(_ slot: Int, in size: CGSize, multiplayer: Bool) {
        let input = playerInputs[slot]
        if slot == 0 {
            input.joystick.position = CGPoint(x: -size.width / 2 + 80, y: -size.height / 2 + 100)
            input.accelerateButton.position = CGPoint(x: size.width / 2 - 60, y: -size.height / 2 + 100)
            input.driftButton.position = CGPoint(x: size.width / 2 - 130, y: -size.height / 2 + 55)
            input.itemButton.position = CGPoint(x: size.width / 2 - 60, y: -size.height / 2 + 175)
        } else {
            input.joystick.position = CGPoint(x: size.width / 2 - 80, y: -size.height / 2 + 100)
            input.accelerateButton.position = CGPoint(x: -size.width / 2 + 60, y: -size.height / 2 + 100)
            input.driftButton.position = CGPoint(x: -size.width / 2 + 130, y: -size.height / 2 + 55)
            input.itemButton.position = CGPoint(x: -size.width / 2 + 60, y: -size.height / 2 + 175)
        }
    }

    func addToHUD(_ hud: SKNode) {
        for input in playerInputs {
            hud.addChild(input.joystick)
            hud.addChild(input.accelerateButton)
            hud.addChild(input.driftButton)
            hud.addChild(input.itemButton)
        }
    }

    func handleTouches(_ touches: Set<UITouch>, in scene: SKScene, phase: UITouch.Phase) {
        for index in playerInputs.indices {
            playerInputs[index].handleTouches(touches, in: scene, phase: phase)
        }
    }

    func steer(for slot: Int) -> CGFloat { playerInputs[slot].steer }
    func accelerate(for slot: Int) -> Bool { playerInputs[slot].accelerate }
    func brake(for slot: Int) -> Bool { playerInputs[slot].brake }
    func drift(for slot: Int) -> Bool { playerInputs[slot].drift }

    mutating func consumeItemTap(for slot: Int) -> Bool {
        playerInputs[slot].consumeItemTap()
    }

    var steer: CGFloat { playerInputs[0].steer }
    var accelerate: Bool { playerInputs[0].accelerate }
    var brake: Bool { playerInputs[0].brake }
    var drift: Bool { playerInputs[0].drift }

    func consumeItemTap() -> Bool {
        consumeItemTap(for: 0)
    }
}
