# Cart Dash — After Hours

A touch-first arcade racer set in a supermarket after closing. Race three AI
rivals, drift through the aisles, collect boost bags, and finish three laps.

## Run locally

```sh
npm start
```

Open `http://localhost:8000`. The game has no runtime dependencies.

## Controls

- Arrow keys or WASD — push and steer
- Space — drift
- Shift or E — use a collected boost
- Touch controls — built into the race screen

## Build and test

```sh
npm test
npm run build
```

The production build is written to `public/`. The included web app manifest and
service worker allow the game to run full-screen and offline after installation
to a phone's home screen.
