# Store Cart Racer (iOS)

A lightweight iOS kart-racing prototype built with **SwiftUI + SpriteKit**.

Theme:
- You race shopping carts through a big-box store
- Dodging aisles, shelf blocks, and rival carts
- 3-lap sprint with live place tracking

## Features

- Touch controls tuned for phones:
  - Left side of screen: steer
  - Right upper side: accelerate
  - Right lower side: brake
- Top-down arcade driving model (drift-like steering at speed)
- AI opponents that follow race waypoints
- Cart-to-cart bumping and shelf collision slowdown
- Lap counter, race timer, and current race position

## Run in Xcode

1. Open `StoreCartRacer.xcodeproj` in Xcode.
2. Select an iOS Simulator (or physical iPhone).
3. Build and run.

## Notes

- This prototype uses only code-generated visuals (no external art assets required).
- To evolve this into a fuller Mario-Kart-style game:
  - Add power-ups (speed boost, spill hazards, temporary shield)
  - Add item spawn logic and inventory slots
  - Add multiple store tracks and a cup/tournament mode
