#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-CartKart}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 15}"

echo "Building Cart Kart ($SCHEME) for $DESTINATION..."

if ! command -v xcodebuild >/dev/null; then
  echo "error: xcodebuild not found. Open this project on macOS with Xcode installed." >&2
  exit 1
fi

if xcodebuild -project CartKart.xcodeproj -list 2>/dev/null | grep -q "Schemes:"; then
  xcodebuild \
    -project CartKart.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  xcodebuild \
    -project CartKart.xcodeproj \
    -target CartKart \
    -sdk iphonesimulator \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

echo "Build succeeded."
