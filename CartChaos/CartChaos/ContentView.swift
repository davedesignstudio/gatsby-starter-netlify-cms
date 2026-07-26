import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            switch gameState.phase {
            case .menu:
                MainMenuView(gameState: gameState)
            case .countdown, .racing:
                GameContainerView(gameState: gameState)
            case .finished:
                ResultsView(gameState: gameState)
            }
        }
        .statusBarHidden()
    }
}

#Preview {
    ContentView()
}
