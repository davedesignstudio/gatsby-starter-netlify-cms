import Foundation

struct CupStanding: Identifiable {
    let id = UUID()
    let name: String
    var points: Int
    let isHuman: Bool
}

struct CupDefinition: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let tracks: [TrackDefinition]
    let pointsTable: [Int]

    var raceCount: Int { tracks.count }
}

extension CupDefinition {
    static let storeChampionship = CupDefinition(
        id: "store",
        name: "Store Championship",
        emoji: "🏆",
        tracks: [.grocery, .frozen, .produce],
        pointsTable: [15, 12, 10, 8]
    )

    static let nightShift = CupDefinition(
        id: "night",
        name: "Night Shift Cup",
        emoji: "🌙",
        tracks: [.bakery, .liquor, .midnight],
        pointsTable: [15, 12, 10, 8]
    )

    static let grandPrix = CupDefinition(
        id: "grand",
        name: "Grand Aisle Prix",
        emoji: "🛒",
        tracks: [.grocery, .frozen, .produce, .bakery, .liquor, .midnight],
        pointsTable: [15, 12, 10, 8, 6, 4]
    )

    static let all: [CupDefinition] = [.storeChampionship, .nightShift, .grandPrix]
}

final class CupSession {
    static var active: CupSession?

    let cup: CupDefinition
    var currentRaceIndex = 0
    var standings: [CupStanding] = []
    var lastRaceOrder: [CartRacer] = []

    init(cup: CupDefinition, racerNames: [(String, Bool)]) {
        self.cup = cup
        standings = racerNames.map { CupStanding(name: $0.0, points: 0, isHuman: $0.1) }
    }

    var currentTrack: TrackDefinition {
        cup.tracks[currentRaceIndex]
    }

    var isComplete: Bool {
        currentRaceIndex >= cup.tracks.count
    }

    func recordRace(finishOrder: [CartRacer]) {
        lastRaceOrder = finishOrder
        for (index, racer) in finishOrder.enumerated() {
            guard index < cup.pointsTable.count else { break }
            let points = cup.pointsTable[index]
            if let standingIndex = standings.firstIndex(where: { $0.name == racer.racerName }) {
                standings[standingIndex].points += points
            } else if racer.isPlayer, let humanIndex = standings.firstIndex(where: { $0.isHuman }) {
                standings[humanIndex].points += points
            }
        }
        currentRaceIndex += 1
    }

    var sortedStandings: [CupStanding] {
        standings.sorted { $0.points > $1.points }
    }
}
