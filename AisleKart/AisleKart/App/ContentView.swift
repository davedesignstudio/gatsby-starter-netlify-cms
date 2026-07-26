import SwiftUI
import SpriteKit

struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeMenuScene(size: geo.size))
                .ignoresSafeArea()
        }
        .background(Color(red: 0.08, green: 0.12, blue: 0.10))
    }

    private func makeMenuScene(size: CGSize) -> SKScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }
}
