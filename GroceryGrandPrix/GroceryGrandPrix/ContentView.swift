import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var game = GameState()
    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                } else {
                    Color.ggpDark.ignoresSafeArea()
                }

                overlay
                    .environmentObject(game)
            }
            .onAppear {
                if scene == nil {
                    let startSize = geo.size == .zero ? CGSize(width: 844, height: 390) : geo.size
                    let newScene = GameScene(size: startSize)
                    newScene.scaleMode = .resizeFill
                    newScene.game = game
                    scene = newScene
                }
            }
        }
    }

    @ViewBuilder private var overlay: some View {
        switch game.phase {
        case .menu:
            MenuView()
        case .countdown, .racing:
            RacingOverlay()
        case .finished:
            ResultsView()
        }
    }
}
