import SwiftUI

@main
struct CartKartApp: App {
    var body: some Scene {
        WindowGroup {
            GameRootView()
                .statusBarHidden(true)
                .ignoresSafeArea()
        }
    }
}
