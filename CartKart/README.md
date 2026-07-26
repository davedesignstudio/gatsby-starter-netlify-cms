# Cart Kart: Grocery Gauntlet

A Mario Kart-style arcade racer for iOS where you pilot wobbly shopping carts through chaotic grocery store aisles.

![Cart Kart](docs/preview.svg)

## Gameplay

Race against three AI cart riders on a store-floor track lined with shelves, item boxes, and tight corners. Complete **3 laps** by hitting each checkpoint around the aisles.

### Controls

| Input | Action |
|-------|--------|
| Virtual joystick (left) | Steer |
| **GO** button | Accelerate |
| **DRIFT** button | Slide around corners for tighter turns |
| **ITEM** button | Use collected power-up |

### Power-ups

- **Banana Peel** — Drop a hazard behind you
- **Coupon Boost** — Short speed burst
- **Spilled Milk** — Leave a slippery puddle
- **Can Pyramid** — Stun nearby rivals

### Racers

- **You** — Blue beanie, silver cart
- **Rusty Ron** — Veteran of the express lane
- **Cart Carl** — Green jacket, aggressive drifter
- **Wheels Wendy** — Purple cart, skilled AI

## Requirements

- Xcode 15+
- iOS 16.0+
- iPhone (portrait)

## Getting Started

1. Open `CartKart.xcodeproj` in Xcode on macOS.
2. Select an iPhone simulator or connected device.
3. Press **Run** (⌘R).

## Project Structure

```
CartKart/
├── App/                 # SwiftUI app entry + SpriteKit host
├── Scenes/              # Menu, race, and results scenes
├── Entities/            # Cart racer physics + visuals
├── Models/              # Track layout, power-ups, race state
├── Systems/             # Touch input and AI driving
└── Assets.xcassets/     # App icon and launch color
```

## Built With

- **SpriteKit** — 2D rendering, physics, and scene management
- **SwiftUI** — App lifecycle and `SpriteView` integration
- **GameplayKit**-style AI — Checkpoint-following opponents with item usage

## License

MIT — see repository root `LICENSE`.
