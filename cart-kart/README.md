# Cart Kart — MegaMart Mayhem

Mario Kart–style shopping-cart racing through a grocery store. Built for iPhone.

## Play now (iOS Safari / desktop)

Open the web build — works great on iPhone (Add to Home Screen for fullscreen):

```bash
cd cart-kart
python3 -m http.server 8080
```

Then visit `http://localhost:8080` (or your machine’s LAN IP on an iPhone).

### Controls

| Action | Touch (iPhone) | Keyboard |
|--------|----------------|----------|
| Steer | Drag on left side of screen | ← → / A D |
| Gas | Green pedal (auto-gas on by default) | ↑ / W |
| Brake | Red pedal | ↓ / S |
| Use item | FIRE / item box | Space |
| Pause | ❚❚ | Esc / P |

### Features

- 6 playable carts (Rusty, Squeaky, Neon, Basket Case, Rolling Stone, Coupon Queen)
- MegaMart aisle track with shelves as walls
- 5 AI racers
- Item crates: banana peels, soda boost, can cannon, milk spill, bag bomb
- 3-lap races, place HUD, minimap, finish podium

## Native iOS (Xcode)

Open `CartKart-iOS/CartKart.xcodeproj` in Xcode 15+, pick an iPhone simulator or device, and Run.

SwiftUI shells the menus; SpriteKit runs the race (`RaceScene.swift`) with the same cart roster, items, and touch pedals.

Bundle ID: `com.cartkart.game` — set your Development Team in Signing to install on a device.

## Project layout

```
cart-kart/           Playable HTML5 + PWA (touch-first)
CartKart-iOS/        Native SwiftUI + SpriteKit app
```
