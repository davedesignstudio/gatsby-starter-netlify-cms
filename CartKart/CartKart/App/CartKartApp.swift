import SwiftUI

@main
struct CartKartApp: App {
    init() {
        GameCenterManager.shared.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
