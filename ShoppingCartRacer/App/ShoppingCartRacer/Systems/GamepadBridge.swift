import GameController

/// Optional MFi / PlayStation / Xbox controller support. When a pad is connected
/// it takes over from the on-screen controls; otherwise it costs nothing.
final class GamepadBridge {
    private(set) var isConnected = false
    private var observers: [NSObjectProtocol] = []

    init() {
        isConnected = GCController.controllers().contains { $0.extendedGamepad != nil }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
                self?.isConnected = GCController.controllers().contains { $0.extendedGamepad != nil }
            }
        )
        observers.append(
            center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                self?.isConnected = GCController.controllers().contains { $0.extendedGamepad != nil }
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Folds the pad state into the on-screen control state.
    ///
    /// Buttons are mapped like a kart racer: right trigger accelerates, left
    /// trigger brakes, the bottom face button drifts and the right face button
    /// fires an item.
    func apply(to controls: inout RawControlState) {
        guard let pad = GCController.controllers().compactMap(\.extendedGamepad).first else { return }

        // Sticks and the d-pad both steer; whichever is deflected more wins.
        let stick = Double(pad.leftThumbstick.xAxis.value)
        var dpad = 0.0
        if pad.dpad.left.isPressed { dpad -= 1 }
        if pad.dpad.right.isPressed { dpad += 1 }
        let steer = abs(stick) > abs(dpad) ? stick : dpad
        // Pushing right on the stick steers right, which is a negative value.
        if abs(steer) > 0.02 { controls.steer = -steer }

        if pad.rightTrigger.isPressed || pad.buttonA.isPressed {
            controls.accelerating = true
        }
        if pad.leftTrigger.isPressed {
            controls.braking = true
        }
        if pad.rightShoulder.isPressed || pad.buttonB.isPressed {
            controls.drifting = true
        }
        if pad.leftShoulder.isPressed || pad.buttonX.isPressed {
            controls.firingItem = true
        }
    }
}
