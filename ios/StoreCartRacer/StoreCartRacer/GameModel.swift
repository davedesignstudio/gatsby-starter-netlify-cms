import CoreGraphics
import Foundation

final class GameModel: ObservableObject {
    @Published var lap: Int = 1
    @Published var position: Int = 1
    @Published var speed: CGFloat = 0
    @Published var steering: CGFloat = 0
    @Published var boosting: Bool = false
    @Published var raceFinished: Bool = false

    let maxLaps = 3

    func resetRace() {
        lap = 1
        position = 1
        speed = 0
        steering = 0
        boosting = false
        raceFinished = false
    }
}
