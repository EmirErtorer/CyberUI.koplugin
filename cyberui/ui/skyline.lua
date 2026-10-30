-- A reading history as a night city. Each day (or week) is a tower, as tall as
-- the pages read and with more of its windows lit the longer it was read (15%
-- of them at least, 85% for the longest day); days
-- with no reading are rubble. Behind the towers a pale second skyline gives the
-- city depth. Towers are built from their own seed (ziggurat, core and wings,
-- twin spires), with antennas, a beacon on today, a billboard on a week a book
-- was finished and a neon strip on some, so no two look alike. All of it is
-- flat rectangles and slants in ink and paper, so it reads the same on any
-- screen; the accent colour only marks the lights and signs.
--
-- Fields: buildings = { { pages, minutes, current, sign } ... }, labels =
-- { [index] = text } under some of them, height (px).

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Skyline = Element:extend({ height = 150 })

-- How wide a tower may be, and the lowest a tower stands.
local MAX_WIDTH, MIN_HEIGHT = 64, 16

-- The tiers of each tower style as { width share, height share } from the
-- ground up (a "twin" is drawn as two columns and a bridge instead).
local STYLES = {
    { { 1, 0.5 }, { 0.78, 0.3 }, { 0.5, 0.2 } },   -- ziggurat
    { { 1, 0.62 }, { 0.58, 0.38 } },               -- block with a core
    { { 1, 0.7 }, { 0.34, 0.3 } },                 -- block with a spire
    "twin",
}

-- Room for the day labels under the ground line.
local function labelRoom()
    return Text.height("micro") + Theme.px(4)
end

-- Fixed height.
function Skyline:naturalHeight()
    return Theme.px(self.height)
end

-- A moon and a few stars in the sky.
local function sky(bb, x, y, w, h, th)
    local r = Theme.px(7)
    local mx, my = x + w - r - Theme.px(10), y + r + Theme.px(6)
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy) + 0.5)
        Paint.fill(bb, mx - half, my + dy, 2 * half, 1, th.c.muted)
    end
    local rnd = Profile.rng("skyline")
    for _i = 1, 9 do
        local sx, sy = x + math.floor(rnd() * (w - Theme.px(30))), y + math.floor(rnd() * h * 0.4)
        Paint.fill(bb, sx, sy, Theme.px(2), Theme.px(2), th.c.line)
    end
end

-- The far city: a row of pale, windowless blocks of every size behind the towers.
local function backdrop(bb, x, ground, w, top, th)
    local rnd = Profile.rng("far-city")
    local cx = x
    while cx < x + w do
        local bw = Theme.px(12) + math.floor(rnd() * Theme.px(26))
        local bh = math.floor(top * (0.2 + rnd() * 0.45))
        bw = math.min(bw, x + w - cx)
        Paint.fill(bb, cx, ground - bh, bw, bh, th.c.line)
        if rnd() < 0.3 then Paint.fill(bb, cx + math.floor(bw / 2), ground - bh - Theme.px(7), 1, Theme.px(7), th.c.line) end
        if rnd() < 0.2 then Paint.fill(bb, cx + Theme.px(2), ground - bh - Theme.px(3), math.max(2, bw - Theme.px(4)), Theme.px(3), th.c.line) end
        cx = cx + bw + (rnd() < 0.35 and Theme.px(3) or 0)
    end
end

-- The windows of a block at (x, y) (top left), w x h: their top-left corners.
local function windowGrid(list, x, y, w, h, ww)
    local pitch = ww * 2
    local cols = math.floor((w - 2 * ww + ww) / pitch)
    local rows = math.floor((h - 2 * ww + ww) / pitch)
    if cols < 1 or rows < 1 then return end
    local gx = math.floor((w - (cols * pitch - ww)) / 2)
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do list[#list + 1] = { x + gx + c * pitch, y + ww + r * pitch } end
    end
end

-- Light `n` of the windows, chosen by the tower's own seed.
local function lightWindows(bb, list, n, ww, seed, th)
    local rnd = Profile.rng(seed)
    for k = #list, 2, -1 do
        local j = 1 + math.floor(rnd() * k)
        list[k], list[j] = list[j], list[k]
    end
    for k = 1, math.min(n, #list) do Paint.fill(bb, list[k][1], list[k][2], ww, ww, th.c.bg) end
end

-- One tower with its base on `ground`: body, windows, roof gear and signs.
-- `lit` is the share (0..1) of its windows that are lit.
local function tower(bb, b, i, x, ground, bw, bh, lit, th)
    local rnd = Profile.rng("tower" .. i)
    local style = STYLES[1 + math.floor(rnd() * #STYLES)]
    local ww = math.max(2, Theme.px(3))
    local windows = {}
    local roof_x, roof_y, roof_w
    if bw < Theme.px(14) then style = { { 1, 1 } } end
    if style == "twin" then
        local cw = math.floor(bw * 0.36)
        Paint.fill(bb, x, ground - bh, cw, bh, th.c.ink)
        Paint.fill(bb, x + bw - cw, ground - bh, cw, bh, th.c.ink)
        Paint.fill(bb, x + cw, ground - math.floor(bh * 0.55), bw - 2 * cw, math.max(3, Theme.px(4)), th.c.ink)
        windowGrid(windows, x, ground - bh, cw, bh, ww)
        windowGrid(windows, x + bw - cw, ground - bh, cw, bh, ww)
        roof_x, roof_y, roof_w = x, ground - bh, cw
        -- a spire on each column
        Paint.fill(bb, x + math.floor(cw / 2), ground - bh - Theme.px(8), 2, Theme.px(8), th.c.ink)
        Paint.fill(bb, x + bw - math.floor(cw / 2) - 2, ground - bh - Theme.px(8), 2, Theme.px(8), th.c.ink)
    else
        local used = 0
        for t, tier in ipairs(style) do
            local tw = math.max(3, math.floor(bw * tier[1]))
            local tier_h = t == #style and bh - used or math.floor(bh * tier[2])
            local tx = x + math.floor((bw - tw) / 2)
            Paint.fill(bb, tx, ground - used - tier_h, tw, tier_h, th.c.ink)
            windowGrid(windows, tx, ground - used - tier_h, tw, tier_h, ww)
            used = used + tier_h
            roof_x, roof_y, roof_w = tx, ground - used, tw
        end
        if style[1][1] ~= 1 or #style > 1 then
            -- a mast on the top tier
            local mast = math.min(Theme.px(16), Theme.px(8) + math.floor(rnd() * Theme.px(10)))
            Paint.fill(bb, roof_x + math.floor(roof_w / 2) - 1, roof_y - mast, 2, mast, th.c.ink)
        end
    end
    lightWindows(bb, windows, math.max((b.minutes or 0) > 0 and 1 or 0, math.floor(#windows * lit + 0.5)), ww, "w" .. i, th)
    -- a red light on some roofs, always on today's
    if b.current then
        Paint.fill(bb, roof_x + math.floor(roof_w / 2) - 2, roof_y - Theme.px(11), 5, 5, th.c.accent)
    elseif rnd() < 0.35 then
        Paint.fill(bb, roof_x + math.floor(roof_w / 2) - 1, roof_y - Theme.px(5), 3, 3, th.c.accent)
    end
    -- a billboard on a week a book was finished: an accent panel with two dark bars
    if b.sign and bw >= Theme.px(14) then
        local sw, sh = math.max(Theme.px(10), math.floor(bw * 0.7)), Theme.px(11)
        local sx, sy = x + math.floor((bw - sw) / 2), ground - math.floor(bh * 0.55)
        Paint.fill(bb, sx, sy, sw, sh, th.c.accent)
        Paint.fill(bb, sx + 2, sy + 3, sw - 4, 2, th.c.ink)
        Paint.fill(bb, sx + 2, sy + 7, math.floor((sw - 4) * 0.6), 2, th.c.ink)
    elseif rnd() < 0.3 and bw >= Theme.px(14) then
        -- a neon strip up the side
        Paint.fill(bb, x + bw - 2, ground - math.floor(bh * 0.7), 2, math.floor(bh * 0.7), th.c.accent)
    end
end

-- Draw the sky, the far city, the towers, the ground line and the labels.
function Skyline:draw(bb, x, y)
    local th = Theme.get()
    local n = #self.buildings
    if n == 0 then return end
    local room = labelRoom()
    local ground = y + self.h - room
    local chart_h = ground - y - Theme.px(8)
    sky(bb, x, y, self.w, chart_h, th)
    backdrop(bb, x, ground, self.w, chart_h, th)
    local slot = self.w / n
    local gap = slot >= 8 and Theme.px(2) or 1
    local max_pages, max_minutes = 1, 1
    for _i, b in ipairs(self.buildings) do
        max_pages, max_minutes = math.max(max_pages, b.pages or 0), math.max(max_minutes, b.minutes or 0)
    end
    local top = math.floor(chart_h * 0.78)   -- the tallest body, leaving room for masts
    for i, b in ipairs(self.buildings) do
        local rnd = Profile.rng("width" .. i)
        local bw = math.max(3, math.min(math.floor(slot * (0.62 + 0.3 * rnd())) - gap, Theme.px(MAX_WIDTH)))
        local bx = x + math.floor((i - 0.5) * slot - bw / 2)
        if (b.pages or 0) > 0 then
            local bh = math.max(Theme.px(MIN_HEIGHT), math.floor(top * math.sqrt(b.pages / max_pages)))
            tower(bb, b, i, bx, ground, bw, bh, 0.15 + 0.7 * (b.minutes or 0) / max_minutes, th)
        else
            -- rubble along the ground; today's empty lot still gets its light
            Paint.fill(bb, bx, ground - th.size.stroke - 1, bw, 1, th.c.ink)
            Paint.fill(bb, bx + math.floor(bw / 3), ground - th.size.stroke - 3, math.max(2, math.floor(bw / 3)), 2, th.c.ink)
            if b.current then Paint.fill(bb, bx + math.floor(bw / 2) - 2, ground - Theme.px(10), 5, 5, th.c.accent) end
        end
    end
    Paint.fill(bb, x, ground, self.w, th.size.stroke, th.c.ink)
    for i, text in pairs(self.labels or {}) do
        local s = Text.fit("micro", text)
        local cx = x + math.floor((i - 0.5) * slot)
        Text.draw(bb, math.min(math.max(x, cx - math.floor(Text.width("micro", s) / 2)), x + self.w - Text.width("micro", s)),
            ground + Theme.px(4), "micro", s, th.c.muted)
    end
end

return Skyline
