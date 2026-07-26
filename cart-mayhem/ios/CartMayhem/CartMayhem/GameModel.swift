import Combine
import SpriteKit
import SwiftUI

@MainActor
final class GameModel: ObservableObject {
    @Published var phase: RacePhase = .title
    @Published var selectedRacer = 0
    @Published var countdownLabel = "3"
    @Published var playerLap = 0
    @Published var playerPlaceLabel = "1st"
    @Published var timeLabel = "0:00.0"
    @Published var playerItemIcon = "·"
    @Published var resultTitle = "FINISH!"
    @Published var standings: [String] = []

    let scene: RaceScene

    init() {
        let scene = RaceScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        self.scene = scene
        scene.onStateChange = { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.phase = snapshot.phase
                self.countdownLabel = snapshot.countdownLabel
                self.playerLap = snapshot.playerLap
                self.playerPlaceLabel = snapshot.playerPlaceLabel
                self.timeLabel = snapshot.timeLabel
                self.playerItemIcon = snapshot.playerItemIcon
                self.resultTitle = snapshot.resultTitle
                self.standings = snapshot.standings
            }
        }
    }

    func openSelect() { scene.openSelect() }
    func openHowTo() { scene.openHowTo() }
    func startCountdown() {
        scene.selectedRacer = selectedRacer
        scene.startCountdown()
    }
    func backToTitle() { scene.setPhase(.title) }
    func useItem() { scene.usePlayerItem() }

    func setTouchLeft(_ v: Bool) { scene.touchLeft = v }
    func setTouchRight(_ v: Bool) { scene.touchRight = v }
    func setTouchDrift(_ v: Bool) { scene.touchDrift = v }
}

struct RaceSnapshot {
    var phase: RacePhase
    var countdownLabel: String
    var playerLap: Int
    var playerPlaceLabel: String
    var timeLabel: String
    var playerItemIcon: String
    var resultTitle: String
    var standings: [String]
}
