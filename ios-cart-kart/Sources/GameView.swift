import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene = StoreRaceScene(size: UIScreen.main.bounds.size)

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .resizeFill
            }
    }
}
