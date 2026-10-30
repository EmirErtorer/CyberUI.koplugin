#!/usr/bin/env python3
"""Set KOReader's language in a copied home folder, as KOReader's own language
menu does:  CYBERUI_LANG=ru setup_language.py <home_dir>"""
import os
import re
import sys

home, lang = sys.argv[1], os.environ.get("CYBERUI_LANG", "de")
path = os.path.join(home, "settings.reader.lua")
s = open(path, encoding="utf-8").read()
s, n = re.subn(r'\["language"\] = "[^"]*"', '["language"] = "%s"' % lang, s, count=1)
if n == 0:
    s = s.replace("return {", 'return {\n    ["language"] = "%s",' % lang, 1)
open(path, "w", encoding="utf-8").write(s)
