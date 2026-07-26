import SpriteKit
import SwiftUI

struct GameView: View {
    @StateObject private var sceneStore = GameSceneStore()

    var body: some View {
        SpriteView(
            scene: sceneStore.scene,
            preferredFramesPerSecond: 60,
            options: [.ignoresSiblingOrder]
        )
        .ignoresSafeArea()
        .onAppear {
            sceneStore.scene.scaleMode = .resizeFill
        }
    }
}

final class GameSceneStore: ObservableObject {
    let scene = GameScene(size: CGSize(width: 844, height: 390))
}
