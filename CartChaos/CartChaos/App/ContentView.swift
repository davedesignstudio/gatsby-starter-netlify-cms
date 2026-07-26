import SwiftUI
import SpriteKit

struct ContentView: View {
    var body: some View {
        SpriteKitHost()
            .ignoresSafeArea()
    }
}

/// Owns an SKView so SpriteKit `presentScene` transitions are not reset by SwiftUI redraws.
struct SpriteKitHost: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        #if DEBUG
        view.showsFPS = false
        view.showsNodeCount = false
        #endif

        let scene = MenuScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        if let scene = uiView.scene, scene.size != uiView.bounds.size, uiView.bounds.size.width > 0 {
            scene.size = uiView.bounds.size
        }
    }
}
