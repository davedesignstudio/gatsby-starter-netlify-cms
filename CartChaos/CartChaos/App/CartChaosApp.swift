import SwiftUI

@main
struct CartChaosApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea()
        }
    }
}
