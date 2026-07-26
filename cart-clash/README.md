# Cart Clash — Aisle Racers

Mario Kart–style racing with **homeless shopping carts** tearing through MegaMart after hours.

Play in the browser (iPhone Safari friendly) or open the native Swift/SpriteKit project in Xcode.

## Play in browser (recommended preview)

```bash
cd cart-clash
python3 -m http.server 8080
```

Open `http://localhost:8080` — on iPhone, Add to Home Screen for a fullscreen app-like feel.

### Controls

| Action | Touch | Keyboard |
|--------|-------|----------|
| Steer | Left pad | ← → / A D |
| Gas | GAS | ↑ / W |
| Brake | BRAKE | ↓ / S |
| Item | ITEM | Space / X |
| Pause | ❚❚ | Esc |

### Power-ups

- **Banana Peel** — drop a slip hazard behind you
- **Soda Boost** — burst of speed
- **Price Gun** — zap the cart ahead
- **Coupon Shield** — block one hit

## Native iOS (Xcode)

Open the Xcode project:

```bash
open ios/CartClash/CartClash.xcodeproj
```

Requirements: Xcode 15+, iOS 16+. Run on a simulator or device. The SpriteKit scene mirrors the web game: pseudo-3D aisle track, cart racers, items, and touch controls.

## Project layout

```
cart-clash/
  index.html          # Web game shell
  css/game.css
  js/                 # Web engine
  ios/CartClash/      # Native SwiftUI + SpriteKit app
```
