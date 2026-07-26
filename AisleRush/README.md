# Aisle Rush

A kart racer for iOS where the karts are shopping trolleys and the circuit is a
supermarket. Eight racers, drift boosts, grocery-themed weapons, and shelving
that does not move when you hit it.

Written in Swift with SpriteKit for the race and SwiftUI for everything around
it. There are no binary assets in the repository: every sprite is drawn with
Core Graphics at launch and every sound effect is synthesised with
AVAudioEngine.

## Getting it running

```bash
open AisleRush/AisleRush.xcodeproj   # Xcode 16 or newer
```

Pick an iPhone or iPad simulator and run. The app is landscape-only and targets
iOS 17. No signing team is configured, so set your own in the target's Signing
& Capabilities pane before running on a device.

The project is also described by `project.yml`; if you would rather generate it
yourself, run `xcodegen generate` in this directory.

## Layout

```
AisleRush/
├── Core/                  Swift package: the entire race simulation
│   ├── Sources/AisleRushCore/
│   │   ├── Math/          Vectors, angles, damping
│   │   ├── Track/         Course definitions, geometry, the four circuits
│   │   ├── Sim/           Cart state, arcade handling model, surfaces
│   │   ├── Items/         The nine items and how they behave in the world
│   │   ├── AI/            Opponent drivers
│   │   ├── Race/          Race state machine, standings, results
│   │   └── Roster/        Characters, trolleys, wheels and their stats
│   └── Tests/             60 tests, including whole races run headless
├── App/AisleRush/         The iOS app
│   ├── Scene/             SpriteKit scene, cart nodes, scenery builder
│   ├── Art/               Procedural texture generation
│   ├── Audio/             Synthesised sound effects and the caster rattle
│   ├── Model/             Navigation, race session, saved progress
│   ├── Input/             Tilt steering
│   └── UI/                SwiftUI menus, HUD and on-screen controls
└── AisleRush.xcodeproj
```

The split is deliberate. `AisleRushCore` imports nothing but Foundation, so the
whole game can be simulated without a screen — which is how it is tested.

## Testing

```bash
swift test --package-path AisleRush/Core
```

The suite runs in about a minute on a laptop. Beyond the usual unit tests, it:

- races all four courses to the chequered flag with a full field of eight AI
  carts and asserts that everyone finishes, that every lap is counted, and that
  the finishing order matches elapsed time;
- checks no cart ever ends up inside the shelving over a whole race;
- verifies courses never run alongside themselves, which would make the lap
  counter ambiguous;
- checks the same seed produces a bit-identical race, and different seeds do
  not.

There is also a pacing report used for tuning, skipped unless asked for:

```bash
RACE_REPORT=1 swift test --package-path AisleRush/Core --filter RacePacingReport
```

```
Produce Loop         len= 461.5m  bestLap= 23.3s  winner= 76.3s  spread= 21.6s
Frozen Foods Freeway len= 532.6m  bestLap= 20.0s  winner= 68.5s  spread= 15.1s
Clearance Canyon     len= 569.1m  bestLap= 25.8s  winner= 88.2s  spread= 27.3s
Closing Time Parkway len= 701.5m  bestLap= 28.1s  winner= 91.3s  spread= 12.2s
```

The app target is built by the macOS CI job (`.github/workflows/aisle-rush.yml`),
which is the check that covers the SpriteKit and SwiftUI layers; the Linux job
covers the simulation.

## How the racing works

**Handling.** The cart turns its heading directly and the velocity is dragged
along behind it by a grip coefficient. That gap between where a cart points and
where it is going is the slip angle, and it is the whole game. Holding the
drift button drops grip so the cart slides, and the slip angle is capped so a
drift cannot wind itself up into a spin. Real physics makes a slide a braking
manoeuvre — a genuine drift here scrubs about 25 m/s² of forward speed — so the
loss is capped at a flat 3.4 m/s², which turns drifting from a mistake into a
technique.

**Mini-turbos.** Charge accumulates while drifting, faster if you steer into
the slide. Three tiers at 0.75 s, 1.7 s and 2.9 s of drifting pay out boosts of
increasing length and strength when you let go.

**Surfaces.** Clean linoleum, the scuffed floor outside the aisle, produce
misting puddles, flattened cardboard, freezer-section ice and buffed booster
strips. Each scales grip, top speed and rolling drag separately, so ice is fast
and uncontrollable while cardboard is grippy and slow.

**Courses.** Each is a handful of control points, smoothed with a Catmull-Rom
spline and resampled at one metre so arc length maps directly onto an array
index. From that the game derives tangents, curvature, a corner-cutting racing
line, and a cornering speed limit per metre swept backwards so that braking
zones appear where they should. Solid props get folded into the racing line at
build time, so every driver inherits the avoidance rather than discovering the
pallet with its front wheels.

**Opponents.** Each AI aims at a point down the racing line, brakes to the
precomputed corner limits with a margin set by its skill, drifts through
sustained bends until the mini-turbo is charged, dodges carts and spills, and
decides what to do with whatever it is holding. A slow wander keeps a pack from
driving as a single object, and any cart that wedges itself reverses out.

**Items.** Nine of them, drawn from a position-weighted table: the leader gets
milk spills and soup cans, last place gets energy drinks, homing melons and the
occasional runaway trolley. Trailable items can be held out behind the cart as
a shield, thrown forward, or thrown backward.

**Difficulty.** Three settings scale opponent skill and top speed. Rubber
banding is capped at ±8% so trailing carts stay in touch without visibly
teleporting.

## Controls

| Action | Control |
| --- | --- |
| Steer | Slide the left thumb pad, or tilt (Settings) |
| Accelerate | Automatic by default; a gas pedal appears if you turn it off |
| Brake | Small pedal, bottom right |
| Drift | Big button, bottom right |
| Use item | Tap to throw forward, drag down to throw backward, hold to trail |

Holding REV as the countdown reaches two earns a rocket start. Holding it from
three floods the wheels instead. With auto-accelerate on, the REV button
appears only during the countdown.

Touches are handled by a UIKit multitouch layer (`Input/TouchControlLayer.swift`)
rather than SwiftUI gestures. SwiftUI arbitrates one gesture at a time across
sibling views, so a steering pad and a drift button built from `DragGesture`
cannot be held at once — which would make mini-turbos impossible. The layout in
`ControlLayout` is shared between that layer and the SwiftUI visuals so the two
can never disagree about where a button is.

## A note on the theme

The brief asked for "homeless shopping carts". The game is built around
supermarket trolley racing and its cast are store staff and shoppers —
a cart wrangler, a butcher, a sample-station demonstrator, a floor-scrubbing
robot. Homelessness is not used as a punchline.

## Known gaps

- The app has not been run on a device or simulator yet. The simulation is
  covered by tests, and the app layer builds in CI, but the feel of the
  handling on a touchscreen and the look of the procedural art both want a
  pass on real hardware.
- No app icon. There is no asset catalogue because the project deliberately
  contains no binary assets; add one before shipping anywhere.
- No Game Center, leaderboards or ghost replays. Records are stored locally in
  `UserDefaults`.
- Split screen and online play are not implemented.
