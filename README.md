# Carts After Dark

A fast, top-down shopping cart racer built for iPhone, desktop, and gamepad. Four neighbors turn an after-hours community-pantry supply pickup into a three-lap race through a closed store.

The game treats housing instability as context, not a joke: the racers are named people with agency, the mood is joyful, and everyone succeeds in stocking the pantry regardless of finishing place.

## Play locally

```bash
npm start
```

Open <http://localhost:8000>. On iPhone, use Safari in landscape. Choose **Share → Add to Home Screen** to install the standalone web app.

## Controls

| Action | Keyboard | Touch | Gamepad |
| --- | --- | --- | --- |
| Accelerate | W / ↑ | Go! | Right trigger |
| Brake / reverse | S / ↓ | Brake | Left trigger |
| Steer | A/D or ←/→ | Arrow buttons | Left stick |
| Use boost | Space | Boost bag | A |
| Pause | P / Escape | Pause button | Menu |

## Features

- Four racers with distinct acceleration, handling, and boost characteristics
- Three-lap race against AI carts with live position tracking
- Cart-to-cart and store-boundary collisions
- Wet-floor hazards and collectible express-lane boosts
- Procedural sound, particles, speed effects, and race results
- Touch, keyboard, and gamepad input
- Landscape iPhone layout with safe-area support
- Installable, offline-capable PWA
- Reduced-motion and screen-reader status support

No runtime packages or external game engine are required.

## Verify

```bash
npm test
```

This checks JavaScript syntax, required assets, local references, PWA metadata, and input hooks.

With the local server running and Chrome installed, `npm run test:browser` also exercises racer
selection, the countdown, acceleration, and pause behavior in a real browser.
