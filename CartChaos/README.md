# Cart Chaos 🛒

**A Mario Kart-style racing game for iOS — with homeless shopping carts in a grocery store!**

Race shopping carts through the aisles of Super Save Mart. Drift around corners, grab power-ups from item boxes, and beat three AI opponents to the finish line.

## Features

- **Top-down kart racing** built with SpriteKit + SwiftUI
- **4 playable characters**, each with unique cart colors and stats:
  - Rusty Ron
  - Bag Lady Betty
  - Coupon Carl
  - Can Collector Clyde
- **Grocery store track** with aisles, shelves, tile floors, and boost pads
- **Mario Kart-style mechanics:**
  - Drift to build boost meter
  - Item boxes with random power-ups
  - 3-lap races with position tracking
- **5 power-up items:**
  - 🍌 Banana Peel — drop behind you to spin out rivals
  - 🥫 Can Missile — homing projectile
  - ⚡ Squeaky Boost — speed burst
  - 🛡️ Coupon Shield — blocks one hit
  - 🥛 Spilled Milk — slippery hazard puddle
- **AI opponents** with checkpoint navigation, collision avoidance, and item usage
- **Full UI flow:** main menu → countdown → race HUD → results screen

## Requirements

- Xcode 15+
- iOS 16.0+
- iPhone or iPad

## Getting Started

1. Open `CartChaos/CartChaos.xcodeproj` in Xcode
2. Select your development team in **Signing & Capabilities**
3. Choose an iPhone simulator or connected device
4. Press **⌘R** to build and run

## Controls

| Control | Action |
|---------|--------|
| **◀ Left half** | Steer left |
| **▶ Right half** | Steer right |
| **DRIFT button** | Hold to drift and charge boost |
| **Item button** | Tap to use collected power-up |

## Project Structure

```
CartChaos/
├── CartChaos.xcodeproj
└── CartChaos/
    ├── CartChaosApp.swift      # App entry point
    ├── ContentView.swift       # Root view / phase router
    ├── Models/
    │   ├── CharacterType.swift # Racer definitions
    │   └── ItemType.swift      # Power-up types
    ├── Game/
    │   ├── GameState.swift     # Observable game state
    │   ├── CartNode.swift      # Cart physics & visuals
    │   ├── TrackBuilder.swift  # Store track generation
    │   ├── AIDriver.swift      # AI steering logic
    │   ├── ItemSystem.swift    # Power-up handling
    │   ├── GameScene.swift     # Main SpriteKit scene
    │   └── GameView.swift      # SwiftUI + SpriteKit bridge
    └── UI/
        ├── MainMenuView.swift  # Character select & start
        ├── RaceHUDView.swift   # Position, lap, timer
        └── ResultsView.swift   # Finish standings
```

## License

MIT
