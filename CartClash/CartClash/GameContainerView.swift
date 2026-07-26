import SwiftUI
import SpriteKit

struct GameContainerView: View {
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size))
                .ignoresSafeArea()
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }
}
