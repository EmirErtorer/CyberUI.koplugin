#!/usr/bin/env bash
# Copied home for restart.lua: KOReader starts in the last book, and CyberUI
# was the reader's home before the restart.
home="$1"
LC_ALL=C sed -i '' 's/\["start_with"\] = "[^"]*"/["start_with"] = "last"/' "$home/settings.reader.lua"
printf 'return {\n    ["home_active"] = true,\n}\n' > "$home/settings/cyberui.lua"
