# Aisle Rally

A fast, friendly shopping-cart racing game designed for iPhone and desktop browsers. Race two laps through Midnight Market, collect power-ups, and compete against three community racers.

The cast includes neighbors navigating housing insecurity, portrayed as named people with skills, goals, and agency. Housing status is never the joke or the game mechanic.

## Play locally

Requires Node.js 18 or newer.

```sh
npm start
```

Open `http://localhost:8000`. On iPhone, rotate to landscape and use Safari’s **Add to Home Screen** action for a full-screen, app-like experience.

## Controls

| Action | Touch | Keyboard |
| --- | --- | --- |
| Accelerate | Hold **GO** | <kbd>↑</kbd> or <kbd>W</kbd> |
| Steer | Hold left/right | <kbd>←</kbd>/<kbd>→</kbd> or <kbd>A</kbd>/<kbd>D</kbd> |
| Power-up | Tap **USE** | <kbd>Space</kbd> or <kbd>Shift</kbd> |
| Pause | Pause button | <kbd>Esc</kbd> |

## Development

```sh
npm test    # game-logic tests
npm build   # production assets in public/
npm check   # tests and build
```

The game is dependency-free and uses Canvas 2D, touch/pointer controls, Web Audio, and a service worker for offline play.
