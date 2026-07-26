#!/usr/bin/env bash
#
# Type-checks as much of the iOS app as is possible without a Mac.
#
# Two passes:
#   1. Every app source file is parsed, which catches syntax errors everywhere,
#      including the SwiftUI views.
#   2. The rendering, audio and device-input files are fully type-checked against
#      the stand-ins in Tools/LinuxTypecheck, together with the real game code.
#      That catches wrong argument labels, missing members and bad maths in the
#      part of the app with the most logic in it.
#
# The SwiftUI views are only parsed: shimming SwiftUI's generic view machinery
# convincingly is not realistic, so those are reviewed on a Mac.
#
# Usage: Tools/typecheck.sh   (needs a Swift toolchain on PATH)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found on PATH" >&2
    exit 127
fi

status=0

echo "== Pass 1: parsing every app source file"
parsed=0
while IFS= read -r file; do
    if ! output=$(swiftc -parse "$file" 2>&1); then
        echo "  FAIL $file"
        echo "$output" | sed 's/^/    /'
        status=1
    fi
    parsed=$((parsed + 1))
done < <(find App/ShoppingCartRacer -name '*.swift' | sort)
echo "  parsed $parsed files"

echo "== Pass 2: type-checking the renderer, audio and input against shims"
# Files whose only Apple dependencies are shimmed.
TYPECHECKED=(
    "App/ShoppingCartRacer/Scenes/ArtFactory.swift"
    "App/ShoppingCartRacer/Scenes/CartNode.swift"
    "App/ShoppingCartRacer/Scenes/UIColorBridge.swift"
    "App/ShoppingCartRacer/Scenes/WorldBuilder.swift"
    "App/ShoppingCartRacer/Scenes/RaceScene.swift"
    "App/ShoppingCartRacer/Systems/AudioDirector.swift"
    "App/ShoppingCartRacer/Systems/HapticsDirector.swift"
    "App/ShoppingCartRacer/Systems/MotionSteering.swift"
    "App/ShoppingCartRacer/Systems/GamepadBridge.swift"
)

# The app files import Apple frameworks by name; the shims stand in for those
# modules, so the imports have to be stripped for this pass. The copies live in a
# scratch directory and are never committed.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

for file in "${TYPECHECKED[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "  FAIL missing $file"
        status=1
        continue
    fi
    sed -E 's/^import (UIKit|SpriteKit|CoreGraphics|AVFoundation|CoreMotion|GameController|Combine)$/import Foundation/' \
        "$file" > "$SCRATCH/$(basename "$file")"
done

mkdir -p "$SCRATCH/shims"
cp Tools/LinuxTypecheck/*.swift "$SCRATCH/shims/"

# Compile the shims, the game code and the app files as one module, exactly as
# the Xcode target does.
mapfile -t GAME_SOURCES < <(find Sources/CartRacerKit Sources/CartRacerPresentation -name '*.swift' | sort)
mapfile -t APP_SOURCES < <(find "$SCRATCH" -maxdepth 1 -name '*.swift' | sort)
mapfile -t SHIM_SOURCES < <(find "$SCRATCH/shims" -name '*.swift' | sort)

if output=$(swiftc -typecheck \
        -swift-version 5 \
        "${SHIM_SOURCES[@]}" "${GAME_SOURCES[@]}" "${APP_SOURCES[@]}" 2>&1); then
    echo "  type-checked ${#APP_SOURCES[@]} app files with ${#GAME_SOURCES[@]} game files"
else
    echo "$output" | sed 's/^/    /'
    status=1
fi

if [[ $status -eq 0 ]]; then
    echo "OK"
else
    echo "FAILED" >&2
fi
exit $status
