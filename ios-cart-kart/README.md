# StoreCartKart (iOS prototype)

This folder contains a playable iOS SpriteKit prototype inspired by arcade kart racers, set inside a supermarket with abandoned shopping carts as racers.

## What is implemented

- Top-down kart movement with acceleration, braking, and steering
- 3 AI rival carts that follow store-lane waypoints
- 3-lap race loop with win/lose detection
- Store-themed track with shelf obstacles and wall collisions
- Camera follow and HUD (lap + speed + messages)
- Touch controls:
  - Left half of the screen: steering
  - Right half of the screen: throttle/brake (up = accelerate, down = brake/reverse)

## Open and run

1. Open `ios-cart-kart` in Xcode 15+.
2. Update `teamIdentifier` in `Package.swift` to your Apple Development Team ID.
3. Select an iOS simulator or connected device.
4. Run the app.

## Notes

- The app uses a Swift Package app manifest (`.iOSApplication`) instead of a traditional `.xcodeproj`.
- `AppIcon` is currently a placeholder entry; add your own icon image in `Assets.xcassets` if needed.
