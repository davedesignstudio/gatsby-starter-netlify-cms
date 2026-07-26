# Aisle Drifters: Cart Rush

A portrait, touch-first arcade racer set in a colorful after-hours supermarket. Race three rival carts across two laps, dodge aisle hazards, collect pantry goods, and spend pickups on boosts.

## Play locally

Requires Node.js 18 or newer.

```bash
npm start
```

Open `http://localhost:8000`. Use the on-screen arrows, swipe across the track, or press the left/right arrow keys to steer. Tap the yellow button, Space, or Arrow Up to boost.

## Validate and build

```bash
npm test
npm run build
npm run serve
```

The production site is written to `public/`. The game uses the Canvas 2D API and has no runtime JavaScript dependencies.
