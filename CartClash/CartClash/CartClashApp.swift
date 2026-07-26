import SwiftUI

@main
struct CartClashApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea()
                .statusBarHidden(true)
        }
    }
}
