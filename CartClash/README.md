# Cart Clash

**Mario Kart–style shopping cart racing** through Mega Mart. Pick a street cart racer, drift the aisles, and beat rivals to the checkout.

Built with **SwiftUI + SpriteKit** for iPhone and iPad (landscape).

## Open in Xcode

1. On a Mac, open `CartClash/CartClash.xcodeproj`
2. Select an iPhone or iPad simulator (landscape works best)
3. Set your Team under Signing & Capabilities if running on a device
4. Press **Run** (⌘R)

Requires **Xcode 15+** and **iOS 16+**.

## How to play

| Control | Action |
|--------|--------|
| ◀ / ▶ buttons (or tap left/right lower screen) | Steer |
| Hold a turn at speed | Drift — release for a boost |
| **BRAKE** | Slow down for tight corners |
| **ITEM** | Use held power-up |
| Yellow `?` pads | Pick up a random item |

**3 laps** around Mega Mart. First to the final checkout wins.

## Racers

| Cart | Style |
|------|--------|
| Tin Can Terry | Top speed, aluminum rocket |
| Blanket Betty | Best handling, cozy drifts |
| Bottle Cap Bill | Balanced all-rounder |
| Dumpster Daisy | Finds boosts in the trash |
| Can Collector Carl | Stack height = horsepower |
| Shopping Bag Sam | Plastic wings, paper dreams |

## Items

- **Banana Peel** — drop behind you
- **Soda Splash** — forward projectile
- **Bean Turbo** — speed boost
- **Bag Shield** — block one hit
- **Homing List** — tracks the leader

## Project layout

```
CartClash/
├── CartClash.xcodeproj
├── README.md
└── CartClash/
    ├── CartClashApp.swift
    ├── GameContainerView.swift
    ├── Info.plist
    ├── Assets.xcassets
    └── Game/
        ├── GameModels.swift
        ├── CartNode.swift
        ├── TrackBuilder.swift
        ├── AIController.swift
        ├── ItemNodes.swift
        ├── RaceHUD.swift
        ├── MenuScene.swift
        ├── CharacterSelectScene.swift
        ├── GameScene.swift
        └── ResultsScene.swift
```

## Notes

- Graphics are procedural (no external art pack required)
- Track is a top-down supermarket loop with aisle shelves as walls
- AI opponents use checkpoint racing with light rivalry avoidance
