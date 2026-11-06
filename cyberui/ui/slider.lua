-- A slider for a number from `min` to `max`: the cells of the progress bar
-- filled up to the value, a marker on the edge of the fill and the value after
-- it. A tap sets the value where the finger is and a drag follows the finger;
-- each change calls on_change(value) and asks on_redraw(self) to repaint it.

local Paint = require("cyberui/gfx/paint")
local Progress = require("cyberui/ui/progress")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Slider = Progress:extend({ min = 0, max = 100, value = 0, segments = 20, cell_h = 26, color = "accent", value_w = 52 })

-- Tall enough to hit with a finger.
function Slider:naturalHeight()
    return Theme.px(self.cell_h)
end

-- The width of the cells, without the value's room after them.
function Slider:trackWidth()
    return math.max(1, (self.w or 0) - Theme.px(self.value_w))
end

-- The value for a finger at screen x (in range, whole numbers).
function Slider:valueAt(px)
    local f = math.max(0, math.min(1, (px - self.x) / self:trackWidth()))
    return math.floor(self.min + f * (self.max - self.min) + 0.5)
end

-- Take a new value, tell the owner and repaint when it changed.
function Slider:set(v)
    v = math.max(self.min, math.min(self.max, v))
    if v == self.value then return end
    self.value = v
    if self.on_change then self.on_change(v) end
    if self.on_redraw then self.on_redraw(self) end
end

-- A tap sets the value under the finger.
function Slider:on_tap()
    if self.touch then self:set(self:valueAt(self.touch.x)) end
end

-- A drag follows the finger from where it began.
function Slider:on_drag(dx, _dy, phase)
    if phase == "start" then
        self.drag_x = self.touch and self.touch.x or self.x
        if self.touch then self:set(self:valueAt(self.touch.x)) end
    elseif phase == "move" then
        self:set(self:valueAt(self.drag_x + dx))
    end
end

-- The cells, the marker at the end of the fill and the value after them.
function Slider:draw(bb, x, y)
    local th = Theme.get()
    local range = math.max(1, self.max - self.min)
    local fraction = math.max(0, math.min(1, (self.value - self.min) / range))
    local full = self.w
    self.w = self:trackWidth()
    local keep = self.value
    self.value = fraction   -- the bar draws a fraction
    Progress.draw(self, bb, x, y)
    self.value = keep
    local mx = x + math.floor(fraction * (self.w - Theme.px(4)))
    Paint.fill(bb, mx, y - Theme.px(3), Theme.px(4), self.h + Theme.px(6), th.c.ink)
    self.w = full
    local text = tostring(self.value)
    Text.draw(bb, x + full - Text.width("mono", text), y + math.floor((self.h - Text.height("mono")) / 2), "mono", text, th.c.ink)
end

return Slider
