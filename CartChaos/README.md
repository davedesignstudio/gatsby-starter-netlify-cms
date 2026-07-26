# Cart Chaos: Aisle Racers

Mario Kart–style racing with rogue shopping carts tearing through MegaMart.

## What's included

| Path | Description |
|------|-------------|
| `CartChaos/` | Native **iOS SpriteKit** app (Swift) |
| `CartChaos.xcodeproj` | Xcode project — open this on a Mac |
| `WebDemo/` | Playable browser demo of the same game |

## How to run (iOS)

1. Open `CartChaos.xcodeproj` in Xcode 15+ on a Mac.
2. Select an iPhone / iPad simulator (landscape).
3. Set your Development Team under Signing if deploying to a device.
4. Press **Run**.

Requires **iOS 16+**. Orientation is locked to landscape.

## How to play the web demo

```bash
cd CartChaos/WebDemo
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

## Gameplay

- **3 laps** through Produce, Dairy, Frozen, Snacks, and Checkout
- **5 carts**: Rusty, Speedy, Jumbo, Zigzag, Glitter — each with different speed / handling
- **4 AI rivals** with light rubber-banding
- **Power-ups**
  - **Banana** — drop a peel behind you
  - **Spill** — leave a sticky mess
  - **Soda** — speed boost
  - **Soup** — fire a can forward
  - **Coupon** — temporary shield
- Touch controls on device; keyboard in the web demo (`A`/`D` or arrows, `Space` gas, `Shift` use item)

## Project layout (iOS)

```
CartChaos/
  AppDelegate.swift
  GameViewController.swift
  Models/          # CartRacer, StoreTrack, power-ups
  Art/CartArt.swift
  Scenes/          # MenuScene, GameScene, ResultsScene
  Assets.xcassets
  Base.lproj/
```

Pseudo-3D aisle rendering projects the linoleum floor, shelves, rivals, and items into a Mode-7-style perspective behind your cart.
