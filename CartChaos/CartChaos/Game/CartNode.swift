import SpriteKit

final class CartNode: SKNode {
    let character: CharacterType
    let isPlayer: Bool

    var velocity = CGVector(dx: 0, dy: 0)
    var heading: CGFloat = 0
    var currentSpeed: CGFloat = 0
    var isDrifting = false
    var driftCharge: CGFloat = 0
    var boostTimer: TimeInterval = 0
    var shieldActive = false
    var spinOutTimer: TimeInterval = 0
    var heldItem: ItemType?
    var lapCount = 0
    var lastCheckpoint = 0
    var raceProgress: CGFloat = 0
    var finished = false
    var finishTime: TimeInterval?

    private let cartBody: SKShapeNode
    private let characterNode: SKShapeNode
    private let wheelNodes: [SKShapeNode]
    private let driftTrail: SKEmitterNode?

    init(character: CharacterType, isPlayer: Bool) {
        self.character = character
        self.isPlayer = isPlayer

        cartBody = SKShapeNode(rectOf: CGSize(width: 28, height: 40), cornerRadius: 4)
        cartBody.fillColor = character.cartColor
        cartBody.strokeColor = .black
        cartBody.lineWidth = 2
        cartBody.zPosition = 1

        characterNode = SKShapeNode(circleOfRadius: 8)
        characterNode.fillColor = character.shirtColor
        characterNode.strokeColor = .black
        characterNode.lineWidth = 1.5
        characterNode.position = CGPoint(x: 0, y: -8)
        characterNode.zPosition = 2

        var wheels: [SKShapeNode] = []
        for offset in [CGPoint(x: -12, y: 14), CGPoint(x: 12, y: 14),
                       CGPoint(x: -12, y: -14), CGPoint(x: 12, y: -14)] {
            let wheel = SKShapeNode(circleOfRadius: 5)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            wheel.position = offset
            wheel.zPosition = 0
            wheels.append(wheel)
        }
        wheelNodes = wheels

        if isPlayer {
            let trail = SKEmitterNode()
            trail.particleBirthRate = 0
            trail.particleLifetime = 0.3
            trail.particleSpeed = 20
            trail.particleSpeedRange = 10
            trail.particleAlpha = 0.6
            trail.particleAlphaSpeed = -2
            trail.particleScale = 0.15
            trail.particleColor = .cyan
            trail.position = CGPoint(x: 0, y: -25)
            driftTrail = trail
        } else {
            driftTrail = nil
        }

        super.init()

        addChild(cartBody)
        addChild(characterNode)
        wheelNodes.forEach { addChild($0) }
        if let driftTrail { addChild(driftTrail) }

        if isPlayer {
            let glow = SKShapeNode(rectOf: CGSize(width: 32, height: 44), cornerRadius: 6)
            glow.strokeColor = .yellow
            glow.lineWidth = 2
            glow.fillColor = .clear
            glow.alpha = 0.7
            glow.zPosition = -1
            glow.name = "playerGlow"
            addChild(glow)
        }

        name = isPlayer ? "playerCart" : "aiCart"
        zPosition = 10
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(deltaTime: TimeInterval, steerInput: CGFloat, isDriftHeld: Bool, trackBounds: CGRect) {
        if spinOutTimer > 0 {
            spinOutTimer -= deltaTime
            heading += 6 * CGFloat(deltaTime)
            currentSpeed *= 0.95
            applyMovement(deltaTime: deltaTime)
            updateVisuals()
            return
        }

        let maxSpeed = character.speed * (boostTimer > 0 ? 1.45 : 1.0)
        let accel = character.acceleration

        currentSpeed = min(maxSpeed, currentSpeed + accel * CGFloat(deltaTime))

        let handling = character.handling * (isDrifting ? 1.6 : 1.0)
        heading += steerInput * handling * CGFloat(deltaTime)

        isDrifting = isDriftHeld && abs(steerInput) > 0.3 && currentSpeed > 80
        if isDrifting {
            driftCharge = min(1.0, driftCharge + CGFloat(deltaTime) * 0.5)
            driftTrail?.particleBirthRate = 40
        } else {
            if driftCharge >= 0.6 {
                boostTimer = 1.2
            }
            driftCharge = 0
            driftTrail?.particleBirthRate = 0
        }

        if boostTimer > 0 {
            boostTimer -= deltaTime
        }

        applyMovement(deltaTime: deltaTime)
        clampToTrack(trackBounds)
        updateVisuals()
    }

    private func applyMovement(deltaTime: TimeInterval) {
        let dx = sin(heading) * currentSpeed * CGFloat(deltaTime)
        let dy = cos(heading) * currentSpeed * CGFloat(deltaTime)
        position.x += dx
        position.y += dy
        zRotation = -heading
    }

    private func clampToTrack(_ bounds: CGRect) {
        let margin: CGFloat = 20
        position.x = max(bounds.minX + margin, min(bounds.maxX - margin, position.x))
        position.y = max(bounds.minY + margin, min(bounds.maxY - margin, position.y))
    }

    private func updateVisuals() {
        let wobble = isDrifting ? sin(CACurrentMediaTime() * 20) * 0.05 : 0
        zRotation = -heading + CGFloat(wobble)

        if shieldActive {
            cartBody.strokeColor = .green
            cartBody.lineWidth = 3
        } else {
            cartBody.strokeColor = .black
            cartBody.lineWidth = 2
        }
    }

    func applySpinOut(duration: TimeInterval = 1.5) {
        guard !shieldActive else {
            shieldActive = false
            return
        }
        spinOutTimer = duration
        currentSpeed *= 0.3
    }

    func applyBoost(duration: TimeInterval = 1.5) {
        boostTimer = duration
    }

    func brake(amount: CGFloat = 0.5) {
        currentSpeed *= (1 - amount)
    }
}
