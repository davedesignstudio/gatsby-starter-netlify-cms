# Store Cart Racer (iOS Prototype)

This is a lightweight iOS racing prototype inspired by arcade kart racers, set inside a grocery store with improvised shopping-cart vehicles.

## What is implemented

- SwiftUI app shell + SpriteKit game scene
- Oval store track with shelf-themed environment
- Player controls:
  - Hold **LEFT** / **RIGHT** to steer
  - Hold **BOOST** for speed burst
- AI rival carts with lane-shifting behavior
- Hazard puddles that slow the player on contact
- Lap counting (3 laps), live race position, and finish overlay

## Project layout

```text
ios/StoreCartRacer/
  project.yml                 # XcodeGen project definition
  StoreCartRacer/
    StoreCartRacerApp.swift
    ContentView.swift
    GameModel.swift
    GameScene.swift
```

## Build and run in Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) on your Mac.
2. From this folder:

   ```bash
   xcodegen generate
   ```

3. Open `StoreCartRacer.xcodeproj`.
4. Select an iOS simulator (landscape works best) and run.

## Notes

- This is intentionally asset-light and uses shape nodes so it runs without external art files.
- You can tune difficulty in `GameScene.swift` by adjusting `baseSpeed`, hazard layout, and lane limits.
