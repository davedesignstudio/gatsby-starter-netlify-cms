# Aisle Kart

**Stray shopping carts. One MegaMart. No mercy.**

A Mario Kart–style top-down racer for iOS — you drive abandoned shopping carts through a chaotic supermarket. Drift the dairy aisle, snag mystery bags, and dump banana peels on rival carts before they beat you to checkout.

## Requirements

- macOS with Xcode 15+
- iOS 16+ simulator or device

## Open & Run

1. Open `AisleKart.xcodeproj` in Xcode
2. Select an iPhone simulator (or your device)
3. Press **Run** (⌘R)

## Controls

| Input | Action |
|-------|--------|
| Left half of screen | Steer left |
| Right half of screen | Steer right |
| Bottom boost button | Turbo (when charged) |
| Item button | Use held power-up |

On devices with a gyroscope, tilt steering is also enabled (can be toggled in the pause menu).

## Gameplay

- **3 laps** around MegaMart’s main loop
- **4 carts** race (you + 3 AI)
- **Mystery bags** drop store-themed items:
  - 🍌 Banana peel — leave a slip trap
  - 🥫 Soda spray — slow the cart ahead
  - 🛡️ Cart shield — block one hit
  - ⚡ Express boost — short speed burst
  - 🦃 Frozen turkey — homing projectile

## Project layout

```
AisleKart/
├── AisleKart.xcodeproj
├── AisleKart/
│   ├── App/           # SwiftUI entry + SpriteKit host
│   ├── Game/          # Scenes, carts, AI, items, track
│   └── Resources/     # Colors, sounds placeholders
└── README.md
```

## Web demo

A browser playable version lives at `/aisle-kart-web/` in this repo — useful for quick playtesting without Xcode.
