import SwiftUI
import SpriteKit
import UIKit

struct GameContainerView: View {
    let trackIndex: Int
    let onExit: () -> Void

    @State private var gameState = GameState()
    @State private var scene: RacingGameScene?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            }

            HUDView(gameState: gameState, onExit: onExit)
                .allowsHitTesting(gameState.phase != .racing)
        }
        .onAppear {
            let newScene = RacingGameScene(size: UIScreen.main.bounds.size, trackIndex: trackIndex)
            newScene.scaleMode = .resizeFill
            newScene.gameState = gameState
            scene = newScene
        }
    }
}
