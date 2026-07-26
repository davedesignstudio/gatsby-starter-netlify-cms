# Cart Dash: Community Market Grand Prix

A native iPhone arcade racer built with Swift, UIKit, and SpriteKit. Race shopping carts around a colorful community market, drift through corners, collect turbo pickups, avoid spills, and beat three rival racers over three laps.

The original concept has been framed as upbeat shopping-cart racing without turning housing insecurity into a joke or costume.

## Play

1. Open `CartDash.xcodeproj` in Xcode 16 or newer.
2. Select the `CartDash` scheme and an iPhone simulator.
3. Press **Run**.

The game targets iOS 16 and later, uses only Apple frameworks, and has no external dependencies or asset downloads.

## Controls

- **◀ / ▶**: steer
- **DRIFT**: hold while steering; release after a long slide for a boost
- **⚡ pickup**: instant turbo
- Green spills slow carts down
- Follow the blue arrow and complete three laps

## Tests

Run the `CartDash` scheme's tests in Xcode with **Product → Test** (`⌘U`). Unit tests cover ordered checkpoints, lap completion, and drift-boost thresholds.

All visuals are generated with SpriteKit shapes, so the prototype is playable immediately and is easy to reskin with production art later.
