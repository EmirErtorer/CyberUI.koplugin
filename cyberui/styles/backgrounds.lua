-- ID card backgrounds: a whole scene behind the card's contents. Each style
-- is { id, name, price, draw(bb, x, y, w, h, top) } and draws below the title
-- strip (`top` tall), in the quiet colours of the theme so the text on it
-- stays easy to read. A style without draw is the plain card.

local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local px = Theme.px

-- A blueprint sheet: a tinted ground, a fine grid with a bold line every fifth,
-- centre lines and registration marks at the corners.
local function blueprint(bb, x, y, w, h, top)
    local th = Theme.get()
    local gy, gh, step = y + top, h - top, px(18)
    Paint.fill(bb, x, gy, w, gh, th.c.soft)
    for k = 0, math.floor(w / step) do
        Paint.fill(bb, x + k * step, gy, k % 5 == 0 and th.size.hair * 2 or th.size.hair, gh, th.c.line)
    end
    for k = 0, math.floor(gh / step) do
        Paint.fill(bb, x, gy + k * step, w, k % 5 == 0 and th.size.hair * 2 or th.size.hair, th.c.line)
    end
    local cx, cy, arm = x + math.floor(w / 2), gy + math.floor(gh / 2), px(18)
    Paint.fill(bb, cx - arm, cy, 2 * arm, th.size.hair * 2, th.c.accent)
    Paint.fill(bb, cx, cy - arm, th.size.hair * 2, 2 * arm, th.c.accent)
    for _i, mx in ipairs({ x + px(10), x + w - px(10) - px(16) }) do
        for _j, my in ipairs({ gy + px(8), y + h - px(8) - px(16) }) do
            Paint.frame(bb, mx, my, px(16), px(16), th.size.hair * 2, th.c.accent)
        end
    end
end

-- A tube screen: a tinted ground under dark raster lines, a bright sweep, dark corners.
local function crt(bb, x, y, w, h, top)
    local th = Theme.get()
    local gy, gh = y + top, h - top
    Paint.fill(bb, x, gy, w, gh, th.c.soft)
    Paint.stripes(bb, x, gy, w, gh, "h", px(4), px(2), th.c.bg)
    Paint.fill(bb, x, gy + math.floor(gh * 0.2), w, px(30), th.c.line)
    Paint.stripes(bb, x, gy + math.floor(gh * 0.2), w, px(30), "h", px(4), px(2), th.c.soft)
    Paint.fill(bb, x, gy + math.floor(gh * 0.2) + px(30), w, th.size.hair * 2, th.c.muted)
    for k = 0, 3 do
        Paint.fill(bb, x, gy + k * px(5), w - k * px(40), px(2), th.c.bg)
        Paint.fill(bb, x + k * px(40), y + h - k * px(5) - px(2), w - k * px(40), px(2), th.c.bg)
    end
end

-- A circuit board: bold routes and chips over the whole card.
local function board(bb, x, y, w, h, top)
    local th = Theme.get()
    local rnd = Profile.rng("cyberui-board")
    local gy, gh = y + top, h - top
    Paint.fill(bb, x, gy, w, gh, th.c.soft)
    local t, pad = px(2), px(8)
    for _i = 1, 16 do
        local sx, sy = x + math.floor(rnd() * w), gy + math.floor(rnd() * gh)
        local dir, run = rnd() > 0.5 and 1 or -1, px(30) + math.floor(rnd() * px(110))
        local ex = math.max(x + pad, math.min(x + w - pad, sx + dir * run))
        local drop = (rnd() > 0.5 and 1 or -1) * (px(14) + math.floor(rnd() * px(30)))
        if sy + drop < gy + pad or sy + drop > gy + gh - pad then drop = -drop end   -- stay on the card
        sy = math.max(gy + pad, math.min(gy + gh - pad, sy))
        if sy + drop < gy + pad or sy + drop > gy + gh - pad then drop = 0 end
        local mx = ex + dir * math.abs(drop)
        mx = math.max(x + pad, math.min(x + w - pad, mx))
        Paint.line(bb, sx, sy, ex, sy, t, th.c.line)
        Paint.line(bb, ex, sy, mx, sy + drop, t, th.c.line)
        Paint.fill(bb, sx - pad, sy - math.floor(pad / 2), pad, pad, th.c.muted)
        Paint.frame(bb, mx - pad, sy + drop - math.floor(pad / 2), pad, pad, t, th.c.muted)
    end
    for _i, at in ipairs({ { 0.5, 0.04 }, { 0.74, 0.14 } }) do
        local cx, cy = x + math.floor(w * at[1]), math.min(gy + math.floor(gh * at[2]), gy + gh - px(60))
        cy = math.max(cy, gy + px(10))
        Paint.fill(bb, cx, cy, px(70), px(44), th.c.bg)
        Paint.frame(bb, cx, cy, px(70), px(44), t, th.c.muted)
        for k = 0, 5 do
            Paint.fill(bb, cx + px(6) + k * px(11), cy - px(5), t, px(5), th.c.muted)
            Paint.fill(bb, cx + px(6) + k * px(11), cy + px(44), t, px(5), th.c.muted)
        end
    end
end

-- A night city: a banded sky, a low moon, searchlights, two rows of towers with lit windows.
local function city(bb, x, y, w, h, top)
    local th = Theme.get()
    local rnd = Profile.rng("cyberui-night-city")
    local gy, gh = y + top, h - top
    for k = 0, 5 do
        Paint.fill(bb, x, gy + math.floor(gh * k / 6), w, math.ceil(gh / 6), k % 2 == 0 and th.c.soft or th.c.bg)
    end
    local mr = px(38)
    local mx, my = x + math.floor(w * 0.78), gy + math.floor(gh * 0.3)
    local ring = {}
    for i = 0, 17 do
        local a = i * math.pi / 9
        ring[#ring + 1] = { mx + mr * math.cos(a), my + mr * math.sin(a) }
    end
    Paint.polygon(bb, ring, th.c.line)
    for _i = 1, 2 do
        local bx = x + px(60) + math.floor(rnd() * (w - px(120)))
        Paint.line(bb, bx, y + h - px(30), bx + (rnd() > 0.5 and 1 or -1) * px(50), gy + px(6), px(5), th.c.line)
    end
    local function row(tall, fill, window, light)
        local xx = x
        while xx < x + w do
            local tw = math.min(px(22) + math.floor(rnd() * px(30)), x + w - xx)
            local tt = math.floor(tall * (0.3 + rnd() * 0.7))
            Paint.fill(bb, xx, y + h - tt, tw, tt, fill)
            if rnd() > 0.5 then Paint.fill(bb, xx + math.floor(tw / 2), y + h - tt - px(14), px(2), px(14), fill) end
            if light and rnd() > 0.6 then Paint.fill(bb, xx + math.floor(tw / 2) - px(2), y + h - tt - px(18), px(5), px(5), th.c.accent) end
            for wy = y + h - tt + px(8), y + h - px(8), px(11) do
                for wx = xx + px(5), xx + tw - px(7), px(10) do
                    if rnd() > 0.65 then Paint.fill(bb, wx, wy, px(4), px(6), window) end
                end
            end
            xx = xx + tw + px(3)
        end
    end
    row(math.floor(gh * 0.62), th.c.line, th.c.soft, false)
    row(math.floor(gh * 0.42), th.c.soft, th.c.muted, true)
end

return {
    { id = "background.plain", name = _("PLAIN"), price = 0 },
    { id = "background.grid", name = _("GRID"), price = 100, draw = blueprint },
    { id = "background.scanlines", name = _("SCANLINES"), price = 220, draw = crt },
    { id = "background.traces", name = _("TRACES"), price = 480, draw = board },
    { id = "background.skyline", name = _("NIGHT CITY"), price = 900, draw = city },
}
