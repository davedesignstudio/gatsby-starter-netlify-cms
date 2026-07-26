import Foundation
@testable import CartRacerKit

/// Purpose-built courses and a simple scripted driver, so physics behaviour can
/// be asserted without depending on how well the race AI happens to drive.
enum TestTracks {
    /// A plain circular course. Wide and gentle unless told otherwise.
    static func circle(
        radius: Double = 70,
        halfWidth: Double = 12,
        surface: Surface = .polishedTile,
        shoulderWidth: Double = 4
    ) -> Track {
        let control = TrackBuilder.polarLoop(
            baseRadius: radius,
            harmonics: [],
            samples: 48
        ) { _ in (halfWidth, surface) }
        return Track(
            definition: TrackDefinition(
                id: "test-circle",
                name: "Test Circle",
                subtitle: "",
                theme: .grocery,
                recommendedLaps: 3,
                nodes: TrackBuilder.centreline(from: control, resolution: 1.5),
                shoulderWidth: shoulderWidth,
                obstacles: [],
                boostPads: [],
                itemBoxes: [],
                tokens: []
            )
        )
    }

    static func configuration(
        track: Track,
        racers: [Racer],
        laps: Int = 3,
        difficulty: Difficulty = .busy,
        seed: UInt64 = 0x1234
    ) -> RaceConfiguration {
        RaceConfiguration(
            track: track,
            laps: laps,
            entries: racers.enumerated().map { RaceEntry(racer: $1, isPlayer: $0 == 0) },
            difficulty: difficulty,
            seed: seed,
            endsWhenPlayerFinishes: false
        )
    }

    /// Runs a simulation to the green light and returns it ready to drive.
    static func started(_ configuration: RaceConfiguration) -> RaceSimulation {
        let simulation = RaceSimulation(configuration: configuration)
        while !simulation.phase.isRacing {
            simulation.step(simulation.tuning.fixedTimeStep)
        }
        _ = simulation.drainEvents()
        return simulation
    }
}

/// Steers a cart along the centreline with a proportional controller. Enough of
/// a driver to measure pace, grip and drift behaviour repeatably.
struct ScriptedDriver {
    var lookahead: Double = 12
    var lateralTarget: Double = 0
    var throttle: Double = 1
    var drift = false
    var steerGain: Double = 2.2
    /// Minimum steering held towards the way the course turns. A well-tracking
    /// pursuit controller barely touches the wheel, which is not enough to
    /// commit to a drift, so drift tests need a decisive hand on it.
    var steerFloor: Double = 0

    func input(for cart: CartState, geometry: TrackGeometry) -> DriverInput {
        let aim = geometry.position(at: cart.distance + lookahead, lateral: lateralTarget)
        let desired = (aim - cart.position).angle
        let error = Scalar.angleDelta(from: cart.heading, to: desired)
        var steer = Scalar.clamp(error * steerGain, -1, 1)

        if steerFloor > 0 {
            let cornerDirection = Scalar.signum(geometry.curvature(at: cart.distance + lookahead, window: 14))
            if cornerDirection != 0, abs(steer) < steerFloor || Scalar.signum(steer) != cornerDirection {
                steer = cornerDirection * steerFloor
            }
        }

        return DriverInput(throttle: throttle, steer: steer, drift: drift, useItem: false)
    }
}

extension RaceSimulation {
    /// Drives every cart with the same scripted policy for `seconds`.
    /// Returns the events raised along the way.
    @discardableResult
    func runScripted(seconds: Double, driver: ScriptedDriver) -> [RaceEvent] {
        var events: [RaceEvent] = []
        var elapsed = 0.0
        while elapsed < seconds {
            for cart in carts {
                setInput(driver.input(for: cart, geometry: geometry), forCart: cart.id)
            }
            step(tuning.fixedTimeStep)
            events += drainEvents()
            elapsed += tuning.fixedTimeStep
            if phase == .complete { break }
        }
        return events
    }
}
