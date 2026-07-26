import SwiftUI

@main
struct ShoppingCartRacerApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden(true)
        }
    }
}
