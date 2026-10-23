#!/usr/bin/env python3
"""Set a copied KOReader home to start with one home-screen plugin, named by
CYBERUI_COMPARE (cyberui, bookshelf or simpleui):  setup_home.py <home_dir>
The other two (and ZenOS, which clashes with SimpleUI) are switched off."""
import os
import re
import sys

PLUGINS = {"cyberui": ("CyberUI", "cyberui"), "bookshelf": ("bookshelf", "bookshelf"),
           "simpleui": ("simpleui", "homescreen_simpleui")}
which, home = os.environ.get("CYBERUI_COMPARE", "cyberui"), sys.argv[1]
on_dir, start_with = PLUGINS[which]
off = [d for d, _ in PLUGINS.values() if d != on_dir] + ["zenos"]

path = os.path.join(home, "settings.reader.lua")
s = open(path, encoding="utf-8").read()
block = '["plugins_disabled"] = {\n' + "".join('        ["%s"] = true,\n' % d for d in off) + "    },"
s, n = re.subn(r'\["plugins_disabled"\] = \{.*?\n    \},', block, s, count=1, flags=re.S)
if n == 0:
    s = s.replace("return {", "return {\n    " + block, 1)
s, n = re.subn(r'\["start_with"\] = "[^"]*"', '["start_with"] = "%s"' % start_with, s, count=1)
if n == 0:
    s = s.replace("return {", 'return {\n    ["start_with"] = "%s",' % start_with, 1)
open(path, "w", encoding="utf-8").write(s)

if which == "simpleui":
    # skip SimpleUI's first-run welcome screen
    sui = os.path.join(home, "settings", "simpleui", "sui_settings.lua")
    os.makedirs(os.path.dirname(sui), exist_ok=True)
    t = open(sui, encoding="utf-8").read() if os.path.exists(sui) else "return {\n}\n"
    if "simpleui_onboarding_done" not in t:
        t = t.replace("return {", 'return {\n    ["simpleui_onboarding_done"] = true,', 1)
    open(sui, "w", encoding="utf-8").write(t)
print("home set to start with", which)
