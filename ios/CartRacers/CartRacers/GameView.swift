import SpriteKit
import SwiftUI
import UIKit

struct GameView: View {
    @State private var scene = StoreCartRaceScene(size: UIScreen.main.bounds.size)

    var body: some View {
        SpriteView(scene: scene)
            .onAppear {
                scene.scaleMode = .resizeFill
            }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
}
