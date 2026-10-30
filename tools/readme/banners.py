"""Draw the README's banners in the Neon scheme: the glitch title, the divider,
the download button and the launcher strip. Text is turned into paths so
GitHub shows it exactly, with no font to load.
Needs fontTools and the Rubik Glitch font (SIL OFL 1.1, from Google Fonts):
    python3 tools/readme/banners.py <RubikGlitch-Regular.ttf>
"""
import os, re, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "assets")
RED, TEAL, DARK, MUTED = "#E0574B", "#93E4EA", "#1E1517", "#9C7A76"
# (the strip sits on GitHub's light or dark page: red icons with teal lights read on both)


def text_path(font_file, text, size, x=0, y=0, tracking=0):
    """The text as one SVG path, baseline at y; returns (d, width)."""
    font = TTFont(font_file)
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    scale = size / font["head"].unitsPerEm
    pen = SVGPathPen(glyphs)
    cx = x
    for ch in text:
        name = cmap.get(ord(ch))
        if not name:
            continue
        g = glyphs[name]
        g.draw(TransformPen(pen, (scale, 0, 0, -scale, cx, y)))
        cx += g.width * scale + tracking
    return pen.getCommands(), cx - x - tracking


def svg(w, h, body, label=None):
    role = f' role="img" aria-label="{label}"><title>{label}</title>' if label else ' aria-hidden="true">'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"{role}{body}</svg>'


def title(glitch_font):
    d, w = text_path(glitch_font, "CYBERUI", 120, 12, 118, 4)
    W, H = int(w + 36), 150
    bands = [(0, 52, 0), (52, 74, 10), (74, 92, -7), (92, 150, 0)]   # y from, y to, shift
    clips = "".join(f'<clipPath id="b{i}"><rect x="0" y="{a}" width="{W}" height="{b - a}"/></clipPath>'
                    for i, (a, b, _s) in enumerate(bands))
    ghost = f'<path d="{d}" fill="{TEAL}" opacity="0.85" transform="translate(5 -3)"/>'
    main = "".join(f'<g clip-path="url(#b{i})"><path d="{d}" fill="{RED}" transform="translate({s} 0)"/></g>'
                   for i, (_a, _b, s) in enumerate(bands))
    return svg(W, H, f"<defs>{clips}</defs>{ghost}{main}", "CyberUI")


def divider():
    W, H = 1000, 40
    nodes = "".join(f'<rect x="{x - 3}" y="{y - 3}" width="6" height="6"/>' for x, y in [(120, 20), (360, 28), (610, 20)])
    body = (f'<defs><linearGradient id="g" x1="0" x2="1000" y1="0" y2="0" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{RED}"/><stop offset="0.45" stop-color="{TEAL}"/>'
            f'<stop offset="0.8" stop-color="{TEAL}" stop-opacity="0.35"/><stop offset="1" stop-color="{TEAL}" stop-opacity="0"/>'
            f'</linearGradient></defs>'
            f'<g fill="url(#g)" stroke="url(#g)"><path d="M0 20 H240 L248 28 H500 L508 20 H1000" fill="none" stroke-width="3"/>'
            f'{nodes}<rect x="0" y="16" width="70" height="8"/></g>')
    return svg(W, H, body)


def download(ui_font):
    d, w = text_path(ui_font, "DOWNLOAD THE LATEST RELEASE", 17, 58, 29.5, 1.2)
    W, H, cut = int(w + 82), 46, 12
    box = f'<path d="M0 0 H{W - cut} L{W} {cut} V{H} H0 Z" fill="{RED}"/>'
    arrow = (f'<g transform="translate(22 11)" fill="none" stroke="{DARK}" stroke-width="2.6" stroke-linecap="square">'
             f'<path d="M12 2 V16 M6 10 L12 16 L18 10 M3 22 H21"/></g>')
    return svg(W, H, f'{box}{arrow}<path d="{d}" fill="{DARK}"/>', "Download the latest release")


def icon_paths(name):
    """The paths of one of CyberUI's icons (stroke and fill layers)."""
    out = []
    for f in (name, name + ".accent"):
        p = os.path.join(REPO, "icons", f + ".svg")
        if os.path.exists(p):
            s = open(p).read()
            for m in re.finditer(r'<path d="([^"]+)"([^>]*)/>', s):
                out.append((m.group(1), 'fill="none"' in m.group(2), f.endswith(".accent")))
            g = re.search(r'<g transform="([^"]+)">', s)
            if g:
                out = [(d, st, ac, g.group(1)) for d, st, ac in out]
    return out


def launcher(ui_font):
    items = [("library", "LIBRARY"), ("collections", "COLLECTIONS"), ("history", "HISTORY"),
             ("search", "SEARCH"), ("gigs", "GIGS"), ("pen", "INK AWAY"), ("settings", "SYSTEM")]
    cell, W, H = 128, 128 * 7, 92
    body = []
    for i, (icon, label) in enumerate(items):
        x = i * cell + cell / 2
        for parts in icon_paths(icon):
            d, stroke, accent = parts[0], parts[1], parts[2]
            inner = parts[3] if len(parts) > 3 else None
            colour = TEAL if accent else RED
            attrs = (f'fill="none" stroke="{colour}" stroke-width="2.2" stroke-linecap="square" stroke-linejoin="miter"'
                     if stroke else f'fill="{colour}"')
            path = f'<path d="{d}" {attrs}/>'
            if inner:
                path = f'<g transform="{inner}">{path}</g>'
            body.append(f'<g transform="translate({x - 24} 8) scale(2)">{path}</g>')
        td, tw = text_path(ui_font, label, 15, 0, 0, 1.5)
        body.append(f'<path d="{td}" fill="{MUTED}" transform="translate({x - tw / 2} 84)"/>')
    return svg(W, H, "".join(body), "The launcher: Library, Collections, History, Search, Gigs, Ink Away and System")


if __name__ == "__main__":
    glitch = sys.argv[1]
    ui = os.path.join(REPO, "fonts", "Oxanium-Bold.ttf")
    os.makedirs(OUT, exist_ok=True)
    for name, data in [("cyberui-title.svg", title(glitch)), ("readme-divider.svg", divider()),
                       ("readme-download.svg", download(ui)), ("readme-launcher.svg", launcher(ui))]:
        open(os.path.join(OUT, name), "w").write(data)
        print("wrote assets/" + name, len(data), "bytes")
