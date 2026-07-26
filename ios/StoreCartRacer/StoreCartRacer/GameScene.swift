import CoreGraphics
import SpriteKit

final class GameScene: SKScene {
    private struct RacerState {
        let node: SKShapeNode
        var progress: CGFloat
        var lane: CGFloat
        var targetLane: CGFloat
        var speed: CGFloat
        let baseSpeed: CGFloat
        var lap: Int
        var stunTimer: CGFloat
        let isPlayer: Bool
        let aiSeed: CGFloat
    }

    private struct HazardState {
        let node: SKShapeNode
        let progress: CGFloat
        let lane: CGFloat
        var cooldown: CGFloat
    }

    private weak var model: GameModel?
    private var racers: [RacerState] = []
    private var hazards: [HazardState] = []
    private var lastUpdateTime: TimeInterval = 0
    private var raceStartedAt: TimeInterval = 0
    private var worldIsBuilt = false
    private let cameraNode = SKCameraNode()

    private let trackRadiusX: CGFloat = 760
    private let trackRadiusY: CGFloat = 520
    private let laneWidth: CGFloat = 128
    private let laneLimit: CGFloat = 0.95

    func bind(model: GameModel) {
        self.model = model
        restartRace()
    }

    func restartRace() {
        model?.resetRace()
        if racers.isEmpty {
            buildRacers()
        }
        if hazards.isEmpty {
            buildHazards()
        }

        resetRacers()
        for i in hazards.indices {
            hazards[i].cooldown = 0
            hazards[i].node.alpha = 1
            hazards[i].node.position = pointOnTrack(progress: hazards[i].progress, lane: hazards[i].lane)
        }
        raceStartedAt = 0
    }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        if !worldIsBuilt {
            buildWorld()
            worldIsBuilt = true
        }
        addChild(cameraNode)
        camera = cameraNode
        restartRace()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let delta = currentTime - lastUpdateTime
        let dt = CGFloat(max(0, min(1.0 / 20.0, delta)))
        lastUpdateTime = currentTime
        if dt == 0 || racers.isEmpty {
            return
        }

        if raceStartedAt == 0 {
            raceStartedAt = currentTime
        }

        updateHazards(dt: dt)
        updateRacers(dt: dt, currentTime: currentTime)
        updateCamera(dt: dt)
        updateStandings()
    }

    private func buildWorld() {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1.0)

        let storeFloor = SKShapeNode(rectOf: CGSize(width: 3600, height: 2600), cornerRadius: 0)
        storeFloor.fillColor = SKColor(red: 0.17, green: 0.2, blue: 0.24, alpha: 1)
        storeFloor.strokeColor = .clear
        storeFloor.zPosition = -50
        addChild(storeFloor)

        let border = SKShapeNode(rectOf: CGSize(width: 3550, height: 2550), cornerRadius: 12)
        border.strokeColor = SKColor(red: 0.32, green: 0.38, blue: 0.44, alpha: 1)
        border.lineWidth = 10
        border.zPosition = -49
        addChild(border)

        // Store shelves around the race loop to sell the "inside a market" look.
        for row in -2...2 {
            let shelf = SKShapeNode(rectOf: CGSize(width: 2400, height: 48), cornerRadius: 8)
            shelf.fillColor = SKColor(red: 0.38, green: 0.3, blue: 0.24, alpha: 1)
            shelf.strokeColor = SKColor(red: 0.52, green: 0.42, blue: 0.35, alpha: 1)
            shelf.lineWidth = 3
            shelf.position = CGPoint(x: 0, y: CGFloat(row) * 250)
            shelf.zPosition = -30
            addChild(shelf)
        }

        let outerRect = CGRect(
            x: -(trackRadiusX + laneWidth * 1.25),
            y: -(trackRadiusY + laneWidth * 1.25),
            width: (trackRadiusX + laneWidth * 1.25) * 2,
            height: (trackRadiusY + laneWidth * 1.25) * 2
        )

        let innerRect = CGRect(
            x: -(trackRadiusX - laneWidth * 1.25),
            y: -(trackRadiusY - laneWidth * 1.25),
            width: (trackRadiusX - laneWidth * 1.25) * 2,
            height: (trackRadiusY - laneWidth * 1.25) * 2
        )

        let trackPath = CGMutablePath()
        trackPath.addEllipse(in: outerRect)
        trackPath.addEllipse(in: innerRect)

        let track = SKShapeNode(path: trackPath)
        track.fillRule = .evenOdd
        track.fillColor = SKColor(red: 0.26, green: 0.29, blue: 0.34, alpha: 1)
        track.strokeColor = SKColor(red: 0.6, green: 0.66, blue: 0.72, alpha: 0.45)
        track.lineWidth = 5
        track.zPosition = -10
        addChild(track)

        let centerIsland = SKShapeNode(ellipseOf: CGSize(width: trackRadiusX * 1.45, height: trackRadiusY * 1.45))
        centerIsland.fillColor = SKColor(red: 0.15, green: 0.22, blue: 0.16, alpha: 1)
        centerIsland.strokeColor = SKColor(red: 0.33, green: 0.47, blue: 0.35, alpha: 1)
        centerIsland.lineWidth = 6
        centerIsland.zPosition = -9
        addChild(centerIsland)

        let startLine = SKShapeNode(rectOf: CGSize(width: 24, height: laneWidth * 2.25), cornerRadius: 4)
        startLine.fillColor = .white
        startLine.strokeColor = .clear
        startLine.position = CGPoint(x: 0, y: trackRadiusY + laneWidth * 0.1)
        startLine.zRotation = .pi / 2
        startLine.zPosition = -5
        addChild(startLine)
    }

    private func buildRacers() {
        let playerNode = makeCartNode(color: .systemRed)
        addChild(playerNode)
        racers.append(
            RacerState(
                node: playerNode,
                progress: 0,
                lane: -0.4,
                targetLane: -0.4,
                speed: 0,
                baseSpeed: 0.34,
                lap: 1,
                stunTimer: 0,
                isPlayer: true,
                aiSeed: 0
            )
        )

        let aiColors: [SKColor] = [.systemBlue, .systemTeal, .systemGreen, .systemPurple]
        for (idx, color) in aiColors.enumerated() {
            let node = makeCartNode(color: color)
            addChild(node)
            racers.append(
                RacerState(
                    node: node,
                    progress: CGFloat(idx + 1) * 0.18,
                    lane: CGFloat(idx % 2 == 0 ? 0.45 : -0.65),
                    targetLane: 0,
                    speed: 0.26,
                    baseSpeed: 0.30 + CGFloat(idx) * 0.012,
                    lap: 1,
                    stunTimer: 0,
                    isPlayer: false,
                    aiSeed: CGFloat(idx + 1) * 1.7
                )
            )
        }
    }

    private func buildHazards() {
        let layout: [(CGFloat, CGFloat)] = [
            (0.11, -0.25),
            (0.24, 0.52),
            (0.37, -0.55),
            (0.49, 0.22),
            (0.63, -0.05),
            (0.72, 0.66),
            (0.85, -0.68)
        ]

        for slot in layout {
            let hazardNode = SKShapeNode(circleOfRadius: 26)
            hazardNode.fillColor = SKColor(red: 0.95, green: 0.85, blue: 0.22, alpha: 1)
            hazardNode.strokeColor = SKColor(red: 0.75, green: 0.65, blue: 0.15, alpha: 1)
            hazardNode.lineWidth = 4
            hazardNode.zPosition = 6
            addChild(hazardNode)
            hazards.append(HazardState(node: hazardNode, progress: slot.0, lane: slot.1, cooldown: 0))
        }
    }

    private func resetRacers() {
        guard !racers.isEmpty else { return }

        for index in racers.indices {
            let startProgress = CGFloat(index) * 0.16
            racers[index].progress = startProgress
            racers[index].lap = 1
            racers[index].stunTimer = 0
            racers[index].speed = racers[index].baseSpeed * 0.75

            if racers[index].isPlayer {
                racers[index].lane = -0.4
                racers[index].targetLane = -0.4
            } else {
                racers[index].lane = index % 2 == 0 ? 0.45 : -0.55
                racers[index].targetLane = racers[index].lane
            }

            let point = pointOnTrack(progress: racers[index].progress, lane: racers[index].lane)
            racers[index].node.position = point
            racers[index].node.zRotation = trackTangent(progress: racers[index].progress, lane: racers[index].lane)
        }
    }

    private func updateHazards(dt: CGFloat) {
        for i in hazards.indices {
            hazards[i].cooldown = max(0, hazards[i].cooldown - dt)
            hazards[i].node.alpha = hazards[i].cooldown > 0 ? 0.35 : 1
        }
    }

    private func updateRacers(dt: CGFloat, currentTime: TimeInterval) {
        let trackLengthEstimate = CGFloat.pi * (3 * (trackRadiusX + trackRadiusY) - sqrt((3 * trackRadiusX + trackRadiusY) * (trackRadiusX + 3 * trackRadiusY)))
        let modelSteering = model?.steering ?? 0
        let isBoosting = model?.boosting ?? false

        for i in racers.indices {
            var racer = racers[i]

            if racer.isPlayer {
                racer.targetLane = clamp(modelSteering * laneLimit, min: -laneLimit, max: laneLimit)
            } else {
                racer.targetLane = sin(CGFloat(currentTime) * 0.7 + racer.aiSeed) * 0.78
            }

            racer.lane += (racer.targetLane - racer.lane) * min(1, dt * 4.6)
            racer.lane = clamp(racer.lane, min: -laneLimit, max: laneLimit)

            if racer.stunTimer > 0 {
                racer.stunTimer = max(0, racer.stunTimer - dt)
            }

            var targetSpeed = racer.baseSpeed
            if racer.isPlayer && isBoosting {
                targetSpeed *= 1.24
            } else if !racer.isPlayer {
                let wiggle = 0.06 * sin(CGFloat(currentTime) * 1.3 + racer.aiSeed * 2)
                targetSpeed *= 1 + wiggle
            }
            if racer.stunTimer > 0 {
                targetSpeed *= 0.52
            }

            racer.speed += (targetSpeed - racer.speed) * min(1, dt * 3.2)
            racer.progress += (racer.speed * dt) / trackLengthEstimate
            if racer.progress >= 1 {
                racer.progress -= 1
                racer.lap += 1
            }

            racer.node.position = pointOnTrack(progress: racer.progress, lane: racer.lane)
            racer.node.zRotation = trackTangent(progress: racer.progress, lane: racer.lane)
            racers[i] = racer
        }

        handleCollisions()

        if let playerIndex = racers.firstIndex(where: { $0.isPlayer }) {
            let player = racers[playerIndex]
            model?.lap = min(player.lap, model?.maxLaps ?? 3)
            model?.speed = player.speed * 720
            if player.lap > (model?.maxLaps ?? 3) && model?.raceFinished == false {
                model?.raceFinished = true
                model?.boosting = false
            }
        }
    }

    private func updateCamera(dt: CGFloat) {
        guard let player = racers.first(where: { $0.isPlayer }) else {
            return
        }
        let followRate = min(1, dt * 3)
        cameraNode.position.x += (player.node.position.x - cameraNode.position.x) * followRate
        cameraNode.position.y += (player.node.position.y - cameraNode.position.y) * followRate
    }

    private func handleCollisions() {
        guard let playerIndex = racers.firstIndex(where: { $0.isPlayer }) else {
            return
        }

        let playerPos = racers[playerIndex].node.position

        for i in hazards.indices where hazards[i].cooldown == 0 {
            let hazardPos = pointOnTrack(progress: hazards[i].progress, lane: hazards[i].lane)
            if distance(playerPos, hazardPos) < 64 {
                hazards[i].cooldown = 1.6
                racers[playerIndex].speed *= 0.62
                racers[playerIndex].stunTimer = max(racers[playerIndex].stunTimer, 1.0)
            }
        }

        for i in racers.indices where i != playerIndex {
            let aiPos = racers[i].node.position
            if distance(playerPos, aiPos) < 72 {
                racers[playerIndex].speed *= 0.86
                racers[playerIndex].stunTimer = max(racers[playerIndex].stunTimer, 0.35)
                let sidePush: CGFloat = aiPos.x < playerPos.x ? 0.14 : -0.14
                racers[playerIndex].lane = clamp(racers[playerIndex].lane + sidePush, min: -laneLimit, max: laneLimit)
            }
        }
    }

    private func updateStandings() {
        let ranked = racers.enumerated().sorted { lhs, rhs in
            score(for: lhs.element) > score(for: rhs.element)
        }

        if let place = ranked.firstIndex(where: { $0.element.isPlayer }) {
            model?.position = place + 1
        }
    }

    private func score(for racer: RacerState) -> CGFloat {
        CGFloat(racer.lap - 1) + racer.progress
    }

    private func makeCartNode(color: SKColor) -> SKShapeNode {
        let cart = SKShapeNode(rectOf: CGSize(width: 56, height: 86), cornerRadius: 14)
        cart.fillColor = color
        cart.strokeColor = .white
        cart.lineWidth = 3
        cart.zPosition = 20

        let basket = SKShapeNode(rectOf: CGSize(width: 30, height: 26), cornerRadius: 6)
        basket.fillColor = SKColor.white.withAlphaComponent(0.45)
        basket.strokeColor = .clear
        basket.position = CGPoint(x: 0, y: 12)
        basket.zPosition = 1
        cart.addChild(basket)

        return cart
    }

    private func pointOnTrack(progress: CGFloat, lane: CGFloat) -> CGPoint {
        let angle = progress * 2 * .pi - (.pi / 2)
        let radiusX = trackRadiusX + lane * laneWidth
        let radiusY = trackRadiusY + lane * laneWidth * 0.82
        return CGPoint(x: cos(angle) * radiusX, y: sin(angle) * radiusY)
    }

    private func trackTangent(progress: CGFloat, lane: CGFloat) -> CGFloat {
        let angle = progress * 2 * .pi - (.pi / 2)
        let radiusX = trackRadiusX + lane * laneWidth
        let radiusY = trackRadiusY + lane * laneWidth * 0.82
        let dx = -sin(angle) * radiusX
        let dy = cos(angle) * radiusY
        return atan2(dy, dx)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}
