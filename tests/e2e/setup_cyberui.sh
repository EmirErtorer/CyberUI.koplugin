#!/usr/bin/env bash
# Home setup for scenes that start KOReader with CyberUI (SolarUI and the
# other home screens switched off, no twin chosen), as on a reader's device.
set -euo pipefail
home="$1"
python3 - "$home/settings.reader.lua" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = re.sub(r'\n    \["twin_ui"\] = "[^"]*",', '', s)
s = re.sub(r'\["start_with"\] = "[^"]*"', '["start_with"] = "cyberui"', s)
off = ["bookshelf", "simpleui", "zenos", "SolarUI", "solarui"]
block = '["plugins_disabled"] = {\n' + "".join('        ["%s"] = true,\n' % d for d in off) + "    },"
s = re.sub(r'\["plugins_disabled"\] = \{.*?\n    \},', block, s, count=1, flags=re.S)
open(p, "w", encoding="utf-8").write(s)
PY
