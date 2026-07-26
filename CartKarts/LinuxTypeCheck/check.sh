#!/usr/bin/env bash
# Type-checks the CartKarts game sources on Linux (no Xcode required) against
# minimal UIKit/SpriteKit stub modules. Catches syntax errors, type errors,
# and misused API signatures. Requires a Swift toolchain on PATH.
set -euo pipefail
cd "$(dirname "$0")"

BUILD=.build
mkdir -p "$BUILD"

swiftc -emit-module -module-name CoreGraphics \
    -emit-module-path "$BUILD/CoreGraphics.swiftmodule" \
    -emit-library -o "$BUILD/libCoreGraphics.so" \
    stubs/CoreGraphicsStub.swift

swiftc -emit-module -module-name UIKit -I "$BUILD" \
    -emit-module-path "$BUILD/UIKit.swiftmodule" \
    -emit-library -o "$BUILD/libUIKit.so" -L "$BUILD" -lCoreGraphics \
    stubs/UIKitStub.swift

swiftc -emit-module -module-name SpriteKit -I "$BUILD" \
    -emit-module-path "$BUILD/SpriteKit.swiftmodule" \
    -emit-library -o "$BUILD/libSpriteKit.so" -L "$BUILD" -lCoreGraphics -lUIKit \
    stubs/SpriteKitStub.swift

# shellcheck disable=SC2046
swiftc -typecheck -I "$BUILD" $(find ../CartKarts -name '*.swift' | sort)

echo "Type check passed."

# Track geometry validation: compile the game logic (minus the app entry
# point, which would clash with this executable's @main) plus the validator,
# then run it.
# shellcheck disable=SC2046
swiftc -o "$BUILD/validate-track" -I "$BUILD" -L "$BUILD" \
    -lCoreGraphics -lUIKit -lSpriteKit \
    TrackValidation.swift \
    $(find ../CartKarts -name '*.swift' ! -name 'AppDelegate.swift' | sort)

LD_LIBRARY_PATH="$BUILD" "$BUILD/validate-track"
