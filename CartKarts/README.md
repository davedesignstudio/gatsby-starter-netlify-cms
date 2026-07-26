# Cart Karts — Midnight at the MegaMart

A Mario Kart-style racing game for iOS where six runaway shopping carts race
through a supermarket after closing time. Built with Swift + SpriteKit.
**Every sprite is drawn procedurally in code** — there are no binary art
assets in the repo.

## The pitch

The MegaMart is closed. The carts are loose. Three laps around the store:
down the bottom straight, through the checkout-lane slalom, up past the dairy
wall, along the top corridor, then an S-curve weave through the grocery
aisles. Watch out for spilled milk.

## Running it

1. Open `CartKarts.xcodeproj` in Xcode 16 or newer.
2. Select the `CartKarts` scheme and any iPhone/iPad simulator (or a device —
   set your development team under Signing & Capabilities first).
3. Build and run. The game is landscape-only.

No dependencies, no packages, no asset pipeline — it should build straight
out of the box.

## How to play

| Control | Action |
| --- | --- |
| Touch and hold **left half** of the screen | Steer left |
| Touch and hold **right half** of the screen | Steer right |
| Tap the **round button** bottom-center | Use held item |

Acceleration is automatic. Hold a hard turn at speed to **drift** — keep it
held for a second and you'll earn a **mini-turbo** when you straighten out.

### Items (grab a mystery grocery bag)

- **Turbo Cola** — short speed boost.
- **Banana Peel** — dropped behind you; spins out whoever runs it over.
- **Soup Can** — fired forward; ricochets off shelving up to two times.

### Hazards

- **Spilled milk** — slick patches that kill your grip and send you wobbling.
- **Checkout counters, gondola shelving, pallet stacks** — solid. Ask Big
  Bertha how she knows.

## The racers

| Cart | Style |
| --- | --- |
| Rusty | Balanced. Squeaks with pride. |
| Squeaky | Cornering specialist, low top speed. |
| Big Bertha | Highest top speed, slow to push, heavy in collisions. |
| Lil' Zip | Best acceleration, lightweight. |
| Boss Hog | Speed-leaning bruiser. |
| Coupon Carl | Balanced all-rounder. |

Rivals are waypoint-driven AI with per-driver skill, racing-line bias,
corner braking, an un-stuck reverse maneuver, and gentle rubber-banding so
races stay close.

## Code tour

```
CartKarts/
├── App/            AppDelegate + GameViewController (SKView host, landscape lock)
├── Scenes/         MenuScene (cart select) and RaceScene (the race itself)
├── Game/
│   ├── Kart.swift          Arcade driving model: grip, drift, boost, spin-out, slip
│   ├── AIDriver.swift      Waypoint-chasing rival brain
│   ├── Track.swift         The MegaMart: geometry, racing line, item/hazard placement
│   ├── Items.swift         Item boxes, bananas, soup cans, milk puddles
│   ├── HUD.swift           Lap/position readout, touch controls, results panel
│   └── CartCharacter.swift The six-cart roster and their stats
├── Rendering/      TextureFactory — all art drawn with CoreGraphics at runtime
└── Support/        Math helpers, physics categories, seeded RNG
```

## Linux type check & track validation (no Mac required)

`LinuxTypeCheck/check.sh` lets you verify the game without Xcode, e.g. in CI
on Linux. It compiles minimal stub modules that mirror the exact
UIKit/SpriteKit API surface the game uses, then:

1. **Type-checks** every game source file against those stubs (catches syntax
   errors, type errors, and wrong API signatures).
2. **Validates the track geometry** — the racing line, item boxes, and
   starting grid must clear all shelving/counters/walls with kart-width
   margin.
3. **Runs a headless race simulation** — every cart in the roster is driven
   by the real `AIDriver` + `Kart` code for two full laps, and must finish
   without stalling or clipping solid geometry.

```bash
cd LinuxTypeCheck && ./check.sh
```

Requires any Swift 5.9+ toolchain on PATH ([swift.org](https://swift.org/download/)).

### Design notes

- Driving is a hybrid model: cart heading is steered directly and the physics
  velocity is rebuilt each frame from damped forward/lateral components, while
  SpriteKit's physics engine resolves collisions with walls and other carts.
- Laps and race positions are scored by ordered waypoint progression along the
  racing line, so wall-riding shortcuts don't count.
- No audio yet — a natural next step, along with more tracks (loading dock?
  garden center?) and a grand-prix points mode.
