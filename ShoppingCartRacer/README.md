# Trolley Trophy

A supermarket kart racer for iOS. Six shopping trolleys, piled with junk, racing
down the aisles, through the freezer section and out past the bins.

It is a Mario Kart-shaped game: drift through the corners for a mini-turbo, grab
crates for items, collect loose change, three laps, championship points.

## The game

**Six characters**, each a different trolley with its own stat curve and a perk:

| | | |
|---|---|---|
| **Squeak** | Stockroom rat on a hand basket | Recovers from spinouts quickly |
| **Marge** | Coupon queen, forty years of trolley experience | Mini-turbos charge faster |
| **Kev** | Off-shift bag boy on a flatbed | Boosts last longer |
| **Rusty** | Loading bay raccoon, cart is 60% cardboard | Wins every bump |
| **Trolley Todd** | Cart wrangler pushing two nested trolleys | Wins every bump |
| **Mopbot 9** | Floor care unit that would rather race | Keeps grip on wet floors |

**Three courses.** Aisle Seven Sprint is fast and boxy with a badly mopped corner
and a seasonal carpet runner that kills your speed. Frozen Foods Loop is twistier,
with frost patches and a defrost puddle. Loading Dock Rally goes out the back:
asphalt, hairpins and no sympathy. Each unlocks by finishing the one before on the
podium.

**Driving.** Hold the drift button into a corner and release at the exit for one
of three mini-turbo tiers. Full-lock counter-steer flicks the drift the other way
and loses the charge. Feather the throttle as the lights go out for a rocket
start — hold it from the first light and you flood the wheels.

**Items** come from promo crates, weighted by race position so the leader gets
defensive junk and the back of the field gets the comeback tools:

- **Energy Drink** — instant boost
- **Shaken Can** — thrown forwards, lightly homing
- **Grease Slick** — dropped behind, and very slippery
- **Crate Shield** — three milk crates orbit and eat three hits
- **Clearance Announcement** — stalls every cart ahead of you and makes them drop their items
- **Express Lane** — auto-piloted sprint up the racing line, for the back of the pack only

**Modes.** Trolley Trophy is a three-round cup with championship points. Single
Race lets you pick any unlocked course. Three difficulties, from a Sunday morning
shop to Black Friday.

## Running it

```bash
cd ShoppingCartRacer
open App/ShoppingCartRacer.xcodeproj
```

Set a development team under Signing & Capabilities, then run on a device or
simulator. The game is landscape only and needs iOS 16.

There are no image or audio assets: every texture is drawn with Core Graphics at
launch and every sound is synthesised at runtime, including the trolley rattle,
whose pitch tracks your speed.

## How it is put together

The entire simulation is free of Apple frameworks, so a whole race can be run
headlessly and asserted in tests. The iOS layer only draws.

```
Sources/CartRacerKit/          the game: physics, tracks, items, AI, race rules
Sources/CartRacerPresentation/ art plans, HUD model, controls, records, navigation
Sources/RaceLab/               headless balance bench (a command line tool)
App/ShoppingCartRacer/         SpriteKit scene and SwiftUI screens
Tests/CartRacerKitTests/       93 tests, all runnable on Linux
Tools/                         project generation, validation and type-checking
```

Both `Sources` targets compile as one module, and the iOS target builds those same
files directly rather than depending on the package, which is why nothing in
`App/` imports anything.

### The simulation

Carts use an arcade model: a heading that the steering rotates, a forward speed
driven by an engine curve, and a lateral velocity that surface grip drags back
into line. Understeer, drifts and spinouts all fall out of those three pieces
rather than being special-cased. The yaw rate rises with speed and then caps, so a
cart understeers progressively as it gets going — that is what makes drifting
worth doing.

A course is a dense centreline polyline. One projection of a cart onto it yields
everything the simulation needs: lap progress, how far off the racing line the
cart has drifted, and which floor it is on. Lap counting accumulates real distance
covered rather than watching for line crossings, so no shortcut can skip arc
length and driving backwards simply unwinds your progress.

Everything is deterministic given a seed, which is what makes the tests worth
having.

### The art

`TrackArtPlan` and `CartArtPlan` describe what to draw — the floor ribbon, the
shelving, the scattered scenery, each character's basket and the junk in it — as
plain data, computed deterministically. The renderer only executes them, and the
tests can assert that no prop ever ends up sitting on the racing line.

## Development

```bash
swift test                    # 93 tests
swift run -c release race-lab # full-field races, balance numbers per course
swift run -c release race-lab tracks
swift run -c release race-lab drift       # is drifting actually quicker?
swift run -c release race-lab drifttrace  # per-frame telemetry for one cart

Tools/typecheck.sh                  # parse every app file, type-check the renderer
python3 Tools/generate_xcodeproj.py # regenerate the Xcode project
python3 Tools/validate_xcodeproj.py # check it parses and compiles everything
```

`race-lab` is a balance bench, and it earns its keep. It found three real bugs
that would have been miserable to chase on a phone: off-road rolling resistance
exceeded some carts' engine force, so a cart that touched the shoulder could never
move again; obstacle contacts re-applied their full speed penalty every frame,
pinning carts against traffic cones permanently; and the drift's minimum turn rate
was tighter than any corner on any course, which made drifting measurably *slower*
than not drifting.

`Tools/generate_xcodeproj.py` builds the Xcode project from the directory tree, so
a new source file cannot be silently left out of the target. Re-run it after
adding, moving or renaming a file and commit the result; the identifiers come from
paths, so an unchanged tree regenerates byte-identically.

`Tools/typecheck.sh` parses every app source file and fully type-checks the
renderer, audio and device-input code against stand-ins for UIKit, SpriteKit, Core
Graphics, AVFoundation, Core Motion and GameController in
`Tools/LinuxTypecheck/`. That catches wrong labels, missing members and bad maths
in the code with the most logic in it, on a machine with no Xcode. The stand-ins
prove nothing about whether a signature matches Apple's — on a Mac, the real SDK
is the authority.

### Not yet verified on hardware

The SwiftUI views are parsed but not type-checked; shimming SwiftUI's generic view
machinery convincingly is not realistic. Tilt steering is calibrated from the
gravity vector, so it should behave the same in either landscape orientation, but
it wants a few minutes with a real device to confirm the direction feels right.
