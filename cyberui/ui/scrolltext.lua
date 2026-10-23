-- Text longer than its box, shown a page at a time (e-ink friendly scrolling):
-- a tap turns to the next page and wraps back to the first. The owner keeps
-- the page in `state` across rebuilds and redraws in on_turn; turn(-1) goes
-- back, for owners that page with swipes. A counter sits at the bottom right
-- when there is more than one page.

local Element = require("cyberui/ui/element")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local ScrollText = Element:extend({ kind = "body", color = "ink" })

-- No height of its own: it fills what its parent gives it.
function ScrollText:naturalHeight()
    return self.height or Text.height(self.kind)
end

-- Wrap the whole text and cut it into pages that fit the height.
function ScrollText:layout(w, h)
    self.w = self.width or w
    self.h = self.height or h or Text.height(self.kind)
    self.state = self.state or {}
    local lh = Text.height(self.kind)
    self.all = Text.wrap(self.kind, self.text, self.w, math.huge)
    self.per = math.max(1, math.floor(self.h / lh))
    if #self.all > self.per then
        -- leave a line for the page counter
        self.per = math.max(1, math.floor((self.h - Text.height("micro")) / lh))
    end
    self.pages = math.max(1, math.ceil(#self.all / self.per))
    self.state.page = math.max(1, math.min(self.state.page or 1, self.pages))
    self.on_tap = self.pages > 1 and function() self:turn(1, true) end or nil
end

-- Turn `by` pages; `wrap` goes round from the last page to the first.
-- True when the page changed.
function ScrollText:turn(by, wrap)
    if self.pages < 2 then return false end
    local p = self.state.page + by
    if wrap then p = (p - 1) % self.pages + 1 end
    if p < 1 or p > self.pages then return false end
    self.state.page = p
    if self.on_turn then self.on_turn() end
    return true
end

-- Draw the lines of the current page and the counter.
function ScrollText:draw(bb, x, y)
    local color = Theme.color(self.color)
    local lh = Text.height(self.kind)
    local first = (self.state.page - 1) * self.per
    for i = 1, self.per do
        local line = self.all[first + i]
        if not line then break end
        Text.draw(bb, x, y + (i - 1) * lh, self.kind, line, color)
    end
    if self.pages > 1 then
        local s = string.format("%d/%d %s", self.state.page, self.pages, self.state.page < self.pages and "\u{25BC}" or "\u{25B2}")
        local mh = Text.height("micro")
        Text.draw(bb, x + self.w - Text.width("micro", s), y + self.h - mh, "micro", s, Theme.color("muted"))
    end
end

return ScrollText
