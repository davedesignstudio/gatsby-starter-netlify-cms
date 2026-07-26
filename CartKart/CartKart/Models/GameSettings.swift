import Foundation

enum RenderMode: String, CaseIterable {
    case spriteKit2D = "2D Classic"
    case sceneKit3D = "3D Aisles"
}

enum PlayerMode: String, CaseIterable {
    case solo = "1 Player"
    case localMultiplayer = "2 Players"
}

final class GameSettings {
    static let shared = GameSettings()

    var selectedTrack: TrackDefinition = .grocery
    var renderMode: RenderMode = .spriteKit2D
    var playerMode: PlayerMode = .solo
    var soundEnabled = true

    private init() {}
}
