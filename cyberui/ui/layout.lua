-- Layout containers: Column and Row stack children with a gap and padding and
-- share spare room among children marked `grow`; Overlay draws children on top
-- of each other; Spacer is empty room.

local Element = require("cyberui/ui/element")

local Layout = {}

-- Padding as top, right, bottom, left from a number, a {vertical, horizontal}
-- pair or a {top, right, bottom, left} table.
local function pads(p)
    if type(p) == "table" then
        if #p == 2 then return p[1], p[2], p[1], p[2] end
        return p[1] or 0, p[2] or 0, p[3] or 0, p[4] or 0
    end
    p = p or 0
    return p, p, p, p
end
Layout.pads = pads

-- Empty room; with `grow` it takes whatever is left over.
Layout.Spacer = Element:extend()

---------------------------------------------------------------- Column
local Column = Element:extend()
Layout.Column = Column

-- Size children top to bottom; `grow` children share the height left over.
function Column:layout(w, h)
    local pt, pr, pb, pl = pads(self.pad)
    self.w = self.width or w or 0
    local inner_w = self.w - pl - pr
    local gap = self.gap or 0
    local used, growers = 0, {}
    for _i, c in ipairs(self.children) do
        if c.grow then
            growers[#growers + 1] = c
        else
            local cw = c.width or (self.align and self.align ~= "stretch" and c:naturalWidth()) or inner_w
            c:layout(math.min(cw, inner_w), c.height)
            used = used + c.h
        end
    end
    used = used + gap * math.max(0, #self.children - 1)
    h = self.height or h
    if self.clip and h then
        -- show only the children that fit; the rest are hidden
        local room = h - pt - pb
        local acc, shown = 0, 0
        for i, c in ipairs(self.children) do
            local need = (c.h or 0) + (i > 1 and gap or 0)
            if acc + need > room then break end
            acc, shown = acc + need, i
        end
        for i = #self.children, shown + 1, -1 do self.children[i] = nil end
        used = acc
    end
    if #growers > 0 then
        local left = math.max(0, (h or used) - pt - pb - used)
        local each = math.floor(left / #growers)
        for i, c in ipairs(growers) do
            local share = (i == #growers) and (left - each * (#growers - 1)) or each
            c:layout(c.width or inner_w, share)
            used = used + c.h
        end
    end
    self.h = h or (used + pt + pb)
end

-- Widest child plus padding, when every child knows its width.
function Column:naturalWidth()
    if self.width then return self.width end
    local _t, r, _b, l = pads(self.pad)
    local widest = 0
    for _i, c in ipairs(self.children) do
        local cw = c:naturalWidth()
        if not cw then return nil end
        widest = math.max(widest, cw)
    end
    return widest + l + r
end

-- Paint children top to bottom, placed across by `align`.
function Column:paint(bb, x, y)
    self.x, self.y = x, y
    self:draw(bb, x, y)
    local pt, pr, _pb, pl = pads(self.pad)
    local inner_w = self.w - pl - pr
    local cy = y + pt
    for _i, c in ipairs(self.children) do
        local cx = x + pl
        if self.align == "center" then cx = cx + math.floor((inner_w - c.w) / 2)
        elseif self.align == "end" then cx = cx + inner_w - c.w end
        c:paint(bb, cx, cy)
        cy = cy + c.h + (self.gap or 0)
    end
end

---------------------------------------------------------------- Row
local Row = Element:extend()
Layout.Row = Row

-- Size children left to right; `grow` children share the width left over.
function Row:layout(w, h)
    local pt, pr, pb, pl = pads(self.pad)
    self.w = self.width or w or 0
    h = self.height or h
    local inner_w = self.w - pl - pr
    local inner_h = h and (h - pt - pb) or nil
    local gap = self.gap or 0
    local used, growers = gap * math.max(0, #self.children - 1), {}
    local stretch = self.valign == "stretch"
    for _i, c in ipairs(self.children) do
        local cw = c.width or (not c.grow and c:naturalWidth())
        if cw then
            c:layout(cw, c.height or (stretch and inner_h) or nil)
            used = used + c.w
        else
            growers[#growers + 1] = c
        end
    end
    if self.clip_start then
        -- too wide: drop children from the start, keeping the last one
        while used > inner_w and #self.children > 1 do
            local c = table.remove(self.children, 1)
            used = used - (c.w or 0) - gap
        end
    end
    local left = math.max(0, inner_w - used)
    local each = #growers > 0 and math.floor(left / #growers) or 0
    for i, c in ipairs(growers) do
        local share = (i == #growers) and (left - each * (#growers - 1)) or each
        c:layout(share, c.height or (stretch and inner_h) or nil)
    end
    if not h then
        local tallest = 0
        for _i, c in ipairs(self.children) do tallest = math.max(tallest, c.h) end
        h = tallest + pt + pb
        if stretch then
            for _i, c in ipairs(self.children) do
                if not c.height then c:layout(c.w, tallest) end
            end
        end
    end
    self.h = h
end

-- Children's widths, gaps and padding added up, when every child knows its width.
function Row:naturalWidth()
    if self.width then return self.width end
    local _t, r, _b, l = pads(self.pad)
    local total = (self.gap or 0) * math.max(0, #self.children - 1)
    for _i, c in ipairs(self.children) do
        local cw = not c.grow and c:naturalWidth()
        if not cw then return nil end
        total = total + cw
    end
    return total + l + r
end

-- Paint children left to right, placed up and down by `valign`.
function Row:paint(bb, x, y)
    self.x, self.y = x, y
    self:draw(bb, x, y)
    local pt, _pr, pb, pl = pads(self.pad)
    local inner_h = self.h - pt - pb
    local cx = x + pl
    for _i, c in ipairs(self.children) do
        local cy = y + pt
        local va = self.valign or "center"
        if va == "center" then cy = cy + math.floor((inner_h - c.h) / 2)
        elseif va == "bottom" then cy = cy + inner_h - c.h end
        c:paint(bb, cx, cy)
        cx = cx + c.w + (self.gap or 0)
    end
end

---------------------------------------------------------------- Overlay
local Overlay = Element:extend()
Layout.Overlay = Overlay

-- Every child gets the whole box (or its own size, placed by its `place`).
function Overlay:layout(w, h)
    self.w = self.width or w or 0
    local tallest = 0
    for _i, c in ipairs(self.children) do
        if c.place then c:layout(c.width or c:naturalWidth(), c.height)
        else c:layout(self.w, self.height or h) end
        tallest = math.max(tallest, c.h)
    end
    self.h = self.height or h or tallest
end

-- Paint children in order; a child with `place` sits at that corner, nudged by `dx`/`dy`.
function Overlay:paint(bb, x, y)
    self.x, self.y = x, y
    self:draw(bb, x, y)
    for _i, c in ipairs(self.children) do
        local cx, cy = x, y
        local p = c.place
        if p then
            if p:find("r", 1, true) then cx = x + self.w - c.w end
            if p:find("b", 1, true) then cy = y + self.h - c.h end
            if p == "c" then cx, cy = x + math.floor((self.w - c.w) / 2), y + math.floor((self.h - c.h) / 2) end
            cx, cy = cx + (c.dx or 0), cy + (c.dy or 0)
        end
        c:paint(bb, cx, cy)
    end
end

return Layout
