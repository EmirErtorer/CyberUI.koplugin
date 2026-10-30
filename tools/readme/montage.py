#!/usr/bin/env python3
"""Make the README's four collages from the pieces shots.lua takes:  montage.py <shots folder>
Each collage is 2 x 2 cells on a 1200 x 1600 page: 14 the shop's four tabs, 15 four jack-in
cards, 16 the gigs story and 17 home in four languages."""
import os
import sys
from PIL import Image

BG = (30, 21, 23)   # Neon dark
PAGE = (1200, 1600)
GAP = 16
GROUPS = [("14", "styles"), ("15", "jackin"), ("16", "gigs"), ("17", "languages")]

folder = sys.argv[1]
for number, name in GROUPS:
    page = Image.new("RGB", PAGE, BG)
    cell_w, cell_h = (PAGE[0] - 3 * GAP) // 2, (PAGE[1] - 3 * GAP) // 2
    for i, letter in enumerate("abcd"):
        path = os.path.join(folder, f"{number}{letter}-{name}.png")
        if not os.path.exists(path):
            print("missing", path)
            continue
        im = Image.open(path).convert("RGB")
        scale = min(cell_w / im.width, cell_h / im.height)
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
        x = GAP + (i % 2) * (cell_w + GAP) + (cell_w - im.width) // 2
        y = GAP + (i // 2) * (cell_h + GAP) + (cell_h - im.height) // 2
        page.paste(im, (x, y))
    page.save(os.path.join(folder, f"{number}-{name}.png"))
    print("made", f"{number}-{name}.png")
