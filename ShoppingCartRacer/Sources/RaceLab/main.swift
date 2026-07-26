import CartRacerKit
import Foundation

// A balance bench for the simulation. Runs full races with nobody watching and
// prints the numbers you would otherwise have to squint at on a phone:
//
//   swift run race-lab            # every track at every difficulty
//   swift run race-lab tracks     # geometry report
//   swift run race-lab racers     # per-character single-cart pace

let arguments = Array(CommandLine.arguments.dropFirst())
let mode = arguments.first ?? "races"

func formatted(_ value: Double, _ decimals: Int = 2) -> String {
    String(format: "%.\(decimals)f", value)
}

func padded(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
}

func rightPadded(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
}

switch mode {
case "tracks":
    print("Track geometry")
    print(padded("course", 22) + rightPadded("length m", 10) + rightPadded("nodes", 8)
        + rightPadded("min half-w", 12) + rightPadded("tightest r", 12) + rightPadded("crates", 8) + rightPadded("tokens", 8))
    for definition in TrackLibrary.all {
        let track = Track(definition: definition)
        let geometry = track.geometry
        var tightestRadius = Double.infinity
        var distance = 0.0
        while distance < geometry.totalLength {
            let curvature = abs(geometry.curvature(at: distance, window: 10))
            if curvature > 1e-5 { tightestRadius = min(tightestRadius, 1 / curvature) }
            distance += 2
        }
        let minHalfWidth = definition.nodes.map(\.halfWidth).min() ?? 0
        print(
            padded(definition.name, 22)
                + rightPadded(formatted(geometry.totalLength, 1), 10)
                + rightPadded("\(definition.nodes.count)", 8)
                + rightPadded(formatted(minHalfWidth, 1), 12)
                + rightPadded(formatted(tightestRadius, 1), 12)
                + rightPadded("\(definition.itemBoxes.count)", 8)
                + rightPadded("\(definition.tokens.count)", 8)
        )
    }

case "racers":
    print("Single-cart pace, three laps of each course, no opponents")
    print(padded("racer", 14) + padded("course", 22) + rightPadded("best lap", 12) + rightPadded("total", 10) + rightPadded("scrapes", 10))
    for racer in RacerRoster.all {
        for definition in TrackLibrary.all {
            let configuration = RaceConfiguration(
                track: Track(definition: definition),
                entries: [RaceEntry(racer: racer, isPlayer: true)],
                difficulty: .blackFriday,
                seed: 0xBEEF
            )
            let report = RaceHarness.run(configuration: configuration)
            let best = report.fastestLap.map { formatted($0) } ?? "dnf"
            let total = report.result.playerStanding?.totalTime.map { formatted($0) } ?? "dnf"
            print(
                padded(racer.name, 14) + padded(definition.name, 22)
                    + rightPadded(best, 12) + rightPadded(total, 10)
                    + rightPadded("\(report.wallScrapes)", 10)
            )
        }
    }

case "drift":
    // Is sliding through the corners actually quicker? Same seed, same racer,
    // drifting on and off.
    print("Drift value check: one cart, three laps, Black Friday AI")
    print(padded("course", 22) + padded("racer", 14) + rightPadded("no drift", 11)
        + rightPadded("drift", 9) + rightPadded("delta", 9) + rightPadded("turbos", 9))
    for definition in TrackLibrary.all {
        for racerID in ["marge", "kev"] {
            guard let racer = RacerRoster.racer(id: racerID) else { continue }
            let configuration = RaceConfiguration(
                track: Track(definition: definition),
                entries: [RaceEntry(racer: racer, isPlayer: true)],
                difficulty: .blackFriday,
                seed: 0x5EED
            )
            let plain = RaceHarness.run(configuration: configuration, drifting: false)
            let sliding = RaceHarness.run(configuration: configuration, drifting: true)
            guard let a = plain.fastestLap, let b = sliding.fastestLap else { continue }
            print(
                padded(definition.name, 22) + padded(racer.name, 14)
                    + rightPadded(formatted(a), 11)
                    + rightPadded(formatted(b), 9)
                    + rightPadded(formatted(b - a), 9)
                    + rightPadded("\(sliding.miniTurbos)", 9)
            )
        }
    }

case "drifttrace":
    // One cart, one course, drift internals at 4 Hz.
    let trackID = arguments.count > 1 ? arguments[1] : TrackLibrary.all[0].id
    let racerID = arguments.count > 2 ? arguments[2] : "marge"
    let window = arguments.count > 3 ? Double(arguments[3]) ?? 25 : 25
    guard let definition = TrackLibrary.definition(id: trackID),
          let racer = RacerRoster.racer(id: racerID) else { fatalError("bad arguments") }
    let configuration = RaceConfiguration(
        track: Track(definition: definition),
        entries: [RaceEntry(racer: racer, isPlayer: true)],
        difficulty: .blackFriday,
        seed: 0x5EED
    )
    print("t      spd  thr  str   D  chg  bst  lat  half  side  curv   trav")
    _ = RaceHarness.run(
        configuration: configuration,
        maxSimulatedSeconds: window,
        drifting: true,
        traceInterval: 0.25
    ) { simulation in
        guard let cart = simulation.carts.first else { return }
        let geometry = simulation.configuration.track.geometry
        print(
            rightPadded(formatted(simulation.elapsedTime, 1), 5)
                + rightPadded(formatted(cart.forwardSpeed, 1), 6)
                + rightPadded(formatted(cart.lastInput.throttle, 1), 5)
                + rightPadded(formatted(cart.lastInput.steer, 1), 5)
                + rightPadded(cart.isDrifting ? "Y" : "-", 4)
                + rightPadded(formatted(cart.driftCharge, 1), 5)
                + rightPadded(formatted(cart.boostTimer, 1), 5)
                + rightPadded(formatted(cart.lateral, 1), 5)
                + rightPadded(formatted(geometry.halfWidth(at: cart.distance), 1), 6)
                + rightPadded(formatted(cart.lateralSpeed, 1), 6)
                + rightPadded(formatted(geometry.curvature(at: cart.distance, window: 12), 3), 7)
                + rightPadded(formatted(cart.travelled, 0), 7)
        )
    }

case "trace":
    // race-lab trace [trackID] [seconds]
    let trackID = arguments.count > 1 ? arguments[1] : TrackLibrary.all[2].id
    let window = arguments.count > 2 ? Double(arguments[2]) ?? 60 : 60
    guard let configuration = RaceConfiguration.standard(
        trackID: trackID,
        playerRacerID: RacerRoster.all[0].id,
        difficulty: .busy,
        seed: 0xC0FFEE
    ) else { fatalError("unknown track \(trackID)") }

    print("t     cart  racer      spd  thr  str  D  lat  half  surface        trav  stuck  spin  pos")
    _ = RaceHarness.run(
        configuration: configuration,
        maxSimulatedSeconds: window,
        traceInterval: 0.5
    ) { simulation in
        for cart in simulation.carts.sorted(by: { $0.id < $1.id }) {
            let half = simulation.configuration.track.geometry.halfWidth(at: cart.distance)
            print(
                rightPadded(formatted(simulation.elapsedTime, 1), 5)
                    + rightPadded("\(cart.id)", 6)
                    + "  " + padded(cart.racer.name, 10)
                    + rightPadded(formatted(cart.forwardSpeed, 1), 5)
                    + rightPadded(formatted(cart.lastInput.throttle, 1), 5)
                    + rightPadded(formatted(cart.lastInput.steer, 1), 5)
                    + rightPadded(cart.isDrifting ? "Y" : "-", 3)
                    + rightPadded(formatted(cart.lateral, 1), 6)
                    + rightPadded(formatted(half, 1), 6)
                    + "  " + padded(cart.surface.rawValue, 14)
                    + rightPadded(formatted(cart.travelled, 0), 6)
                    + rightPadded(formatted(cart.stuckTimer, 1), 7)
                    + rightPadded(formatted(cart.spinoutTimer, 1), 6)
                    + rightPadded("\(cart.racePosition)", 5)
            )
        }
        print("")
    }

default:
    print("Full field races (5 carts, 3 laps)")
    print(padded("course", 22) + padded("difficulty", 14) + rightPadded("winner", 12)
        + rightPadded("race s", 9) + rightPadded("best lap", 10) + rightPadded("avg lap", 9)
        + rightPadded("scrape", 8) + rightPadded("spin", 6) + rightPadded("items", 7)
        + rightPadded("drift", 7) + rightPadded("turbo", 7) + rightPadded("resp", 6) + rightPadded("out m", 8))
    var failures = 0
    for definition in TrackLibrary.all {
        for difficulty in Difficulty.allCases {
            guard let configuration = RaceConfiguration.standard(
                trackID: definition.id,
                playerRacerID: RacerRoster.all[0].id,
                difficulty: difficulty,
                seed: 0xC0FFEE
            ) else { continue }
            let report = RaceHarness.run(configuration: configuration)
            let winner = report.result.standings.first?.racerName ?? "-"
            print(
                padded(definition.name, 22) + padded(difficulty.displayName, 14)
                    + rightPadded(winner, 12)
                    + rightPadded(formatted(report.simulatedSeconds, 1), 9)
                    + rightPadded(report.fastestLap.map { formatted($0) } ?? "-", 10)
                    + rightPadded(report.averageLap.map { formatted($0) } ?? "-", 9)
                    + rightPadded("\(report.wallScrapes)", 8)
                    + rightPadded("\(report.spinouts)", 6)
                    + rightPadded("\(report.itemsUsed)", 7)
                    + rightPadded("\(report.driftsStarted)", 7)
                    + rightPadded("\(report.miniTurbos)", 7)
                    + rightPadded("\(report.respawns)", 6)
                    + rightPadded(formatted(report.worstOverhang, 1), 8)
            )
            if report.timedOut || !report.everyoneFinished {
                failures += 1
                print("  !! only \(report.finishedCount)/\(report.fieldSize) carts finished")
            }
        }
    }
    if failures > 0 {
        print("\n\(failures) configuration(s) failed to get the whole field home.")
        exit(1)
    }
    print("\nAll fields finished.")
}
