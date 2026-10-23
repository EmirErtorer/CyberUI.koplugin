-- A paged grid: fills its box with as many equal cells as fit, shows one page
-- of `items` and reports how many fit (on_layout) so the screen can page.
-- Columns are fixed by `cols`, or as many as fit cells `min_cell_w` wide.
-- One column makes it a paged list.

local Element = require("cyberui/ui/element")
local Theme = require("cyberui/theme")

local Grid = Element:extend({ page = 1 })

-- Size the cells and build the elements of the current page.
function Grid:layout(w, h)
    self.w = self.width or w
    self.h = self.height or h or 0
    local gap = self.gap or Theme.get().space.m
    local row_gap = self.row_gap or gap
    local cols = self.cols or math.max(2, math.floor((self.w + gap) / ((self.min_cell_w or Theme.px(120)) + gap)))
    local cell_w = math.floor((self.w - gap * (cols - 1)) / cols)
    local cell_h = self.cell_h or math.floor(cell_w * (self.ratio or 1.5))
    -- a row taller than the box (big covers on a landscape screen): narrower
    -- cells, more to a row, until one row fits
    while not self.cell_h and not self.cols and cell_h > self.h and cell_w > Theme.px(40) do
        cols = cols + 1
        cell_w = math.floor((self.w - gap * (cols - 1)) / cols)
        cell_h = math.floor(cell_w * (self.ratio or 1.5))
    end
    self.ncols = cols
    local rows = math.max(1, math.floor((self.h + row_gap) / (cell_h + row_gap)))
    local capacity = rows * cols
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
        local col = (i - 1) % self.ncols
        local row = math.floor((i - 1) / self.ncols)
        el:paint(bb, x + col * (self.cell_w + self.gap_x), y + row * (self.cell_h + self.gap_y))
    end
end

return Grid
