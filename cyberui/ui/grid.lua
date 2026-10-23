-- A paged grid: fills its box with as many equal cells as fit, shows one page
-- of `items` and reports how many fit (on_layout) so the screen can page.
-- One column makes it a paged list.

local Element = require("cyberui/ui/element")
local Theme = require("cyberui/theme")

local Grid = Element:extend({ cols = 3, page = 1 })

-- Size the cells and build the elements of the current page.
function Grid:layout(w, h)
    self.w = self.width or w
    self.h = self.height or h or 0
    local gap = self.gap or Theme.get().space.m
    local row_gap = self.row_gap or gap
    local cell_w = math.floor((self.w - gap * (self.cols - 1)) / self.cols)
    local cell_h = self.cell_h or math.floor(cell_w * (self.ratio or 1.5))
    local rows = math.max(1, math.floor((self.h + row_gap) / (cell_h + row_gap)))
    local capacity = rows * self.cols
    local pages = math.max(1, math.ceil(#self.items / capacity))
    self.page = math.max(1, math.min(self.page, pages))
    self.children = {}
    local first = (self.page - 1) * capacity
    for i = 1, capacity do
        local item = self.items[first + i]
        if not item then break end
        local el = self.make(item, cell_w, cell_h)
        el:layout(cell_w, cell_h)
        self.children[i] = el
    end
    self.cell_w, self.cell_h, self.gap_x, self.gap_y = cell_w, cell_h, gap, row_gap
    if self.on_layout then self.on_layout(capacity, pages, self.page) end
end

-- Paint the cells row by row.
function Grid:paint(bb, x, y)
    self.x, self.y = x, y
    for i, el in ipairs(self.children) do
        local col = (i - 1) % self.cols
        local row = math.floor((i - 1) / self.cols)
        el:paint(bb, x + col * (self.cell_w + self.gap_x), y + row * (self.cell_h + self.gap_y))
    end
end

return Grid
