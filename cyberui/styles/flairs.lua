-- Handle flairs: a badge beside the handle on the ID card, a plate with a
-- symbol on it. Each style is { id, name, price, draw(bb, x, y, s) } and draws
-- in a square `s` pixels on a side. The first one is a plain pip.

local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

-- Points given as fractions of the square, placed at (x, y) with side s.
local function place(x, y, s, pts)
    local out = {}
    for i, p in ipairs(pts) do out[i] = { x + p[1] * s, y + p[2] * s } end
    return out
end

-- A chamfered plate filling the square in `colour`; returns the symbol's colour and line weight.
local function plate(bb, x, y, s, colour)
    local th = Theme.get()
    Paint.chamferBox(bb, x, y, s, s, math.floor(s / 4), "tb", 0, colour, nil)
    return th.c.on_accent, math.max(2, math.floor(s / 9))
end

-- A small solid square.
local function pip(bb, x, y, s)
    Paint.fill(bb, x + math.floor(s * 0.3), y + math.floor(s * 0.3), math.floor(s * 0.4), math.floor(s * 0.4), Theme.get().c.accent)
end

-- Two forward chevrons on a plate.
local function chevrons(bb, x, y, s)
    local c, t = plate(bb, x, y, s, Theme.get().c.accent)
    for i = 0, 1 do
        local ox = x + s * (0.2 + 0.28 * i)
        Paint.line(bb, ox, y + s * 0.24, ox + s * 0.26, y + s * 0.5, t, c)
        Paint.line(bb, ox + s * 0.26, y + s * 0.5, ox, y + s * 0.76, t, c)
    end
end

-- A ring with sight marks on a plate.
local function crosshair(bb, x, y, s)
    local c, t = plate(bb, x, y, s, Theme.get().c.accent)
    local ring = {}
    for i = 0, 11 do
        local a = i * math.pi / 6
        ring[#ring + 1] = { x + s * (0.5 + 0.26 * math.cos(a)), y + s * (0.5 + 0.26 * math.sin(a)) }
    end
    Paint.outline(bb, ring, t, c)
    Paint.line(bb, x + s * 0.5, y + s * 0.12, x + s * 0.5, y + s * 0.34, t, c)
    Paint.line(bb, x + s * 0.5, y + s * 0.66, x + s * 0.5, y + s * 0.88, t, c)
    Paint.line(bb, x + s * 0.12, y + s * 0.5, x + s * 0.34, y + s * 0.5, t, c)
    Paint.line(bb, x + s * 0.66, y + s * 0.5, x + s * 0.88, y + s * 0.5, t, c)
end

-- A lightning bolt on a plate.
local function bolt(bb, x, y, s)
    local c = plate(bb, x, y, s, Theme.get().c.accent)
    Paint.polygon(bb, place(x, y, s, { { 0.58, 0.1 }, { 0.24, 0.55 }, { 0.46, 0.55 }, { 0.4, 0.9 }, { 0.78, 0.42 }, { 0.54, 0.42 }, { 0.7, 0.1 } }), c)
end

-- An eye on a plate in the second colour, with a scan line across it and a frame around the plate.
local function eye(bb, x, y, s)
    local th = Theme.get()
    local c, t = plate(bb, x, y, s, th.c.accent2)
    Paint.outline(bb, place(x, y, s, { { 0.12, 0.5 }, { 0.28, 0.34 }, { 0.5, 0.28 }, { 0.72, 0.34 }, { 0.88, 0.5 }, { 0.72, 0.66 }, { 0.5, 0.72 }, { 0.28, 0.66 } }), t, c)
    Paint.polygon(bb, place(x, y, s, { { 0.5, 0.38 }, { 0.62, 0.5 }, { 0.5, 0.62 }, { 0.38, 0.5 } }), c)
    Paint.fill(bb, x + math.floor(s * 0.06), y + math.floor(s * 0.5) - 1, math.floor(s * 0.88), 2, th.c.accent)
    Paint.brackets(bb, x - 2, y - 2, s + 4, s + 4, math.floor(s / 4), math.max(2, math.floor(s / 14)), th.c.accent)
end

return {
    { id = "flair.pip", name = _("PIP"), price = 0, draw = pip },
    { id = "flair.chevrons", name = _("CHEVRONS"), price = 100, draw = chevrons },
    { id = "flair.crosshair", name = _("CROSSHAIR"), price = 200, draw = crosshair },
    { id = "flair.bolt", name = _("BOLT"), price = 450, draw = bolt },
    { id = "flair.eye", name = _("SCANNER EYE"), price = 800, draw = eye },
}
