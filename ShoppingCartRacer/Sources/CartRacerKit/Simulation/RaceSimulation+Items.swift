import Foundation

// MARK: - Pickups, items and things in flight
extension RaceSimulation {
    func updatePickups(delta h: Double) {
        for boxIndex in itemBoxes.indices {
            if itemBoxes[boxIndex].cooldown > 0 {
                itemBoxes[boxIndex].cooldown = max(0, itemBoxes[boxIndex].cooldown - h)
                continue
            }
            let box = itemBoxes[boxIndex]
            for cartIndex in carts.indices {
                let cart = carts[cartIndex]
                // Holding an item means you drive straight past the crate.
                guard cart.heldItem == nil, !cart.hasFinished else { continue }
                let reach = box.spawn.radius + cart.tuning.radius
                guard cart.position.distance(to: box.position) < reach else { continue }

                let item = roulette.draw(
                    racePosition: cart.racePosition,
                    fieldSize: carts.count,
                    random: &random
                )
                carts[cartIndex].heldItem = item
                itemBoxes[boxIndex].cooldown = box.spawn.respawnDelay
                emit(.itemCollected(cartID: cart.id, item: item))
                break
            }
        }

        for tokenIndex in tokens.indices {
            if tokens[tokenIndex].cooldown > 0 {
                tokens[tokenIndex].cooldown = max(0, tokens[tokenIndex].cooldown - h)
                continue
            }
            let token = tokens[tokenIndex]
            for cartIndex in carts.indices {
                let cart = carts[cartIndex]
                guard !cart.hasFinished else { continue }
                let reach = token.spawn.radius + cart.tuning.radius
                guard cart.position.distance(to: token.position) < reach else { continue }

                if cart.tokens < tuning.maxTokens {
                    carts[cartIndex].tokens += 1
                }
                tokens[tokenIndex].cooldown = 9
                emit(.tokenCollected(cartID: cart.id, total: carts[cartIndex].tokens))
                break
            }
        }
    }

    /// Fires items on the rising edge of the button so holding it down does not
    /// empty the slot the instant it refills.
    func handleItemButtons() {
        for index in carts.indices {
            let cart = carts[index]
            let pressed = cart.lastInput.useItem
            let wasPressed = itemButtonDown[cart.id] ?? false
            itemButtonDown[cart.id] = pressed
            guard pressed, !wasPressed, let item = cart.heldItem, !cart.hasFinished else { continue }
            carts[index].heldItem = nil
            use(item: item, cartIndex: index)
            emit(.itemUsed(cartID: cart.id, item: item))
        }
    }

    private func use(item: ItemKind, cartIndex index: Int) {
        var cart = carts[index]
        switch item {
        case .energyDrink:
            applyBoost(&cart, duration: 1.7, strength: 1.35)
            carts[index] = cart

        case .sodaCan:
            let muzzle = cart.position + cart.forward * (cart.tuning.radius + 0.7)
            let speed = max(cart.forwardSpeed, 4) + tuning.projectileSpeed
            spawnProjectile(
                ownerID: cart.id,
                kind: .sodaCan,
                position: muzzle,
                velocity: cart.forward * speed
            )

        case .greaseSlick:
            let drop = cart.position - cart.forward * (cart.tuning.radius + 1.6)
            spawnHazard(ownerID: cart.id, kind: .greaseSlick, position: drop)

        case .crateShield:
            carts[index].shieldCharges = 3
            carts[index].shieldAngle = 0

        case .clearanceAnnouncement:
            let myPosition = cart.racePosition
            for other in carts.indices where carts[other].racePosition < myPosition {
                applyStall(cartIndex: other)
            }
            // A little kick for the announcer, too.
            applyBoost(to: index, duration: 0.6, strength: 1.1)

        case .expressLane:
            carts[index].expressLaneTimer = tuning.expressLaneDuration
            carts[index].shieldCharges = max(carts[index].shieldCharges, 0)
            carts[index].isDrifting = false
            carts[index].driftCharge = 0
        }
    }

    func spawnProjectile(ownerID: Int, kind: Projectile.Kind, position: Vector2, velocity: Vector2) {
        projectiles.append(
            Projectile(
                id: nextObjectID,
                ownerID: ownerID,
                kind: kind,
                position: position,
                velocity: velocity,
                lifetime: tuning.projectileLifetime,
                spin: random.nextDouble(in: -8...8)
            )
        )
        nextObjectID += 1
    }

    func spawnHazard(ownerID: Int, kind: Hazard.Kind, position: Vector2) {
        let location = geometry.location(of: position)
        hazards.append(
            Hazard(
                id: nextObjectID,
                ownerID: ownerID,
                kind: kind,
                position: position,
                lifetime: tuning.hazardLifetime,
                trackDistance: location.distance,
                trackLateral: location.lateral
            )
        )
        nextObjectID += 1
    }

    func updateProjectiles(delta h: Double) {
        var survivors: [Projectile] = []
        survivors.reserveCapacity(projectiles.count)

        for var projectile in projectiles {
            projectile.lifetime -= h
            projectile.ownerImmunity = max(0, projectile.ownerImmunity - h)
            guard projectile.lifetime > 0 else { continue }

            if projectile.kind.homingStrength > 0, let target = homingTarget(for: projectile) {
                let desired = (target.position - projectile.position).angle
                let current = projectile.velocity.angle
                let step = tuning.projectileHomingRate * projectile.kind.homingStrength * h
                let turn = Scalar.clamp(Scalar.angleDelta(from: current, to: desired), -step, step)
                projectile.velocity = projectile.velocity.rotated(by: turn)
            }

            projectile.position += projectile.velocity * h

            // Anything that leaves the building is gone.
            let location = geometry.location(of: projectile.position)
            if abs(location.lateral) > location.halfWidth + configuration.track.definition.shoulderWidth + 1 {
                continue
            }

            var consumed = false
            for index in carts.indices {
                let cart = carts[index]
                if cart.id == projectile.ownerID, projectile.ownerImmunity > 0 { continue }
                if cart.hasFinished { continue }
                let reach = cart.tuning.radius + projectile.kind.radius
                guard cart.position.distance(to: projectile.position) < reach else { continue }
                emit(.projectileHit(cartID: cart.id, position: projectile.position))
                applySpinout(cartIndex: index)
                consumed = true
                break
            }
            if consumed { continue }

            // Hard scenery stops a can dead.
            let hitScenery = configuration.track.definition.obstacles.contains { obstacle in
                !obstacle.kind.isSoft
                    && obstacle.position.distance(to: projectile.position) < obstacle.radius + projectile.kind.radius
            }
            if hitScenery { continue }

            survivors.append(projectile)
        }

        projectiles = survivors
    }

    /// The nearest cart ahead of the can, within a forward cone.
    private func homingTarget(for projectile: Projectile) -> CartState? {
        let heading = projectile.velocity.angle
        var best: CartState?
        var bestDistance = Double.infinity
        for cart in carts where cart.id != projectile.ownerID && !cart.hasFinished {
            let offset = cart.position - projectile.position
            let distance = offset.length
            guard distance < 45 else { continue }
            guard abs(Scalar.angleDelta(from: heading, to: offset.angle)) < 0.9 else { continue }
            if distance < bestDistance {
                bestDistance = distance
                best = cart
            }
        }
        return best
    }

    func updateHazards(delta h: Double) {
        var survivors: [Hazard] = []
        survivors.reserveCapacity(hazards.count)

        for var hazard in hazards {
            hazard.lifetime -= h
            hazard.maturity = min(1, hazard.maturity + h * 4)
            guard hazard.lifetime > 0 else { continue }

            var triggered = false
            for index in carts.indices {
                let cart = carts[index]
                guard !cart.hasFinished, cart.slipTimer <= 0 else { continue }
                // The dropper gets a moment to clear their own mess.
                if cart.id == hazard.ownerID, hazard.lifetime > tuning.hazardLifetime - 0.7 { continue }
                let reach = cart.tuning.radius + hazard.kind.radius * hazard.maturity
                guard cart.position.distance(to: hazard.position) < reach else { continue }
                applySlip(cartIndex: index, at: hazard.position)
                triggered = true
                break
            }

            // Grease is a one-shot: whoever finds it first wipes it up.
            if triggered, hazard.kind == .greaseSlick { continue }
            survivors.append(hazard)
        }

        hazards = survivors
    }
}
