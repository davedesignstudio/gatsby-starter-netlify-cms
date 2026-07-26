import Foundation

enum RenderMode: String, CaseIterable {
    case spriteKit2D = "2D Classic"
    case sceneKit3D = "3D Aisles"
}

enum PlayerMode: String, CaseIterable {
    case solo = "1 Player"
    case localMultiplayer = "2 Players"
    case onlineMultiplayer = "Online"
}

enum GameMode: String, CaseIterable {
    case quickRace = "Quick Race"
    case cup = "Cup Mode"
}

final class GameSettings {
    static let shared = GameSettings()

    var selectedTrack: TrackDefinition = .grocery
    var selectedCharacter: CharacterDefinition = .wobblyWill
    var selectedCharacterP2: CharacterDefinition = .speedySal
    var selectedCup: CupDefinition = .storeChampionship
    var renderMode: RenderMode = .spriteKit2D
    var playerMode: PlayerMode = .solo
    var gameMode: GameMode = .quickRace
    var soundEnabled = true
    var cupSession: CupSession?

    private init() {}

    func beginCup(_ cup: CupDefinition) {
        gameMode = .cup
        selectedCup = cup
        let names: [(String, Bool)] = playerMode == .localMultiplayer
            ? [(selectedCharacter.name, true), (selectedCharacterP2.name, true), ("Rusty Ron", false), ("Cart Carl", false)]
            : [(selectedCharacter.name, true), ("Rusty Ron", false), ("Cart Carl", false), ("Wheels Wendy", false)]
        cupSession = CupSession(cup: cup, racerNames: names)
        selectedTrack = cupSession?.currentTrack ?? .grocery
    }

    func advanceCupOrFinish() -> Bool {
        guard let session = cupSession else { return false }
        if session.isComplete {
            cupSession = nil
            gameMode = .quickRace
            return false
        }
        selectedTrack = session.currentTrack
        return true
    }
}
