# Cart Rush

Mario Kart–style racing with **rogue shopping carts** tearing through a supermarket after hours.

## Play (iPhone / iPad / desktop)

Open [`index.html`](./index.html) in a browser, or serve the folder:

```bash
cd cart-rush
python3 -m http.server 8080
```

Then visit `http://localhost:8080` — on a phone, use your machine’s LAN IP.

### Controls

| Platform | Steer | Accelerate | Brake | Use item |
|----------|-------|------------|-------|----------|
| **iOS / touch** | Left pad | Hold **GAS** | **BRAKE** | Tap item box |
| **Desktop** | ← → / A D | ↑ / W | ↓ / S / Shift | Space |

Add to Home Screen on iOS for a full-screen app-like experience (landscape recommended).

## Gameplay

- Pick a cart: **Squeaky**, **Dent**, **Wobbles**, or **Chrome**
- Race **3 laps** on the MegaMart Circuit against 3 AI carts
- Grab glowing **?** boxes for grocery power-ups:
  - **Banana** — leave a peel trap
  - **Soda** — speed boost
  - **Soup Can** — projectile
  - **Coupon** — shield
  - **Milk Spill** — wet-floor slow zone

## Native iOS (SpriteKit)

A SwiftUI + SpriteKit port lives in [`../CartRush`](../CartRush). Open those sources in a new Xcode **iOS App** target (iOS 16+) and build to a device or Simulator.
