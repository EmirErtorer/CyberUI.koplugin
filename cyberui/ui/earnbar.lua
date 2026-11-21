-- A book's eddies as a bar: ten cells, one for each tenth of the book that
-- pays, and the finish at the end. A tenth that has paid is filled; one being
-- read is hatched as far as its pages have counted; the finish cell, cut at
-- the corners, fills when the finish has paid.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local EarnBar = Element:extend({ paid = nil, tenths = nil, finish_paid = false, cell_h = 16 })

-- One bar tall.
function EarnBar:naturalHeight()
    return Theme.px(self.cell_h)
end

-- Draw the ten tenths and the finish.
function EarnBar:draw(bb, x, y)
    local th = Theme.get()
    local hair, gap = th.size.hair, th.size.segment_gap
    local ink, accent, muted = Theme.color("ink"), Theme.color("accent"), Theme.color("muted")
    local paid, tenths = self.paid or {}, self.tenths or {}
    -- the finish cell is as wide as two tenths
    local cell = math.max(3, math.floor((self.w - 11 * gap) / 12))
    local h = self.h
    local cx = x
    for k = 1, 10 do
        if paid[k] then
            Paint.fill(bb, cx, y, cell, h, ink)
        else
            local share = math.max(0, math.min(1, tenths[k] or 0))
            local fw = math.floor(cell * share + 0.5)
            if fw > 0 then Paint.stripes(bb, cx, y, fw, h, "d", Theme.px(4), hair, accent) end
            Paint.frame(bb, cx, y, cell, h, hair, muted)
        end
        cx = cx + cell + gap
    end
    local fw = x + self.w - cx
    local cut = math.floor(h / 3)
    if self.finish_paid then
        Paint.chamfer(bb, cx, y, fw, h, cut, "tb", ink)
    else
        Paint.chamferFrame(bb, cx, y, fw, h, cut, "tb", hair, ink)
    end
end

return EarnBar
