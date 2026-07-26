import SwiftUI

/// Read-only bridge between the SpriteKit game and the SwiftUI menus / HUD.
final class GameState: ObservableObject {
    enum Phase { case menu, countdown, racing, finished }

    @Published var phase: Phase = .menu
    @Published var countdownText: String = ""
    @Published var lap: Int = 1
    @Published var totalLaps: Int = 3
    @Published var positionText: String = "1/6"
    @Published var itemName: String = "—"
    @Published var speed: Int = 0
    @Published var raceTime: TimeInterval = 0
    @Published var results: [String] = []
}
