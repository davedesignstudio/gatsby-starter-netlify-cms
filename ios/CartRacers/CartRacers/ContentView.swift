import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene = GameScene()

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .onAppear {
                    scene.scaleMode = .resizeFill
                    scene.size = proxy.size
                }
                .onChange(of: proxy.size) { _, newSize in
                    scene.size = newSize
                }
        }
    }
}

#Preview {
    ContentView()
}
