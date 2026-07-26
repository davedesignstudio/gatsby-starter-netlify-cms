import Foundation

/// The three courses of the Trolley Trophy.
public enum TrackLibrary {
    public static let all: [TrackDefinition] = [aisleSevenSprint, frozenFoodsLoop, loadingDockRally]

    /// Cup order for Grand Prix mode.
    public static let cupOrder: [String] = all.map(\.id)

    public static func definition(id: String) -> TrackDefinition? {
        all.first { $0.id == id }
    }

    public static func track(id: String) -> Track? {
        definition(id: id).map(Track.init(definition:))
    }

    // MARK: - Aisle Seven Sprint

    /// A boxy lap of the main shop floor: long straights, one badly mopped
    /// corner, and a seasonal carpet runner that kills your speed.
    public static let aisleSevenSprint: TrackDefinition = {
        var pen = TrackBuilder.Pen(halfWidth: 9, surface: .polishedTile)

        // Anti-clockwise, starting on the bottom straight heading towards +x.
        pen.line(from: Vector2(-50, -45), to: Vector2(50, -45))

        // Produce misters keep this corner permanently damp.
        pen.surface = .wetFloor
        pen.halfWidth = 8
        pen.arc(centre: Vector2(50, -25), radius: 20, startAngle: -.pi / 2, endAngle: 0)

        // Aisle seven proper: narrow, fast, unforgiving.
        pen.surface = .polishedTile
        pen.halfWidth = 7.5
        pen.line(from: Vector2(70, -25), to: Vector2(70, 25))

        pen.halfWidth = 8.5
        pen.arc(centre: Vector2(50, 25), radius: 20, startAngle: 0, endAngle: .pi / 2)

        pen.halfWidth = 9
        pen.line(from: Vector2(50, 45), to: Vector2(0, 45))

        // Seasonal aisle: someone laid carpet over the tiles.
        pen.surface = .carpetRunner
        pen.line(from: Vector2(0, 45), to: Vector2(-50, 45))

        pen.surface = .polishedTile
        pen.halfWidth = 8.5
        pen.arc(centre: Vector2(-50, 25), radius: 20, startAngle: .pi / 2, endAngle: .pi)

        // Entrance matting by the automatic doors.
        pen.surface = .rubberMat
        pen.halfWidth = 9
        pen.line(from: Vector2(-70, 25), to: Vector2(-70, -25))

        pen.surface = .polishedTile
        pen.arc(centre: Vector2(-50, -25), radius: 20, startAngle: .pi, endAngle: 1.5 * .pi)

        let nodes = TrackBuilder.centreline(from: pen.points, resolution: 1.6)
        let dresser = TrackDresser(geometry: TrackGeometry(nodes: nodes))

        var obstacles: [Obstacle] = [
            dresser.obstacle(progress: 0.19, lateral: 6.2, kind: .palletStack, radius: 1.5),
            dresser.obstacle(progress: 0.155, lateral: -3.4, kind: .wetFloorSign, radius: 0.7),
            dresser.obstacle(progress: 0.43, lateral: 6.0, kind: .palletStack, radius: 1.5),
            dresser.obstacle(progress: 0.70, lateral: 6.4, kind: .produceCrate, radius: 1.0),
            dresser.obstacle(progress: 0.905, lateral: 6.2, kind: .palletStack, radius: 1.5),
            dresser.obstacle(progress: 0.34, lateral: -5.8, kind: .mopBucket, radius: 0.8)
        ]
        // Promo displays down the middle of the seasonal aisle.
        obstacles += dresser.obstacleCluster(
            progress: 0.575,
            lateralOffsets: [-2.0, 2.4, -2.6],
            kind: .displayTower,
            spacing: 0.016,
            radius: 1.6
        )

        var tokens = dresser.tokenTrail(from: 0.03, to: 0.10, count: 6, lateral: -1.5, lateralEnd: 3.0)
        tokens += dresser.tokenTrail(from: 0.245, to: 0.30, count: 5, lateral: 0, lateralEnd: 0)
        tokens += dresser.tokenTrail(from: 0.63, to: 0.69, count: 6, lateral: 4.0, lateralEnd: -4.0)
        tokens += dresser.tokenTrail(from: 0.80, to: 0.86, count: 5, lateral: -3.0, lateralEnd: -3.0)

        return TrackDefinition(
            id: "aisle-seven",
            name: "Aisle Seven Sprint",
            subtitle: "Clean-up on lap three",
            theme: .grocery,
            recommendedLaps: 3,
            nodes: nodes,
            shoulderWidth: 3.6,
            obstacles: obstacles,
            boostPads: dresser.boostStrip(progress: 0.225, lateralOffsets: [-3.2, 0, 3.2], duration: 1.15)
                + dresser.boostStrip(progress: 0.755, lateralOffsets: [-2.6, 2.6], duration: 1.0),
            itemBoxes: dresser.itemRow(progress: 0.125, lateralOffsets: [-5.4, -2.7, 0, 2.7, 5.4])
                + dresser.itemRow(progress: 0.50, lateralOffsets: [-4.2, 0, 4.2])
                + dresser.itemRow(progress: 0.845, lateralOffsets: [-4.6, 0, 4.6]),
            tokens: tokens
        )
    }()

    // MARK: - Frozen Foods Loop

    /// Twistier and colder. Frost patches mean the racing line is a suggestion.
    public static let frozenFoodsLoop: TrackDefinition = {
        let controlPoints = TrackBuilder.polarLoop(
            baseRadius: 50,
            harmonics: [(k: 2, amplitude: 9, phase: 0.5), (k: 3, amplitude: 5, phase: 1.2)],
            aspect: 1.2,
            samples: 44
        ) { progress in
            // Two long freezer runs with a puddle where the cabinets defrost.
            if progress > 0.10 && progress < 0.28 {
                return (7.6, .freezerFrost)
            }
            if progress > 0.30 && progress < 0.36 {
                return (8.4, .wetFloor)
            }
            if progress > 0.55 && progress < 0.72 {
                return (7.2, .freezerFrost)
            }
            if progress > 0.80 && progress < 0.88 {
                return (9.0, .rubberMat)
            }
            return (8.6, .polishedTile)
        }

        let nodes = TrackBuilder.centreline(from: controlPoints, resolution: 1.5)
        let dresser = TrackDresser(geometry: TrackGeometry(nodes: nodes))

        var obstacles: [Obstacle] = [
            dresser.obstacle(progress: 0.135, lateral: 5.0, kind: .trafficCone, radius: 0.6),
            dresser.obstacle(progress: 0.16, lateral: -5.2, kind: .trafficCone, radius: 0.6),
            dresser.obstacle(progress: 0.315, lateral: -3.0, kind: .wetFloorSign, radius: 0.7),
            dresser.obstacle(progress: 0.335, lateral: 3.4, kind: .mopBucket, radius: 0.8),
            dresser.obstacle(progress: 0.47, lateral: 5.6, kind: .palletStack, radius: 1.4),
            dresser.obstacle(progress: 0.615, lateral: -4.8, kind: .produceCrate, radius: 1.0),
            dresser.obstacle(progress: 0.66, lateral: 4.6, kind: .produceCrate, radius: 1.0),
            dresser.obstacle(progress: 0.92, lateral: 5.4, kind: .displayTower, radius: 1.5)
        ]
        obstacles += dresser.obstacleCluster(
            progress: 0.40,
            lateralOffsets: [3.0, -3.0],
            kind: .trafficCone,
            spacing: 0.014,
            radius: 0.6
        )

        var tokens = dresser.tokenTrail(from: 0.05, to: 0.09, count: 5, lateral: 2.0, lateralEnd: -2.0)
        tokens += dresser.tokenTrail(from: 0.20, to: 0.26, count: 6, lateral: -4.5, lateralEnd: -1.0)
        tokens += dresser.tokenTrail(from: 0.44, to: 0.49, count: 4, lateral: -3.0, lateralEnd: -3.0)
        tokens += dresser.tokenTrail(from: 0.73, to: 0.79, count: 6, lateral: 3.5, lateralEnd: 0)

        return TrackDefinition(
            id: "frozen-foods",
            name: "Frozen Foods Loop",
            subtitle: "Mind the defrost puddle",
            theme: .frozenFoods,
            recommendedLaps: 3,
            nodes: nodes,
            shoulderWidth: 3.2,
            obstacles: obstacles,
            boostPads: dresser.boostStrip(progress: 0.29, lateralOffsets: [-2.4, 2.4], duration: 1.2)
                + dresser.boostStrip(progress: 0.53, lateralOffsets: [0], duration: 1.3)
                + dresser.boostStrip(progress: 0.86, lateralOffsets: [-3.0, 3.0], duration: 1.0),
            itemBoxes: dresser.itemRow(progress: 0.10, lateralOffsets: [-4.8, -1.6, 1.6, 4.8])
                + dresser.itemRow(progress: 0.435, lateralOffsets: [-4.0, 0, 4.0])
                + dresser.itemRow(progress: 0.70, lateralOffsets: [-3.6, 0, 3.6]),
            tokens: tokens
        )
    }()

    // MARK: - Loading Dock Rally

    /// Out through the roller shutter: asphalt, hairpins and zero sympathy.
    public static let loadingDockRally: TrackDefinition = {
        let controlPoints = TrackBuilder.polarLoop(
            baseRadius: 58,
            harmonics: [(k: 1, amplitude: 7, phase: 0.3), (k: 4, amplitude: 8, phase: 0.7)],
            aspect: 1.3,
            samples: 56
        ) { progress in
            // The lap starts inside the stockroom before heading out back.
            if progress < 0.12 {
                return (8.4, .polishedTile)
            }
            if progress > 0.12 && progress < 0.18 {
                return (7.6, .rubberMat)
            }
            if progress > 0.46 && progress < 0.52 {
                return (7.0, .wetFloor)
            }
            if progress > 0.66 && progress < 0.74 {
                return (6.8, .carpetRunner)
            }
            return (7.8, .loadingDockAsphalt)
        }

        let nodes = TrackBuilder.centreline(from: controlPoints, resolution: 1.5)
        let dresser = TrackDresser(geometry: TrackGeometry(nodes: nodes))

        var obstacles: [Obstacle] = [
            dresser.obstacle(progress: 0.145, lateral: 4.8, kind: .palletStack, radius: 1.5),
            dresser.obstacle(progress: 0.155, lateral: -4.9, kind: .palletStack, radius: 1.5),
            dresser.obstacle(progress: 0.235, lateral: 4.4, kind: .produceCrate, radius: 1.0),
            dresser.obstacle(progress: 0.37, lateral: -4.6, kind: .mopBucket, radius: 0.8),
            dresser.obstacle(progress: 0.485, lateral: 2.8, kind: .wetFloorSign, radius: 0.7),
            dresser.obstacle(progress: 0.56, lateral: -4.2, kind: .palletStack, radius: 1.4),
            dresser.obstacle(progress: 0.70, lateral: 4.0, kind: .displayTower, radius: 1.5),
            dresser.obstacle(progress: 0.885, lateral: -4.4, kind: .produceCrate, radius: 1.0)
        ]
        obstacles += dresser.obstacleCluster(
            progress: 0.30,
            lateralOffsets: [-3.4, 0.0, 3.4],
            kind: .trafficCone,
            spacing: 0.011,
            radius: 0.6
        )
        obstacles += dresser.obstacleCluster(
            progress: 0.79,
            lateralOffsets: [3.2, -3.2],
            kind: .trafficCone,
            spacing: 0.012,
            radius: 0.6
        )

        var tokens = dresser.tokenTrail(from: 0.04, to: 0.10, count: 6, lateral: -2.0, lateralEnd: 2.0)
        tokens += dresser.tokenTrail(from: 0.26, to: 0.31, count: 5, lateral: -3.6, lateralEnd: -3.6)
        tokens += dresser.tokenTrail(from: 0.52, to: 0.58, count: 6, lateral: 3.0, lateralEnd: -1.0)
        tokens += dresser.tokenTrail(from: 0.90, to: 0.96, count: 5, lateral: 1.5, lateralEnd: 1.5)

        return TrackDefinition(
            id: "loading-dock",
            name: "Loading Dock Rally",
            subtitle: "Round the back, past the bins",
            theme: .loadingDock,
            recommendedLaps: 3,
            nodes: nodes,
            shoulderWidth: 4.2,
            obstacles: obstacles,
            boostPads: dresser.boostStrip(progress: 0.20, lateralOffsets: [-2.8, 2.8], duration: 1.25)
                + dresser.boostStrip(progress: 0.415, lateralOffsets: [0], duration: 1.35)
                + dresser.boostStrip(progress: 0.63, lateralOffsets: [-3.0, 3.0], duration: 1.1)
                + dresser.boostStrip(progress: 0.94, lateralOffsets: [0], duration: 1.0),
            itemBoxes: dresser.itemRow(progress: 0.115, lateralOffsets: [-4.4, -1.5, 1.5, 4.4])
                + dresser.itemRow(progress: 0.345, lateralOffsets: [-3.6, 0, 3.6])
                + dresser.itemRow(progress: 0.605, lateralOffsets: [-3.4, 0, 3.4])
                + dresser.itemRow(progress: 0.855, lateralOffsets: [-3.0, 3.0]),
            tokens: tokens
        )
    }()
}
