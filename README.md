# Cart Crashers: After Hours

A mobile-first arcade racer where runaway shopping carts compete through a supermarket after closing.

## Play

```sh
npm install
npm run dev
```

Open the local URL in a landscape browser. The game is optimized for iPhone and iPad, including safe-area spacing, touch controls, audio, and haptic feedback.

## Controls

- Touch the left and right buttons to steer.
- Hold **Drift** while steering to charge another boost.
- Tap **Boost** to spend a turbo can.
- Keyboard: <kbd>A</kbd>/<kbd>D</kbd> or arrow keys to steer, <kbd>Space</kbd> to drift, and <kbd>B</kbd> to boost.

## Build

```sh
npm run check
npm run build
```

The production site is generated in `dist/`. Netlify is configured to publish that directory.
