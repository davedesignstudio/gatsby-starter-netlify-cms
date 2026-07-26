import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @State private var scene: SKScene = {
        let menu = MenuScene(size: CGSize(width: 390, height: 844))
        menu.scaleMode = .resizeFill
        return menu
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}
