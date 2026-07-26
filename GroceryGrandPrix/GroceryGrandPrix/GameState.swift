import Foundation
import SwiftUI

// MARK: - Items

enum ItemType: CaseIterable {
    case turboCola      // self speed boost
    case spilledMilk    // drop a slick behind you; anyone who touches it spins out
    case cannedGoods    // launch a can forward; first cart hit spins out

    var icon: String {
        switch self {
        case .turboCola:   return "🥤"
        case .spilledMilk: return "🥛"
        case .cannedGoods: return "🥫"
        }
    }

    var displayName: String {
        switch self {
        case .turboCola:   return "Turbo Cola"
        case .spilledMilk: return "Spilled Milk"
        case .cannedGoods: return "Canned Goods"
        }
    }

    static func random() -> ItemType {
        allCases.randomElement() ?? .turboCola
    }
}

// MARK: - Results

struct RaceResult: Identifiable {
    let id = UUID()
    let position: Int
    let name: String
    let isPlayer: Bool
    let time: TimeInterval
    let finished: Bool
}

// MARK: - Phase

enum GamePhase {
    case menu
    case countdown
    case racing
    case finished
}

// MARK: - Game state / bridge between SwiftUI and SpriteKit

final class GameState: ObservableObject {
    // Published race info (read by SwiftUI HUD / screens)
    @Published var phase: GamePhase = .menu
    @Published var lap: Int = 1
    @Published var totalLaps: Int = 3
    @Published var rank: Int = 1
    @Published var racerCount: Int = 4
    @Published var heldItem: ItemType? = nil
    @Published var countdownText: String = ""
    @Published var speed: Int = 0
    @Published var raceTime: TimeInterval = 0
    @Published var boostActive: Bool = false
    @Published var results: [RaceResult] = []
    @Published var bestTime: TimeInterval? = nil

    // Input flags (written by SwiftUI controls, polled by the scene)
    var steerLeft = false
    var steerRight = false
    var driftHeld = false
    var brakeHeld = false
    var useItemRequested = false

    /// Steering axis in range -1 (left) ... 1 (right).
    var steerAxis: CGFloat {
        (steerRight ? 1 : 0) - (steerLeft ? 1 : 0)
    }

    // Actions wired up by the scene
    var onStartRace: (() -> Void)?
    var onRestart: (() -> Void)?

    func resetInputs() {
        steerLeft = false
        steerRight = false
        driftHeld = false
        brakeHeld = false
        useItemRequested = false
    }

    func requestStart() {
        resetInputs()
        onStartRace?()
    }

    func requestRestart() {
        resetInputs()
        onRestart?()
    }

    static func format(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let millis = Int((time - floor(time)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, millis)
    }
}
