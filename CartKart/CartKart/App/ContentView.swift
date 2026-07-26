import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene: SKScene = {
        let scene = MenuScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .statusBarHidden(true)
    }
}
