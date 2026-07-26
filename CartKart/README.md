# Cart Kart: Aisle Rush 🛒

A Mario Kart–style arcade racer for iOS where **runaway shopping carts** tear
through a supermarket. Grab items off the shelves, sling canned goods at your
rivals, leave puddles of spilled milk in your wake, and be first to the checkout.

Built with **Swift + SpriteKit**. Every visual is drawn procedurally with
SpriteKit shape/sprite nodes, so the game ships with **zero binary art assets**.

> Theme note: the concept is framed as *abandoned / runaway* shopping carts
> racing through a store, keeping the fun kart-racing spirit without punching down.

## Gameplay

- **3 laps** around a store course against **3 AI opponents**.
- **Top-down kart physics**: momentum, drag, off-track slowdown (drive on the
  polished aisle, not the shelves) and speed boosts.
- **Item boxes** grant a random power-up:
  - ⚡️ **Energy Drink** — instant speed boost.
  - 🥛 **Spilled Milk** — drops a slick behind you; anyone who touches it spins out.
  - 🥫 **Canned Goods** — launched forward to bonk the racer ahead.
- Live **standings, lap counter and lap timer**, a **3‑2‑1‑GO** countdown, and a
  results screen with finishing times.

## Controls

Landscape orientation.

- **◀ / ▶** (bottom-left) — steer. The cart auto-accelerates.
- **USE** (bottom-right) — deploy the item currently in your slot.

## Project layout

```
CartKart/
├── CartKart.xcodeproj/        # Ready-to-open Xcode project (+ shared scheme)
├── project.yml                # XcodeGen spec (fallback / regeneration)
└── CartKart/
    ├── AppDelegate.swift          # App entry (programmatic window, no storyboards)
    ├── GameViewController.swift    # Hosts the SKView, boots the menu
    ├── Info.plist
    ├── Assets.xcassets/
    ├── GameConfig.swift            # All balancing/tuning constants
    ├── MathUtils.swift             # Vector & angle helpers
    ├── Track.swift                 # Course geometry, on/off-track test, rendering
    ├── Cart.swift                  # Racer entity: physics, laps, AI driving
    ├── Item.swift                  # Power-up types + node factory
    ├── RaceResult.swift            # Standings model, roster, time formatting
    ├── MenuScene.swift             # Title screen
    ├── GameScene.swift             # The race: camera, HUD, items, race flow
    └── ResultsScene.swift          # Post-race standings
```

## Build & run

Requires **macOS with Xcode 15+** (SpriteKit/UIKit are Apple-only — the project
cannot be compiled on Linux).

1. Open `CartKart/CartKart.xcodeproj` in Xcode.
2. Select the **CartKart** scheme and an iPhone/iPad simulator (or a device).
3. Press **Run** (⌘R).

Deployment target: iOS 15.0. Universal (iPhone + iPad).

### Fallback: regenerate the project with XcodeGen

If the checked-in `.xcodeproj` ever gets out of sync, you can regenerate it:

```bash
brew install xcodegen
cd CartKart
xcodegen generate
```

## Tuning

Want a wilder race? Almost all feel is controlled from `GameConfig.swift` —
top speeds, acceleration, turn rate, boost strength, spin-out duration, number
of laps and racers, and the world/track dimensions.
