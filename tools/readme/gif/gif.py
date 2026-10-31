"""Make a README animation from the frames a scene took in the emulator
(gifkit.lua): each frame gets the touches on it drawn over the screen (a
fingertip, with a fading trail while it slides, or a pen), is scaled down,
and the frames go into one GIF with one shared palette and no dithering, so
text stays crisp and nothing flickers from frame to frame.

    python3 gif.py <frames dir> <out.gif> [--width 600] [--colors 160]

ImageMagick, when present, then keeps only what changes between frames.
"""
import argparse
import math
import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = os.path.expanduser("~/koreader-emulator/resources/fonts/Inter-ExtraBold.ttf")

ap = argparse.ArgumentParser()
ap.add_argument("frames")
ap.add_argument("out")
ap.add_argument("--width", type=int, default=600)
ap.add_argument("--colors", type=int, default=160)
args = ap.parse_args()

SS = 2   # overlays are drawn at twice the size and scaled down, for smooth edges


def read_log(path):
    frames = []
    for line in open(path, encoding="utf-8"):
        parts = line.split()
        if len(parts) < 2:
            continue
        touches = []
        caption = None
        for t in parts[2:]:
            if t.startswith("cap="):
                caption = t[4:].replace("_", " ")
                continue
            kind, x, y, alpha, trail = t.split(":", 4)
            pts = [int(v) for v in trail.split(",")] if trail else []
            touches.append({"kind": kind, "x": int(x), "y": int(y), "alpha": float(alpha),
                            "trail": list(zip(pts[0::2], pts[1::2]))})
        frames.append({"n": int(parts[0]), "ms": int(parts[1]), "touches": touches, "caption": caption})
    return frames


def finger(draw, x, y, alpha, r=30):
    """A fingertip: a soft grey disc with a white rim."""
    x, y, r = x * SS, y * SS, r * SS
    a = int(255 * alpha)
    draw.ellipse((x - r - 3 * SS, y - r - 3 * SS, x + r + 3 * SS, y + r + 3 * SS), fill=(255, 255, 255, int(a * 0.85)))
    draw.ellipse((x - r, y - r, x + r, y + r), fill=(70, 70, 76, int(a * 0.55)))


def trail(draw, pts, alpha):
    """Where the finger has been: smaller, fainter discs behind it."""
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        f = (i + 1) / (n + 1)
        r = 10 + 14 * f
        finger(draw, x, y, alpha * 0.35 * f, r)


def pen(draw, x, y, alpha):
    """A stylus held by a right hand: the tip on the point, the body down to
    the right."""
    ang = math.radians(58)
    ux, uy = math.cos(ang), math.sin(ang)        # along the pen, away from the tip
    vx, vy = -uy, ux                             # across it
    tip_len, body_len, half = 30, 250, 11

    def p(along, across):
        return ((x + ux * along + vx * across) * SS, (y + uy * along + vy * across) * SS)

    a = int(255 * alpha)
    shadow = [p(4, 4), p(tip_len + 4, half + 4), p(tip_len + body_len, half + 4), p(tip_len + body_len, -half + 4),
              p(tip_len + 4, -half + 4)]
    draw.polygon(shadow, fill=(0, 0, 0, int(a * 0.12)))
    cone = [p(0, 0), p(tip_len, half), p(tip_len, -half)]
    draw.polygon(cone, fill=(190, 190, 196, int(a * 0.92)))
    draw.polygon([p(0, 0), p(9, 3), p(9, -3)], fill=(40, 40, 44, a))
    body = [p(tip_len, half), p(tip_len + body_len, half), p(tip_len + body_len, -half), p(tip_len, -half)]
    draw.polygon(body, fill=(52, 54, 62, int(a * 0.9)))
    shine = [p(tip_len + 6, -half + 3), p(tip_len + body_len - 6, -half + 3), p(tip_len + body_len - 6, -half + 7),
             p(tip_len + 6, -half + 7)]
    draw.polygon(shine, fill=(120, 124, 136, int(a * 0.8)))
    band = [p(tip_len + 2, half), p(tip_len + 10, half), p(tip_len + 10, -half), p(tip_len + 2, -half)]
    draw.polygon(band, fill=(150, 152, 160, int(a * 0.9)))


def compose(path, touches, size, caption=None):
    im = Image.open(path).convert("RGB")
    if touches:
        over = Image.new("RGBA", (im.width * SS, im.height * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(over)
        for t in touches:
            if t["kind"] == "pen":
                pen(d, t["x"], t["y"], t["alpha"])
            else:
                if t["trail"]:
                    trail(d, t["trail"], t["alpha"])
                finger(d, t["x"], t["y"], t["alpha"])
        over = over.filter(ImageFilter.GaussianBlur(0.6 * SS)).resize(im.size, Image.LANCZOS)
        im = Image.alpha_composite(im.convert("RGBA"), over).convert("RGB")
    im = im.resize(size, Image.LANCZOS)
    if caption:
        im = im.convert("RGBA")
        over = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(over)
        font = ImageFont.truetype(FONT, round(im.width * 0.04))
        box = d.textbbox((0, 0), caption, font=font)
        tw, th = box[2] - box[0], box[3] - box[1]
        px, py = round(im.width * 0.03), round(im.width * 0.02)
        x0 = (im.width - tw) // 2 - px
        y0 = round(im.height * 0.885)
        d.rounded_rectangle((x0, y0, x0 + tw + 2 * px, y0 + th + 2 * py), radius=6, fill=(236, 72, 153, 235))
        d.text((x0 + px - box[0], y0 + py - box[1]), caption, font=font, fill=(255, 255, 255, 255))
        im = Image.alpha_composite(im, over).convert("RGB")
    return im


frames = read_log(os.path.join(args.frames, "frames.txt"))
first = Image.open(os.path.join(args.frames, "f%04d.png" % frames[0]["n"]))
size = (args.width, round(first.height * args.width / first.width))
images = [compose(os.path.join(args.frames, "f%04d.png" % f["n"]), f["touches"], size, f["caption"]) for f in frames]

# one palette for every frame, from a sample of them side by side
step = max(1, len(images) // 24)
sample = images[::step]
mosaic = Image.new("RGB", (size[0] * len(sample), size[1]))
for i, im in enumerate(sample):
    mosaic.paste(im, (i * size[0], 0))
pal = mosaic.quantize(colors=args.colors, method=Image.Quantize.LIBIMAGEQUANT, dither=Image.Dither.NONE)
quant = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in images]

# frames that look the same are one frame shown for longer
out, durations = [], []
for im, f in zip(quant, frames):
    if out and im.tobytes() == out[-1].tobytes():
        durations[-1] += f["ms"]
    else:
        out.append(im)
        durations.append(f["ms"])
durations = [max(20, int(round(ms / 10.0)) * 10) for ms in durations]

tmp = args.out + ".tmp.gif"
out[0].save(tmp, save_all=True, append_images=out[1:], duration=durations, loop=0, optimize=False, disposal=1)
magick = shutil.which("magick")
if magick:
    subprocess.run([magick, tmp, "-layers", "Optimize", args.out], check=True)
    os.remove(tmp)
else:
    os.replace(tmp, args.out)
total = sum(durations) / 1000
print("%s: %d frames, %.1f s, %d KB" % (args.out, len(out), total, os.path.getsize(args.out) // 1024))
