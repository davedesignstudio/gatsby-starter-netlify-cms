# Cart Dash: After Hours

An original, touch-first arcade racing game about a crew turning an empty supermarket into a shopping-cart circuit after closing.

## Play locally

```bash
npm start
```

Open <http://localhost:4173>. The game supports:

- iPhone and iPad touch controls
- Keyboard controls (`A`/`D` or arrow keys, hold `Shift` to drift)
- Three racers with different speed, grip, and boost characteristics
- Three-lap races against adaptive rivals
- Drift boosts, snack pickups, speed pickups, spills, collisions, and best times
- Offline play and iOS home-screen installation as a progressive web app

On iOS, open the deployed game in Safari and choose **Share → Add to Home Screen**. Landscape orientation is recommended for racing.

## Verify

```bash
npm run check
npm test
```

The game uses the browser Canvas and Web Audio APIs with no runtime dependencies.
