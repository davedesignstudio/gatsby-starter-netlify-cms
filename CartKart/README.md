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
Procedural SceneKit assets (no external model files):

**Shopping cart** — wire-frame basket packed with realistic belongings across 8 categories: bedding (blankets, sleeping bags, pillows), clothing (jackets, spare shoes), weather protection (tarps, plastic sheeting, umbrellas), bags/containers, recyclables (cans/bottles), water/food, hygiene items, and cardboard (sheets/signs). Exterior attachments include draped tarps and hanging bags.

**Power-up 3D models** — banana peel, coupon tag, milk carton, can pyramid

**Track props** — 3D product boxes on shelves, spinning `?` item crates, deployed hazards (banana peel, milk puddle, can stack)

Dynamic track lighting and spotlights on the midnight track.

## Requirements
- Xcode 15+, iOS 16+, iPhone (portrait)
- Game Center enabled on device/simulator for online play
- Apple Developer account with Game Center capability for device testing

## Getting Started
1. Open `CartKart/CartKart.xcodeproj` in Xcode on macOS
2. Enable Game Center capability in Signing & Capabilities if testing online
3. Select iPhone simulator or device, press Run (⌘R)
4. On the menu, configure mode, characters, cup/track, players, and graphics

### Build from terminal (macOS)
```bash
cd CartKart
./scripts/build-ios.sh
```

GitHub Actions runs the same simulator build on every push to `CartKart/`.

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
├── SceneKit/      3D renderer, Item3DModels, cart models, lighting
├── Entities/      Cart physics + visuals
├── Models/        Tracks, characters, cups, settings
├── Systems/       Input, AI, audio, Game Center
└── Sounds/        WAV audio assets
```

## License
MIT — see repository root `LICENSE`.
