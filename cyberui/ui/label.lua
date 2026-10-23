-- A line or a few wrapped lines of text in a theme text kind and colour role,
-- cut with an ellipsis when it does not fit.

local Element = require("cyberui/ui/element")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Label = Element:extend({ kind = "body", color = "ink", align = "left", lines = 1 })

-- Width of the whole text on one line.
function Label:naturalWidth()
    return self.width or Text.width(self.kind, self.text)
end

-- Height of the lines the text needs at width w.
function Label:naturalHeight(w)
    local n = 1
    if self.lines > 1 then n = math.max(1, #Text.wrap(self.kind, self.text, w, self.lines)) end
    return n * Text.height(self.kind)
end

-- Fit the text to the width given (text_fn, when set, gives the text now).
function Label:layout(w, h)
    if self.text_fn then self.text = self.text_fn() end
    self.w = self.width or w or self:naturalWidth()
    if self.lines > 1 then
        self.shown = Text.wrap(self.kind, self.text, self.w, self.lines)
    else
        self.shown = { Text.fit(self.kind, self.text, self.w) }
    end
    self.h = self.height or h or math.max(1, #self.shown) * Text.height(self.kind)
end

-- Draw each line, placed by `align`.
function Label:draw(bb, x, y)
    local color = Theme.color(self.color)
    local lh = Text.height(self.kind)
    local top = y + math.max(0, math.floor((self.h - #self.shown * lh) / 2))
    for i, line in ipairs(self.shown) do
        local lx = x
        if self.align ~= "left" then
            local lw = Text.width(self.kind, line)
            lx = self.align == "center" and x + math.floor((self.w - lw) / 2) or x + self.w - lw
        end
        Text.draw(bb, lx, top + (i - 1) * lh, self.kind, line, color)
    end
end

return Label
