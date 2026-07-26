import Foundation
import Combine

enum RacePhase {
    case countdown
    case racing
    case finished
}

struct Standing: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let isPlayer: Bool
}

@MainActor
final class GameState: ObservableObject {
    @Published var phase: RacePhase = .countdown
    @Published var countdownText = "3"
    @Published var playerLap = 0
    @Published var playerPosition = 1
    @Published var playerSpeed: CGFloat = 0
    @Published var heldItem: RaceItem?
    @Published var bestLapTime: TimeInterval = 0
    @Published var finalStandings: [Standing] = []

    let totalLaps = 3

    var positionText: String {
        switch playerPosition {
        case 1: return "1st Place"
        case 2: return "2nd Place"
        case 3: return "3rd Place"
        default: return "\(playerPosition)th Place"
        }
    }

    func finishRace(position: Int, standings: [Standing], bestLap: TimeInterval) {
        playerPosition = position
        finalStandings = standings
        bestLapTime = bestLap
        phase = .finished
    }
}
