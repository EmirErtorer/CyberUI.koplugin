#!/usr/bin/env python3
"""The GitHub social preview (1280 x 640) in the README's Neon dark colours:
    python3 tools/readme/social.py   ->  assets/social-preview.png"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", ".."))
BG, INK, RED, MUTED, LINE, SOFT = "#1E1517", "#93E4EA", "#E0574B", "#C9A19C", "#5A3A3C", "#3E2729"
W, H = 1280, 640

def font(name, size):
    return ImageFont.truetype(os.path.join(REPO, "fonts", name), size)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

# a fine grid and scanlines, quiet
for x in range(0, W, 40):
    d.line([(x, 0), (x, H)], fill="#271B1D", width=1)
for y in range(0, H, 40):
    d.line([(0, y), (W, y)], fill="#271B1D", width=1)
for y in range(0, H, 4):
    d.line([(0, y), (W, y)], fill="#1A1214", width=1)

# the glitch title: the word cut into bands, each shifted a little, as in the README banner
title, tf = "CYBERUI", font("Oxanium-Bold.ttf", 124)
tx, ty = 70, 150
bands = [(0, 52, 0), (52, 76, 12), (76, 98, -9), (98, 200, 0)]
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for dx, dy, col in ((-5, 4, RED), (5, -3, "#1FA3AE")):
    ld = ImageDraw.Draw(layer)
    ld.text((tx + dx, ty + dy), title, font=tf, fill=col)
img.paste(layer, (0, 0), layer)
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).text((tx, ty), title, font=tf, fill=255)
for top, bottom, shift in bands:
    band = Image.new("L", (W, H), 0)
    band.paste(mask.crop((0, ty + top, W, ty + bottom)), (shift, ty + top))
    img.paste(Image.new("RGB", (W, H), INK), (0, 0), band)
d = ImageDraw.Draw(img)

# the line under it and what it is
d.rectangle([70, 330, 70 + 520, 334], fill=RED)
d.text((70, 356), "A CYBERPUNK HOME SCREEN", font=font("Oxanium-Bold.ttf", 34), fill=INK)
d.text((70, 402), "FOR KOREADER", font=font("Oxanium-Bold.ttf", 34), fill=INK)

# feature chips
chips = ["GIGS", "SHOP", "OPERATOR ID", "10 LANGUAGES"]
cf = font("Oxanium-Bold.ttf", 22)
x = 70
for text in chips:
    w = d.textlength(text, font=cf)
    box = [x, 480, x + w + 36, 524]
    d.polygon([(box[0], box[1]), (box[2] - 12, box[1]), (box[2], box[1] + 12), (box[2], box[3]), (box[0], box[3])], fill=RED)
    d.text((x + 18, 488), text, font=cf, fill=BG)
    x += w + 52

d.text((70, 580), "ROOT@KINDLE:~#  E-INK  FAST  YOURS", font=font("JetBrainsMono-Regular.ttf", 18), fill=MUTED)

# three screens on the right, the middle one in front, cut off by the bottom edge
def shot(name, size):
    s = Image.open(os.path.join(REPO, "assets", "screenshots", name)).convert("RGB")
    return s.resize(size, Image.LANCZOS)

def framed(s, pos, border=INK):
    x0, y0 = pos
    w, h = s.size
    cut = 18
    mask = Image.new("L", (w, h), 255)
    ImageDraw.Draw(mask).polygon([(w - cut, 0), (w, 0), (w, cut)], fill=0)
    ImageDraw.Draw(mask).polygon([(0, h - cut), (0, h), (cut, h)], fill=0)
    img.paste(s, (x0, y0), mask)
    dd = ImageDraw.Draw(img)
    dd.polygon([(x0, y0), (x0 + w - cut, y0), (x0 + w, y0 + cut), (x0 + w, y0 + h), (x0 + cut, y0 + h), (x0, y0 + h - cut)], outline=border, width=3)

framed(shot("02-gigs.png", (270, 360)), (650, 96), MUTED)
framed(shot("03-card.png", (270, 360)), (1000, 60), MUTED)
framed(shot("01-home.png", (345, 460)), (800, 180), INK)

# corner brackets
for (cx, cy, sx, sy) in ((24, 24, 1, 1), (W - 24, 24, -1, 1), (24, H - 24, 1, -1), (W - 24, H - 24, -1, -1)):
    d.line([(cx, cy), (cx + 46 * sx, cy)], fill=INK, width=4)
    d.line([(cx, cy), (cx, cy + 46 * sy)], fill=INK, width=4)

out = os.path.join(REPO, "assets", "social-preview.png")
img.save(out)
print("wrote", out)
