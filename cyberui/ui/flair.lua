-- A handle flair: the style's badge, as tall as a line of the handle.

local Element = require("cyberui/ui/element")
local Shop = require("cyberui/data/shop")
local Text = require("cyberui/gfx/text")

local Flair = Element:extend()

-- The badge is a square a good deal taller than a line of the handle.
function Flair:side()
    return math.floor(Text.height(self.kind or "display") * 1.4)
end

-- Square, as wide as it is tall.
function Flair:naturalWidth() return self:side() end
function Flair:naturalHeight() return self:side() end

-- Draw the style given as `style` (a flair of the shop), else the worn one.
function Flair:draw(bb, x, y)
    local style = self.style or Shop.worn("flair")
    local s = self:side()
    if style.draw then style.draw(bb, x, y + math.floor((self.h - s) / 2), s) end
end

return Flair
