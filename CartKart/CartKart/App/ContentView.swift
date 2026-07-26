import SwiftUI
import SpriteKit
import SceneKit

struct ContentView: View {
    @State private var renderMode = GameSettings.shared.renderMode
    @State private var menuID = UUID()

    var body: some View {
        Group {
            if renderMode == .sceneKit3D {
                SceneKitRaceContainer(onExitToMenu: {
                    GameSettings.shared.renderMode = .spriteKit2D
                    renderMode = .spriteKit2D
                    menuID = UUID()
                })
            } else {
                SpriteKitRaceContainer(onModeChange: { renderMode = $0 })
                    .id(menuID)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

struct SpriteKitRaceContainer: View {
    @State private var scene: SKScene = {
        let scene = MenuScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var onModeChange: (RenderMode) -> Void

    var body: some View {
        SpriteView(scene: scene)
            .onAppear(perform: subscribe)
    }

    private func subscribe() {
        NotificationCenter.default.addObserver(
            forName: .cartKartRenderModeChanged,
            object: nil,
            queue: .main
        ) { _ in
            onModeChange(GameSettings.shared.renderMode)
        }
    }
}

struct SceneKitRaceContainer: View {
    @StateObject private var controller = RaceScene3DController()
    var onExitToMenu: () -> Void

    var body: some View {
        ZStack {
            SceneKitRaceView(controller: controller)
            if controller.phase == .menu {
                Color.clear
            }
        }
        .onAppear {
            controller.startRace(
                track: GameSettings.shared.selectedTrack,
                multiplayer: GameSettings.shared.playerMode == .localMultiplayer
            )
        }
        .onChange(of: controller.requestMenu) { wantsMenu in
            if wantsMenu {
                GameSettings.shared.renderMode = .spriteKit2D
                onExitToMenu()
            }
        }
    }
}

extension Notification.Name {
    static let cartKartRenderModeChanged = Notification.Name("cartKartRenderModeChanged")
}
