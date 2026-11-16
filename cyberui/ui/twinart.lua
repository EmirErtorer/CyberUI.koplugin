-- The twin switch between SolarUI and CyberUI, drawn as one plaque split on a
-- slant: on the left SolarUI's garden (cream and gold, a round end, a sun, a
-- whiplash vine, its name in curling letters), on the right CyberUI's deck
-- (night black, a cut corner end, neon traces and scanlines, its name in
-- segment letters). The vine crosses the seam and turns into a circuit
-- trace. The side in charge is lit, its emblem bright; the other side sleeps
-- under a veil. Both names are drawn here as strokes, so the plaque looks the
-- same in either UI whatever fonts it has. Kept the same in both plugins
-- (art/twinart.lua in SolarUI, ui/twinart.lua in CyberUI): plain Lua, no requires.

local TwinArt = {}

-- The plaque's own canvas, in units (5 : 1).
TwinArt.W = 1000
TwinArt.H = 200

-- The colours of the two halves (each UI's own, the same in every theme).
local SOL = { bg = "#F4E8C8", gold = "#C59A3E", deep = "#8A6420", leaf = "#6E8F4E", stem = "#3E5B3A", ink = "#3A2A1A", bloom = "#D9826A", sun = "#F2C14E" }
local CYB = { bg = "#0B0F1A", panel = "#141B2D", cyan = "#19F0FF", pink = "#FF2BD6", dim = "#2A3550", ink = "#05070D" }

-- A number written short.
local function n(v) return string.format("%.1f", v):gsub("%.0$", "") end

-- An SVG path with fill and stroke (nil for none).
local function path(d, fill, stroke, sw, extra)
    return string.format('<path d="%s" fill="%s" stroke="%s" stroke-width="%s"%s/>', d, fill or "none", stroke or "none", n(sw or 0), extra or "")
end

-- A circle.
local function circle(cx, cy, r, fill, stroke, sw, extra)
    return string.format('<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="%s"%s/>', n(cx), n(cy), n(r), fill or "none", stroke or "none", n(sw or 0), extra or "")
end

-- Strokes in a group moved to (x, y) and scaled by k.
local function group(x, y, k, body)
    return string.format('<g transform="translate(%s %s) scale(%s)">%s</g>', n(x), n(y), n(k), body)
end

-- Where the seam runs: from the top at TOP_X to the foot at FOOT_X.
local TOP_X, FOOT_X = 545, 455

-- The outline of each half: SolarUI's with a round end, CyberUI's with cut corners.
local SOL_EDGE = string.format("M%d 0 L100 0 A100 100 0 0 0 100 200 L%d 200 Z", TOP_X, FOOT_X)
local CYB_EDGE = string.format("M%d 0 L956 0 L1000 44 L1000 156 L956 200 L%d 200 Z", TOP_X, FOOT_X)

-- The letters of SolarUI's name: curling strokes in a box 100 high (the
-- baseline at 100, small letters from 40), with each letter's width.
local SOL_GLYPHS = {
    S = { 58, "M54 12 C46 -2 10 -4 7 22 C4 46 56 44 56 72 C56 100 14 106 2 86" },
    o = { 46, "M23 40 C54 40 54 100 23 100 C-8 100 -8 40 23 40 Z" },
    l = { 24, "M9 -2 C4 8 6 16 9 22 L9 86 C9 100 20 102 24 92" },
    a = { 54, "M44 54 C40 36 6 38 3 66 C0 98 42 104 44 70 L44 90 C44 102 52 102 56 94" },
    r = { 40, "M3 100 L3 44 M3 66 C10 44 28 38 40 48" },
    U = { 60, "M-6 8 C-2 -4 4 -2 4 10 L4 64 C4 108 56 108 56 64 L56 0" },
    I = { 30, "M15 2 L15 98 M-1 2 C8 -3 22 -3 31 2 M-1 98 C8 103 22 103 31 98" },
}

-- The letters of CyberUI's name: straight segments with cut corners.
local CYB_GLYPHS = {
    C = { 60, "M60 0 L14 0 L0 14 L0 86 L14 100 L60 100" },
    y = { 46, "M0 40 L0 80 L10 90 L46 90 M46 40 L46 122 L36 132 L4 132" },
    b = { 46, "M0 0 L0 100 L38 100 L46 92 L46 48 L38 40 L0 40" },
    e = { 46, "M46 100 L8 100 L0 92 L0 48 L8 40 L38 40 L46 48 L46 70 L0 70" },
    r = { 40, "M0 100 L0 40 M0 58 L18 40 L40 40" },
    U = { 60, "M0 0 L0 86 L14 100 L46 100 L60 86 L60 0" },
    I = { 30, "M0 0 L30 0 M15 0 L15 100 M0 100 L30 100" },
}

-- A word in one of the stroke alphabets, `gap` between letters: the path of
-- each letter placed along a line, and the word's width.
local function word(glyphs, text, gap)
    local d, x = {}, 0
    for i = 1, #text do
        local g = glyphs[text:sub(i, i)]
        d[#d + 1] = string.format('<g transform="translate(%s 0)"><path d="%s"/></g>', n(x), g[2])
        x = x + g[1] + gap
    end
    return table.concat(d), x - gap
end

-- A word drawn centred on (cx, base - 50 * k), letters 100 * k high.
local function name(glyphs, text, gap, cx, cy, k, stroke, sw, cap, glow)
    local body, w = word(glyphs, text, gap)
    local attrs = string.format(' fill="none" stroke-linecap="%s" stroke-linejoin="%s"', cap, cap == "round" and "round" or "miter")
    local out = ""
    if glow then   -- (a wide faint stroke under the letters: neon light)
        out = out .. group(cx - w * k / 2, cy - 50 * k, k, string.format('<g%s stroke="%s" stroke-width="%s" stroke-opacity="0.28">%s</g>', attrs, glow, n(sw * 2.6), body))
    end
    return out .. group(cx - w * k / 2, cy - 50 * k, k, string.format('<g%s stroke="%s" stroke-width="%s">%s</g>', attrs, stroke, n(sw), body))
end

-- A leaf on the vine at (x, y), pointing `rot` degrees.
local function leaf(x, y, rot, L)
    local W = L * .42
    return string.format('<g transform="translate(%s %s) rotate(%s)">%s</g>', n(x), n(y), n(rot),
        path(string.format("M0 0 C%s %s %s %s %s 0 C%s %s %s %s 0 0Z", n(L * .25), n(-W), n(L * .75), n(-W), n(L), n(L * .7), n(W * .8), n(L * .3), n(W * .8)), SOL.leaf, SOL.stem, 2))
end

-- A rosette of eight petals round a gold heart.
local function rosette(cx, cy, r)
    local petals = {}
    for i = 0, 7 do
        local a = i * 45
        petals[#petals + 1] = string.format('<g transform="translate(%s %s) rotate(%s)">%s</g>', n(cx), n(cy), n(a),
            path(string.format("M0 0 C%s %s %s %s 0 %s C%s %s %s %s 0 0Z", n(r * .34), n(-r * .3), n(r * .3), n(-r * .82), n(-r), n(-r * .3), n(-r * .82), n(-r * .34), n(-r * .3)), SOL.bloom, SOL.deep, 1.4))
    end
    return table.concat(petals) .. circle(cx, cy, r * .3, SOL.gold, SOL.deep, 1.6) .. circle(cx, cy, r * .12, SOL.deep)
end

-- SolarUI's emblem: a sun with petal rays round a rosette.
local function sun(cx, cy, r)
    local rays = {}
    for i = 0, 15 do
        local a = math.rad(i * 22.5)
        local long = (i % 2 == 0) and 1 or .82
        local tip, s1, s2 = r * long, math.rad(i * 22.5 - 7), math.rad(i * 22.5 + 7)
        rays[#rays + 1] = string.format("M%s %s L%s %s L%s %s Z",
            n(cx + math.cos(s1) * r * .55), n(cy + math.sin(s1) * r * .55), n(cx + math.cos(a) * tip), n(cy + math.sin(a) * tip),
            n(cx + math.cos(s2) * r * .55), n(cy + math.sin(s2) * r * .55))
    end
    return path(table.concat(rays, " "), SOL.sun, SOL.deep, 2.2, ' stroke-linejoin="round"')
        .. circle(cx, cy, r * .58, SOL.gold, SOL.ink, 3) .. circle(cx, cy, r * .46, SOL.sun, SOL.deep, 1.6)
        .. rosette(cx, cy, r * .4)
end

-- CyberUI's emblem: a hexagon chip ringed in neon, pins at its sides.
local function chip(cx, cy, r)
    local hex, inner = {}, {}
    for i = 0, 5 do
        local a = math.rad(i * 60 + 30)
        hex[#hex + 1] = string.format("%s %s", n(cx + math.cos(a) * r), n(cy + math.sin(a) * r))
        inner[#inner + 1] = string.format("%s %s", n(cx + math.cos(a) * r * .66), n(cy + math.sin(a) * r * .66))
    end
    local pins = {}
    for i = -2, 2 do
        pins[#pins + 1] = string.format("M%s %s L%s %s M%s %s L%s %s", n(cx - r * .9), n(cy + i * r * .14), n(cx - r * 1.12), n(cy + i * r * .14),
            n(cx + r * .9), n(cy + i * r * .14), n(cx + r * 1.12), n(cy + i * r * .14))
    end
    local s = r * .26
    return path("M" .. table.concat(hex, " L") .. " Z", nil, CYB.cyan, r * .22, ' stroke-opacity="0.25"')
        .. path(table.concat(pins, " "), nil, CYB.cyan, 3)
        .. path("M" .. table.concat(hex, " L") .. " Z", CYB.panel, CYB.cyan, 4)
        .. path("M" .. table.concat(inner, " L") .. " Z", CYB.ink, CYB.pink, 2.5)
        .. path(string.format("M%s %s L%s %s L%s %s L%s %s Z", n(cx - s), n(cy - s), n(cx + s), n(cy - s), n(cx + s), n(cy + s), n(cx - s), n(cy + s)), CYB.cyan, nil)
        .. path(string.format("M%s %s L%s %s M%s %s L%s %s", n(cx - s * .5), n(cy - s * .3), n(cx + s * .5), n(cy - s * .3), n(cx - s * .5), n(cy + s * .3), n(cx + s * .2), n(cy + s * .3)), nil, CYB.ink, 2.4)
end

-- SolarUI's half: cream ground, a gold double rule along its edge, the
-- whiplash vine with leaves and a bloom along the foot, the sun and the name.
local function solarHalf()
    local vine = "M190 176 C236 196 286 150 336 166 C380 180 420 184 470 168"
    local out = path(SOL_EDGE, SOL.bg)
        -- the gold rule inside the edge
        .. path(string.format("M%d 12 L100 12 A88 88 0 0 0 100 188 L%d 188", TOP_X - 4, FOOT_X + 4), nil, SOL.gold, 3)
        .. path(string.format("M%d 20 L100 20 A80 80 0 0 0 100 180 L%d 180", TOP_X - 6, FOOT_X + 6), nil, SOL.gold, 1.2)
        -- a curl at the top of the rule, by the seam
        .. path("M470 20 C488 20 494 36 482 40 C472 44 468 32 476 30", nil, SOL.gold, 2, ' stroke-linecap="round"')
        .. path(vine, nil, SOL.stem, 5, ' stroke-linecap="round"')
        .. leaf(232, 186, -150, 26) .. leaf(286, 162, -40, 24) .. leaf(350, 170, 150, 22) .. leaf(410, 180, -30, 22)
        .. circle(318, 156, 9, SOL.bloom, SOL.ink, 2) .. circle(318, 156, 3.5, SOL.sun)
    out = out .. sun(100, 100, 74)
    out = out .. name(SOL_GLYPHS, "SolarUI", 10, 318, 92, .62, SOL.ink, 11, "round")
        .. name(SOL_GLYPHS, "SolarUI", 10, 318, 92, .62, SOL.gold, 3.6, "round")
        -- a whiplash flourish under the name, ending in a curl
        .. path("M206 136 C260 128 330 146 392 134 C418 129 436 122 440 112 C443 104 434 100 430 106", nil, SOL.deep, 2.6, ' stroke-linecap="round"')
    return out
end

-- CyberUI's half: night ground, a panel, scanlines, neon traces with pads in
-- the corners, cut-corner brackets, the chip and the name with a glow.
local function cyberHalf()
    local out = path(CYB_EDGE, CYB.bg)
        .. path(string.format("M%d 14 L950 14 L986 50 L986 150 L950 186 L%d 186 Z", TOP_X - 6, FOOT_X + 6), CYB.panel, CYB.dim, 1.5)
    -- scanlines
    local lines = {}
    for y = 22, 180, 8 do
        local x0 = TOP_X - 6 - (y - 14) * (TOP_X - FOOT_X) / 172 + 10
        lines[#lines + 1] = string.format("M%s %d L%d %d", n(x0), y, y < 50 and 950 - (50 - y) or (y > 150 and 950 - (y - 150) or 984), y)
    end
    out = out .. path(table.concat(lines, " "), nil, CYB.cyan, 1, ' stroke-opacity="0.07"')
    -- the corner brackets
    out = out .. path("M902 26 L946 26 L972 52 L972 74 M972 126 L972 148 L946 174 L902 174", nil, CYB.pink, 3)
    -- traces with pads, top and foot
    out = out .. path("M600 30 L660 30 L676 46 L760 46 M600 172 L700 172 L716 156 L790 156", nil, CYB.cyan, 2.5, ' stroke-opacity="0.75"')
        .. circle(760, 46, 4.5, CYB.bg, CYB.cyan, 2.5) .. circle(790, 156, 4.5, CYB.bg, CYB.cyan, 2.5)
    -- small readouts
    out = out .. path("M606 152 L624 152 L624 160 L606 160 Z M630 152 L640 152 L640 160 L630 160 Z M646 152 L652 152 L652 160 L646 160 Z", CYB.pink, nil, 0, ' fill-opacity="0.8"')
    out = out .. chip(900, 100, 58)
    out = out .. name(CYB_GLYPHS, "CyberUI", 13, 700, 92, .6, CYB.cyan, 9, "square", CYB.cyan)
    return out
end

-- The seam: the vine running over into a neon trace, a gold rule on the
-- garden's side and a pink one on the deck's, a spark where they meet.
local function seam()
    return path(string.format("M%d 0 L%d 200", TOP_X - 5, FOOT_X - 5), nil, SOL.gold, 4)
        .. path(string.format("M%d 0 L%d 200", TOP_X + 5, FOOT_X + 5), nil, CYB.pink, 4)
        .. path("M470 168 C482 164 492 160 500 158", nil, SOL.stem, 5, ' stroke-linecap="round"')
        .. path("M500 158 L560 158 L584 134 L650 134", nil, CYB.cyan, 4)
        .. circle(650, 134, 5, CYB.bg, CYB.cyan, 3)
        .. circle(500, 158, 7, "#FFFFFF", CYB.cyan, 2.5)
end

-- The veil over the side that is not in charge.
local function veil(edge, colour)
    return path(edge, colour, nil, 0, ' fill-opacity="0.66"')
end

-- The plaque at vw x vh with `active` ("solarui" or "cyberui") in charge, as SVG body.
function TwinArt.body(vw, vh, active)
    local cyber = active == "cyberui"
    local out = solarHalf() .. cyberHalf() .. seam()
    out = out .. (cyber and veil(SOL_EDGE, "#E9DFC8") or veil(CYB_EDGE, CYB.bg))
    -- the outline, round on the left, cut on the right
    out = out .. path("M100 0 L956 0 L1000 44 L1000 156 L956 200 L100 200 A100 100 0 0 1 100 0 Z", nil, "#1A1410", 4)
    return string.format('<g transform="scale(%s %s)">%s</g>', n(vw / TwinArt.W), n(vh / TwinArt.H), out)
end

-- A whole SVG document of the plaque, w x h pixels.
function TwinArt.document(w, h, active)
    return string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>', w, h, w, h, TwinArt.body(w, h, active))
end

return TwinArt
