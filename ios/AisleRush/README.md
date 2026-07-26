# Aisle Rush

Aisle Rush is an original, top-down iOS kart racer about runaway shopping carts tearing through a supermarket after closing time. It uses SpriteKit and UIKit with no third-party packages or external art assets.

## Play

1. Open `AisleRush.xcodeproj` in Xcode 16 or newer.
2. Select an iPhone or iPad simulator in landscape orientation.
3. Run the `AisleRush` scheme.

The carts accelerate automatically:

- Hold the left and right buttons to steer.
- Hold **DRIFT** for tighter cornering.
- Collect yellow coupon tokens for a speed boost.
- Avoid brown spills or the cart will spin.
- Complete three laps and beat the three AI carts to checkout.

## Included

- Procedurally drawn supermarket, carts, shelves, signs, pickups, and hazards
- Four-cart racing with waypoint-driven opponents
- Touch steering, drifting, boost trails, collisions, and haptics
- Ordered checkpoints, lap timing, race position, countdown, and replay flow
- Unit tests for lap and checkpoint progression

## Tests

From macOS with Xcode installed:

```sh
xcodebuild test \
  -project AisleRush.xcodeproj \
  -scheme AisleRush \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The project targets iOS 16 and later. Change the bundle identifier and development team in the target's Signing & Capabilities settings before installing on a physical device.
