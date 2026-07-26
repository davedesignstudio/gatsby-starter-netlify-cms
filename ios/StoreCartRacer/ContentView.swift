import SwiftUI
import SpriteKit

struct ContentView: View {
    private let scene: GameScene = {
        let gameScene = GameScene(size: CGSize(width: 1080, height: 1920))
        gameScene.scaleMode = .resizeFill
        return gameScene
    }()

    var body: some View {
        SpriteView(
            scene: scene,
            options: [.shouldCullNonVisibleNodes, .ignoresSiblingOrder],
            debugOptions: []
        )
        .ignoresSafeArea()
    }
}
