import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @ObservedObject var gameState: GameState
    @State private var scene: GameScene?
    @State private var steerLeft = false
    @State private var steerRight = false
    @State private var driftHeld = false

    var body: some View {
        ZStack {
            SpriteView(scene: makeScene())
                .ignoresSafeArea()

            VStack {
                RaceHUDView(gameState: gameState)
                Spacer()
                controlOverlay
            }
        }
    }

    private func makeScene() -> GameScene {
        if let scene { return scene }

        let newScene = GameScene()
        newScene.gameState = gameState
        newScene.scaleMode = .resizeFill
        newScene.size = CGSize(width: 390, height: 844)

        DispatchQueue.main.async {
            self.scene = newScene
        }
        return newScene
    }

    private var controlOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if let item = gameState.heldItem {
                    Button {
                        scene?.usePlayerItem()
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.emoji)
                                .font(.title)
                            Text(item.displayName)
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .frame(width: 70, height: 70)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.yellow, lineWidth: 2))
                    }
                }

                Spacer()

                driftButton
            }
            .padding(.horizontal)

            HStack(spacing: 0) {
                steerButton(label: "◀", isPressed: $steerLeft)
                steerButton(label: "▶", isPressed: $steerRight)
            }
            .frame(height: 100)
        }
        .padding(.bottom, 20)
    }

    private func steerButton(label: String, isPressed: Binding<Bool>) -> some View {
        Text(label)
            .font(.system(size: 36, weight: .bold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isPressed.wrappedValue ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isPressed.wrappedValue = true
                        updateSteer()
                    }
                    .onEnded { _ in
                        isPressed.wrappedValue = false
                        updateSteer()
                    }
            )
    }

    private var driftButton: some View {
        Text("DRIFT")
            .font(.headline)
            .fontWeight(.heavy)
            .foregroundStyle(driftHeld ? .black : .white)
            .frame(width: 80, height: 50)
            .background(driftHeld ? Color.cyan : Color.white.opacity(0.2))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.cyan, lineWidth: 2))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        driftHeld = true
                        scene?.setDriftHeld(true)
                    }
                    .onEnded { _ in
                        driftHeld = false
                        scene?.setDriftHeld(false)
                    }
            )
    }

    private func updateSteer() {
        var input: CGFloat = 0
        if steerLeft { input -= 1 }
        if steerRight { input += 1 }
        scene?.setSteerInput(input)
    }
}
