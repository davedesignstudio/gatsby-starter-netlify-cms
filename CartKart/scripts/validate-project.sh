#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Validating Cart Kart Xcode project..."

PBX="CartKart.xcodeproj/project.pbxproj"
missing=0

while IFS= read -r file; do
  rel="CartKart/${file#CartKart/}"
  if ! grep -q "$(basename "$file")" "$PBX"; then
    echo "missing from project.pbxproj: $rel"
    missing=1
  fi
  if [[ ! -f "$rel" ]]; then
    echo "file not found: $rel"
    missing=1
  fi
done < <(find CartKart -name '*.swift' | sort)

required=(
  CartKart/Info.plist
  CartKart/CartKart.entitlements
  CartKart/Assets.xcassets
)

for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "missing required path: $path"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Validation failed."
  exit 1
fi

echo "All Swift sources and required resources are present."
