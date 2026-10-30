-- A square window onto a picture that can be dragged and zoomed: what the
-- reader frames to make their photo. The picture is scaled once per zoom and
-- a drag only moves the part blitted, so dragging stays cheap. Zoom is a
-- multiple of the picture fitted whole into the window; the window never
-- shows past the picture's edge unless the picture is smaller than it.

local Blitbuffer = require("ffi/blitbuffer")
local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local RenderImage = require("ui/renderimage")
local Theme = require("cyberui/theme")

local MAX_SIDE = 3000   -- the scaled picture is never larger than this on a side

local PhotoWindow = Element:extend({ size = 400 })

-- Start framing `img` (a flat colour buffer): the picture fills the window.
function PhotoWindow:init()
    local w, h = self.img:getWidth(), self.img:getHeight()
    self.fit = 1 / math.max(w, h)          -- scale at which the whole picture fits a window of side 1
    self.zoom = math.max(w, h) / math.min(w, h)   -- fills the window (no empty edge)
    self.ox, self.oy = 0, 0
    self.scaled, self.scaled_zoom = nil, nil
    self:centre()
end

-- Square, whatever room is given.
function PhotoWindow:naturalWidth() return self.size end
function PhotoWindow:naturalHeight() return self.size end

-- The window's side and the picture's scale at the zoom now.
function PhotoWindow:scale()
    return self.zoom * self.fit * (self.w or self.size)
end

-- The most the picture may be zoomed: as large as the scaled copy may be.
function PhotoWindow:maxZoom()
    return math.max(1, MAX_SIDE / (math.max(self.img:getWidth(), self.img:getHeight()) * self.fit * (self.w or self.size)))
end

-- The offsets the picture may have: it cannot leave the window, and a
-- picture smaller than the window stays in the middle.
function PhotoWindow:clamp()
    local s, side = self:scale(), self.w or self.size
    local sw, sh = self.img:getWidth() * s, self.img:getHeight() * s
    local function limit(v, extent)
        if extent <= side then return (extent - side) / 2 end
        return math.max(0, math.min(extent - side, v))
    end
    self.ox, self.oy = limit(self.ox, sw), limit(self.oy, sh)
end

-- Look at the middle of the picture.
function PhotoWindow:centre()
    local s, side = self:scale(), self.w or self.size
    self.ox = (self.img:getWidth() * s - side) / 2
    self.oy = (self.img:getHeight() * s - side) / 2
    self:clamp()
end

-- Zoom to z (kept in range), staying on the middle of what is in view.
function PhotoWindow:setZoom(z)
    local old, side = self:scale(), self.w or self.size
    local cx, cy = (self.ox + side / 2) / old, (self.oy + side / 2) / old
    self.zoom = math.max(1, math.min(self:maxZoom(), z))
    local s = self:scale()
    self.ox, self.oy = cx * s - side / 2, cy * s - side / 2
    self:clamp()
end

-- Drag: the picture follows the finger from where the touch began.
function PhotoWindow:on_drag(dx, dy, phase)
    if phase == "start" then
        self.from_x, self.from_y = self.ox, self.oy
    elseif phase == "move" then
        self.ox, self.oy = self.from_x - dx, self.from_y - dy
        self:clamp()
        require("cyberui/app").repaint(self)
    else
        require("cyberui/app").repaint(self, "ui")
    end
end

-- The square of the picture in view, as the picture's own pixels: x, y (which
-- may lie outside the picture) and the side.
function PhotoWindow:crop()
    local s, side = self:scale(), self.w or self.size
    return self.ox / s, self.oy / s, side / s
end

-- The picture scaled for the zoom now (kept until the zoom changes).
function PhotoWindow:scaledImage()
    if self.scaled and self.scaled_zoom == self.zoom and self.scaled_side == self.w then return self.scaled end
    if self.scaled then self.scaled:free() end
    local s = self:scale()
    self.scaled = RenderImage:scaleBlitBuffer(self.img, math.max(1, math.floor(self.img:getWidth() * s + 0.5)),
        math.max(1, math.floor(self.img:getHeight() * s + 0.5)), false)
    if self.scaled == self.img then self.scaled = self.img:copy() end
    self.scaled_zoom, self.scaled_side = self.zoom, self.w
    return self.scaled
end

-- Draw the part of the picture in view on a white page, with the frame.
function PhotoWindow:draw(bb, x, y)
    local th = Theme.get()
    local side = self.w
    self:clamp()
    Paint.fill(bb, x, y, side, side, Blitbuffer.COLOR_WHITE)
    local img = self:scaledImage()
    local ox, oy = math.floor(self.ox), math.floor(self.oy)
    local dx, dy = math.max(0, -ox), math.max(0, -oy)
    local sx, sy = math.max(0, ox), math.max(0, oy)
    local w, h = math.min(side - dx, img:getWidth() - sx), math.min(side - dy, img:getHeight() - sy)
    if w > 0 and h > 0 then bb:blitFrom(img, x + dx, y + dy, sx, sy, w, h) end
    Paint.frame(bb, x, y, side, side, th.size.stroke, th.c.ink)
    Paint.brackets(bb, x - th.size.stroke * 2, y - th.size.stroke * 2, side + th.size.stroke * 4, side + th.size.stroke * 4,
        th.size.bracket, th.size.stroke, th.c.accent)
end

-- Give back the memory.
function PhotoWindow:release()
    if self.scaled then self.scaled:free(); self.scaled = nil end
    if self.img then self.img:free(); self.img = nil end
end

return PhotoWindow
