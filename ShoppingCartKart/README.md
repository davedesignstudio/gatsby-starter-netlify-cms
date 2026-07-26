# Cart Chaos: Aisle Racers

A top-down, *Mario Kart*-style arcade racer for iOS where runaway **homeless
shopping carts** tear around the aisles of a grocery store — the **Mega-Mart
Grand Prix**. Built natively with **SwiftUI + SpriteKit** (no third-party
dependencies).

![top-down kart racing in a grocery store]

## Gameplay

- Race 6 shopping carts around a store circuit for **3 laps**.
- Your cart **auto-accelerates** — you just steer and use items.
- Grab **? boxes** for grocery-themed power-ups:
  - **Energy Drink** — a temporary speed boost.
  - **Spilled Milk** — dropped behind you; anyone who hits it spins out.
  - **Canned Beans** — hurled forward to spin out the cart ahead.
- Driving off the track (onto the store floor) slows you down.
- Live HUD shows your **lap**, **position**, and **held item**.
- Rubber-band AI keeps the pack close, and a results screen ranks everyone at
  the finish.

## Controls (on-screen, touch)

| Control | Action |
| --- | --- |
| ◀ / ▶ (bottom-left) | Steer left / right |
| USE (bottom-right) | Fire / drop your current item |

Multi-touch is supported, so you can steer and fire at the same time.

## Requirements

- Xcode 16 or newer
- iOS 16.0+ device or simulator (the project targets iPhone & iPad, landscape)

## Build & Run

```bash
open ShoppingCartKart/CartKart.xcodeproj
```

Select the **CartKart** scheme and an iOS Simulator (e.g. *iPhone 15*), then
press **Run** (⌘R). Or from the command line:

```bash
xcodebuild -project ShoppingCartKart/CartKart.xcodeproj \
           -scheme CartKart \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

## Project layout

```
ShoppingCartKart/
├── CartKart.xcodeproj          # Xcode project (file-system synchronized group)
└── CartKart/
    ├── CartKartApp.swift        # @main SwiftUI app entry point
    ├── ContentView.swift        # Menu, HUD overlay, results screen
    ├── GameState.swift          # Observable bridge between SpriteKit and SwiftUI
    ├── GameScene.swift          # All gameplay: track, AI, items, laps, controls
    ├── RaceModels.swift         # Track, Cart, items, hazards + vector math
    └── Assets.xcassets          # App icon / accent color
```

## Notes

The renderer is fully procedural (SpriteKit shape nodes), so no art assets are
required — the store, track, carts, groceries and power-ups are all drawn in
code. Drop in a `1024×1024` PNG at `Assets.xcassets/AppIcon.appiconset` to give
the app a home-screen icon.
