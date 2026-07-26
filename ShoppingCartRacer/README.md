# Cart Aisle Rally

Cart Aisle Rally is a native iOS SpriteKit prototype: a top-down, kart-style race through a closed store where shopping carts dodge shelves, collect essentials, and sprint through checkout for three laps.

The theme is handled as playful arcade racing without copying Mario Kart names, characters, tracks, or assets. All game visuals are drawn with SpriteKit shapes, so there are no external art dependencies.

## Gameplay

- Race a blue shopping cart against three AI carts through store aisles.
- Complete 3 laps around the checkout track.
- Pick up:
  - `>` Boost tokens for a short speed burst.
  - `+` Supply tokens to increase the collected supplies score.
  - `*` Shield tokens to absorb one shelf bump.
- Shelves and aisle displays slow carts down or bounce them back.
- A finish banner appears after lap 3; tap anywhere to restart.

## Controls

- Touch the left or right side of the screen to steer.
- Touch the top half to accelerate.
- Touch the bottom half to brake/reverse.
- Device tilt adds subtle steering support on iPhone and iPad.

## Run in Xcode

1. Open `ShoppingCartRacer/ShoppingCartRacer.xcodeproj` in Xcode 15 or newer.
2. Select the `ShoppingCartRacer` target.
3. Pick an iPhone or iPad simulator.
4. Press Run.

The project targets iOS 16 and newer and is locked to landscape orientation for the racing layout.

## Main files

- `ShoppingCartRacer/App/ShoppingCartRacerApp.swift` - SwiftUI app entry point.
- `ShoppingCartRacer/Game/GameView.swift` - SwiftUI host for the SpriteKit scene.
- `ShoppingCartRacer/Game/GameScene.swift` - Store track, carts, AI, pickups, HUD, and controls.
- `ShoppingCartRacer/Resources/Info.plist` - iOS app metadata and orientation settings.
