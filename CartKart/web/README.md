# Cart Kart — Web Edition

Play **Cart Kart: Grocery Gauntlet** in your browser. Race wobbly shopping carts through grocery store aisles — a web port of the iOS SpriteKit game.

## Play locally

```bash
cd CartKart/web
npx --yes serve .
```

Open http://localhost:3000 (or the URL shown).

Or use any static file server:

```bash
python3 -m http.server 8080 --directory CartKart/web
```

## Controls

### Keyboard
| Key | Action |
|-----|--------|
| WASD / Arrow keys | Steer |
| Space | Accelerate |
| Shift | Drift |
| E | Use item |

## Android / mobile

Cart Kart is optimized for Android phones and tablets:

- **Add to Home Screen** — open in Chrome, tap menu → "Install app" (PWA manifest included)
- **Landscape racing** — portrait shows a rotate hint; races lock to landscape when supported
- **Touch controls** — larger joystick and buttons with multi-touch support (hold GO + DRIFT)
- **Haptic feedback** — vibration on collisions, boosts, and finish line
- **Screen wake lock** — keeps the screen on during races
- **Safe areas** — respects notches and navigation bars
- **Performance** — capped pixel ratio on Android for smoother frame rates

### Touch (mobile)
- **Left joystick** — steer (push up to accelerate, down to brake)
- **GO** — accelerate
- **DRIFT** — slide around corners
- **ITEM** — use power-up
- **Tap menu rows** — change settings

### Menu
Click or tap option rows to cycle settings, then **START RACE**.

## Features

- 6 tracks (Grocery, Frozen, Produce, Bakery, Liquor, Midnight Shift)
- 5 characters with unique stats
- Cup mode (3 championships)
- 3-lap races with AI opponents
- Power-ups: banana peel, coupon boost, spilled milk, can pyramid
- Procedural Web Audio sound effects
- Responsive canvas (desktop + mobile + Android PWA)

## Tech

- HTML5 Canvas
- Vanilla ES modules (no build step)
- Web Audio API
- PWA manifest for Android install
- Screen Wake Lock + Vibration APIs

## Files

```
web/
├── index.html
├── manifest.json
├── icons/
├── css/style.css
└── js/
    ├── main.js       Entry point
    ├── platform.js   Mobile/Android detection & utilities
    ├── game.js       State machine (menu/race/results)
    ├── data.js       Tracks, characters, cups
    ├── racer.js      Cart physics
    ├── ai.js         AI driving
    ├── input.js      Keyboard + touch
    ├── renderer.js   Canvas drawing
    └── audio.js      Sound effects
```

## Deploy

Upload the `web/` folder to any static host (Netlify, GitHub Pages, Vercel, S3, etc.). No build required.

For GitHub Pages, set the publish directory to `CartKart/web`.
