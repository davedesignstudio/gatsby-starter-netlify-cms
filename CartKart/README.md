# Cart Kart

**Cart Kart** is a Mario Kart-style arcade racer for iOS where you race shopping carts through supermarket aisles. Drift around corners, grab power-ups from item boxes, and beat three AI opponents across three laps to reach the checkout first.

## Features

- **3 store tracks**: Aisle 7 Speedway, Frozen Foods Loop, and Checkout Chaos
- **4 racers**: You plus Cart Carl, Bag Lady Barb, and Dumpster Dan
- **Kart-style controls**: Left thumb to steer, right thumb for gas/brake
- **Drift boost**: Hold a drift through corners to earn a speed burst
- **Power-ups**:
  - Coffee Boost — temporary speed increase
  - Banana Peel — slip up rivals
  - Cardboard Box — slow down opponents
  - Coupon Shield — block one hit
- **Track hazards**: Spilled liquid patches and green boost pads
- **Full race loop**: 3-lap races with live position, speed, and results screen

## Requirements

- Xcode 15+
- iOS 17.0+
- iPhone or iPad

## Getting Started

1. Open `CartKart/CartKart.xcodeproj` in Xcode
2. Select your development team under Signing & Capabilities
3. Choose an iOS Simulator or connected device
4. Press **Run** (⌘R)

## How to Play

1. Pick a track from the main menu
2. Tap **START RACE**
3. Wait for the countdown, then race
4. **Left side of screen** — drag left/right to steer
5. **Right side of screen** — drag up to accelerate, down to brake
6. Drift through tight corners (steer hard while accelerating) for a boost
7. Drive through yellow **?** boxes to collect items; tap the right side while holding an item to use it
8. Complete 3 laps and cross the checkout line first to win

## Project Structure

```
CartKart/
├── CartKart.xcodeproj/
└── CartKart/
    ├── CartKartApp.swift          # App entry point
    ├── Views/
    │   ├── ContentView.swift      # Main menu
    │   ├── GameContainerView.swift
    │   └── HUDView.swift          # In-game overlay
    └── Game/
        ├── RacingGameScene.swift  # Main SpriteKit scene
        ├── PhysicsCategory.swift
        ├── Entities/
        │   ├── ShoppingCart.swift # Player & AI carts
        │   ├── TrackBuilder.swift # Procedural store tracks
        │   ├── ItemBoxNode.swift
        │   ├── ProjectileNode.swift
        │   └── RaceItem.swift
        └── Managers/
            └── GameState.swift
```

## Tech Stack

- **SwiftUI** for menus and HUD
- **SpriteKit** for 2D racing physics and rendering
- Programmatic art (no external assets required)

## License

MIT
