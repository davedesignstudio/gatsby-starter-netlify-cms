# Aisle Rush

A touch-first, after-hours shopping-cart racing game for mobile browsers. Choose a cart, dodge aisle hazards, collect boost coupons, and race five rivals through three laps of a grocery store.

## Play locally

```sh
npm start
```

Open the address shown in the terminal. The game is designed for portrait orientation and works with:

- touch buttons on phones and tablets
- arrow keys or A/D to steer
- Arrow Up or Space to boost
- Escape to pause or resume

## Quality checks

```sh
npm test
npm run check
npm run build
```

The production build is written to `public/`. Netlify uses the same build command.

## iPhone installation

Open the deployed game in Safari, tap **Share**, then choose **Add to Home Screen**. The included web app manifest and service worker provide a standalone portrait experience and cache the game for offline play.

## Project layout

- `index.html` — game shell, HUD, menus, and touch controls
- `css/cart-racer.css` — responsive mobile presentation and safe-area support
- `js/cart-racer.js` — game loop, input, physics, drawing, rivals, and audio
- `js/game-core.js` — testable race utility functions
- `service-worker.js` — offline cache
- `scripts/build-static.js` — dependency-free production build
