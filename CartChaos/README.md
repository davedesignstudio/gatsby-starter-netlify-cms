# Cart Chaos

**Rogue shopping carts. Midnight at MegaMart. Winner takes the parking lot.**

A Mario Kart–style arcade racer for iOS where abandoned shopping carts tear through supermarket aisles, launch soup cans, and drift around spilled milk.

## Requirements

- macOS with Xcode 15+
- iOS 16+ Simulator or device

## Open & Run

1. Open `CartChaos.xcodeproj` in Xcode
2. Select an iPhone simulator (or your device)
3. Press **Run** (⌘R)

## How to Play

| Control | Action |
|--------|--------|
| Left / Right buttons (or tilt) | Steer |
| Hold **GAS** | Accelerate |
| **ITEM** | Use held power-up |
| **BRAKE** | Slow down / reverse slightly |

### Power-ups

- **Banana Peel** — Drop a hazard that spins rivals
- **Soda Boost** — Temporary speed surge
- **Soup Can** — Fire a projectile ahead
- **Coupon** — Brief shield against hits

### Racers

Pick a cart personality before the race: Rusty Rex, Coupon Queen, Dumpster Dan, Aisle Ace, and more.

## Project Layout

```
CartChaos/
├── CartChaosApp.swift          # App entry
├── ContentView.swift           # SwiftUI ↔ SpriteKit host
├── Game/
│   ├── MenuScene.swift
│   ├── CharacterSelectScene.swift
│   ├── GameScene.swift         # Main race loop
│   ├── ResultsScene.swift
│   ├── CartNode.swift
│   ├── TrackBuilder.swift
│   ├── PowerUpSystem.swift
│   ├── AIController.swift
│   └── Models.swift
└── Resources/
```

## Web Demo

A touch-friendly HTML5 prototype lives at [`../cart-chaos/`](../cart-chaos/) — open `index.html` on an iPhone for a quick taste of the same fantasy.
