# Midnight Cart Rally

A dependency-free, top-down shopping-cart racing game built for desktop and
mobile browsers. Race three laps through a closed store, dodge aisle hazards,
collect boost, and compete against three AI carts.

## Play locally

```sh
npm start
```

Open <http://localhost:8000>. Use WASD or the arrow keys to steer and accelerate;
press Space to boost. Touch controls appear automatically on mobile devices.

## iPhone installation

Open the game in Safari, rotate to landscape, then choose **Share → Add to Home
Screen**. The PWA manifest, standalone display mode, safe-area layout, and
offline cache are included.

## Build and test

```sh
npm test
npm run build
```

The production build is written to `public/` for Netlify deployment.

## Game structure

- `game.js` — race simulation, cart physics, AI, input, audio, and canvas renderer
- `game.css` — responsive game shell, HUD, menus, and touch controls
- `index.html` — accessible UI and PWA metadata
- `service-worker.js` — offline asset cache
