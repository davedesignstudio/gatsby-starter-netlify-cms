import Foundation

/// Internal hooks that let the test suite set up specific race situations
/// (an item in a slot, a spill on the floor) without waiting for one to occur
/// naturally. Not visible outside the module.
extension RaceEngine {
    func setKartForTesting(at index: Int, _ mutate: (inout KartState) -> Void) {
        guard karts.indices.contains(index) else { return }
        var kart = karts[index]
        mutate(&kart)
        replaceKartForTesting(at: index, with: kart)
    }

    func spawnHazardForTesting(
        _ kind: DroppedHazard.Kind,
        at position: Vec2,
        radius: Double,
        owner: Int?,
        life: Double = 20
    ) {
        appendHazardForTesting(
            DroppedHazard(
                id: -(hazards.count + 1),
                kind: kind,
                position: position,
                radius: radius,
                ownerID: owner,
                remainingLife: life,
                ownerGrace: 0.9
            )
        )
    }
}
