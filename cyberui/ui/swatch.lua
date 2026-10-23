-- A row of colour squares: a scheme's palette, or one colour to pick.

local Element = require("cyberui/ui/element")
local Color = require("cyberui/theme/color")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local Swatch = Element:extend({})

-- As wide as its squares.
function Swatch:naturalWidth()
    local s, gap = Theme.px(self.size or 18), Theme.px(3)
    return #self.colors * s + (#self.colors - 1) * gap
end

-- One square tall.
function Swatch:naturalHeight()
    return Theme.px(self.size or 18)
end

-- Draw each hex colour as an outlined square.
function Swatch:draw(bb, x, y)
    local th = Theme.get()
    local s, gap = math.min(self.h, Theme.px(self.size or 18)), Theme.px(3)
    for i, hex in ipairs(self.colors) do
        local sx = x + (i - 1) * (s + gap)
        Paint.fill(bb, sx, y + math.floor((self.h - s) / 2), s, s, Color.toScreen(Color.parse(hex), th.colour))
        Paint.frame(bb, sx, y + math.floor((self.h - s) / 2), s, s, th.size.hair, th.c.ink)
    end
end

return Swatch
