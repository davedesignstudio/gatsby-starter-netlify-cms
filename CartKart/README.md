# Cart Kart

A kart racer for iPhone and iPad where the karts are supermarket trolleys and
the circuits are the aisles of a shop after closing time. Eight carts, four
courses, drifting, mini-turbos, item boxes, and a melon that hunts down whoever
is in the lead.

Everything you would expect from the genre is here: a countdown with a rocket
start, drift charging through three tiers, a position-weighted item roulette so
last place gets the good stuff, catch-up assistance, lap tracking with a wrong
way warning, a grand prix scored on points, and time trials with saved records.

## Layout

```
CartKart/
  Package.swift            Swift package: the simulation and the CLI
  Sources/CartKartCore/    All game rules. No UIKit, no SpriteKit, no platform code.
  Sources/CartKartSim/     Headless simulator used for balancing
  Tests/CartKartCoreTests/ 55 tests covering physics, items, laps and race flow
  App/                     The iOS app: SwiftUI menus, SpriteKit race scene
  project.yml              XcodeGen spec that turns App/ into an Xcode project
```

The split is deliberate. `CartKartCore` contains the entire game — driving
model, items, AI, lap counting, standings — and depends on nothing but
Foundation, so it compiles and is tested on Linux as well as on a Mac. The app
target only draws what the simulation reports and feeds player input back in.

## Building the game

You need a Mac with Xcode 15 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen        # once
cd CartKart
xcodegen generate            # writes CartKart.xcodeproj
open CartKart.xcodeproj
```

Pick an iPhone or iPad simulator and run. The game is landscape only. Set your
own signing team in the target settings before running on a device.

If you would rather not use XcodeGen, create an iOS App target by hand, add the
`App` folder to it, and add this directory as a local Swift package dependency
on the `CartKartCore` product.

## Working on the simulation without a Mac

The package builds and tests anywhere Swift runs:

```bash
swift test                              # 55 tests, about two seconds
swift run -c release cartkart-sim race --track frozen-foods
swift run -c release cartkart-sim balance --races 20
swift run -c release cartkart-sim items
swift run -c release cartkart-sim tracks
```

`cartkart-sim` simulates whole races headlessly with every cart on autopilot.
`balance` is the useful one: it races the full roster across all four courses
and prints lap times and win shares, which is how the cart stats were tuned.

```
Wins and points by cart
  Rusty         22.9%   383 pts  ###########
  Squeaks       12.5%   344 pts  ######
  Chrome        18.8%   388 pts  #########
  ...
```

## How it plays

Carts accelerate on their own. You steer, drift, brake and use items.

- **Steering** — slide your left thumb, tap arrow buttons, or tilt the device.
- **Drifting** — hold DRIFT through a corner while steering into it. Sparks go
  blue, then orange, then purple; release for a mini-turbo whose size matches
  the charge.
- **Rocket start** — hold the throttle as the countdown reaches one. Too early
  and the wheels judder off the line.
- **Surfaces** — waxed pads boost, mopped floors take away your steering while
  leaving your speed, and matting off the racing line slows you to a crawl
  unless your trolley is built for rough ground.

Items, in rising order of unfairness: Grape Spill, Soup Can, Triple Soup,
Energy Drink, Mop Bucket, Flour Bomb, Bulk Buy (invincibility), and the
Runaway Melon, which only appears for the back of the pack and rolls along the
aisle until it flattens the leader.

## Courses

| Course | Character |
| --- | --- |
| Produce Plaza | Wide sweepers, sprinklers, a friendly opener |
| Frozen Foods Freeway | Long straights and meltwater with no grip |
| Bulk Warehouse Rally | The longest lap, littered with pallets |
| Checkout Chaos | Tight, dark and mean, after hours at the tills |

Courses are authored as a handful of control points with a lane width; the
engine fits a Catmull-Rom spline through them, resamples it at even spacing,
and derives the racing line, walls, starting grid, lap progress and minimap
from that one centreline. Furniture (item boxes, boost pads, puddles, pallet
stacks) is placed in fractions of a lap rather than world coordinates, so a
course can be reshaped without moving everything by hand.

## Notes on the implementation

- **Fixed timestep.** The engine advances in 1/120s steps with an accumulator,
  so a race plays identically at 30fps and 120fps, and a seeded race replays
  exactly. Tests rely on both properties.
- **No binary assets.** Every sprite is drawn at launch with Core Graphics and
  every sound effect is synthesised into a PCM buffer, so the repository is
  entirely text.
- **Progress by arc length.** Each cart's position on the course is a single
  cumulative distance along the centreline. Laps, standings, wrong way
  detection and the melon's navigation all fall out of that one number.
- **AI.** Computer carts aim at a point down the racing line, brake for corners
  they cannot take flat, drift through the long ones, dodge hazards, detour for
  item boxes, and pick sensible moments to fire. Difficulty changes their pace,
  their steering precision and how late they brake.
