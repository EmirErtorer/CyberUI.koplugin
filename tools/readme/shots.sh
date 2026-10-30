#!/usr/bin/env bash
# Take the README's screenshots in the emulator (600x800, captured at twice that
# on a Retina Mac), make the collages and put them in assets/screenshots:
#   CYBERUI_SHOT_BOOKS=<folder of the epubs to show> tools/readme/shots.sh
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
E2E_NO_DIR=1 HOME_SETUP="$repo/tools/readme/setup_books.py" TIMEOUT=300 "$repo/tests/e2e/run.sh" "$repo/tools/readme/shots.lua" "$tmp/p" 600 800 167 >/dev/null
mkdir -p "$repo/assets/screenshots"
python3 "$repo/tools/readme/montage.py" "$tmp/p"
rm -f "$repo/assets/screenshots/"*.png
cp "$tmp"/p/[01][0-9]-*.png "$repo/assets/screenshots/"
ls "$repo/assets/screenshots"
