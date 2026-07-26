# Cart Mayhem — Aisle Racers

Mario Kart–style arcade racing with **shopping carts** tearing through a supermarket after hours.

Abandoned carts. Empty aisles. No rules.

## Play now (iPhone / iPad / desktop)

Open the web build in Safari (or any browser):

1. From the repo root, serve the folder:
   ```bash
   npx --yes serve cart-mayhem -p 5173
   ```
2. Visit `http://localhost:5173`
3. On iPhone: open that URL in Safari → Share → **Add to Home Screen** for a full-screen app-like feel

### Controls

| Action | Touch | Keyboard |
|--------|-------|----------|
| Steer | ◀ ▶ | A / D or ← → |
| Drift (+ mini boost) | DRIFT | Space / Shift |
| Use item | ITEM | F |

### Racers

- **Rusty Rick** — beater cart, sticky wheels  
- **Dumpster Dana** — tight turns, alley-trained  
- **Alley Ace** — built for straightaways  
- **Cart King** — balanced aisle legend  

### Power-ups

Neon `?` crates along the aisles drop:

- ⚡ Soda Rush — speed boost  
- 🍌 Banana Peel — spin-out trap  
- 🥫 Soup Can — forward projectile  
- 🫧 Sticky Gum — slow trap  

Race is **3 laps** around MegaSave’s main loop. Beat the AI carts to become Aisle Champ.

---

## Native iOS (SwiftUI + SpriteKit)

Sources live in `ios/CartMayhem/CartMayhem/`.

### Open in Xcode (Mac)

1. Create a new **iOS App** project named `CartMayhem` (SwiftUI, iOS 16+).
2. Replace the generated files with the sources in `ios/CartMayhem/CartMayhem/`:
   - `CartMayhemApp.swift`
   - `ContentView.swift`
   - `GameModel.swift`
   - `Models.swift`
   - `RaceScene.swift`
   - `Info.plist` (optional display name / orientations)
3. Set bundle id, team, and run on a simulator or device.

The native build mirrors the web game: same racers, items, 3-lap supermarket loop, and on-screen controls.

---

## Project layout

```
cart-mayhem/
  index.html      # playable web game
  styles.css
  game.js
  README.md
  ios/CartMayhem/CartMayhem/   # SwiftUI + SpriteKit sources
```
