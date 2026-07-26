# 🛒💨 Grocery Grand Prix

A **Mario-Kart-style** arcade racer for iOS where you race **shopping carts** around a
supermarket. Drift down the aisles, grab item boxes, and fling cans at your rivals to
take the checkered flag. Built with **SwiftUI + SpriteKit**, no external dependencies.

> Theme note: this is a light-hearted "runaway shopping cart" kart racer set inside a
> grocery store. The player and CPU racers are carts driven around the aisles.

## Gameplay

- **3 laps** around a rounded supermarket loop with a shelf island in the middle.
- **4 racers**: you (red cart) versus 3 CPU carts with waypoint-following AI.
- **Auto-accelerate** — you focus on steering, drifting, and items.
- **Drift boost**: hold `DRIFT` while turning to charge a mini-turbo, then let go.
- **Item boxes** (🛒) scattered around the track grant a random power-up:
  - 🥤 **Turbo Cola** — instant speed boost.
  - 🥛 **Spilled Milk** — drop a slick behind you; the next cart to hit it spins out.
  - 🥫 **Canned Goods** — launch a can forward; the first cart it hits spins out.
- **Live HUD**: lap, position, lap time, and speedometer.
- **Results screen** with standings, your finish time, and a saved best time.

## Controls (on-screen, landscape)

| Button | Action |
| --- | --- |
| ◀ / ▶ | Steer left / right (auto-accelerate) |
| DRIFT | Hold in a turn to charge a mini-boost |
| BRAKE | Slow down / reverse |
| ITEM / USE | Use your currently held item |

## Requirements

- **Xcode 15** or newer
- **iOS 16.0+** device or Simulator
- Landscape orientation (locked)

## Build & Run

1. Open the project:
   ```bash
   open GroceryGrandPrix/GroceryGrandPrix.xcodeproj
   ```
2. Select the **GroceryGrandPrix** scheme and an iPhone/iPad simulator (or a device).
3. Press **⌘R** to build and run.

Or from the command line:

```bash
cd GroceryGrandPrix
xcodebuild -project GroceryGrandPrix.xcodeproj \
  -scheme GroceryGrandPrix \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

> The project is fully code/vector driven — all carts, track, and items are drawn with
> `SKShapeNode`/`SKLabelNode`, so there are no binary art assets to manage. The app icon
> slot is intentionally left empty (Xcode will show a placeholder warning only).

## Project structure

```
GroceryGrandPrix/
├── GroceryGrandPrix.xcodeproj      # Xcode project
└── GroceryGrandPrix/
    ├── GroceryGrandPrixApp.swift   # @main SwiftUI app entry
    ├── ContentView.swift           # Hosts the SpriteView + SwiftUI overlays
    ├── GameState.swift             # ObservableObject bridge + items/results/phase
    ├── GameScene.swift             # Core SpriteKit scene: loop, physics, AI, laps
    ├── Cart.swift                  # Shopping-cart racer node + arcade movement
    ├── Track.swift                 # Track geometry, walls, waypoints, decor
    ├── Item.swift                  # Item boxes, milk slicks, can projectiles
    ├── GameViews.swift             # Menu, HUD, controls, results (SwiftUI)
    ├── Theme.swift                 # Colors, math helpers, physics categories, haptics
    └── Assets.xcassets             # Accent color + (empty) app icon slot
```

## How it works (brief)

- **Movement** uses a lightweight arcade model (heading + speed) that drives each cart's
  physics-body velocity, so wall and cart collisions are resolved by SpriteKit.
- **Track** is a rounded-rectangle "aisle" ring bounded by inner/outer wall edge loops,
  with a uniformly resampled centreline used as **waypoints**.
- **Laps & position** are tracked by advancing each cart through the waypoint loop using a
  perpendicular-plane crossing test, producing a monotonic progress score used for ranking.
- **AI** steers toward a look-ahead waypoint (with a per-cart racing-line offset) and uses
  items on a randomized cooldown.
