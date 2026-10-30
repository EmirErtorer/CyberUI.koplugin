-- A column of fixed items (a caption, a card) over a list of rows that share
-- what room is left: as many rows as fit at about their usual height, each
-- stretched or squeezed a little (between `min` and `max` times `base`) so
-- the column ends where it ends instead of leaving a gap too small for another
-- row. make(i, height, factor) builds row i at that height; factor is the
-- height over `base`, for things that scale with it (a thumbnail).

local Element = require("cyberui/ui/element")

local FitList = Element:extend({ min = 0.88, max = 1.12, gap = 0 })

-- Lay out the head, then the rows that fit.
function FitList:layout(w, h)
    self.w = self.width or w or 0
    self.h = self.height or h or 0
    self.children = {}
    local used = 0
    for _i, c in ipairs(self.head) do
        c:layout(self.w, c.height)
        used = used + c.h + self.gap
        self.children[#self.children + 1] = c
    end
    local room = self.h - used
    local n = math.min(self.count, math.max(0, math.floor((room + self.gap) / (self.base * self.min + self.gap))))
    if n == 0 then return end
    local row_h = math.min(math.floor((room - (n - 1) * self.gap) / n), math.floor(self.base * self.max))
    for i = 1, n do
        local row = self.make(i, row_h, row_h / self.base)
        row:layout(self.w, row_h)
        self.children[#self.children + 1] = row
    end
end

-- Paint the children from the top.
function FitList:paint(bb, x, y)
    self.x, self.y = x, y
    local cy = y
    for _i, c in ipairs(self.children) do
        c:paint(bb, x, cy)
        cy = cy + c.h + self.gap
    end
end

return FitList
