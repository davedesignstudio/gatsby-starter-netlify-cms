# Cart Racers

Cart Racers is a small native iOS SpriteKit game prototype set in an after-hours grocery store. Players steer a shopping cart through store aisles, dodge spills and stock boxes, collect pantry pickups, and finish three laps before the cart runs out of durability.

The game is an original top-down cart racer prototype. It does not include third-party characters, tracks, brands, or assets.

## Gameplay

- Drag anywhere on the screen to steer the cart left or right.
- Avoid store hazards like spills, box stacks, and caution signs.
- Collect coupon boosts for temporary speed.
- Collect pantry pickups for score and cart durability.
- Finish three laps to complete the pantry run.
- Tap after winning or crashing to restart.

## Opening in Xcode

1. Open `ios/CartRacers/CartRacers.xcodeproj`.
2. Select an iPhone simulator.
3. Build and run the `CartRacers` scheme.

## Project layout

- `CartRacersApp.swift` - SwiftUI app entry point.
- `GameView.swift` - Hosts the SpriteKit scene.
- `GameScene.swift` - Game loop, spawning, collision, UI, and restart logic.
- `Assets.xcassets` - Placeholder asset catalog for Xcode.
