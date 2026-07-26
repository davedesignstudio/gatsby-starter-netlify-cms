import SwiftUI
import SceneKit
import SpriteKit

struct SceneKitRaceView: UIViewRepresentable {
    @ObservedObject var controller: RaceScene3DController

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1)
        view.delegate = context.coordinator

        let overlay = SKView(frame: view.bounds)
        overlay.backgroundColor = .clear
        overlay.allowsTransparency = true
        overlay.presentScene(controller.overlaySKScene)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
        context.coordinator.overlayView = overlay

        let hud = UIHostingController(rootView: Race3DHUD(controller: controller))
        hud.view.backgroundColor = .clear
        hud.view.frame = view.bounds
        hud.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hud.view.isUserInteractionEnabled = false
        view.addSubview(hud.view)
        context.coordinator.hudView = hud.view

        let touchCatcher = TouchForwardingView()
        touchCatcher.frame = view.bounds
        touchCatcher.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        touchCatcher.onTouches = { touches, phase in
            controller.handleTouches(touches, phase: phase)
        }
        view.addSubview(touchCatcher)
        context.coordinator.touchView = touchCatcher

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.overlayView?.presentScene(controller.overlaySKScene)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var overlayView: SKView?
        var hudView: UIView?
        var touchView: TouchForwardingView?
    }
}

struct Race3DHUD: View {
    @ObservedObject var controller: RaceScene3DController

    var body: some View {
        VStack {
            HStack {
                Text(controller.hudLapText)
                Spacer()
                Text(controller.hudTimeText)
                Spacer()
                Text(controller.hudPositionText)
                    .font(.title2.bold())
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 50)

            Text(controller.hudItemText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            if !controller.countdownText.isEmpty {
                Text(controller.countdownText)
                    .font(.system(size: 88, weight: .heavy))
                    .foregroundStyle(controller.countdownText == "GO!" ? .green : .yellow)
            }

            if controller.phase == .finished {
                Text("Race Complete!")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
                    .padding(.bottom, 40)
            }
        }
    }
}

final class TouchForwardingView: UIView {
    var onTouches: ((Set<UITouch>, UITouch.Phase) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouches?(touches, .began)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouches?(touches, .moved)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouches?(touches, .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouches?(touches, .cancelled)
    }
}
