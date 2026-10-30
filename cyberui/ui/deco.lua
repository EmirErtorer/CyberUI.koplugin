-- Small decorative elements of the style: a barcode strip, ruler ticks, a
-- divider line and a striped box. Each draws nothing when the style turns its
-- decoration off.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local Deco = {}

-- Is this decoration on in the current style?
local function on(name)
    return Theme.get().decor[name] ~= false
end

-- A barcode strip, with its own bar widths when `bars` is given.
Deco.Barcode = Element:extend({ color = "ink", unit = 1 })
function Deco.Barcode:naturalHeight() return self.height or Theme.px(20) end
function Deco.Barcode:draw(bb, x, y)
    if on("barcode") then Paint.barcode(bb, x, y, self.w, self.h, Theme.px(self.unit), Theme.color(self.color), self.bars) end
end

-- Ruler ticks across the box.
Deco.Ruler = Element:extend({ color = "muted", period = 14 })
function Deco.Ruler:naturalHeight() return self.height or Theme.px(8) end
function Deco.Ruler:draw(bb, x, y)
    if on("ruler") then
        Paint.ticks(bb, x, y, self.w, self.h, Theme.px(self.period), Theme.get().size.hair, Theme.color(self.color))
    end
end

-- A horizontal (or vertical when `vertical`) line.
Deco.Divider = Element:extend({ color = "line", thick = "hair" })
function Deco.Divider:naturalHeight()
    return Theme.get().size[self.thick]
end
function Deco.Divider:draw(bb, x, y)
    Paint.fill(bb, x, y, self.w, self.h, Theme.color(self.color))
end

-- A box filled with stripes ("h", "v", "d", "b").
Deco.Stripes = Element:extend({ color = "line", dir = "h", period = 6, thick = 2 })
function Deco.Stripes:naturalHeight() return self.height or Theme.px(16) end
function Deco.Stripes:draw(bb, x, y)
    if on("hatch") then
        Paint.stripes(bb, x, y, self.w, self.h, self.dir, Theme.px(self.period), Theme.px(self.thick), Theme.color(self.color))
    end
end

return Deco
