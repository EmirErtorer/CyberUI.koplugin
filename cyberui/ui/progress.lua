-- The segmented progress bar: a row of cells, filled up to `value` (0 to 1).

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local Progress = Element:extend({ value = 0, segments = 20, cell_h = 12, color = "ink" })

-- One cell tall.
function Progress:naturalHeight()
    return Theme.px(self.cell_h)
end

-- Draw filled cells up to the value and outlined ones after it.
function Progress:draw(bb, x, y)
    local th = Theme.get()
    local n = self.segments
    local gap = th.size.segment_gap
    local cell = math.floor((self.w - gap * (n - 1)) / n)
    if cell < 2 then n, cell = math.max(1, math.floor(self.w / 4)), 2 end
    local filled = math.floor(math.max(0, math.min(1, self.value)) * n + 0.5)
    local c = Theme.color(self.color)
    local hair = th.size.hair
    -- the last cell takes the rounding left over so the bar ends flush
    local cx = x
    for i = 1, n do
        local cw = (i == n) and (x + self.w - cx) or cell
        if i <= filled then Paint.fill(bb, cx, y, cw, self.h, c)
        else Paint.frame(bb, cx, y, cw, self.h, hair, c) end
        cx = cx + cell + gap
    end
end

return Progress
