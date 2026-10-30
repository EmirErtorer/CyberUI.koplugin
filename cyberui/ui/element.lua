-- Base of every CyberUI widget: a box its parent sizes with layout(w, h) and
-- paints at an absolute position. Elements with on_tap or on_hold answer
-- gestures through the host's hit test; containers keep `children`.

local Element = {}
Element.__index = Element

-- Make a subclass: Button = Element:extend().
function Element:extend(cls)
    cls = cls or {}
    cls.__index = cls
    return setmetatable(cls, { __index = self })
end

-- Make an instance from a table of properties.
function Element:new(o)
    o = setmetatable(o or {}, self)
    if o.init then o:init() end
    return o
end

-- Preferred width when nothing else decides it (nil means "take what is given").
function Element:naturalWidth()
    return self.width
end

-- Preferred height for a given width.
function Element:naturalHeight(_w)
    return self.height or 0
end

-- Take a size: fixed width/height win, then what the parent gives, then natural.
function Element:layout(w, h)
    self.w = self.width or w or self:naturalWidth() or 0
    self.h = self.height or h or self:naturalHeight(self.w)
end

-- Draw this element's own pixels; subclasses override.
function Element:draw(_bb, _x, _y) end

-- Paint the element and its children with its top-left at (x, y).
function Element:paint(bb, x, y)
    self.x, self.y = x, y
    self:draw(bb, x, y)
end

-- Is the point inside the element's last painted box?
function Element:contains(px, py)
    return self.x ~= nil and px >= self.x and py >= self.y and px < self.x + self.w and py < self.y + self.h
end

-- The innermost element at (px, py) that answers `handler` ("on_tap"...).
function Element:hit(px, py, handler)
    if not self:contains(px, py) then return nil end
    local kids = self.children
    if kids then
        for i = #kids, 1, -1 do
            local found = kids[i]:hit(px, py, handler)
            if found then return found end
        end
    end
    if (self[handler] or self.swallow) and not self.disabled then return self end
    return nil
end

return Element
