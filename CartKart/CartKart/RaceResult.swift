import SpriteKit

/// One row of the final standings, handed from the race to the results screen.
struct RaceResult {
    let place: Int
    let name: String
    let tint: SKColor
    let isPlayer: Bool
    let finished: Bool
    let time: TimeInterval
}

/// The fixed roster of racers. Index 0 is always the human player.
enum Roster {
    struct Entry {
        let name: String
        let tint: SKColor
    }

    static let entries: [Entry] = [
        Entry(name: "You",     tint: SKColor(red: 1.00, green: 0.85, blue: 0.20, alpha: 1)),
        Entry(name: "Rusty",   tint: SKColor(red: 0.90, green: 0.30, blue: 0.35, alpha: 1)),
        Entry(name: "Squeaky", tint: SKColor(red: 0.35, green: 0.75, blue: 0.45, alpha: 1)),
        Entry(name: "Wobbles", tint: SKColor(red: 0.55, green: 0.45, blue: 0.90, alpha: 1))
    ]
}

/// Format seconds as m:ss.d for the HUD and results.
func formatRaceTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "--:--" }
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60
    let tenths = Int((seconds - floor(seconds)) * 10)
    return String(format: "%d:%02d.%d", minutes, secs, tenths)
}
