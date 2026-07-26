import Foundation

/// A can or melon in flight.
public struct Projectile: Sendable, Identifiable {
    public var id: Int
    public var kind: ItemKind
    public var ownerID: Int
    public var position: Vector2
    public var velocity: Vector2
    public var life: Double
    public var bouncesLeft: Int
    public var targetID: Int?
    /// Owners are immune to their own shot for a moment after firing.
    public var ownerImmunity: Double
    public var radius: Double = 0.45
}

/// Something left on the floor for other people to find.
public struct Drop: Sendable, Identifiable {
    public var id: Int
    public var kind: ItemKind
    public var ownerID: Int
    public var position: Vector2
    public var life: Double
    public var radius: Double
    /// Brief delay before the dropper can be caught by their own mess.
    public var armTime: Double
    /// Set once something has run through it, so the view can splatter it.
    public var isSpent = false
}

public enum ItemSystem {
    public static let canSpeed: Double = 27
    public static let melonSpeed: Double = 24
    public static let melonTurnRate: Double = 3.4
    public static let spillRadius: Double = 1.7
    public static let signRadius: Double = 0.75

    // MARK: - Firing

    /// Turns a held item into world state. Returns events for presentation.
    public static func deploy(
        cart: inout Cart,
        aimBackward: Bool,
        nextID: inout Int,
        projectiles: inout [Projectile],
        drops: inout [Drop],
        allCarts: [Cart],
        standings: [Int],
        events: inout [RaceEvent]
    ) {
        guard let item = cart.heldItem else { return }
        let forward = Vector2.angled(cart.heading)
        let direction = aimBackward ? -forward : forward

        switch item {
        case .soupCan, .tripleCans:
            let origin = cart.position + direction * (cart.collisionRadius + 0.7)
            projectiles.append(Projectile(
                id: nextID,
                kind: .soupCan,
                ownerID: cart.id,
                position: origin,
                velocity: direction * canSpeed + cart.velocity * 0.35,
                life: 7,
                bouncesLeft: 4,
                targetID: nil,
                ownerImmunity: 0.45
            ))
            nextID += 1
            events.append(.projectileFired(cartID: cart.id, kind: .soupCan))
            if item == .tripleCans {
                cart.orbitingCans = max(0, cart.orbitingCans - 1)
                cart.heldCharges -= 1
                if cart.heldCharges <= 0 { cart.heldItem = nil }
            } else {
                cart.heldItem = nil
                cart.heldCharges = 0
            }

        case .rogueMelon:
            let origin = cart.position + direction * (cart.collisionRadius + 0.8)
            projectiles.append(Projectile(
                id: nextID,
                kind: .rogueMelon,
                ownerID: cart.id,
                position: origin,
                velocity: direction * melonSpeed,
                life: 9,
                bouncesLeft: 2,
                targetID: aimBackward ? nil : cartAhead(of: cart.id, standings: standings, carts: allCarts),
                ownerImmunity: 0.6,
                radius: 0.6
            ))
            nextID += 1
            events.append(.projectileFired(cartID: cart.id, kind: .rogueMelon))
            cart.heldItem = nil
            cart.heldCharges = 0

        case .milkSpill, .wetFloorSign:
            let behind = cart.position - forward * (cart.collisionRadius + 1.0)
            drops.append(Drop(
                id: nextID,
                kind: item,
                ownerID: cart.id,
                position: behind,
                life: item == .milkSpill ? 28 : 45,
                radius: item == .milkSpill ? spillRadius : signRadius,
                armTime: 0.6
            ))
            nextID += 1
            cart.heldItem = nil
            cart.heldCharges = 0

        case .energyDrink:
            cart.grantBoost(duration: 1.6, strength: 1.38)
            cart.heldItem = nil
            cart.heldCharges = 0

        case .vipCard:
            cart.invincibleTimer = max(cart.invincibleTimer, 7.5)
            cart.spinTimer = 0
            cart.slowTimer = 0
            cart.grantBoost(duration: 7.5, strength: 1.16)
            cart.heldItem = nil
            cart.heldCharges = 0

        case .runawayCart:
            cart.autopilotTimer = max(cart.autopilotTimer, 4.5)
            cart.invincibleTimer = max(cart.invincibleTimer, 4.8)
            cart.spinTimer = 0
            cart.slowTimer = 0
            cart.heldItem = nil
            cart.heldCharges = 0

        case .cleanupCall:
            cart.heldItem = nil
            cart.heldCharges = 0
        }

        events.append(.itemUsed(cartID: cart.id, kind: item))
        cart.isTrailingItem = false
    }

    /// The cart one place ahead in the standings, if there is one.
    public static func cartAhead(of cartID: Int, standings: [Int], carts: [Cart]) -> Int? {
        guard let index = standings.firstIndex(of: cartID), index > 0 else { return nil }
        return standings[index - 1]
    }

    // MARK: - Simulation

    public static func updateProjectiles(
        _ projectiles: inout [Projectile],
        carts: inout [Cart],
        track: Track,
        dt: Double,
        events: inout [RaceEvent]
    ) {
        var index = 0
        while index < projectiles.count {
            var projectile = projectiles[index]
            projectile.life -= dt
            projectile.ownerImmunity = max(0, projectile.ownerImmunity - dt)

            if projectile.kind == .rogueMelon {
                steerMelon(&projectile, carts: carts, track: track, dt: dt)
            }

            projectile.position += projectile.velocity * dt

            // Ricochet off the shelving.
            let projection = track.project(projectile.position)
            let wall = track.wallDistance(atDistance: projection.distance)
            if abs(projection.lateral) > wall {
                if projectile.bouncesLeft <= 0 {
                    projectiles.remove(at: index)
                    continue
                }
                let normal = projection.tangent.perpendicular * (projection.lateral > 0 ? -1 : 1)
                let penetration = abs(projection.lateral) - wall
                projectile.position += normal * (penetration + 0.05)
                let into = projectile.velocity.dot(normal)
                if into < 0 {
                    projectile.velocity -= normal * (2 * into)
                }
                projectile.bouncesLeft -= 1
            }

            var consumed = false
            for cartIndex in carts.indices {
                if carts[cartIndex].id == projectile.ownerID, projectile.ownerImmunity > 0 { continue }
                if carts[cartIndex].hasFinished { continue }
                let reach = carts[cartIndex].collisionRadius + projectile.radius
                guard carts[cartIndex].position.distance(to: projectile.position) < reach else { continue }

                if carts[cartIndex].isInvincible {
                    // Bounces harmlessly off a VIP.
                    consumed = true
                    events.append(.cartHit(cartID: carts[cartIndex].id, by: projectile.kind, sourceID: projectile.ownerID))
                    break
                }
                if carts[cartIndex].orbitingCans > 0, carts[cartIndex].id != projectile.ownerID {
                    carts[cartIndex].orbitingCans -= 1
                    carts[cartIndex].heldCharges = max(0, carts[cartIndex].heldCharges - 1)
                    if carts[cartIndex].heldCharges <= 0 { carts[cartIndex].heldItem = nil }
                    consumed = true
                    break
                }
                let side = projectile.velocity.cross(Vector2.angled(carts[cartIndex].heading))
                carts[cartIndex].spinOut(direction: side >= 0 ? 1 : -1, duration: projectile.kind == .rogueMelon ? 1.4 : 1.1)
                events.append(.cartHit(cartID: carts[cartIndex].id, by: projectile.kind, sourceID: projectile.ownerID))
                consumed = true
                break
            }

            if consumed || projectile.life <= 0 {
                projectiles.remove(at: index)
                continue
            }
            projectiles[index] = projectile
            index += 1
        }
    }

    private static func steerMelon(_ projectile: inout Projectile, carts: [Cart], track: Track, dt: Double) {
        var desired: Double?
        if let targetID = projectile.targetID, let target = carts.first(where: { $0.id == targetID }), !target.hasFinished {
            let toTarget = target.position - projectile.position
            if toTarget.length < 70 {
                desired = toTarget.angle
            }
        }
        if desired == nil {
            // No lock: follow the racing line so it stays a threat.
            let projection = track.project(projectile.position)
            let ahead = track.racingLinePoint(atDistance: projection.distance + 12)
            desired = (ahead - projection.closestPoint).length > 0.01
                ? (ahead - projection.closestPoint).angle
                : projection.tangent.angle
        }
        guard let target = desired else { return }
        let heading = Angle.rotate(projectile.velocity.angle, towards: target, maxStep: melonTurnRate * dt)
        projectile.velocity = Vector2.angled(heading, length: melonSpeed)
    }

    public static func updateDrops(
        _ drops: inout [Drop],
        carts: inout [Cart],
        dt: Double,
        events: inout [RaceEvent]
    ) {
        var index = 0
        while index < drops.count {
            drops[index].life -= dt
            drops[index].armTime = max(0, drops[index].armTime - dt)
            if drops[index].life <= 0 {
                drops.remove(at: index)
                continue
            }

            let drop = drops[index]
            var triggered = false
            for cartIndex in carts.indices {
                if carts[cartIndex].hasFinished { continue }
                if carts[cartIndex].id == drop.ownerID, drop.armTime > 0 { continue }
                if carts[cartIndex].isInvincible || carts[cartIndex].autopilotTimer > 0 { continue }
                let reach = carts[cartIndex].collisionRadius * 0.8 + drop.radius
                guard carts[cartIndex].position.distance(to: drop.position) < reach else { continue }

                switch drop.kind {
                case .milkSpill:
                    // Milk does not stop you, it just takes the wheel.
                    carts[cartIndex].spinOut(direction: carts[cartIndex].slipAngle >= 0 ? 1 : -1, duration: 1.25)
                case .wetFloorSign:
                    carts[cartIndex].spinOut(direction: carts[cartIndex].heading >= 0 ? 1 : -1, duration: 0.9)
                default:
                    break
                }
                events.append(.cartHit(cartID: carts[cartIndex].id, by: drop.kind, sourceID: drop.ownerID))
                triggered = true
                break
            }

            if triggered {
                drops.remove(at: index)
                continue
            }
            index += 1
        }
    }
}
