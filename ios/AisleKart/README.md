# Aisle Kart (iOS / SpriteKit)

Native iOS companion to the web game in [`../../aisle-kart`](../../aisle-kart).

Rogue shopping carts race supermarket aisles — Mario Kart energy, linoleum chaos.

## Open in Xcode

1. Open `AisleKart.xcodeproj` in **Xcode 15+**
2. Select an iPhone simulator or device
3. Press **Run** (⌘R)

Requires iOS 16+.

## Controls

- **Tilt / on-screen** left & right to steer  
- **Gas / Brake** pedals  
- **Item** button for banana, soda boost, soap slick, or canned goods  

## Project layout

```
AisleKart/
  App.swift              SwiftUI app entry
  ContentView.swift      Hosts SpriteView + overlays
  GameScene.swift        Race loop, AI, items, track
  Models.swift           Cart builds & item types
  Assets.xcassets        App icon / accent color
```

Gameplay mirrors the HTML5 demo so you can prototype on the web and ship natively from this target.
