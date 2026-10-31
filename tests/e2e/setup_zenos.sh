#!/usr/bin/env bash
# Copied home for zenhome.lua: ZenOS switched on, CyberUI the start screen, the
# screenshot books as the library (needs CYBERUI_SHOT_BOOKS).
home="$1"
LC_ALL=C sed -i '' '/\["zenos"\] = true,/d' "$home/settings.reader.lua"
LC_ALL=C sed -i '' 's/\["start_with"\] = "[^"]*"/["start_with"] = "cyberui"/' "$home/settings.reader.lua"
python3 "$(dirname "$0")/../../tools/readme/setup_books.py" "$home"
