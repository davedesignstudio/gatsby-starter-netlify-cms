# Cart Kart: Grocery Gauntlet

A Mario Kart-style arcade racer for iOS where you pilot wobbly shopping carts through chaotic grocery store aisles.

![Cart Kart](docs/preview.svg)

## Gameplay

Race against AI cart riders on store-floor tracks lined with shelves, item boxes, and tight corners. Complete **3 laps** by hitting each checkpoint around the aisles.

### Tracks

| Track | Theme |
|-------|-------|
| **Grocery Gauntlet** | Classic dairy-loop aisles |
| **Frozen Fury** | Icy freezer section with wider corners |
| **Produce Pit** | Organic section with a tighter inner island |

### Modes

- **1 Player** — You vs 3 AI carts
- **2 Players** — Local multiplayer on one device (P1 left controls, P2 right controls)
- **2D Classic** — Top-down SpriteKit racing
- **3D Aisles** — SceneKit camera behind the carts

### Controls

| Input | Action |
|-------|--------|
| Virtual joystick | Steer |
| **GO** button | Accelerate |
| **DRIFT** button | Slide around corners |
| **ITEM** button | Use collected power-up |

In **2-player mode**, Player 1 uses the left stick + right buttons; Player 2 uses the right stick + left buttons.

### Power-ups

- **Banana Peel** — Drop a hazard behind you
- **Coupon Boost** — Short speed burst
- **Spilled Milk** — Leave a slippery puddle
- **Can Pyramid** — Stun nearby rivals

### Sound

Procedural sound effects (no external audio files) for countdown, boosts, items, collisions, lap complete, and race finish.

## Requirements

- Xcode 15+
- iOS 16.0+
- iPhone (portrait)

## Getting Started

1. Open `CartKart.xcodeproj` in Xcode on macOS.
2. Select an iPhone simulator or connected device.
3. On the main menu, tap options to cycle **track**, **players**, and **graphics** mode.
4. Press **START RACE** (⌘R).

## Project Structure

```
CartKart/
├── App/                 # SwiftUI entry + mode switching
├── Scenes/              # Menu, 2D race, and results scenes
├── SceneKit/            # 3D race renderer + controller
├── Entities/            # Cart racer physics + visuals
├── Models/              # Tracks, settings, power-ups
├── Systems/             # Touch input, AI, procedural audio
└── Assets.xcassets/     # App icon and launch color
```

## Built With

- **SpriteKit** — 2D rendering, physics, and HUD
- **SceneKit** — 3D aisle racing mode
- **SwiftUI** — App lifecycle and view composition
- **AVAudioEngine** — Procedural sound effects

## License

MIT — see repository root `LICENSE`.
