-- A container that frames one child in the style's shapes: "chamfer" (cut
-- corners), "frame" (plain outline), "brackets" (corner marks), "header" (an
-- inverted title strip over a frame), "rail" (a bar down the left, or the
-- right with side = "r") or "none".
-- A `label` sits on the border. `backdrop` and `trim` are optional functions
-- (bb, x, y, w, h, top) that paint behind the content and over the border; top
-- is the height of the title strip.

local Element = require("cyberui/ui/element")
local Layout = require("cyberui/ui/layout")
local Paint = require("cyberui/gfx/paint")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Panel = Element:extend({ shape = "frame", line = "ink", corners = "t", cut = "cut", thick = "stroke", pad = 0 })

-- Padding in pixels; a header strip adds to the top.
function Panel:insets()
    local t, r, b, l = Layout.pads(self.pad)
    if self.shape == "header" then t = t + self:headerHeight() end
    return t, r, b, l
end

-- Height of the header strip.
function Panel:headerHeight()
    return Text.height("label") + 2 * Theme.get().space.s
end

-- The panel's only child (it holds one).
function Panel:init()
    self.children = { self.child }
end

-- Size the child inside the padding.
function Panel:layout(w, h)
    local t, r, b, l = self:insets()
    self.w = self.width or w or ((self.child:naturalWidth() or 0) + l + r)
    h = self.height or h
    self.child:layout(self.w - l - r, h and (h - t - b) or nil)
    self.h = h or (self.child.h + t + b)
end

-- Natural width of the child plus padding.
function Panel:naturalWidth()
    if self.width then return self.width end
    local cw = self.child:naturalWidth()
    if not cw then return nil end
    local _t, r, _b, l = self:insets()
    return cw + l + r
end

-- Draw the frame shape, then the label on the border.
function Panel:draw(bb, x, y)
    local th = Theme.get()
    local w, h = self.w, self.h
    local stroke = th.size[self.thick] or self.thick
    local line = self.line and Theme.color(self.line)
    local fill = self.fill and Theme.color(self.fill)
    local shape = self.shape
    if shape == "chamfer" and not th.decor.chamfer then shape = "frame" end
    if shape == "brackets" and not th.decor.brackets then shape = "none" end
    if shape == "chamfer" then
        Paint.chamferBox(bb, x, y, w, h, th.size[self.cut] or self.cut, self.corners, stroke, fill, line)
    else
        if fill then Paint.fill(bb, x, y, w, h, fill) end
        if self.backdrop then self.backdrop(bb, x, y, w, h, shape == "header" and self:headerHeight() or 0) end
        if shape == "frame" or shape == "header" then
            Paint.frame(bb, x, y, w, h, stroke, line)
        elseif shape == "brackets" then
            Paint.brackets(bb, x, y, w, h, th.size.bracket, stroke, line)
        elseif shape == "rail" then
            local bar = Theme.px(5)
            Paint.fill(bb, self.side == "r" and x + w - bar or x, y, bar, h, line)
        end
    end
    if shape == "header" then
        local hh = self:headerHeight()
        Paint.fill(bb, x, y, w, hh, line)
        local pad = th.space.m
        local ty = y + math.floor((hh - Text.height("label")) / 2)
        if self.title then Text.draw(bb, x + pad, ty, "label", Text.fit("label", self.title, w - 2 * pad), th.c.on_ink) end
        if self.title_right then
            local s = Text.fit("label", self.title_right)
            Text.draw(bb, x + w - pad - Text.width("label", s), ty, "label", s, th.c.on_ink)
        end
    end
    if self.label then
        -- a small caption breaking the top border
        local s = Text.fit("micro", self.label, w)
        local lw = Text.width("micro", s)
        local lh = Text.height("micro")
        local lx = x + th.size.bracket + th.space.s
        local ly = y - math.floor(lh / 2) + math.floor(stroke / 2)
        Paint.fill(bb, lx - th.space.xs, ly, lw + 2 * th.space.xs, lh, fill or th.c.bg)
        Text.draw(bb, lx, ly, "micro", s, th.c.muted)
    end
end

-- Paint the frame, then the child inside the padding.
function Panel:paint(bb, x, y)
    self.x, self.y = x, y
    self:draw(bb, x, y)
    local t, _r, _b, l = self:insets()
    self.child:paint(bb, x + l, y + t)
    if self.trim then self.trim(bb, x, y, self.w, self.h, self.shape == "header" and self:headerHeight() or 0) end
end

return Panel
