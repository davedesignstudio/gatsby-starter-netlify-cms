# Aisle Rush

A fast, mobile-first arcade racer where runaway shopping carts tear through a supermarket after closing time.

## Play locally

```bash
npm start
```

Open `http://localhost:3000`. Use <kbd>←</kbd>/<kbd>→</kbd> or <kbd>A</kbd>/<kbd>D</kbd> to steer and hold <kbd>Space</kbd>, <kbd>W</kbd>, or <kbd>↑</kbd> to boost. Touch controls appear automatically on mobile devices.

## Build

```bash
npm run build
npm run serve
```

The dependency-free build is written to `public/` and can be hosted on any static web server.

## Game features

- Six-cart, three-lap races with adaptive rivals
- Boost pickups, obstacles, collisions, and shelf-edge penalties
- Procedurally drawn supermarket, carts, products, and effects
- Keyboard and multitouch controls
- Generated arcade audio with mute and pause controls
- Responsive HUD and installable iOS web-app metadata
