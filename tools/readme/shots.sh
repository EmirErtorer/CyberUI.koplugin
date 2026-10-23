#!/usr/bin/env bash
# Take the README's twelve screenshots in the emulator (600x800 and 800x600,
# captured at twice that on a Retina Mac) and put them in assets/screenshots.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
E2E_NO_DIR=1 TIMEOUT=300 "$repo/tests/e2e/run.sh" "$repo/tools/readme/shots.lua" "$tmp/p" 600 800 167 >/dev/null
E2E_NO_DIR=1 CYBERUI_SHOTS_LANDSCAPE=1 TIMEOUT=200 "$repo/tests/e2e/run.sh" "$repo/tools/readme/shots.lua" "$tmp/l" 800 600 167 >/dev/null
mkdir -p "$repo/assets/screenshots"
cp "$tmp"/p/[01]*.png "$tmp"/l/12-*.png "$repo/assets/screenshots/"
ls "$repo/assets/screenshots"
