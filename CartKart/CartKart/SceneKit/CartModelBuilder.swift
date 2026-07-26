import SceneKit
import SpriteKit

enum CartModelBuilder {
    static func makeDetailedCart(bodyColor: UIColor, cartColor: UIColor, emitParticles: Bool = true) -> SCNNode {
        let root = SCNNode()

        let chassis = SCNBox(width: 30, height: 6, length: 38, chamferRadius: 2)
        chassis.firstMaterial?.diffuse.contents = cartColor
        chassis.firstMaterial?.metalness.contents = 0.6
        chassis.firstMaterial?.roughness.contents = 0.35
        let chassisNode = SCNNode(geometry: chassis)
        chassisNode.position = SCNVector3(0, 8, 0)
        root.addChildNode(chassisNode)

        let basket = SCNBox(width: 28, height: 14, length: 4, chamferRadius: 1)
        basket.firstMaterial?.diffuse.contents = cartColor.withAlphaComponent(0.9)
        let basketNode = SCNNode(geometry: basket)
        basketNode.position = SCNVector3(0, 16, -14)
        root.addChildNode(basketNode)

        let handle = SCNTube(innerRadius: 0.8, outerRadius: 1.2, height: 32)
        handle.firstMaterial?.diffuse.contents = UIColor.lightGray
        handle.firstMaterial?.metalness.contents = 0.9
        let handleL = SCNNode(geometry: handle)
        handleL.position = SCNVector3(-12, 18, -10)
        handleL.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        root.addChildNode(handleL)

        let handleR = handleL.clone()
        handleR.position = SCNVector3(12, 18, -10)
        root.addChildNode(handleR)

        let torso = SCNCapsule(capRadius: 7, height: 16)
        torso.firstMaterial?.diffuse.contents = bodyColor
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(0, 26, -4)
        root.addChildNode(torsoNode)

        let head = SCNSphere(radius: 7)
        head.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.78, blue: 0.62, alpha: 1)
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 36, -4)
        root.addChildNode(headNode)

        let wheelPositions: [SCNVector3] = [
            SCNVector3(-12, 4, 12), SCNVector3(12, 4, 12),
            SCNVector3(-12, 4, -10), SCNVector3(12, 4, -10)
        ]
        for position in wheelPositions {
            let wheel = SCNCylinder(radius: 4, height: 3)
            wheel.firstMaterial?.diffuse.contents = UIColor.darkGray
            wheel.firstMaterial?.metalness.contents = 0.4
            let wheelNode = SCNNode(geometry: wheel)
            wheelNode.position = position
            wheelNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            root.addChildNode(wheelNode)
        }

        if emitParticles {
            let dust = SCNParticleSystem()
            dust.birthRate = 0
            dust.particleLifeSpan = 0.4
            dust.particleSize = 0.08
            dust.particleColor = UIColor(white: 0.8, alpha: 0.5)
            dust.emissionDuration = 0
            dust.spreadingAngle = 25
            dust.particleVelocity = 2
            dust.particleVelocityVariation = 1
            dust.name = "dust"
            root.addParticleSystem(dust)

            let sparks = SCNParticleSystem()
            sparks.birthRate = 0
            sparks.particleLifeSpan = 0.25
            sparks.particleSize = 0.05
            sparks.particleColor = UIColor.orange
            sparks.emissionDuration = 0
            sparks.spreadingAngle = 40
            sparks.particleVelocity = 4
            sparks.name = "sparks"
            root.addParticleSystem(sparks)
        }

        return root
    }

    static func setupTrackLighting(in scene: SCNScene, track: TrackDefinition) {
        scene.rootNode.childNodes.filter { $0.name?.hasPrefix("trackLight") == true }.forEach { $0.removeFromParentNode() }

        let ambient = SCNNode()
        ambient.name = "trackLight_ambient"
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = track.isDarkStore ? 180 : 500
        ambient.light?.color = track.isDarkStore ? UIColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 1) : UIColor(white: 0.85, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.name = "trackLight_sun"
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = track.isDarkStore ? 400 : 900
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.eulerAngles = SCNVector3(-1.1, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        if track.isDarkStore {
            for (index, point) in track.itemBoxPositions.enumerated() {
                let spot = SCNNode()
                spot.name = "trackLight_spot_\(index)"
                spot.light = SCNLight()
                spot.light?.type = .spot
                spot.light?.intensity = 600
                spot.light?.spotInnerAngle = 30
                spot.light?.spotOuterAngle = 60
                spot.light?.color = UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1)
                spot.position = SCNVector3(point.x, 120, -point.y)
                spot.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                scene.rootNode.addChildNode(spot)
            }
        }
    }

    static func updateParticles(on node: SCNNode, speed: CGFloat, drifting: Bool) {
        for system in node.particleSystems ?? [] {
            if system.name == "dust" {
                system.birthRate = speed > 80 ? Float(speed / 40) : 0
            }
            if system.name == "sparks" {
                system.birthRate = drifting && speed > 100 ? 30 : 0
            }
        }
    }

    static func uiColor(from skColor: SKColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        skColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
