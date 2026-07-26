import Foundation
import Combine

enum GamePhase {
    case menu
    case countdown
    case racing
    case finished
}

struct RacerStanding: Identifiable {
    let id = UUID()
    let name: String
    let position: Int
    let finishTime: TimeInterval?
    let isPlayer: Bool
}

@MainActor
final class GameState: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var selectedCharacter: CharacterType = .rustyRon
    @Published var playerPosition: Int = 1
    @Published var currentLap: Int = 1
    @Published var totalLaps: Int = 3
    @Published var raceTime: TimeInterval = 0
    @Published var countdownValue: Int = 3
    @Published var heldItem: ItemType?
    @Published var standings: [RacerStanding] = []
    @Published var boostMeter: CGFloat = 0

    var raceStarted = false

    func startRace() {
        phase = .countdown
        countdownValue = 3
        currentLap = 1
        playerPosition = 1
        raceTime = 0
        heldItem = nil
        boostMeter = 0
        standings = []
        raceStarted = false
    }

    func beginRacing() {
        phase = .racing
        raceStarted = true
    }

    func finishRace(standings: [RacerStanding]) {
        self.standings = standings
        phase = .finished
    }

    func returnToMenu() {
        phase = .menu
    }
}
