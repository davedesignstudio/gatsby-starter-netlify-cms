// CartKartApp.swift — native iOS entry (SwiftUI + SpriteKit)
import SwiftUI

@main
struct CartKartApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBarHidden(true)
        }
    }
}

struct ContentView: View {
    @State private var screen: AppScreen = .title
    @State private var selectedCart: CartDef = CartCatalog.all[0]
    @State private var results: [RaceResult] = []

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.12, blue: 0.09).ignoresSafeArea()

            switch screen {
            case .title:
                TitleView(
                    onPlay: { screen = .select },
                    onHow: { screen = .how }
                )
            case .how:
                HowToView(onBack: { screen = .title })
            case .select:
                SelectView(
                    selected: $selectedCart,
                    onBack: { screen = .title },
                    onStart: { screen = .race }
                )
            case .race:
                RaceView(cart: selectedCart) { order in
                    results = order
                    screen = .results
                }
            case .results:
                ResultsView(
                    results: results,
                    onMenu: { screen = .title },
                    onRetry: { screen = .race }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum AppScreen {
    case title, how, select, race, results
}

struct RaceResult: Identifiable {
    let id = UUID()
    let place: Int
    let name: String
    let isPlayer: Bool
    let time: TimeInterval
}
