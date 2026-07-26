import Foundation
import SwiftUI

@MainActor
final class GameSession: ObservableObject {
    enum Phase {
        case menu
        case racing
        case results(RaceResult)
    }

    @Published var phase: Phase = .menu
    @Published var selectedRacer: RacerStyle = .sunset
    @Published private(set) var bestTime: TimeInterval?

    init() {
        let storedTime = UserDefaults.standard.double(forKey: "bestRaceTime")
        bestTime = storedTime > 0 ? storedTime : nil
    }

    func startRace() {
        phase = .racing
    }

    func finishRace(_ result: RaceResult) {
        if result.place == 1, bestTime == nil || result.time < bestTime! {
            bestTime = result.time
            UserDefaults.standard.set(result.time, forKey: "bestRaceTime")
        }
        phase = .results(result)
    }

    func returnToMenu() {
        phase = .menu
    }
}

struct RaceResult {
    let place: Int
    let time: TimeInterval
    let pantryItems: Int
}

enum RacerStyle: String, CaseIterable, Identifiable {
    case sunset
    case mint
    case grape

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sunset: "Roxy"
        case .mint: "Milo"
        case .grape: "June"
        }
    }

    var cartName: String {
        switch self {
        case .sunset: "The Fire Escape"
        case .mint: "Fresh Wheels"
        case .grape: "Purple Reign"
        }
    }

    var color: Color {
        switch self {
        case .sunset: Color(red: 1.0, green: 0.34, blue: 0.24)
        case .mint: Color(red: 0.20, green: 0.86, blue: 0.64)
        case .grape: Color(red: 0.62, green: 0.38, blue: 0.96)
        }
    }
}

extension TimeInterval {
    var raceTime: String {
        let minutes = Int(self) / 60
        let seconds = self.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
}
