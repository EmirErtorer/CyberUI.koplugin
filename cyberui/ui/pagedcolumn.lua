-- A column of elements that is too long for its box, shown a page at a time:
-- as many whole items as fit make a page, and a paging row appears under them
-- only when there is more than one page. The owner keeps `page` between
-- rebuilds and learns how many pages there are from on_layout(pages, page),
-- so swipes and the page keys can turn them too.

local Element = require("cyberui/ui/element")
local Theme = require("cyberui/theme")

local PagedColumn = Element:extend({ page = 1 })

-- Cut the items into pages of at most `room` pixels, each laid out at width w.
local function split(items, w, room, gap)
    local pages, cur, used = {}, {}, 0
    for _i, item in ipairs(items) do
        item:layout(w, nil)
        local need = item.h + (#cur > 0 and gap or 0)
        if #cur > 0 and used + need > room then
            pages[#pages + 1] = cur
            cur, used, need = {}, 0, item.h
        end
        cur[#cur + 1] = item
        used = used + need
    end
    pages[#pages + 1] = cur
    return pages
end

-- Lay the items out and pick the page to show.
function PagedColumn:layout(w, h)
    self.w = self.width or w
    self.h = self.height or h or 0
    self.gap = self.gap or Theme.get().space.m
    local pages = split(self.items, self.w, self.h, self.gap)
    if #pages > 1 then
        -- a page is shorter by the paging row
        if not self.pager then self.pager = self.make_pager(self) end
        self.pager:layout(self.w, nil)
        pages = split(self.items, self.w, self.h - self.pager.h - self.gap, self.gap)
    end
    self.pages = #pages
    self.page = math.max(1, math.min(self.page, self.pages))
    self.children = {}
    for i, item in ipairs(pages[self.page]) do self.children[i] = item end
    if self.pages > 1 then self.children[#self.children + 1] = self.pager end
    if self.on_layout then self.on_layout(self.pages, self.page) end
end

-- Paint the page's items from the top and the paging row at the bottom.
function PagedColumn:paint(bb, x, y)
    self.x, self.y = x, y
    local cy = y
    for _i, c in ipairs(self.children) do
        if c == self.pager then
            c:paint(bb, x, y + self.h - c.h)
        else
            c:paint(bb, x, cy)
            cy = cy + c.h + self.gap
        end
    end
end

return PagedColumn
