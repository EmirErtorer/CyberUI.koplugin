-- Small charts for the reading log: a bar chart whose bars can be tapped and
-- a calendar heatmap. Shades come from theme roles, lightest to darkest.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Charts = {}

-- The theme roles used for heatmap levels 0 (nothing) to 4 (most).
local LEVELS = { "bg", "soft", "line", "muted", "ink" }

---------------------------------------------------------------- Bar
local Bar = Element:extend({})

-- One bar: outlined, filled when selected, sitting on the baseline.
function Bar:draw(bb, x, y)
    local th = Theme.get()
    local bh = math.floor(self.h * self.frac + 0.5)
    local bw = math.floor(self.w * 0.6)
    local bx = x + math.floor((self.w - bw) / 2)
    if bh <= 0 then return end
    if self.selected then Paint.fill(bb, bx, y + self.h - bh, bw, bh, th.c.ink)
    else Paint.frame(bb, bx, y + self.h - bh, bw, bh, th.size.stroke, th.c.ink) end
end

---------------------------------------------------------------- Bars
local Bars = Element:extend({ selected = 0 })
Charts.Bars = Bars

-- Make one tappable bar per value.
function Bars:init()
    self.children = {}
    local max = self.goal or 0
    for _i, v in ipairs(self.values) do max = math.max(max, v) end
    self.max = math.max(max, 1)
    for i, v in ipairs(self.values) do
        self.children[i] = Bar:new({ frac = v / self.max, selected = i == self.selected,
            on_tap = function() if self.on_select then self.on_select(i) end end })
    end
end

-- Bars share the width; labels take a line under them.
function Bars:layout(w, h)
    self.w = self.width or w
    self.h = self.height or h or Theme.px(140)
    local label_h = Text.height("micro") + Theme.px(4)
    local n = #self.children
    self.bar_w = math.floor(self.w / n)
    for _i, c in ipairs(self.children) do c:layout(self.bar_w, self.h - label_h) end
end

-- Baseline, goal line, bars and day labels.
function Bars:paint(bb, x, y)
    self.x, self.y = x, y
    local th = Theme.get()
    local chart_h = self.children[1].h
    for i, c in ipairs(self.children) do
        c:paint(bb, x + (i - 1) * self.bar_w, y)
        local s = Text.fit("micro", self.labels[i])
        Text.draw(bb, x + (i - 1) * self.bar_w + math.floor((self.bar_w - Text.width("micro", s)) / 2),
            y + chart_h + Theme.px(4), "micro", s, i == self.selected and th.c.ink or th.c.muted)
    end
    Paint.fill(bb, x, y + chart_h - th.size.stroke, self.w, th.size.stroke, th.c.ink)
    if self.goal and self.goal > 0 then
        local gy = y + chart_h - math.floor(chart_h * self.goal / self.max)
        local dash = Theme.px(6)
        for gx = x, x + self.w - 1, 2 * dash do Paint.fill(bb, gx, gy, math.min(dash, x + self.w - gx), th.size.hair, th.c.muted) end
    end
end

---------------------------------------------------------------- Heatmap
local Heatmap = Element:extend({ weeks = 12 })
Charts.Heatmap = Heatmap

-- Seven rows of square cells, one column per week.
function Heatmap:naturalHeight()
    return 7 * Theme.px(12) + 6 * Theme.px(3)
end

-- Cells from oldest (top-left) to today, shaded by level 0..4; each week is
-- a column sharing the width, each day a row.
function Heatmap:draw(bb, x, y)
    local th = Theme.get()
    local gap = Theme.px(3)
    local cell_w = math.floor((self.w - gap * (self.weeks - 1)) / self.weeks)
    local cell_h = Theme.px(12)
    for i, level in ipairs(self.levels) do
        local week = math.floor((i - 1) / 7)
        local day = (i - 1) % 7
        local cx, cy = x + week * (cell_w + gap), y + day * (cell_h + gap)
        Paint.fill(bb, cx, cy, cell_w, cell_h, th.c[LEVELS[level + 1]])
        Paint.frame(bb, cx, cy, cell_w, cell_h, th.size.hair, th.c.line)
    end
end

return Charts
