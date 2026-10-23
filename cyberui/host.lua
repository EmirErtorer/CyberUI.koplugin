-- The one full-screen window CyberUI lives in. It paints the current screen's
-- element tree and an optional overlay (dialog or toast), turns touches into
-- taps, holds and swipes on elements, and gives instant press feedback.

local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local Screen = Device.screen

local Host = InputContainer:extend({
    name = "cyberui",
    covers_fullscreen = true,
    root = nil,        -- element tree of the current screen
    overlay = nil,     -- dialog element shown over it
    toast = nil,       -- notice element at the top
})

-- Full-screen gesture ranges and the Back key.
function Host:init()
    self.dimen = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
    local whole = function() return self.dimen end
    self.ges_events = {
        Tap = { GestureRange:new({ ges = "tap", range = whole }) },
        Hold = { GestureRange:new({ ges = "hold", range = whole }) },
        Swipe = { GestureRange:new({ ges = "swipe", range = whole }) },
    }
    if Device:hasKeys() then self.key_events.Back = { { "Back" } } end
end

-- Lay out the tree and overlays for the current screen size.
function Host:relayout()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen.w, self.dimen.h = w, h
    if self.root then self.root:layout(w, h) end
    if self.overlay then self.overlay:layout(self.overlay:naturalWidth() or w, nil) end
    if self.toast then self.toast:layout(nil, nil) end
    self.laid_w, self.laid_h = w, h
end

-- Show a new element tree.
function Host:setRoot(root)
    self.root = root
    self:relayout()
end

-- Where the overlay sits: centred.
function Host:overlayPos()
    local o = self.overlay
    return math.floor((self.dimen.w - o.w) / 2), math.floor((self.dimen.h - o.h) / 2)
end

-- Where the toast sits: centred near the top.
function Host:toastPos()
    local t = self.toast
    return math.floor((self.dimen.w - t.w) / 2), Theme.get().size.status + Theme.get().space.l
end

-- Paint background, screen, overlay and toast. A size change (rotation)
-- re-lays everything out first.
function Host:paintTo(bb, x, y)
    Theme.sync()
    if self.laid_w ~= Screen:getWidth() or self.laid_h ~= Screen:getHeight() then
        if self.on_resize then self.on_resize() else self:relayout() end
    end
    Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, Theme.get().c.bg)
    if self.root then self.root:paint(bb, x, y) end
    if self.overlay then
        local ox, oy = self:overlayPos()
        self.overlay:paint(bb, x + ox, y + oy)
    end
    if self.toast then
        local tx, ty = self:toastPos()
        self.toast:paint(bb, x + tx, y + ty)
    end
end

-- The box an element was painted in, as a Geom.
local function box(el)
    return Geom:new({ x = el.x, y = el.y, w = el.w, h = el.h })
end
Host.box = box

-- Flash the element inverted at once, run its action, then repaint the area
-- unless the action already redrew the screen.
function Host:press(el, handler)
    local d = box(el)
    Screen.bb:invertRect(d.x, d.y, d.w, d.h)
    UIManager:setDirty(nil, "fast", d)
    UIManager:forceRePaint()
    self.repainted = false
    el[handler](el)
    if not self.repainted and UIManager:isWidgetShown(self) then
        UIManager:setDirty(self, "ui", d)
    end
end

-- Mark that the screen was redrawn by the action (so press needs no restore).
function Host:markRepainted()
    self.repainted = true
end

-- Find what was touched: the overlay is modal and closes on a touch outside it.
function Host:target(pos, handler)
    if self.overlay then
        local el = self.overlay:hit(pos.x, pos.y, handler)
        if not el and not self.overlay:contains(pos.x, pos.y) and handler == "on_tap" and self.on_outside then
            self.on_outside()
        end
        return el
    end
    return self.root and self.root:hit(pos.x, pos.y, handler)
end

-- A tap runs the innermost element's on_tap.
function Host:onTap(_, ges)
    local el = self:target(ges.pos, "on_tap")
    if el then self:press(el, "on_tap") end
    return true
end

-- A hold runs on_hold, or nothing.
function Host:onHold(_, ges)
    local el = self:target(ges.pos, "on_hold")
    if el then self:press(el, "on_hold") end
    return true
end

-- Swipes go to the app (paging, the KOReader menu from the top edge).
function Host:onSwipe(_, ges)
    if self.on_swipe and not self.overlay then self.on_swipe(ges.direction, ges.pos) end
    return true
end

-- The Back key goes back a screen.
function Host:onBack()
    if self.on_back then self.on_back() end
    return true
end

return Host
