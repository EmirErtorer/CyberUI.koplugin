-- A reading history as a night city: one building per day (or week), as tall as
-- the pages read and with a lit window for every few minutes. Days with no
-- reading are empty lots. Buildings are drawn in ink with paper-coloured lit
-- windows, so it reads the same on any screen; the accent marks today's
-- beacon and the signs on top of weeks a book was finished.
--
-- Fields: buildings = { { pages, minutes, current, sign } ... }, labels =
-- { [index] = text } under some of them, minutes_per_window, height (px).

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Skyline = Element:extend({ minutes_per_window = 5, height = 150 })

-- The roof styles, picked per building so the skyline is not a bar chart (the
-- third, a flat roof, needs nothing drawn).
local ANTENNA, STEPPED = 2, 3

-- Room for the day labels under the ground line.
local function labelRoom()
    return Text.height("micro") + Theme.px(4)
end

-- Fixed height.
function Skyline:naturalHeight()
    return Theme.px(self.height)
end

-- A moon and a few stars in the sky above the buildings.
local function sky(bb, x, y, w, h, th)
    local r = Theme.px(7)
    local mx, my = x + w - r - Theme.px(10), y + r + Theme.px(6)
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy) + 0.5)
        Paint.fill(bb, mx - half, my + dy, 2 * half, 1, th.c.muted)
    end
    local rnd = Profile.rng("skyline")
    for _i = 1, 7 do
        local sx, sy = x + math.floor(rnd() * (w - Theme.px(30))), y + math.floor(rnd() * h * 0.4)
        Paint.fill(bb, sx, sy, Theme.px(2), Theme.px(2), th.c.line)
    end
end

-- One building at x with its base on `ground`: body, roof and windows.
local function building(bb, b, i, x, ground, bw, bh, th, per_window, chart_h)
    local roof = i % 3 + 1
    local body_h = bh
    if roof == STEPPED and bh > Theme.px(14) then
        local sw = math.floor(bw * 0.6)
        Paint.fill(bb, x + math.floor((bw - sw) / 2), ground - bh - Theme.px(4), sw, Theme.px(4), th.c.ink)
    elseif roof == ANTENNA and bh > Theme.px(10) then
        local ah = math.min(Theme.px(10), chart_h - bh)
        if ah > 0 then Paint.fill(bb, x + math.floor(bw / 2), ground - bh - ah, th.size.hair * 2, ah, th.c.ink) end
    end
    Paint.fill(bb, x, ground - body_h, bw, body_h, th.c.ink)
    -- windows: a grid inside the body, the first few of a shuffled order lit
    local ww = math.max(2, math.floor(bw / 4))
    local margin = math.max(2, math.floor(bw / 6))
    local cols = math.max(1, math.floor((bw - 2 * margin + ww) / (2 * ww)))
    local rows = math.max(1, math.floor((body_h - 2 * margin + ww) / (2 * ww)))
    local total = cols * rows
    local lit = math.min(total, math.ceil((b.minutes or 0) / per_window))
    if lit > 0 and bw >= 6 and body_h >= 2 * margin + ww then
        local rnd = Profile.rng("w" .. i)
        local order = {}
        for k = 1, total do order[k] = k end
        for k = total, 2, -1 do
            local j = 1 + math.floor(rnd() * k)
            order[k], order[j] = order[j], order[k]
        end
        local gx = bw - 2 * margin
        for n = 1, lit do
            local k = order[n] - 1
            local c, r = k % cols, math.floor(k / cols)
            local wx = x + margin + (cols > 1 and math.floor(c * (gx - ww) / (cols - 1)) or math.floor((gx - ww) / 2))
            Paint.fill(bb, wx, ground - body_h + margin + r * 2 * ww, ww, ww, th.c.bg)
        end
    end
    if b.sign then Paint.fill(bb, x, ground - bh - Theme.px(5), bw, Theme.px(4), th.c.accent) end
    if b.current then Paint.fill(bb, x + math.floor(bw / 2) - 1, ground - bh - Theme.px(8), 3, Theme.px(3), th.c.accent) end
end

-- Draw the sky, the buildings, the ground line and the labels.
function Skyline:draw(bb, x, y)
    local th = Theme.get()
    local n = #self.buildings
    if n == 0 then return end
    local room = labelRoom()
    local ground = y + self.h - room
    local chart_h = ground - y - Theme.px(8)
    sky(bb, x, y, self.w, chart_h, th)
    local slot = self.w / n
    local gap = slot >= 8 and Theme.px(2) or 1
    local max = 1
    for _i, b in ipairs(self.buildings) do max = math.max(max, b.pages or 0) end
    local top = math.floor(chart_h * 0.84)   -- the tallest body, leaving room for roofs
    for i, b in ipairs(self.buildings) do
        local bx = x + math.floor((i - 1) * slot)
        local bw = math.max(3, math.floor(slot) - gap)
        if (b.pages or 0) > 0 then
            local bh = math.max(Theme.px(8), math.floor(top * math.sqrt(b.pages / max)))
            building(bb, b, i, bx, ground, bw, bh, th, self.minutes_per_window, chart_h)
        else
            -- an empty lot: rubble along the ground
            Paint.fill(bb, bx, ground - th.size.stroke - 1, bw, 1, th.c.line)
            if b.current then Paint.fill(bb, bx + math.floor(bw / 2) - 1, ground - Theme.px(8), 3, Theme.px(3), th.c.accent) end
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
