# 🛒 Cart Kart — Homeless Shopping Cart Racing Game

A Mario Kart-style 2D top-down racer built with **Phaser 3**, set entirely inside
a grocery store.  Race as one of four legendary carts through the **Mega Mart
Raceway**, dodge item boxes, drop banana peels, and blast opponents with Shopping
Basket Bombs!

---

## Characters

| Cart       | Speed | Handling | Power | Trait                                 |
|------------|-------|----------|-------|---------------------------------------|
| Rusty      | ★★★   | ★★★★     | ★★★   | Reliable veteran, knows every aisle   |
| Baggage    | ★★    | ★★       | ★★★★★ | Slow tank – nothing pushes it around  |
| Express    | ★★★★★ | ★★★      | ★     | Tiny basket cart, blazing fast        |
| Fresh      | ★★★   | ★★★      | ★★★   | Brand-new all-rounder (balanced)      |

## Power-ups

| Item              | Effect                                       |
|-------------------|----------------------------------------------|
| 🍌 Banana Peel    | Drop behind – spins out the next cart that hits it |
| ⚡ Energy Drink   | 5-second speed boost (+55 % max speed)       |
| 🧺 Basket Bomb    | Fires a projectile in your facing direction  |
| ⚠️ Wet Floor Sign | Drops a puddle that slows carts passing over |
| 🛡️ Cart Shield   | Absorbs the next hit for 5 seconds           |

---

## Running in Browser

```bash
cd cart-kart
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

### Controls

| Platform | Steer | Accelerate | Use Item |
|----------|-------|------------|----------|
| Keyboard | Arrow Keys / WASD | ↑ / W | Space |
| Touch (iOS) | Left joystick (drag) | Right GAS button | Right ITEM button |

---

## Building for iOS with Capacitor

### Prerequisites
- macOS with Xcode 15+
- Node.js 18+
- CocoaPods

### Steps

```bash
# 1. Install dependencies
cd cart-kart
npm install

# 2. Build the web bundle
npm run build

# 3. Install Capacitor CLI
npm install -g @capacitor/cli @capacitor/core @capacitor/ios

# 4. Initialise Capacitor (first time only)
npx cap init "Cart Kart" "com.cartkart.game" --web-dir dist

# 5. Add iOS platform
npx cap add ios

# 6. Sync built assets to the native project
npx cap sync ios

# 7. Open in Xcode
npx cap open ios
```

Inside Xcode:
- Select your target device (iPhone / iPad / Simulator)
- Press **Run** (⌘R)
- For App Store distribution: set your Bundle ID, Signing team, and archive

### Recommended iPhone settings
- Requires iOS 14.0+
- Supports all orientations (auto-rotates)
- Fullscreen (status bar hidden via `overlaysWebView: true` in capacitor config)

---

## Project Structure

```
cart-kart/
├── index.html               # App entry, mobile viewport meta
├── vite.config.js           # Vite bundler config
├── capacitor.config.json    # Capacitor iOS/Android config
├── src/
│   ├── main.js              # Phaser game config
│   ├── scenes/
│   │   ├── BootScene.js     # Procedurally generates ALL textures (no external assets)
│   │   ├── MenuScene.js     # Title screen + character selection
│   │   ├── GameScene.js     # Racing game logic, physics, AI, power-ups
│   │   └── UIScene.js       # HUD overlay + virtual joystick for iOS touch
│   └── data/
│       ├── characters.js    # Character stats + power-up definitions
│       └── trackWaypoints.js# Track layout: waypoints, checkpoints, item boxes
```

---

## Track: Mega Mart Raceway

A clockwise oval circuit through the store's themed sections:

```
        ┌─────────[🥐 BAKERY]──────────┐
        │                              │
[🧊 FROZEN]    🏪 MEGA MART    [⚠️ CHICANE]
        │      (inner island)          │
[🥦 PRODUCE]                  [🥫 CANNED]
        │                              │
        └─────[💳 CHECKOUT]────────────┘
                   ▶ START / FINISH
```

3 laps to win.  Intermediate checkpoints prevent shortcutting.

---

## License

MIT – do whatever you want with it.
