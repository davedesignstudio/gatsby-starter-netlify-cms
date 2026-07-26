import SwiftUI
import SpriteKit

struct GameRootView: View {
    @State private var sceneHolder = SceneHolder()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: sceneHolder.scene, options: [.ignoresSiblingOrder])
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear {
                    sceneHolder.resize(to: geo.size)
                }
                .onChange(of: geo.size) { newSize in
                    sceneHolder.resize(to: newSize)
                }
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
    }
}

/// Keeps a stable SKScene instance for SpriteView.
final class SceneHolder {
    let scene: SKScene

    init() {
        let menu = MenuScene(size: CGSize(width: 390, height: 844))
        menu.scaleMode = .resizeFill
        scene = menu
    }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        scene.size = size
    }
}
