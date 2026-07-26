# Cart Crashers

An original, iPhone-first shopping-cart racing game set in an after-hours grocery store. The game is a lightweight HTML5 Canvas PWA: open it in Safari, add it to the Home Screen, and play in portrait mode.

## Play

```sh
npm start
```

Then open the local URL on a phone or desktop browser. Use the on-screen controls on touch devices, or arrow/A-D keys to steer and Space/Shift to drift.

## Game features

- Six-cart race with adaptive AI and three tracked laps
- Arcade steering, off-track slowdown, drift charging, and release-to-boost
- Express-lane pickups, race positions, lap timing, and finish receipts
- Responsive portrait UI with iPhone safe-area support
- Installable PWA and offline game assets
- No third-party runtime game libraries or borrowed game assets

## Development

```sh
npm test
npm run build
```

The production build is emitted to `public/` for Netlify. Core track geometry and race display helpers have Node-based unit coverage.
