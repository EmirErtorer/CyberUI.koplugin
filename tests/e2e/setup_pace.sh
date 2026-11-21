#!/usr/bin/env bash
# Home setup for pace.lua: a picture book (a PDF of 120 pages of pictures, no
# text at all) next to the library's books, and eddies on with a clean ledger.
set -euo pipefail
home="$1"
python3 - "$home/Books/Picture book.pdf" <<'PY'
import sys, random
from PIL import Image
random.seed(7)
pages = []
for i in range(120):
    img = Image.effect_noise((600, 800), 60 + i % 40).convert("RGB")
    pages.append(img)
pages[0].save(sys.argv[1], save_all=True, append_images=pages[1:], quality=80)
PY
