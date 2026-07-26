# Cart Kart: Grocery Gauntlet

A Mario Kart-style arcade racer for iOS — race wobbly shopping carts through grocery store aisles.

## Features

### Racing
- Top-down 2D (SpriteKit) or 3D chase-camera (SceneKit) modes
- 6 tracks, 5 playable characters, 4 power-ups, 3-lap races
- Local 1–2 player and Game Center online multiplayer

### Tracks (6)
| Track | Theme |
|-------|-------|
| Grocery Gauntlet | Classic dairy loop |
| Frozen Fury | Icy freezer section |
| Produce Pit | Organic wet-floor sprint |
| Bakery Blitz | Flour-dusted aisles |
| Liquor Lane | Bottle-lined bends |
| Midnight Shift | Dark after-hours store |

### Characters (5)
Each rider has unique speed, acceleration, handling, and weight stats:
- Wobbly Will (balanced), Speedy Sal (fast), Drift King (cornering), Tank Tanya (heavy), Coupon Carla (accel)

### Cup Mode
- **Store Championship** — Grocery, Frozen, Produce
- **Night Shift Cup** — Bakery, Liquor, Midnight
- **Grand Aisle Prix** — all 6 tracks

### Audio
Bundled WAV assets: cart squeaks, collisions, boosts, countdown, race theme loop, and aisle ambience.

### Online
Game Center authentication + matchmaking with live position sync between players.

### 3D Enhancements
Detailed cart models (chassis, basket, handle, wheels), dust/spark particles, dynamic track lighting, and spotlights on the midnight track.

## Requirements
- Xcode 15+, iOS 16+, iPhone (portrait)
- Game Center enabled on device/simulator for online play
- Apple Developer account with Game Center capability for device testing

## Getting Started
1. Open `CartKart/CartKart.xcodeproj` in Xcode on macOS
2. Enable Game Center capability in Signing & Capabilities if testing online
3. Select iPhone simulator or device, press Run (⌘R)
4. On the menu, configure mode, characters, cup/track, players, and graphics

## Menu Options
| Row | Cycles through |
|-----|----------------|
| Mode | Quick Race / Cup Mode |
| P1 / P2 | Character select |
| Cup | Championship cup (Cup Mode only) |
| Track | Individual track (Quick Race only) |
| Players | 1P / 2P / Online |
| Graphics | 2D Classic / 3D Aisles |

**START RACE** — begin local or cup race  
**FIND ONLINE MATCH** — Game Center matchmaking

## Project Structure
```
CartKart/
├── App/           SwiftUI entry + mode switching
├── Scenes/        Menu, race, results, cup results
├── SceneKit/      3D renderer, cart models, lighting
├── Entities/      Cart physics + visuals
├── Models/        Tracks, characters, cups, settings
├── Systems/       Input, AI, audio, Game Center
└── Sounds/        WAV audio assets
```

## License
MIT — see repository root `LICENSE`.
