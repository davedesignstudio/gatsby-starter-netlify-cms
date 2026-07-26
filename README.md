# Cart Dash: Community Cup

A fast, colorful shopping-cart racer designed for iPhone and desktop browsers. The fictional
Community Cup puts local cart crews on a supermarket track to raise money for neighborhood
outreach.

## Play

```bash
npm start
```

Open `http://localhost:4173`. The game is best played in landscape.

- Touch: hold the left or right buttons to steer; tap the center button to use a power-up.
- Keyboard: use A/D or the arrow keys to steer and Space to use a power-up.
- Collect yellow item boxes, stay on the aisle, and finish three laps.

## Development

The game uses the Canvas 2D API and Web Audio with no runtime dependencies.

```bash
npm test
npm run build
```

The production build is written to `public/`. A web app manifest and service worker make the
game installable and available offline after its first load.
