# Cart Chaos

**Cart Chaos** is a Mario Kart-style iOS racing game built with SwiftUI and SpriteKit. Race beat-up shopping carts through a grocery store — drift around aisles, collect power-ups, and be the first to complete 3 laps!

## Features

- **Top-down kart racing** with drift mechanics and touch controls
- **Store-themed track** with aisles, shelves, product displays, and checkout lanes
- **4 racers** — you plus 3 AI opponents (Rusty, Wobbly, and Lucky)
- **Power-ups** themed for the grocery store:
  - **Coupon Boost** — temporary speed burst
  - **Paper Bag Shield** — blocks one hit
  - **Wet Floor Sign** — drops a hazard behind you
  - **Spilled Soda** — leaves a slippery puddle
- **3-lap races** with live position and lap tracking
- **Procedural graphics** — no external art assets required

## Requirements

- Xcode 15+
- iOS 16.0+
- iPhone or iPad

## Getting Started

1. Open `CartChaos/CartChaos.xcodeproj` in Xcode on a Mac
2. Select your development team in **Signing & Capabilities**
3. Choose an iPhone simulator or connected device
4. Press **Run** (⌘R)

## Controls

| Input | Action |
|-------|--------|
| Left side of screen (drag) | Steer left/right |
| Right side — upper area | Accelerate |
| Right side — lower area | Brake |
| **USE ITEM** button | Deploy collected power-up |

## Project Structure

```
CartChaos/
├── CartChaos.xcodeproj
└── CartChaos/
    ├── App/                  # SwiftUI entry point
    ├── Game/
    │   ├── Scenes/           # Menu, Race, Game Over
    │   ├── Entities/         # Shopping carts & AI
    │   ├── Systems/          # Race & power-up logic
    │   ├── Track/            # Store track builder
    │   └── Models/           # Data types
    ├── Assets.xcassets
    └── Info.plist
```

## Gameplay Tips

- Drift on the right edge of the gas zone for tighter cornering at speed
- Grab power-ups from glowing icons around the track
- Use **Wet Floor** and **Spilled Soda** to slow down carts behind you
- Save **Paper Bag Shield** for when you're about to hit a hazard

## License

MIT
