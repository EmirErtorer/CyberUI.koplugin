-- ID card frames: a whole new border for the card, drawn over its edge in
-- the room the style asks for (`inset`, base pixels added to the card's
-- padding, so nothing drawn ever touches the contents). Each style is { id,
-- name, price, inset, draw(bb, x, y, w, h, top, pad) }; `top` is the height of
-- the title strip, which is left alone, and `pad` the padding the card has (a
-- frame draws within pad less a little). A style without draw is the plain card.

local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local px = Theme.px

-- The width of the band the frame has to draw in, between the edge and the contents.
local function band(pad)
    return pad - px(4)
end

-- Cut corners, heavy accent edges and a double line: a plated panel.
local function notch(bb, x, y, w, h, top, pad)
    local th = Theme.get()
    local cut, t, b = px(30), px(4), band(pad)
    Paint.frame(bb, x + px(2), y + top, w - px(4), h - top - px(2), t, th.c.accent)
    Paint.frame(bb, x + b - px(2), y + top + b - px(2), w - 2 * b + px(4), h - top - 2 * b + px(4), th.size.hair, th.c.ink)
    local corners = { { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }
    for _i, c in ipairs(corners) do
        Paint.polygon(bb, { { c[1], c[2] }, { c[1] + c[3] * cut, c[2] }, { c[1], c[2] + c[4] * cut } }, th.c.bg)
        Paint.line(bb, c[1] + c[3] * cut, c[2] - px(1), c[1] + px(1) * c[3], c[2] + c[4] * cut, t, th.c.accent)
    end
    Paint.polygon(bb, { { x, y }, { x + px(14), y }, { x, y + px(14) } }, th.c.bg)
end

-- A circuit board border: buses down both sides with pads, a chip and traces along the bottom.
local function circuit(bb, x, y, w, h, top, pad)
    local th = Theme.get()
    local c, hair, b = th.c.accent2, th.size.hair * 3, band(pad)
    local dot = px(6)
    for _i, bx in ipairs({ x + math.floor(b / 2) - px(4), x + w - math.floor(b / 2) + px(4) }) do
        Paint.fill(bb, bx - px(3), y + top + px(8), hair, h - top - px(16), c)
        Paint.fill(bb, bx + px(3), y + top + px(8), hair, h - top - px(16), c)
    end
    local rnd = Profile.rng("cyberui-frame-circuit")
    for yy = y + top + px(24), y + h - px(40), px(36) do
        local stub = px(6) + math.floor(rnd() * px(8))
        Paint.fill(bb, x + px(2), yy, math.floor(b / 2) - px(6), hair, c)
        Paint.fill(bb, x + px(2) - 1, yy - 3, dot, dot, c)
        Paint.fill(bb, x + w - math.floor(b / 2) + px(6), yy + px(14), math.floor(b / 2) - px(6) - stub + px(2), hair, c)
        Paint.fill(bb, x + w - px(2) - dot, yy + px(11), dot, dot, c)
    end
    -- a chip with legs, bottom left, and a trace to its right
    local cx, cy = x + b + px(8), y + h - b + px(2)
    Paint.frame(bb, cx, cy, px(46), b - px(10), hair, c)
    for k = 0, 4 do
        Paint.fill(bb, cx + px(5) + k * px(9), cy - px(5), hair, px(5), c)
        Paint.fill(bb, cx + px(5) + k * px(9), cy + b - px(10), hair, px(5), c)
    end
    local ty = cy + math.floor((b - px(10)) / 2)
    Paint.line(bb, cx + px(46), ty, cx + px(90), ty, hair, c)
    Paint.line(bb, cx + px(90), ty, cx + px(104), ty - px(8), hair, c)
    Paint.line(bb, cx + px(104), ty - px(8), x + w - b - px(10), ty - px(8), hair, c)
    Paint.fill(bb, x + w - b - px(10), ty - px(8) - px(3), dot, dot, c)
    Paint.frame(bb, x + b - px(2), y + top + b - px(2) - px(6), w - 2 * b + px(4), h - top - 2 * b + px(10), th.size.hair, th.c.line)
end

-- A full border of caution stripes, framed in lines.
local function hazard(bb, x, y, w, h, top, pad)
    local th = Theme.get()
    local b, edge = band(pad), th.size.stroke
    local s = b - px(5)
    Paint.stripes(bb, x + edge, y + top, w - 2 * edge, s, "d", px(12), px(6), th.c.accent)
    Paint.stripes(bb, x + edge, y + h - edge - s, w - 2 * edge, s, "d", px(12), px(6), th.c.accent)
    Paint.stripes(bb, x + edge, y + top + s, s, h - top - 2 * s - edge, "d", px(12), px(6), th.c.accent)
    Paint.stripes(bb, x + w - edge - s, y + top + s, s, h - top - 2 * s - edge, "d", px(12), px(6), th.c.accent)
    Paint.frame(bb, x + edge + s, y + top + s, w - 2 * (edge + s), h - top - 2 * s - edge, th.size.hair * 2, th.c.ink)
end

-- The border shifted and split in two colours, broken here and there, with slices torn out of it.
local function glitch(bb, x, y, w, h, top, pad)
    local th = Theme.get()
    local b = band(pad)
    local rnd = Profile.rng("cyberui-frame-glitch")
    local t = px(3)
    Paint.frame(bb, x + px(8), y + top + px(7), w - px(16), h - top - px(14), t, th.c.accent)
    Paint.frame(bb, x + px(14), y + top + px(12), w - px(26), h - top - px(22), th.size.hair * 2, th.c.accent2)
    for _i = 1, 9 do
        -- a gap knocked out of the two lines, on one side or the other
        local gy = y + top + px(20) + math.floor(rnd() * (h - top - px(60)))
        local gx = rnd() > 0.5 and x or x + w - b
        Paint.fill(bb, gx + px(4), gy, b - px(8), px(2) + math.floor(rnd() * px(8)), th.c.bg)
    end
    for _i = 1, 5 do
        local gx = x + b + math.floor(rnd() * (w - 2 * b - px(60)))
        local gy = rnd() > 0.5 and y + top + px(6) or y + h - px(12)
        Paint.fill(bb, gx, gy, px(30) + math.floor(rnd() * px(50)), px(7), th.c.bg)
    end
    for k = 1, 5 do
        local sy = y + top + math.floor((h - top) * (0.1 + 0.14 * k))
        Paint.fill(bb, x + px(2), sy, b - px(6) + (k % 2) * px(8), px(5), k % 2 == 0 and th.c.accent or th.c.ink)
        Paint.fill(bb, x + w - px(2) - (b - px(6)) - ((k + 1) % 2) * px(8), sy + px(10), b - px(6) + ((k + 1) % 2) * px(8), px(5), k % 2 == 0 and th.c.ink or th.c.accent2)
    end
    for _i = 1, 10 do
        Paint.fill(bb, x + px(4) + math.floor(rnd() * (w - px(12))), y + h - px(5) - math.floor(rnd() * px(18)), px(5), px(5), th.c.accent)
    end
end

return {
    { id = "frame.standard", name = _("STANDARD"), price = 0 },
    { id = "frame.notch", name = _("NOTCH"), price = 100, inset = 10, draw = notch },
    { id = "frame.circuit", name = _("CIRCUIT"), price = 250, inset = 14, draw = circuit },
    { id = "frame.hazard", name = _("HAZARD"), price = 450, inset = 12, draw = hazard },
    { id = "frame.glitch", name = _("GLITCH"), price = 900, inset = 14, draw = glitch },
}
