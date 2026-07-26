# CartKart

**Homeless shopping-cart racers tearing through Mega Mart.**

An iOS Mario Kart–style top-down racer built with **SwiftUI + SpriteKit**. You drive a battered shopping cart around the Aisle Circuit, dodge shelves, grab store power-ups, and beat rival cart racers to the checkout.

## Requirements

- macOS with **Xcode 15+**
- iOS **16.0+** (iPhone or iPad)
- Apple Developer account optional for simulator; required for device

## Open & Run

1. Open `CartKart/CartKart.xcodeproj` in Xcode
2. Select an iPhone simulator (or a connected device)
3. Set your **Team** under Signing & Capabilities if deploying to a device
4. Press **Run** (⌘R)

## How to Play

| Control | Action |
|--------|--------|
| Left / right zones (or tap screen sides) | Steer |
| **BOOST** | Extra acceleration |
| **ITEM** | Use held power-up |

Race **3 laps** around Mega Mart. Finish ahead of Tinny, Squeaky, and Dumpster.

### Power-ups

| Item | Effect |
|------|--------|
| 🍌 Banana Peel | Drop a slip hazard behind you |
| 🥤 Soda Boost | Speed burst |
| 🥫 Canned Goods | Fire a projectile |
| 🛍️ Shopping Bag | Temporary shield |
| ⚠️ Wet Floor | Drop a slow zone |

## Project Layout

```
CartKart/
├── CartKart.xcodeproj
└── CartKart/
    ├── App/                 # SwiftUI entry + SpriteView host
    ├── Game/
    │   ├── Models/          # Profiles, physics categories, power-ups
    │   ├── Entities/        # Carts, track, items, hazards
    │   ├── Systems/         # AI racers
    │   ├── UI/              # Race HUD + touch controls
    │   └── Scenes/          # MenuScene, RaceScene
    ├── Resources/           # Asset catalog
    └── Info.plist
```

## Features

- Top-down supermarket circuit with aisle shelves and checkpoints
- Player cart (**Rusty**) plus 3 AI opponents with distinct handling
- Item boxes, offensive/defensive power-ups, shield, and slip physics
- Camera follow, minimap, lap/place HUD, countdown, finish results
- Portrait and landscape support

## Notes

Procedural SpriteKit shapes are used for carts, shelves, and UI so the project runs without external art packs. Swap in textures later under `Resources/Assets.xcassets` if you want custom cart skins.
