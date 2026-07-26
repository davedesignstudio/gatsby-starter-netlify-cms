import SwiftUI

@main
struct CartKartApp: App {
    @StateObject private var storage: Storage
    @StateObject private var game: GameCoordinator

    init() {
        // One Storage instance, shared by the coordinator and the views.
        let storage = Storage()
        _storage = StateObject(wrappedValue: storage)
        _game = StateObject(wrappedValue: GameCoordinator(storage: storage))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(storage)
                .statusBarHidden()
        }
    }
}
