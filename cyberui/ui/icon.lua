-- A line icon in a theme colour role.

local Element = require("cyberui/ui/element")
local Icons = require("cyberui/gfx/icons")
local Theme = require("cyberui/theme")

local Icon = Element:extend({ color = "ink", size = 22 })

-- Icons are square: their scaled size both ways.
function Icon:naturalWidth()
    return Theme.px(self.size)
end

-- Same as the width.
function Icon:naturalHeight()
    return Theme.px(self.size)
end

-- Draw the icon centred in its box.
function Icon:draw(bb, x, y)
    local s = Theme.px(self.size)
    Icons.draw(bb, self.name, x + math.floor((self.w - s) / 2), y + math.floor((self.h - s) / 2), s, Theme.color(self.color))
end

return Icon
