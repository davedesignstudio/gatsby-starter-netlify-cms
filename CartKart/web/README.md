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

### Touch (mobile)
- **Left joystick** — steer
- **GO** — accelerate
- **DRIFT** — slide around corners
- **ITEM** — use power-up

### Menu
Click option rows to cycle settings, then **START RACE**.

## Features

- 6 tracks (Grocery, Frozen, Produce, Bakery, Liquor, Midnight Shift)
- 5 characters with unique stats
- Cup mode (3 championships)
- 3-lap races with AI opponents
- Power-ups: banana peel, coupon boost, spilled milk, can pyramid
- Procedural Web Audio sound effects
- Responsive canvas (desktop + mobile)

## Tech

- HTML5 Canvas
- Vanilla ES modules (no build step)
- Web Audio API

## Files

```
web/
├── index.html
├── css/style.css
└── js/
    ├── main.js       Entry point
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
