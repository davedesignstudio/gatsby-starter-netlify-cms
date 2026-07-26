import CartKartCore
import Foundation

/// Headless front end for `CartKartCore`.
///
/// The game itself needs Xcode and a device, but the simulation does not, so
/// this exists to sanity check balance from any machine:
///
///     swift run -c release cartkart-sim race --track frozen-foods
///     swift run -c release cartkart-sim balance --races 40
///     swift run -c release cartkart-sim tracks

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "race"

func value(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: "--\(name)"), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func intValue(_ name: String, default fallback: Int) -> Int {
    value(name).flatMap(Int.init) ?? fallback
}

func difficultyValue() -> RaceConfiguration.Difficulty {
    guard let raw = value("difficulty") else { return .weeklyShop }
    return RaceConfiguration.Difficulty(rawValue: raw) ?? .weeklyShop
}

func entries(count: Int, withPlayer: Bool) -> [RaceConfiguration.Entry] {
    (0..<count).map { index in
        RaceConfiguration.Entry(
            profile: Roster.all[index % Roster.all.count],
            isPlayer: withPlayer && index == 0
        )
    }
}

/// Runs a race with every cart on autopilot.
func simulate(
    track: Track,
    racers: Int,
    laps: Int?,
    difficulty: RaceConfiguration.Difficulty,
    seed: UInt64
) -> RaceEngine {
    let engine = RaceEngine(
        configuration: RaceConfiguration(
            track: track,
            entries: entries(count: racers, withPlayer: false),
            difficulty: difficulty,
            lapCount: laps,
            seed: seed
        )
    )
    engine.runToCompletion(maxSimulatedSeconds: 900)
    return engine
}

switch command {
case "tracks":
    print("Courses")
    print(String(repeating: "-", count: 68))
    for track in TrackLibrary.all {
        let length = String(format: "%6.0f", track.trackLength)
        print("\(track.id.padding(toLength: 18, withPad: " ", startingAt: 0)) \(length) units  \(track.lapCount) laps  \(track.itemBoxes.count) item boxes  \(track.obstacles.count) obstacles")
        print("    \(track.name) — \(track.subtitle)")
    }
    print("\nRoster")
    print(String(repeating: "-", count: 68))
    for profile in Roster.all {
        let stats = "spd \(profile.speed)  acc \(profile.acceleration)  hnd \(profile.handling)  drf \(profile.drift)  ter \(profile.allTerrain)"
        print("\(profile.name.padding(toLength: 12, withPad: " ", startingAt: 0)) \(profile.weight.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(stats)")
    }

case "race":
    let track = TrackLibrary.track(id: value("track") ?? "produce-plaza")
    let engine = simulate(
        track: track,
        racers: intValue("racers", default: 8),
        laps: value("laps").flatMap(Int.init),
        difficulty: difficultyValue(),
        seed: UInt64(intValue("seed", default: 2026))
    )

    print("\(track.name) — \(track.subtitle)")
    print("\(engine.lapCount) laps, \(engine.karts.count) carts, \(difficultyValue().displayName)")
    print(String(repeating: "-", count: 58))
    let winnerTime = engine.results.first?.totalTime ?? 0
    for result in engine.results {
        let place = TimeFormat.ordinal(result.place).padding(toLength: 5, withPad: " ", startingAt: 0)
        let name = result.profile.name.padding(toLength: 12, withPad: " ", startingAt: 0)
        let total = TimeFormat.lap(result.totalTime ?? 0)
        let best = result.bestLap.map(TimeFormat.lap) ?? "--"
        let gap = result.place == 1 ? "     " : TimeFormat.gap((result.totalTime ?? 0) - winnerTime)
        print("\(place) \(name) \(total)  best \(best)  \(gap)")
    }

case "balance":
    let races = intValue("races", default: 20)
    let racers = intValue("racers", default: 8)
    let difficulty = difficultyValue()
    var wins: [String: Int] = [:]
    var points: [String: Int] = [:]
    var lapStats: [String: (total: Double, best: Double, count: Int)] = [:]

    for track in TrackLibrary.all {
        for race in 0..<races {
            let engine = simulate(
                track: track,
                racers: racers,
                laps: nil,
                difficulty: difficulty,
                seed: UInt64(race * 7919 + 13)
            )
            guard let winner = engine.results.first else {
                print("!! \(track.id) race \(race) never finished")
                continue
            }
            wins[winner.profile.id, default: 0] += 1
            for result in engine.results {
                points[result.profile.id, default: 0] += result.points
            }
            for kart in engine.karts {
                for lap in kart.lapTimes {
                    var entry = lapStats[track.id] ?? (0, .greatestFiniteMagnitude, 0)
                    entry.total += lap
                    entry.best = min(entry.best, lap)
                    entry.count += 1
                    lapStats[track.id] = entry
                }
            }
        }
    }

    print("Balance over \(races) races per course, \(racers) carts, \(difficulty.displayName)")
    print(String(repeating: "-", count: 58))
    print("Lap times")
    for track in TrackLibrary.all {
        guard let stats = lapStats[track.id], stats.count > 0 else { continue }
        let average = stats.total / Double(stats.count)
        print("  \(track.name.padding(toLength: 24, withPad: " ", startingAt: 0)) avg \(TimeFormat.lap(average))  best \(TimeFormat.lap(stats.best))")
    }
    print("\nWins and points by cart")
    let totalRaces = races * TrackLibrary.all.count
    for profile in Roster.all {
        let won = wins[profile.id] ?? 0
        let share = Double(won) / Double(max(totalRaces, 1)) * 100
        let bar = String(repeating: "#", count: Int(share / 2))
        print("  \(profile.name.padding(toLength: 12, withPad: " ", startingAt: 0)) \(String(format: "%5.1f%%", share)) \(String(format: "%5d", points[profile.id] ?? 0)) pts  \(bar)")
    }

case "items":
    print("Item draw chances by race position")
    print(String(repeating: "-", count: 78))
    let kinds = ItemKind.allCases
    let header = kinds.map { $0.displayName.prefix(6).padding(toLength: 7, withPad: " ", startingAt: 0) }.joined()
    print("pos    \(header)")
    for place in 1...8 {
        let fraction = Double(place - 1) / 7
        let table = ItemRoulette.weights(positionFraction: fraction, racerCount: 8)
        let total = table.reduce(0) { $0 + $1.1 }
        let row = kinds.map { kind -> String in
            let weight = table.first { $0.0 == kind }?.1 ?? 0
            return String(format: "%5.1f%% ", weight / total * 100).padding(toLength: 7, withPad: " ", startingAt: 0)
        }.joined()
        print("\(TimeFormat.ordinal(place).padding(toLength: 6, withPad: " ", startingAt: 0)) \(row)")
    }

default:
    print("""
    cartkart-sim — headless CartKart simulator

      race     [--track id] [--racers n] [--laps n] [--difficulty d] [--seed n]
      balance  [--races n] [--racers n] [--difficulty d]
      items
      tracks

    Difficulties: trolleyDash, weeklyShop, blackFriday
    """)
}
